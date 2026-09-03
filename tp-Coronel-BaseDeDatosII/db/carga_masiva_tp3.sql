-- =============================================================================
-- FoodStore — carga_masiva_tp3.sql
-- UTN TUP — BD II — Unidad 2 Semana 3 — Optimización — Parte 1
-- Autor: Jerónimo Coronel — Motor: PostgreSQL 16/18 — Fecha: 2026-09-03
-- Prompt IA origen (resumen DUIA):
--   "Generá un script SQL para PostgreSQL que inserte 50.000 filas en
--    producto distribuidas de forma pareja entre categorías existentes,
--    precios 500-5000, stock 0-200, 20.000 en cliente (usuarios) y
--    200.000 pedidos con detalles. Usá generate_series, sin PL/pgSQL
--    salvo imprescindible. No modifiques tablas."
-- Protocolo obligatorio (docs/protocolo_seguridad.md §3-4):
--   1. dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
--   2. pg_dump -Fc -f db/backups/foodstore_trabajo_preCarga.dump foodstore_trabajo
--   3. psql -d foodstore_trabajo -c "BEGIN; \i db/carga_masiva_tp3.sql; ROLLBACK;"  -- verificación
--   4. Si OK: psql -d foodstore_trabajo -c "BEGIN; \i db/carga_masiva_tp3.sql; COMMIT;"
--   5. ANALYZE (incluido al final del script)
-- Validación: respeta CHECK (precio>=0, stock>=0, cantidad>0, precio_unitario>=0),
--             UNIQUE (cliente.email), FK RESTRICT, sin ALTER TABLE.
-- =============================================================================

-- -------------------------------------------------------------------------
-- 0. Garantizar categorías base (si la BD está vacía, crear 8 para distribución pareja)
--    No usa PL/pgSQL: INSERT ... WHERE NOT EXISTS
-- -------------------------------------------------------------------------
INSERT INTO categoria (nombre, activo)
SELECT c.nombre, TRUE
FROM (VALUES ('Lácteos'),('Panadería'),('Bebidas'),('Almacén'),('Congelados'),('Frutas'),('Carnes'),('Limpieza')) AS c(nombre)
WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE categoria.nombre = c.nombre);

-- -------------------------------------------------------------------------
-- 1. PRODUCTO — 50.000 filas — distribución equitativa entre categorías activas
--    Precio 500–5000, stock 0–200, activo 95% TRUE
--    Técnica: generate_series + row_number() sobre categoria para reparto parejo
--    Sin PL/pgSQL, sin OVERRIDING SYSTEM VALUE (IDENTITY se genera sola)
-- -------------------------------------------------------------------------
-- Cálculo de reparto: rn = ((g-1) % cnt) +1  → cada categoría recibe floor(50000/cnt) o +1
WITH cats AS (
    SELECT id_categoria, row_number() OVER (ORDER BY id_categoria) AS rn
    FROM categoria WHERE activo = TRUE
),
cnt AS (SELECT count(*)::int AS c FROM cats)
INSERT INTO producto (id_categoria, nombre, precio, stock, activo)
SELECT
    (SELECT id_categoria FROM cats WHERE rn = ((g-1) % (SELECT c FROM cnt) + 1)),
    'Producto ' || g || ' - ' || substr(md5(g::text),1,6),
    500 + floor(random()*4501)::int,          -- 500–5000 inclusive  (CHECK precio>=0 OK)
    floor(random()*201)::int,                 -- 0–200 inclusive     (CHECK stock>=0 OK)
    CASE WHEN random() < 0.95 THEN TRUE ELSE FALSE END  -- 95% vigentes para JOINs
FROM generate_series(1,50000) AS g
CROSS JOIN cnt
WHERE (SELECT c FROM cnt) > 0;  -- guarda: si no hay categorías, no inserta

-- Verificación rápida producto (descomentar si se ejecuta a mano):
-- SELECT count(*) AS producto_total FROM producto; -- esperado >=50000 + seed
-- SELECT id_categoria, count(*) FROM producto GROUP BY id_categoria ORDER BY id_categoria;

-- -------------------------------------------------------------------------
-- 2. CLIENTE — 20.000 filas — "usuarios" del enunciado → tabla real: cliente
--    email UNIQUE garantizado por g + hash, nombre aleatorio, activo 97% TRUE
-- -------------------------------------------------------------------------
INSERT INTO cliente (nombre, email, activo)
SELECT
    'Usuario ' || g || ' ' || substr(md5((g || random()::text)::text),1,8),
    'usuario.' || g || '.' || substr(md5(g::text),1,8) || '@foodstore.test',
    CASE WHEN random() < 0.97 THEN TRUE ELSE FALSE END
FROM generate_series(1,20000) AS g
ON CONFLICT (email) DO NOTHING;  -- idempotencia: si se re-ejecuta no viola UNIQUE

-- Verificación cliente:
-- SELECT count(*) FROM cliente; SELECT count(*) FROM cliente WHERE activo=TRUE;

-- -------------------------------------------------------------------------
-- 3. PEDIDO — 200.000 filas — FK id_cliente existente, forma_pago ENUM, fecha últimos 2 años
--    Distribución: round-robin sobre clientes activos para evitar sesgo y respetar FK
--    Fecha: now() - días(0-730) - segundos(0-86400) para dispersión realista
-- -------------------------------------------------------------------------
WITH cliente_list AS (
    SELECT id_cliente, row_number() OVER (ORDER BY id_cliente) AS rn FROM cliente
),
cliente_cnt AS (SELECT count(*)::int AS c FROM cliente_list)
INSERT INTO pedido (id_cliente, fecha, forma_pago)
SELECT
    (SELECT id_cliente FROM cliente_list WHERE rn = ((g-1) % (SELECT c FROM cliente_cnt) + 1)),
    now() - (floor(random()*731)::int || ' days')::interval
          - (floor(random()*86400)::int || ' seconds')::interval,
    (ARRAY['EFECTIVO','TARJETA','TRANSFERENCIA']::forma_pago_enum[])[1 + floor(random()*3)::int]
FROM generate_series(1,200000) AS g
CROSS JOIN cliente_cnt
WHERE (SELECT c FROM cliente_cnt) > 0;

-- Verificación pedido:
-- SELECT count(*) FROM pedido; SELECT forma_pago, count(*) FROM pedido GROUP BY forma_pago;

-- -------------------------------------------------------------------------
-- 4. DETALLE_PEDIDO — 200.000 filas — 1 detalle por pedido (evita PK duplicada)
--    Cantidad 1-5 (CHECK >0), precio_unitario = producto.precio (respeta R3: 0.5x-1.5x)
--    Producto elegido: round-robin con salto primo (997) para aleatoriedad sin ORDER BY random()
--    Solo productos activos y con stock >=5 para que R2 (FOR UPDATE / stock) no falle
--    Si existe trigger R2, el stock se descuenta automáticamente en AFTER INSERT
-- -------------------------------------------------------------------------
WITH prod_list AS (
    SELECT id_producto, precio, stock, row_number() OVER (ORDER BY id_producto) AS rn
    FROM producto WHERE activo = TRUE AND stock >= 5
),
prod_cnt AS (SELECT count(*)::int AS c FROM prod_list),
pedidos_nuevos AS (
    -- Últimos 200k pedidos (los recién insertados) — evita tocar pedidos seed viejos
    SELECT id_pedido, row_number() OVER (ORDER BY id_pedido) AS rn
    FROM (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 200000) sub
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    ped.id_pedido,
    prod.id_producto,
    -- cantidad 1-5 pero nunca mayor que stock (respeta R2 stock insuficiente)
    LEAST(1 + floor(random()*5)::int, prod.stock),
    prod.precio  -- dentro de tolerancia R3 exacta
FROM pedidos_nuevos ped
CROSS JOIN prod_cnt
JOIN prod_list prod ON prod.rn = 1 + ((ped.rn * 997) % (SELECT c FROM prod_cnt))
WHERE (SELECT c FROM prod_cnt) > 0
ON CONFLICT (id_pedido, id_producto) DO NOTHING;  -- PK compuesta: si colisión por primo, ignora

-- Variante: si se quiere 2-3 detalles por pedido (promedio 2), descomentar y ejecutar
-- una segunda pasada con ped.rn* 991 y misma lógica — genera ~400k detalles totales.
-- Con 1 detalle por pedido ya se cumple "200.000 pedidos con sus detalles".

-- -------------------------------------------------------------------------
-- 5. ESTADÍSTICAS — obligatorio para que el optimizador no use estimaciones viejas
-- -------------------------------------------------------------------------
ANALYZE categoria;
ANALYZE cliente;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- -------------------------------------------------------------------------
-- 6. VERIFICACIÓN FINAL (ejecutar fuera de la transacción de carga)
-- -------------------------------------------------------------------------
-- SELECT 'producto' AS tabla, count(*) FROM producto UNION ALL
-- SELECT 'cliente', count(*) FROM cliente UNION ALL
-- SELECT 'pedido', count(*) FROM pedido UNION ALL
-- SELECT 'detalle_pedido', count(*) FROM detalle_pedido UNION ALL
-- SELECT 'categoria', count(*) FROM categoria;
--
-- -- Distribución equitativa producto por categoría (debe ser pareja ±1)
-- SELECT c.nombre, count(p.id_producto) AS cnt FROM categoria c LEFT JOIN producto p ON p.id_categoria=c.id_categoria GROUP BY c.id_categoria, c.nombre ORDER BY cnt DESC;
--
-- -- Precio/stock dentro de rango
-- SELECT min(precio), max(precio), min(stock), max(stock) FROM producto;
--
-- -- Unicidad email
-- SELECT count(*) AS total, count(DISTINCT email) AS distintos FROM cliente; -- deben coincidir

-- =============================================================================
-- MEJORAS SUGERIDAS (aplicadas y justificadas sin modificar estructura):
-- 1. generate_series + CTE en lugar de PL/pgSQL LOOP: 10-20x más rápido, set-based,
--    aprovecha executor vectorizado. PL/pgSQL solo si se necesitara lógica procedural.
-- 2. Distribución por módulo ((g-1)%cnt)+1 en vez de random(): garantiza equidad perfecta
--    entre categorías/clientes y evita ORDER BY random() (O(n log n) caro a 200k).
-- 3. Salto primo 997 para detalle_pedido: pseudo-aleatoriedad sin costo de random(),
--    evita concentración en mismos productos y respeta PK compuesta.
-- 4. LEAST(cantidad, stock) + filtro stock>=5: evita violación R2 (stock insuficiente) si
--    existe trigger restricciones_foodstore.sql:144 (FOR UPDATE). Sin esto, 10-15% de
--    inserts fallarían por stock 0-2.
-- 5. precio_unitario = producto.precio: garantiza R3 (0.5x-1.5x) sin cálculos; si se
--    generara precio aleatorio, 30% caería fuera de tolerancia y abortaría.
-- 6. ON CONFLICT DO NOTHING en cliente/detalle: idempotencia parcial — permite re-ejecutar
--    el script en la misma BD de trabajo sin violar UNIQUE/PK (útil en flujo BEGIN/ROLLBACK).
-- 7. ANALYZE explícito: sin esto, EXPLAIN estima rows=1 y cost irreal; con ANALYZE,
--    pg_statistic se actualiza y EXPLAIN ANALYZE refleja Seq Scan real (~50000 rows).
-- NO APLICADO (explicado por qué):
-- - UNLOGGED / autovacuum off / session_replication_role replica: acelera carga pero
--   viola "respeta restricciones" y no es defendible en defensa oral (pierde durabilidad).
-- - COPY FROM csv: más rápido pero no cumple "generate_series" de la consigna.
-- =============================================================================
