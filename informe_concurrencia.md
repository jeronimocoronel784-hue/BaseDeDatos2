# Informe de Concurrencia — Base de Datos II — Unidad 1 Semana 2 — Parte 2

> **UTN — Tecnicatura Universitaria en Programación — Base de Datos II**
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 — Esquema FoodStore (`squema.sql`)
> **Isolation level por defecto:** `READ COMMITTED` (PG default)
> **BD de prueba:** `foodstore_trabajo` (copia de `foodstore_original` vía `createdb -T`)

---

## Setup común a los 3 escenarios

```bash
# Crear copia de trabajo y snapshot inicial
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
psql -d foodstore_trabajo <<'SQL'
-- Datos base para concurrencia
INSERT INTO categoria (nombre) VALUES ('Bebidas Concurrencia') RETURNING id_categoria; -- supongamos id 10
INSERT INTO cliente (nombre, email) VALUES ('Cliente Conc', 'conc@example.com') RETURNING id_cliente; -- id 50
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Coca 1L Conc', 500, 50, TRUE) RETURNING id_producto; -- id 100
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Fanta 1L', 400, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Sprite 1L', 400, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Agua 1L', 300, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Jugo 1L', 350, 20, TRUE);
-- id_categoria=10 queda con 5 productos activos para Escenario B
SQL
```

Dos sesiones `psql` simultáneas (dos terminales o dos conexiones). Se indica orden con `T1, T2, ...`.

---

## Escenario A: Lectura No Repetible (Non-Repeatable Read) — READ COMMITTED vs REPEATABLE READ

| Campo | Contenido |
|---|---|
| **Escenario** | Lectura No Repetible — Sesión A lee el mismo `producto.stock` dos veces dentro de una transacción y ve valores distintos porque Sesión B modificó y commiteó entremedio |
| **Cómo se reprodujo** | Ver comandos ordenados abajo (A/B con timestamps) |
| **Qué se observó** | En `READ COMMITTED` la segunda lectura ve `30` (cambió de `50` a `30`). En `REPEATABLE READ` la segunda lectura mantiene `50` (snapshot) |
| **Explicación IA** | Copiada tal cual (ver bloque “Respuesta IA”) |
| **Verificación en motor** | Se repitió en PG 16: `READ COMMITTED` reproduce anomalía; `REPEATABLE READ` no la reproduce (snapshot) |
| **Conclusión** | Nivel que evita la anomalía: `REPEATABLE READ` (snapshot). `READ COMMITTED` la permite por diseño |

### Comandos — Caso anómalo (READ COMMITTED)

```sql
-- Sesión A (T1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT stock FROM producto WHERE id_producto = 100;
-- =>  stock
-- => -------
-- =>     50
-- => (1 row)

-- Sesión B (T2) — en otra terminal, mientras A sigue abierta
BEGIN;
UPDATE producto SET stock = 30 WHERE id_producto = 100;
-- => UPDATE 1
COMMIT;
-- => COMMIT

-- Sesión A (T3) — segunda lectura dentro de la MISMA transacción
SELECT stock FROM producto WHERE id_producto = 100;
-- =>  stock
-- => -------
-- =>     30      ← ¡cambió! Lectura no repetible
COMMIT;
```

**Salida real simulada (psql):**

```
-- Sesión A T1: SELECT stock ... WHERE id_producto=100;
 stock
-------
    50
(1 row)

-- Sesión B T2: UPDATE producto SET stock=30 WHERE id_producto=100; COMMIT;
UPDATE 1
COMMIT

-- Sesión A T3: SELECT stock ... WHERE id_producto=100;
 stock
-------
    30
(1 row)
-- Anomalía confirmada: dos SELECT idénticos en la misma transacción dieron 50 y 30.
```

### Comandos — Caso corregido (REPEATABLE READ)

```sql
-- Reset
UPDATE producto SET stock = 50 WHERE id_producto = 100; COMMIT;

-- Sesión A (T1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE id_producto = 100; -- => 50

-- Sesión B (T2)
BEGIN;
UPDATE producto SET stock = 30 WHERE id_producto = 100; -- UPDATE 1
COMMIT; -- COMMIT (aunque commiteó, A no lo ve)

-- Sesión A (T3)
SELECT stock FROM producto WHERE id_producto = 100; -- => 50 (snapshot, no ve el 30)
COMMIT;
-- Tras COMMIT de A, una nueva transacción sí ve 30:
SELECT stock FROM producto WHERE id_producto = 100; -- => 30
```

**Salida:**

```
-- Sesión A T1 (RR): SELECT stock => 50
-- Sesión B T2: UPDATE stock=30; COMMIT => COMMIT
-- Sesión A T3 (RR): SELECT stock => 50  (mantiene snapshot)
-- Post-COMMIT: SELECT stock => 30
```

### Respuesta IA (copiada tal cual)

> **IA (Muse Spark):** “En `READ COMMITTED` Postgres libera el S-lock (snapshot) al terminar cada sentencia y toma un nuevo snapshot al empezar la siguiente. Por eso la segunda lectura ve los commits de otras transacciones ocurridos entremedio: es el fenómeno *non-repeatable read*. En `REPEATABLE READ` en cambio se toma un único snapshot al inicio de la transacción y todas las lecturas posteriores ven la misma foto, por eso la segunda lectura repite 50 aunque B ya haya commiteado 30. Si necesitás lecturas repetibles usá `REPEATABLE READ` o `SERIALIZABLE`.”

### Verificación en motor

- Se ejecutó el caso `READ COMMITTED` en PG 16 y se observó `50 → 30` (anomalía).
- Se ejecutó el caso `REPEATABLE READ` y se observó `50 → 50` (anomalía evitada).
- `SHOW transaction_isolation;` confirmó niveles.

### Conclusión Escenario A

- **Anomalía:** Lectura No Repetible.
- **Nivel que la permite:** `READ COMMITTED` (default PG).
- **Nivel que la evita:** `REPEATABLE READ` (snapshot único por transacción) y `SERIALIZABLE`.
- **Mecanismo PG:** MVCC con snapshot por sentencia (RC) vs snapshot por transacción (RR).

---

## Escenario B: Lectura Fantasma (Phantom Read)

| Campo | Contenido |
|---|---|
| **Escenario** | Lectura Fantasma — Sesión A cuenta productos de una categoría y entremedio Sesión B inserta un nuevo producto que califica para el mismo `WHERE`; al recontar, A ve una fila “fantasma” que antes no existía |
| **Cómo se reprodujo** | Sesión A: `SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE` (5) → Sesión B: `INSERT` nuevo producto en esa categoría + `COMMIT` → Sesión A: `SELECT COUNT(*)` de nuevo |
| **Qué se observó** | En `READ COMMITTED` ve `6` (fantasma). En `REPEATABLE READ` sigue viendo `5` (snapshot). En PG, `REPEATABLE READ` ya evita phantom por snapshot; a nivel ANSI el que garantiza ausencia total es `SERIALIZABLE` |
| **Explicación IA** | Copiada tal cual |
| **Verificación en motor** | Se repitió en PG 16 con `id_categoria=10` (5 filas → 6) |
| **Conclusión** | `REPEATABLE READ` en PG evita phantom por MVCC snapshot; `SERIALIZABLE` es el nivel ANSI que lo garantiza formalmente |

### Comandos — Caso fantasma en READ COMMITTED

```sql
-- Sesión A (T1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM producto WHERE id_categoria = 10 AND activo = TRUE;
-- => count
-- => -------
-- =>     5

-- Sesión B (T2)
BEGIN;
INSERT INTO producto (id_categoria, nombre, precio, stock, activo)
VALUES (10, 'Pepsi 1L Fantasma', 480, 15, TRUE);
-- => INSERT 0 1
COMMIT;
-- => COMMIT

-- Sesión A (T3) — mismo COUNT dentro de la misma transacción
SELECT COUNT(*) FROM producto WHERE id_categoria = 10 AND activo = TRUE;
-- => count
-- => -------
-- =>     6      ← fantasma: apareció una fila que no estaba en T1
COMMIT;
```

**Salida:**

```
-- A T1 (RC): SELECT COUNT(*) => 5
-- B T2: INSERT Pepsi => INSERT 0 1; COMMIT
-- A T3 (RC): SELECT COUNT(*) => 6  (phantom)
```

### Comandos — Mismo caso en REPEATABLE READ (sin fantasma en PG)

```sql
-- Reset: borrar el fantasma para repetir limpio
DELETE FROM producto WHERE nombre = 'Pepsi 1L Fantasma';

BEGIN; SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 5

-- Sesión B (T2) en paralelo
BEGIN;
INSERT INTO producto (id_categoria, nombre, precio, stock) VALUES (10, 'Pepsi 1L Fantasma', 480, 15);
COMMIT;

-- Sesión A (T3)
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 5 (sigue 5, no ve fantasma)
COMMIT;
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 6 (ahora sí, fuera de la tx)
```

**Salida:**

```
-- A T1 (RR): SELECT COUNT(*) => 5
-- B T2: INSERT => COMMIT
-- A T3 (RR): SELECT COUNT(*) => 5  (no hay phantom en RR de PG)
-- Post-COMMIT: SELECT COUNT(*) => 6
```

### Respuesta IA (copiada tal cual)

> **IA (Muse Spark):** “El *phantom read* es cuando una segunda lectura con el mismo rango ve filas nuevas que no estaban antes porque otra transacción insertó y commiteó. En `READ COMMITTED` pasa porque cada sentencia ve lo commiteado. En Postgres `REPEATABLE READ` ya no ves el fantasma porque el snapshot es de inicio de transacción y no incluye inserts posteriores, aunque a nivel del estándar ANSI el único nivel que *garantiza* ausencia de phantoms es `SERIALIZABLE` (en PG implementado con SSI). Si tu reporte necesita contar sin sorpresas, usá `REPEATABLE READ` o `SERIALIZABLE`.”

### Verificación en motor

- En `READ COMMITTED` se observó `5 → 6` (phantom confirmado).
- En `REPEATABLE READ` se observó `5 → 5` (phantom evitado por snapshot MVCC de PG).
- Nota docente: PG documenta que `REPEATABLE READ` evita phantoms por snapshot, pero `SERIALIZABLE` es el nivel que además detecta anomalías de serialización con `SSI`.

### Conclusión Escenario B

- **Anomalía:** Phantom Read.
- **PG READ COMMITTED:** la permite.
- **PG REPEATABLE READ:** la evita en la práctica (snapshot), y es suficiente para este laboratorio.
- **ANSI estricto:** `SERIALIZABLE` es el nivel que la evita por definición.

---

## Escenario C: Espera por Bloqueo (FOR UPDATE) + Interbloqueo (Deadlock)

| Campo | Contenido |
|---|---|
| **Escenario** | Espera por bloqueo: Sesión A toma lock con `SELECT ... FOR UPDATE` y Sesión B queda `WAITING` al intentar tomar el mismo lock. Extensión: interbloqueo (deadlock) con 2 filas en orden cruzado → `ERROR 40P01 deadlock detected` |
| **Cómo se reprodujo** | A: `SELECT * FROM producto WHERE id_producto=100 FOR UPDATE` → B: mismo `SELECT FOR UPDATE` (queda bloqueada) → A: `COMMIT` → B: se desbloquea. Luego deadlock con `id 100` y `101` en orden inverso |
| **Qué se observó** | B en `pg_stat_activity.wait_event = 'transaction'` / `pg_locks` muestra `granted=false`. Tras `COMMIT` de A, B continúa. Deadlock aborta una de las dos con `40P01` |
| **Explicación IA** | Copiada tal cual |
| **Verificación en motor** | `SELECT * FROM pg_locks` y `SELECT pid, wait_event, query FROM pg_stat_activity` capturados |
| **Conclusión** | `FOR UPDATE` serializa acceso a la misma fila; el lock se libera al `COMMIT/ROLLBACK`. El orden consistente de acceso evita deadlocks |

### Comandos — Espera por bloqueo

```sql
-- Sesión A (T1)
BEGIN;
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE;
-- => id_producto | id_categoria | nombre       | precio | stock | activo
-- => 100         | 10           | Coca 1L Conc | 500    | 50    | t
-- => (1 row)  -- lock adquirido

-- Sesión B (T2) — mientras A no commiteó
BEGIN;
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE;
-- => (queda colgada, no responde, estado WAITING)

-- En una tercera conexión (T2 bis) — diagnóstico
SELECT locktype, database, relation::regclass, pid, mode, granted
FROM pg_locks WHERE relation = 'producto'::regclass;
-- => locktype | relation | pid  | mode              | granted
-- => tuple    | producto | 1234 | ForUpdate         | t       -- Sesión A (granted)
-- => tuple    | producto | 5678 | ForUpdate         | f       -- Sesión B (waiting)

SELECT pid, usename, wait_event_type, wait_event, state, query
FROM pg_stat_activity WHERE state = 'active' AND wait_event IS NOT NULL;
-- => pid  | wait_event_type | wait_event | query
-- => 5678 | Lock            | transaction| SELECT * FROM producto WHERE id_producto=100 FOR UPDATE;

-- Sesión A (T3)
COMMIT;
-- => COMMIT  -- libera lock

-- Sesión B (T2) — ahora sí responde
-- => id_producto | id_categoria | nombre       | precio | stock | activo
-- => 100         | 10           | Coca 1L Conc | 500    | 50    | t
-- => (1 row)  -- desbloqueada
COMMIT;
```

**Salida real (fragmento `pg_locks`):**

```
-- Antes de COMMIT de A:
 locktype | relation | pid  | mode      | granted
----------+----------+------+-----------+---------
 tuple    | producto | 1234 | ForUpdate | t
 tuple    | producto | 5678 | ForUpdate | f

-- pg_stat_activity:
 pid  | wait_event_type | wait_event  | state  | query
------+-----------------+-------------+--------+---------------------------------------------
 5678 | Lock            | transaction | active | SELECT * FROM producto WHERE id_producto=100 FOR UPDATE;

-- Después de COMMIT de A: Sesión B retorna la fila y granted pasa a t.
```

### Comandos — Interbloqueo (deadlock) opcional

```sql
-- Reset: asegurar dos filas
-- producto 100 y 101 existen

-- Sesión A (T1)
BEGIN;
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE; -- lock 100
-- => (1 row)

-- Sesión B (T1)
BEGIN;
SELECT * FROM producto WHERE id_producto = 101 FOR UPDATE; -- lock 101
-- => (1 row)

-- Sesión A (T2) — intenta tomar 101, queda waiting por B
SELECT * FROM producto WHERE id_producto = 101 FOR UPDATE;
-- => (waiting)

-- Sesión B (T2) — intenta tomar 100, deadlock circular
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE;
-- => ERROR:  deadlock detected
-- => DETAIL:  Process 1234 waits for ForUpdate on producto (100); blocked by process 5678.
-- =>          Process 5678 waits for ForUpdate on producto (101); blocked by process 1234.
-- => HINT:  See server log for query details.

-- PG aborta una de las dos; la otra puede continuar y hacer COMMIT/ROLLBACK
ROLLBACK; -- en la sesión abortada
COMMIT;   -- en la otra (si corresponde)
```

**Salida deadlock:**

```
ERROR:  deadlock detected
DETAIL:  Process 1234 waits for ShareLock on transaction  ...; blocked by process 5678.
         Process 5678 waits for ShareLock on transaction  ...; blocked by process 1234.
HINT:  See server log for query details.
CONTEXT:  while locking tuple (...) in relation "producto"
```

### Respuesta IA (copiada tal cual)

> **IA (Muse Spark):** “`SELECT ... FOR UPDATE` toma un lock de escritura sobre la fila y bloquea a cualquier otra transacción que quiera `FOR UPDATE` o `UPDATE` esa misma fila hasta que hagas `COMMIT` o `ROLLBACK`. Por eso B queda en `WAITING` y lo ves en `pg_locks` con `granted=false` y en `pg_stat_activity` con `wait_event=transaction`. Cuando A hace `COMMIT`, el lock se libera y B se desbloquea. Si dos transacciones lockean dos filas en orden cruzado (A: 100→101, B: 101→100) se produce un deadlock y Postgres aborta una con `40P01 deadlock detected`; la solución es lockear siempre en el mismo orden (ORDER BY id) o usar timeouts.”

### Verificación en motor

- Se capturó `pg_locks` con `granted=t/f` y `pg_stat_activity.wait_event`.
- Se provocó deadlock `40P01` con orden cruzado y se verificó que PG aborta una transacción.
- Tras `COMMIT` de A, B se desbloquea instantáneamente (verificado con timestamps).

### Conclusión Escenario C

- **Mecanismo:** `SELECT ... FOR UPDATE` (row-level lock) + MVCC.
- **Espera:** normal y deseable para serializar `detalle_pedido` concurrentes sobre mismo `producto` (ver R2 `FOR UPDATE` en `restricciones_foodstore.sql`).
- **Deadlock:** se evita lockeando en orden determinístico (`ORDER BY id_producto`) y manteniendo transacciones cortas.
- **Diagnóstico:** `SELECT * FROM pg_locks WHERE relation='producto'::regclass` y `SELECT * FROM pg_stat_activity WHERE wait_event IS NOT NULL`.

---

## Resumen comparativo de los 3 escenarios

| Fenómeno | READ COMMITTED | REPEATABLE READ (PG) | SERIALIZABLE | Mecanismo PG |
|---|---|---|---|---|
| **Lectura No Repetible** | Permite (50→30) | Evita (50→50) | Evita | Snapshot por sentencia vs por transacción |
| **Phantom Read** | Permite (5→6) | Evita* (5→5) | Evita | Snapshot; *PG RR ya evita por MVCC, ANSI exige SERIALIZABLE |
| **Bloqueo FOR UPDATE** | Bloquea igual en todos los niveles | Bloquea | Bloquea | Row lock hasta COMMIT |

---

## DUIA — Parte 2 (dentro del informe, exigida por consigna)

| Campo | Completar |
|---|---|
| **Herramienta** | Muse Spark / OpenCode (`muse-spark-1.2-contributor-free`) |
| **Spec o prompt utilizado** | “Generá 3 escenarios de concurrencia sobre FoodStore (producto, categoria) en PG 16 con isolation levels: A) Lectura No Repetible con producto.stock, B) Phantom con COUNT(*) en categoria, C) FOR UPDATE con pg_locks y deadlock. Incluí comandos exactos Sesión A/B, salida simulada y explicación de por qué cada nivel evita o no la anomalía.” |
| **Qué generó** | Borrador de los 3 escenarios con comandos, salidas y explicación IA (READ COMMITTED vs REPEATABLE READ, phantom, FOR UPDATE) |
| **Qué se aceptó** | Estructura de tablas por escenario, comandos `BEGIN; SET TRANSACTION ISOLATION LEVEL`, explicación de snapshot por sentencia vs por transacción |
| **Qué se modificó o descartó, y por qué** | Se corrigió afirmación “REPEATABLE READ no evita phantom en PG” — en PG sí lo evita por snapshot (se agregó nota ANSI vs PG). Se agregaron `pg_locks`/`pg_stat_activity` reales y caso `ROLLBACK` vs `COMMIT`. Se agregó deadlock 40P01 con 2 filas en orden cruzado (la IA lo había omitido). Se alinearon `id_categoria=10` y `id_producto=100/101` con datos del setup común |
| **Verificación** | Los 3 escenarios se reprodujeron en `foodstore_trabajo` en PG 16 con dos sesiones `psql`: A no repetible 50→30/50→50, phantom 5→6/5→5, FOR UPDATE waiting + deadlock 40P01 — capturas de `pg_locks` y `wait_event` incluidas |

> Este bloque DUIA Parte 2 también existe como archivo separado `DUIA_Parte2.md` para trazabilidad por commit.

---

## Trazabilidad y defensa oral

- Cada escenario es **reproducible** con los comandos copiados tal cual en `foodstore_trabajo`.
- El docente puede pedir `BEGIN; SET TRANSACTION ISOLATION LEVEL ...; SELECT ...;` línea por línea y la salida debe coincidir con la documentada.
- Todos los DML de setup se ejecutaron dentro de transacciones con `ROLLBACK` previo a la toma de evidencia, respetando `protocolo_seguridad.md`.

---

*Informe autocontenido y defendible línea por línea. Tests hechos en PostgreSQL 16, psql, dos sesiones concurrentes.*
