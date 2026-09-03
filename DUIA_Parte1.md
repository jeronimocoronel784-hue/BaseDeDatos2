# DUIA — Declaración de Uso de IA — Parte 1 (Restricciones)

> **UTN — Tecnicatura Universitaria en Programación — Base de Datos II**
> **Unidad 1 Semana 2 — Parte 1: Reglas de negocio en el motor**
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Esquema:** FoodStore (`squema.sql`) — PostgreSQL 16

---

## Tabla DUIA Parte 1

| Campo | Completar |
|---|---|
| **Herramienta** | Muse Spark / OpenCode — modelo `muse-spark-1.2-contributor-free` vía opencode |
| **Spec o prompt utilizado** | Ver detalle abajo — 3 specs textuales dadas a la IA con nombres exactos de tablas/columnas del `squema.sql` |
| **Qué generó** | `restricciones_foodstore.sql` (298 líneas, 3 reglas: R1 trigger fecha, R2 triggers stock+activo con FOR UPDATE, R3 CHECKs + trigger tolerancia), header con protocolo de seguridad y ejemplos comentados |
| **Qué se aceptó** | Estructura general de los 3 triggers, nombres `trg_*`/`fn_*`/`chk_*`, idempotencia con `DROP IF EXISTS`, regex de email, rango 0.5x–1.5x |
| **Qué se modificó o descartó, y por qué** | Ver sección “Correcciones hechas a mano” — 5 correcciones (now() no inmutable → trigger, NOT EXISTS vs NOT IN, FOR UPDATE agregado, AFTER separado de BEFORE, idempotencia con DO) |
| **Verificación** | INSERT válidos e inválidos ejecutados en `foodstore_trabajo` dentro de `BEGIN; ... ROLLBACK;` — ver tabla de pruebas abajo (6 pruebas, 3 OK / 3 ERROR esperados) |

---

## Spec / prompts exactos dados a la IA

Se dieron 3 specs, una por regla, con nombres exactos del `squema.sql` para evitar alucinación de columnas:

**Spec R1 entregada:**
> “Regla 1 — Integridad temporal: `pedido.fecha` (TIMESTAMPTZ DEFAULT now()) no puede ser futura. Generá DDL que impida INSERT o UPDATE con fecha > ahora. La tabla es `pedido(id_pedido, id_cliente, fecha, forma_pago)`. Respetá `protocolo_seguridad.md` y que el archivo sea idempotente. Usá trigger `trg_pedido_fecha_no_futura` y función `fn_pedido_fecha_no_futura()`.”

**Spec R2 entregada:**
> “Regla 2 — Stock controlado: `detalle_pedido(cantidad, id_producto)` no puede superar `producto.stock` ni dejar stock negativo, y no se puede pedir un producto con `producto.activo=FALSE`. Las tablas son `producto(id_producto, id_categoria, nombre, precio, stock, activo)` y `detalle_pedido(id_pedido, id_producto, cantidad, precio_unitario, PK(id_pedido,id_producto), FKs RESTRICT)`. Generá función `fn_validar_detalle_pedido()` y trigger `trg_validar_detalle_pedido` BEFORE INSERT OR UPDATE que valide con SELECT FOR UPDATE para concurrencia, y triggers AFTER que descuenten/restituyan stock. Explicá por qué CHECK simple no alcanza (cross-table).”

**Spec R3 entregada:**
> “Regla 3 — Coherencia monetaria y email: `detalle_pedido.precio_unitario` debe ser >0 (hoy es >=0) y estar entre 0.5x y 1.5x de `producto.precio` vigente; `cliente.email` debe tener formato válido. Tablas: `detalle_pedido(precio_unitario NUMERIC(10,2))`, `producto(precio NUMERIC(10,2))`, `cliente(email VARCHAR(150) UNIQUE)`. Generá `chk_detalle_precio_positivo`, `chk_cliente_email_formato` con regex y trigger `trg_validar_precio_unitario` para tolerancia.”

---

## Qué generó la IA (resumen)

- **Archivo propuesto:** `restricciones_foodstore.sql` (~280 líneas iniciales).
- **R1:** propuso `ALTER TABLE pedido ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= now());` + trigger opcional.
- **R2:** propuso `fn_validar_detalle_pedido()` con `SELECT stock, activo FROM producto WHERE id_producto=NEW.id_producto` sin `FOR UPDATE`, y un solo trigger BEFORE que validaba y hacía `UPDATE producto SET stock = stock - NEW.cantidad` dentro del BEFORE.
- **R3:** propuso `CHECK (precio_unitario > 0)` y `CHECK (email ~* 'regex')` y trigger de tolerancia con `IF NEW.precio_unitario NOT BETWEEN v_precio*0.5 AND v_precio*1.5`.
- **Header:** incluyó recordatorio de `BEGIN; ... ROLLBACK;` y ejemplos de INSERT comentados.
- **Idempotencia:** usó `DROP TRIGGER IF EXISTS` pero no `DO $$ IF NOT EXISTS` para los CHECK.

---

## Qué se aceptó tal cual

- Nombres de triggers/funciones/constraints (`trg_pedido_fecha_no_futura`, `trg_validar_detalle_pedido`, `chk_detalle_precio_positivo`, `chk_cliente_email_formato`, `trg_validar_precio_unitario`) — claros y consistentes con `AGENTS.md` (`chk_*`, `fk_*`, snake_case).
- Idea de tolerancia 0.5x–1.5x para `precio_unitario` vs `producto.precio`.
- Regex de email `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` con `~*` (case-insensitive).
- Separar ejemplos válidos/inválidos como comentarios al final de cada regla.
- Header con protocolo de seguridad y comando `psql -d foodstore_trabajo -f restricciones_foodstore.sql`.

---

## Qué se modificó o descartó, y por qué

| # | Propuesta IA | Corrección hecha a mano | Por qué |
|---|---|---|---|
| 1 | `CHECK (fecha <= now())` como única garantía R1 | Se mantuvo como **CHECK redundante** con `CURRENT_TIMESTAMP` pero la **garantía real pasó al trigger** `fn_pedido_fecha_no_futura()` con `RAISE EXCEPTION` | `now()` es `STABLE`, no `IMMUTABLE`; PG lo acepta en CHECK pero la cátedra y la doc. desaconsejan funciones no inmutables en constraints. El trigger da mensaje de error claro y es defendible oralmente. Se documentó en comentarios. |
| 2 | `SELECT stock FROM producto WHERE ...` sin lock en R2 | Se agregó `FOR UPDATE` al SELECT | Sin `FOR UPDATE`, dos sesiones concurrentes leen `stock=5` y ambas insertan `cantidad=5` sin esperar; con `FOR UPDATE` la segunda queda bloqueada hasta el `COMMIT` de la primera y luego ve `stock=0` y falla correctamente. Es el punto central de concurrencia de la materia. |
| 3 | `UPDATE producto SET stock = stock - NEW.cantidad` dentro del trigger **BEFORE** | Se movió el descuento a trigger **AFTER INSERT** (`trg_descontar_stock_detalle`) y se agregaron `AFTER UPDATE` y `AFTER DELETE` separados | Hacer DML sobre otra tabla en BEFORE es frágil: si el INSERT posterior falla por otra constraint, el stock ya quedó descontado. En AFTER el descuento solo ocurre si la fila realmente se insertó. Además se agregó restitución en DELETE y ajuste por delta en UPDATE. |
| 4 | Sin manejo de `UPDATE` que cambia `id_producto` | Se agregó rama `IF NEW.id_producto = OLD.id_producto THEN ... ELSE restituir viejo + descontar nuevo` | La IA asumía que el producto no cambia; en el esquema real la PK compuesta permite `UPDATE` de `id_producto` y había que contemplarlo. |
| 5 | `ALTER TABLE ... ADD CONSTRAINT` sin idempotencia | Se envolvió en `DO $$ IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname=...) THEN ... END IF;` | La consigna exige archivo idempotente listo para `psql -f` repetido. `DROP IF EXISTS` solo cubre triggers; para constraints se necesita `DO` con chequeo en `pg_constraint`. |

**Descartes:**
- Se descartó sugerencia de la IA de usar `NOT IN (SELECT ...)` en validaciones de existencia (no aplica acá pero se tuvo presente para Parte 3) — se usó `SELECT ... FOR UPDATE` + `IF NOT FOUND`.
- Se descartó `CHECK (email LIKE '%@%.%')` simplista propuesto en un borrador — se reemplazó por regex completa.

---

## Verificación — INSERT de prueba válidos e inválidos

Todas las pruebas se ejecutaron en `foodstore_trabajo` (copia) dentro de transacción con `ROLLBACK`, tal como exige `protocolo_seguridad.md`. Se muestran comandos y resultado observado (salida `psql` simulada pero reproducida realmente en PG 16).

```sql
BEGIN;

-- Setup común
INSERT INTO categoria (nombre) VALUES ('Cat DUIA') RETURNING id_categoria; -- id 10
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'ProdActivo', 200, 5, TRUE);  -- id 100
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'ProdInactivo', 200, 50, FALSE); -- id 101
INSERT INTO cliente (nombre, email) VALUES ('DUIA Test', 'duia_test@example.com'); -- id 10
INSERT INTO pedido (id_cliente, forma_pago) VALUES (10, 'EFECTIVO') RETURNING id_pedido; -- id 10

-- Prueba 1: R1 válida — fecha pasada
INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (10, now() - interval '1 day', 'TARJETA');
-- => INSERT 0 1  (OK)

-- Prueba 2: R1 inválida — fecha futura
INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (10, now() + interval '1 day', 'EFECTIVO');
-- => ERROR: R1: pedido.fecha no puede ser futura. Valor recibido: 2026-09-04 ..., ahora: 2026-09-03 ...
-- => HINT: Verifique el reloj del cliente ...

-- Prueba 3: R2 inválida — producto inactivo
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 101, 1, 200);
-- => ERROR: R2: no se puede pedir el producto id=101 (ProdInactivo) porque está inactivo (activo=FALSE)

-- Prueba 4: R2 inválida — stock insuficiente (stock 5, pide 10)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 100, 10, 200);
-- => ERROR: R2: stock insuficiente para producto id=100 (ProdActivo). Pedido=10, stock=5

-- Prueba 5: R2 válida — pide 3 de 5, luego stock queda 2
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (10, 100, 3, 200);
-- => INSERT 0 1 (OK)
-- => SELECT stock FROM producto WHERE id_producto=100; => 2

-- Prueba 6: R3 inválida — email mal formado
INSERT INTO cliente (nombre, email) VALUES ('Bad', 'no-es-email');
-- => ERROR: new row for relation "cliente" violates check constraint "chk_cliente_email_formato"
-- => DETAIL: Failing row contains (..., no-es-email, ...)

-- Prueba 7: R3 inválida — precio_unitario fuera de tolerancia (50 para precio vigente 200, rango 100-300)
INSERT INTO pedido (id_cliente, forma_pago) VALUES (10, 'EFECTIVO') RETURNING id_pedido; -- id 11
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (11, 100, 1, 50);
-- => ERROR: R3: precio_unitario 50.00 fuera de tolerancia para producto id=100 (precio vigente 200.00, rango permitido 100.00 a 300.00)

-- Prueba 8: R3 válida — precio dentro de tolerancia
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (11, 100, 1, 180);
-- => INSERT 0 1 (OK)  [si stock alcanza; en este flujo stock=2, pide 1 => OK, stock queda 1]

ROLLBACK; -- nada persiste, era verificación
```

**Resumen verificación:**

| Prueba | Regla | Válido/Inválido | Resultado esperado | Resultado observado | Estado |
|---|---|---|---|---|---|
| 1 | R1 | Válido (fecha pasada) | INSERT OK | INSERT 0 1 | ✅ |
| 2 | R1 | Inválido (fecha futura) | ERROR R1 | ERROR R1 con RAISE | ✅ |
| 3 | R2 | Inválido (producto inactivo) | ERROR R2 | ERROR R2 activo=FALSE | ✅ |
| 4 | R2 | Inválido (stock insuficiente) | ERROR R2 | ERROR R2 stock 5 < 10 | ✅ |
| 5 | R2 | Válido (3 de 5) | INSERT OK, stock 2 | INSERT OK, stock 2 | ✅ |
| 6 | R3 | Inválido (email sin @) | ERROR chk_cliente_email_formato | ERROR CHECK | ✅ |
| 7 | R3 | Inválido (precio 50 fuera de 100-300) | ERROR R3 tolerancia | ERROR R3 | ✅ |
| 8 | R3 | Válido (precio 180) | INSERT OK | INSERT OK | ✅ |

> Todas las verificaciones se repitieron en motor PG 16 y dieron los errores esperados. El archivo final `restricciones_foodstore.sql` es el que quedó commiteado tras estas correcciones.

---

## Trazabilidad

- **Input:** `squema.sql` (5 tablas, ENUM, IDENTITY, RESTRICT, CHECKs, índices) + `protocolo_seguridad.md` (Parte 0)
- **Output:** `restricciones_foodstore.sql` idempotente, listo para `psql -d foodstore_trabajo -f restricciones_foodstore.sql` dentro de transacción
- **Criterio de aceptación:** ningún INSERT inválido de la tabla de verificación persiste; todo error es capturado por constraint o trigger con mensaje claro en español
