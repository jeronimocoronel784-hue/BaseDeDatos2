-- =============================================================================
-- restricciones_foodstore.sql
-- UTN — Tecnicatura Universitaria en Programación — Base de Datos II
-- Unidad 1 Semana 2 — Parte 1: Reglas de negocio en el motor
-- Autor: Jerónimo Coronel — Fecha: 2026-09-03 — Motor: PostgreSQL 16
-- Esquema: FoodStore (categoria, cliente, producto, pedido, detalle_pedido)
-- =============================================================================
-- PROTOCOLO DE SEGURIDAD — RECORDATORIO OBLIGATORIO
-- -------------------------------------------------------------------------
-- ¡NO ejecutar fuera de transacción! Flujo exigido por protocolo_seguridad.md:
--
--   dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
--   mkdir -p backups; pg_dump -Fc -f backups/foodstore_trabajo_20260903_preDDL.dump foodstore_trabajo
--   psql -d foodstore_trabajo <<'SQL'
--     BEGIN;
--     \i restricciones_foodstore.sql
--     -- verificar: SELECT conname FROM pg_constraint; SELECT tgname FROM pg_trigger;
--     ROLLBACK;  -- primero verificar, luego repetir con COMMIT si todo ok
--   SQL
--
-- Solo cuando ROLLBACK mostró que todo es correcto:
--   psql -d foodstore_trabajo -c "BEGIN; \i restricciones_foodstore.sql; COMMIT;"
--
-- Este archivo es idempotente: puede re-ejecutarse N veces sin error
-- (DROP IF EXISTS / CREATE OR REPLACE / ADD CONSTRAINT IF NOT EXISTS donde PG lo permite).
-- Para compatibilidad con PG < 9.6 se emula IF NOT EXISTS con bloques DO.
-- =============================================================================

\echo '=== restricciones_foodstore.sql — FoodStore — Jerónimo Coronel — 2026-09-03 ==='
\echo 'Ejecutar SIEMPRE dentro de BEGIN/COMMIT y sobre foodstore_trabajo (ver header).'

-- =============================================================================
-- REGLA 1 (R1): Integridad temporal — pedido.fecha no puede ser futura
-- =============================================================================
-- Spec IA: "pedido.fecha no puede ser futura (no se puede registrar un pedido
--           con fecha posterior a ahora)"
-- Qué garantiza: evita pedidos con timestamp futuro por error de app, reloj
--                desfasado o carga manual. Protege reportes, auditoría y
--                orden cronológico. Complementa el DEFAULT now() que solo
--                pone valor por defecto pero no valida si se inserta explícito.
-- Por qué no alcanza un CHECK simple: CHECK (fecha <= now()) parece válido
--                pero now() / CURRENT_TIMESTAMP es STABLE, no IMMUTABLE.
--                PG lo permite en CHECK pero lo evalúa al INSERT/UPDATE con
--                el now() de la transacción; aun así el estándar desaconseja
--                funciones no inmutables en CHECK y pg_dump puede tener
--                matices. La forma robusta y defendible es un TRIGGER
--                BEFORE que hace RAISE EXCEPTION con mensaje claro.
--                Se deja también un CHECK redundante con CURRENT_TIMESTAMP
--                como documentación, pero la garantía real es el trigger.
-- =============================================================================

-- Limpieza idempotente R1
DROP TRIGGER IF EXISTS trg_pedido_fecha_no_futura ON pedido;
DROP FUNCTION IF EXISTS fn_pedido_fecha_no_futura();

-- Función trigger R1: rechaza fecha futura
CREATE OR REPLACE FUNCTION fn_pedido_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    -- Compara con now() (hora del servidor, TIMESTAMPTZ). Tolerancia 0: cualquier
    -- valor > now() es futuro. Si se quiere tolerancia de 1s por clock skew,
    -- cambiar a: IF NEW.fecha > (now() + interval '1 second') THEN
    IF NEW.fecha > now() THEN
        RAISE EXCEPTION 'R1: pedido.fecha no puede ser futura. Valor recibido: %, ahora: %', NEW.fecha, now()
            USING ERRCODE = '23514', HINT = 'Verifique el reloj del cliente o no envíe fecha explícita futura.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger R1
CREATE TRIGGER trg_pedido_fecha_no_futura
    BEFORE INSERT OR UPDATE OF fecha ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_pedido_fecha_no_futura();

-- CHECK redundante documentativo (si PG lo acepta, queda como segunda barrera).
-- Se envuelve en DO para idempotencia.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_pedido_fecha_no_futura'
    ) THEN
        ALTER TABLE pedido
            ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= CURRENT_TIMESTAMP);
    END IF;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END;
$$;

-- Ejemplos R1 (comentados, para probar dentro de transacción con ROLLBACK):
-- -- Válido: fecha ahora o pasada
-- INSERT INTO cliente (nombre, email) VALUES ('Test R1', 'r1_test@example.com');
-- INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (
--     (SELECT id_cliente FROM cliente WHERE email='r1_test@example.com'),
--     now() - interval '1 hour', 'EFECTIVO'
-- ); -- OK
-- INSERT INTO pedido (id_cliente, forma_pago) VALUES (
--     (SELECT id_cliente FROM cliente WHERE email='r1_test@example.com'), 'TARJETA'
-- ); -- OK (usa DEFAULT now())
--
-- -- Inválido: fecha futura -> debe dar ERROR R1
-- INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (
--     (SELECT id_cliente FROM cliente WHERE email='r1_test@example.com'),
--     now() + interval '1 day', 'TRANSFERENCIA'
-- ); -- ERROR: R1: pedido.fecha no puede ser futura
-- UPDATE pedido SET fecha = now() + interval '1 year' WHERE id_pedido = 1; -- ERROR


-- =============================================================================
-- REGLA 2 (R2): Stock controlado — detalle_pedido valida stock y activo
-- =============================================================================
-- Spec IA: "detalle_pedido.cantidad no puede superar el stock disponible ni
--           dejar stock negativo; además no se puede pedir un producto inactivo"
-- Qué garantiza:
--   a) No se puede insertar/actualizar un detalle si producto.activo = FALSE
--   b) No se puede pedir más de lo que hay (cantidad <= producto.stock)
--   c) Con SELECT FOR UPDATE evita carrera: dos sesiones que leen stock=5
--      y piden 5 cada una no pueden pasar ambas (la segunda espera el lock
--      y luego ve stock ya descontado).
-- Por qué CHECK no alcanza: CHECK solo ve la fila de detalle_pedido, no puede
--                hacer SELECT a producto.stock ni a producto.activo (cross-table).
--                Necesita trigger con acceso a otra tabla.
-- Estrategia: trigger BEFORE valida; trigger AFTER descuenta stock.
--             El descuento se hace en AFTER para no tocar stock si el INSERT
--             falla por otra constraint. UPDATE de stock usa stock = stock - NEW.cantidad.
--             Para UPDATE de detalle, se ajusta por delta.
--             Para DELETE, se restituye stock (opcional pero incluido).
-- Concurrencia: SELECT ... FOR UPDATE bloquea la fila de producto hasta COMMIT,
--               serializando pedidos concurrentes sobre el mismo producto.
-- =============================================================================

-- Limpieza idempotente R2
DROP TRIGGER IF EXISTS trg_validar_detalle_pedido ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_descontar_stock_detalle ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_actualizar_stock_detalle ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_restituir_stock_detalle ON detalle_pedido;
DROP FUNCTION IF EXISTS fn_validar_detalle_pedido();
DROP FUNCTION IF EXISTS fn_descontar_stock_detalle();
DROP FUNCTION IF EXISTS fn_actualizar_stock_detalle();
DROP FUNCTION IF EXISTS fn_restituir_stock_detalle();

-- Función BEFORE: valida activo y stock con lock
CREATE OR REPLACE FUNCTION fn_validar_detalle_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INTEGER;
    v_activo BOOLEAN;
    v_precio NUMERIC(10,2);
    v_nombre TEXT;
BEGIN
    -- Bloquea la fila de producto para esta transacción (evita carrera)
    SELECT stock, activo, precio, nombre
      INTO v_stock, v_activo, v_precio, v_nombre
    FROM producto
    WHERE id_producto = NEW.id_producto
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'R2: producto id=% no existe', NEW.id_producto
            USING ERRCODE = '23503';
    END IF;

    IF v_activo = FALSE THEN
        RAISE EXCEPTION 'R2: no se puede pedir el producto id=% (%) porque está inactivo (activo=FALSE)', NEW.id_producto, v_nombre
            USING ERRCODE = '23514', HINT = 'Active el producto o elija otro vigente.';
    END IF;

    -- Para INSERT: validar cantidad <= stock actual
    -- Para UPDATE: validar delta. Si aumenta cantidad, verificar que el incremento no supere stock.
    IF TG_OP = 'INSERT' THEN
        IF NEW.cantidad > v_stock THEN
            RAISE EXCEPTION 'R2: stock insuficiente para producto id=% (%). Pedido=%, stock=%', NEW.id_producto, v_nombre, NEW.cantidad, v_stock
                USING ERRCODE = '23514';
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Si cambia de producto, validar contra el nuevo producto (ya lockeado)
        -- Si es mismo producto, validar delta
        IF NEW.id_producto = OLD.id_producto THEN
            -- stock actual ya refleja que OLD.cantidad aún no se descontó/restituyó en esta tx
            -- Para UPDATE dentro de misma tx, el AFTER de la fila anterior ya ajustó stock,
            -- pero como estamos en BEFORE del UPDATE, v_stock es el stock post-INSERT.
            -- Validamos que (v_stock + OLD.cantidad - NEW.cantidad) >= 0
            -- Simplificado: NEW.cantidad - OLD.cantidad <= v_stock
            IF (NEW.cantidad - OLD.cantidad) > v_stock THEN
                RAISE EXCEPTION 'R2: stock insuficiente al modificar detalle producto id=% (%). Delta=%, stock=%', NEW.id_producto, v_nombre, (NEW.cantidad - OLD.cantidad), v_stock
                    USING ERRCODE = '23514';
            END IF;
        ELSE
            -- Cambio de producto: validar como INSERT contra nuevo producto
            IF NEW.cantidad > v_stock THEN
                RAISE EXCEPTION 'R2: stock insuficiente para nuevo producto id=% (%). Pedido=%, stock=%', NEW.id_producto, v_nombre, NEW.cantidad, v_stock
                    USING ERRCODE = '23514';
            END IF;
            -- El stock del producto viejo se restituirá en el trigger de UPDATE (ver fn_actualizar...)
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_detalle_pedido
    BEFORE INSERT OR UPDATE OF id_producto, cantidad ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_detalle_pedido();

-- Función AFTER INSERT: descuenta stock
CREATE OR REPLACE FUNCTION fn_descontar_stock_detalle()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
    -- Salvaguarda: si por alguna razón quedó negativo (no debería por BEFORE), abortar
    IF (SELECT stock FROM producto WHERE id_producto = NEW.id_producto) < 0 THEN
        RAISE EXCEPTION 'R2: stock negativo detectado post-descuento producto id=%', NEW.id_producto
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descontar_stock_detalle
    AFTER INSERT ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_descontar_stock_detalle();

-- Función AFTER UPDATE: ajusta stock por delta o por cambio de producto
CREATE OR REPLACE FUNCTION fn_actualizar_stock_detalle()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_producto = OLD.id_producto THEN
        -- Mismo producto: ajustar por diferencia
        UPDATE producto SET stock = stock - (NEW.cantidad - OLD.cantidad)
        WHERE id_producto = NEW.id_producto;
    ELSE
        -- Producto distinto: restituir al viejo, descontar del nuevo
        UPDATE producto SET stock = stock + OLD.cantidad
        WHERE id_producto = OLD.id_producto;
        UPDATE producto SET stock = stock - NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_stock_detalle
    AFTER UPDATE OF id_producto, cantidad ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_actualizar_stock_detalle();

-- Función AFTER DELETE: restituye stock
CREATE OR REPLACE FUNCTION fn_restituir_stock_detalle()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto SET stock = stock + OLD.cantidad
    WHERE id_producto = OLD.id_producto;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restituir_stock_detalle
    AFTER DELETE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_restituir_stock_detalle();

-- Ejemplos R2 (comentados, probar con ROLLBACK):
-- -- Setup
-- INSERT INTO categoria (nombre) VALUES ('Lácteos R2') RETURNING id_categoria; -- supongamos 10
-- INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Yogur R2', 100, 5, TRUE) RETURNING id_producto; -- supongamos 100
-- INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Inactivo R2', 100, 50, FALSE) RETURNING id_producto; -- 101
-- INSERT INTO cliente (nombre, email) VALUES ('Cliente R2', 'r2@example.com') RETURNING id_cliente; -- 10
-- INSERT INTO pedido (id_cliente, forma_pago) VALUES (10, 'EFECTIVO') RETURNING id_pedido; -- 10
--
-- -- Válido: pide 3 de 5 -> stock queda 2
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 100, 3, 100); -- OK
-- -- Inválido: pide 10 de 2 (stock remanente) -> ERROR R2 stock insuficiente
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 100, 10, 100); -- ERROR
-- -- Inválido: producto inactivo -> ERROR R2
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 101, 1, 100); -- ERROR
-- -- Concurrencia: Sesión A: BEGIN; INSERT ... (lock); Sesión B: INSERT mismo producto -> queda WAITING hasta COMMIT de A


-- =============================================================================
-- REGLA 3 (R3): Coherencia monetaria y email — precio_unitario >0 y email válido
--               + tolerancia de precio vs precio vigente
-- =============================================================================
-- Spec IA: "precio_unitario debe ser >0 y no desviarse brutalmente del precio
--           vigente; email con formato válido"
-- Qué garantiza:
--   a) precio_unitario > 0 (refuerza el CHECK >=0 del esquema a >0 estricto)
--   b) precio_unitario entre 0.5x y 1.5x del producto.precio al momento de la
--      inserción (evita errores de carga: 10 vs 1000 por coma mal puesta)
--   c) cliente.email con formato RFC básico (regex)
-- Por qué trigger para (b): necesita comparar con producto.precio (cross-table).
--                El CHECK >0 sí puede ser constraint simple; la tolerancia no.
-- =============================================================================

-- R3a: CHECK precio_unitario > 0 (refuerzo). Idempotente via DO.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_detalle_precio_positivo') THEN
        ALTER TABLE detalle_pedido
            ADD CONSTRAINT chk_detalle_precio_positivo CHECK (precio_unitario > 0);
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

-- R3b: CHECK email formato válido. Idempotente via DO.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_cliente_email_formato') THEN
        ALTER TABLE cliente
            ADD CONSTRAINT chk_cliente_email_formato
            CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

-- R3c: Trigger tolerancia precio (0.5x a 1.5x)
DROP TRIGGER IF EXISTS trg_validar_precio_unitario ON detalle_pedido;
DROP FUNCTION IF EXISTS fn_validar_precio_unitario();

CREATE OR REPLACE FUNCTION fn_validar_precio_unitario()
RETURNS TRIGGER AS $$
DECLARE
    v_precio_vigente NUMERIC(10,2);
    v_min NUMERIC(10,2);
    v_max NUMERIC(10,2);
BEGIN
    SELECT precio INTO v_precio_vigente FROM producto WHERE id_producto = NEW.id_producto;
    IF NOT FOUND THEN
        RETURN NEW; -- deja que FK falle con su propio mensaje
    END IF;
    -- Si precio vigente es 0, solo validar >0 (ya hecho por CHECK)
    IF v_precio_vigente = 0 THEN
        RETURN NEW;
    END IF;
    v_min := v_precio_vigente * 0.5;
    v_max := v_precio_vigente * 1.5;
    IF NEW.precio_unitario < v_min OR NEW.precio_unitario > v_max THEN
        RAISE EXCEPTION 'R3: precio_unitario % fuera de tolerancia para producto id=% (precio vigente %, rango permitido % a %)', NEW.precio_unitario, NEW.id_producto, v_precio_vigente, v_min, v_max
            USING ERRCODE = '23514', HINT = 'Verifique coma decimal o use precio vigente. Para forzar, ajuste producto.precio primero.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_precio_unitario
    BEFORE INSERT OR UPDATE OF precio_unitario, id_producto ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_precio_unitario();

-- Ejemplos R3 (comentados, probar con ROLLBACK):
-- -- Válido
-- INSERT INTO cliente (nombre, email) VALUES ('Ana R3', 'ana.r3@example.com'); -- OK
-- INSERT INTO producto (id_categoria, nombre, precio, stock) VALUES (1, 'Pan R3', 200, 10) RETURNING id_producto; -- supongamos 200, precio 200
-- INSERT INTO pedido (id_cliente, forma_pago) VALUES ((SELECT id_cliente FROM cliente WHERE email='ana.r3@example.com'), 'EFECTIVO') RETURNING id_pedido;
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, 200); -- OK (dentro de 100-300)
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, 180); -- OK
--
-- -- Inválido: precio_unitario = 0 -> ERROR chk_detalle_precio_positivo
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, 0); -- ERROR
-- -- Inválido: precio_unitario = -5 -> ERROR
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, -5); -- ERROR
-- -- Inválido: precio_unitario 50 para producto de 200 -> fuera de 100-300 -> ERROR R3 tolerancia
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, 50); -- ERROR
-- -- Inválido: precio_unitario 500 para producto de 200 -> ERROR
-- INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (..., 200, 1, 500); -- ERROR
-- -- Inválido: email sin @
-- INSERT INTO cliente (nombre, email) VALUES ('Bad', 'no-es-email'); -- ERROR chk_cliente_email_formato
-- INSERT INTO cliente (nombre, email) VALUES ('Bad2', 'a@b'); -- ERROR (TLD muy corto)
-- INSERT INTO cliente (nombre, email) VALUES ('Bad3', 'a@b.c'); -- ERROR (TLD 1 letra)


-- =============================================================================
-- VERIFICACIÓN POST-INSTALACIÓN (descomentar para validar)
-- =============================================================================
-- SELECT conname, contype, consrc FROM pg_constraint WHERE conname LIKE 'chk_%' ORDER BY conname;
-- SELECT tgname, tgenabled, tgtype FROM pg_trigger WHERE tgname LIKE 'trg_%' ORDER BY tgname;
-- SELECT proname FROM pg_proc WHERE proname LIKE 'fn_%validar%' OR proname LIKE 'fn_%pedido%' OR proname LIKE 'fn_%descontar%' ORDER BY proname;

\echo '=== restricciones_foodstore.sql aplicado. Verificar con SELECT * FROM pg_constraint / pg_trigger. Recuerde COMMIT o ROLLBACK según protocolo. ==='
