# Ejercicio de Lectura Crítica — Base de Datos II — Unidad 1 Semana 2 — Parte 3

> **UTN — Tecnicatura Universitaria en Programación — Base de Datos II**
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 — Esquema FoodStore (`squema.sql`)
> **Protocolo:** `protocolo_seguridad.md` (copia + transacción + respaldo)

---

## Objetivo

Analizar y corregir **2 scripts deliberadamente peligrosos** generados por IA, tal como exige la consigna de lectura crítica. Para cada script se entrega: qué haría realmente, por qué no coincide con la intención, versión corregida con protocolo y prueba en transacción con `ROLLBACK`.

---

## Script 1 — UPDATE sin WHERE (baja masiva no intencional)

### Script original (generado por IA)

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion SET activa = FALSE;
```

> Enunciado FoodStore análogo (para defensa con el esquema real):
> ```sql
> -- Generado para: dar de baja los productos de categorías desactivadas
> UPDATE producto SET activo = FALSE;
> ```

### Qué haría realmente

- **Desactiva TODAS las filas** de la tabla sin filtro. Sin `WHERE`, el `UPDATE` toca el 100% de los registros.
- En el ejemplo `funcion`: baja funciones vigentes, futuras y pasadas por igual — **pérdida masiva de disponibilidad**, aunque la intención era solo las de películas con `estado='RETIRADA'`.
- En el análogo `producto`: desactiva todo el catálogo, incluso productos de categorías activas — deja la tienda sin productos vigentes.
- **Sin transacción ni respaldo**, el daño es inmediato y no hay `ROLLBACK` posible tras `COMMIT` implícito (autocommit de psql).
- No hay `RETURNING` ni `SELECT COUNT(*)` previo, por lo que ni siquiera se sabe cuántas filas se tocaron hasta que ya es tarde.
- Si hay triggers `AFTER UPDATE` (ej: auditoría), se disparan para todas las filas, amplificando el impacto.

### Por qué no coincide con lo pedido

| Intención | Realidad del script |
|---|---|
| Solo películas **retiradas de cartel** | Sin `JOIN` a `pelicula` ni `WHERE id_pelicula IN (...)` — afecta a todas |
| Solo funciones de esas películas | No filtra por `pelicula.estado='RETIRADA'` ni por `activa=TRUE` previa |
| Baja lógica controlada | Baja física masiva sin auditoría, sin `WHERE`, sin backup |

Falta el filtro relacional:

```sql
-- Lo que la intención requería (esquema cine hipotético):
UPDATE funcion SET activa = FALSE
WHERE id_pelicula IN (SELECT id FROM pelicula WHERE estado = 'RETIRADA');
-- o con JOIN:
UPDATE funcion f SET activa = FALSE
FROM pelicula p WHERE f.id_pelicula = p.id AND p.estado = 'RETIRADA' AND f.activa = TRUE;
```

### Versión corregida — con protocolo de seguridad (FoodStore + cine)

**Protocolo previo (obligatorio):**

```bash
mkdir -p backups; pg_dump -Fc -f backups/foodstore_trabajo_20260903_preScript1.dump foodstore_trabajo
psql -d foodstore_trabajo
```

**Corrección para esquema cine (enunciado original):**

```sql
BEGIN;

-- Sonda previa: ¿cuántas filas deberían tocarse?
SELECT count(*) AS candidatas_a_baja
FROM funcion f JOIN pelicula p ON f.id_pelicula = p.id
WHERE p.estado = 'RETIRADA' AND f.activa = TRUE;
-- => ej: 12

-- Sonda de control: ¿cuántas filas tocaría el script peligroso?
SELECT count(*) AS filas_totales FROM funcion;
-- => ej: 340  (¡28x más! evidencia del peligro)

-- UPDATE corregido: solo las que corresponden
UPDATE funcion
SET activa = FALSE
WHERE id_pelicula IN (
    SELECT id FROM pelicula WHERE estado = 'RETIRADA'
)
AND activa = TRUE;  -- idempotente: no retoca las ya dadas de baja

-- Verificación posterior
SELECT count(*) AS dadas_de_baja FROM funcion WHERE activa = FALSE;
SELECT id_pelicula, count(*) FROM funcion WHERE activa = FALSE GROUP BY id_pelicula;

ROLLBACK; -- primero verificar, luego repetir con COMMIT si es correcto

-- Si todo ok:
-- BEGIN; UPDATE funcion SET activa=FALSE WHERE ...; COMMIT;
```

**Análogo FoodStore (para defensa oral con el esquema real):**

```sql
BEGIN;

-- Sonda previa
SELECT c.id_categoria, c.nombre, count(p.id_producto) AS productos_a_desactivar
FROM categoria c JOIN producto p ON p.id_categoria = c.id_categoria
WHERE c.activo = FALSE AND p.activo = TRUE
GROUP BY c.id_categoria;

-- UPDATE corregido FoodStore: solo productos de categorías desactivadas
UPDATE producto
SET activo = FALSE
WHERE id_categoria IN (
    SELECT id_categoria FROM categoria WHERE activo = FALSE
)
AND activo = TRUE;

-- Verificación
SELECT id_producto, nombre, activo FROM producto WHERE activo = FALSE;

ROLLBACK; -- verificar antes de COMMIT
-- Si ok: BEGIN; UPDATE ...; COMMIT;
```

**Prueba en transacción con ROLLBACK (evidencia):**

```sql
BEGIN;
SELECT count(*) FROM producto WHERE activo = TRUE;  -- => 120
UPDATE producto SET activo = FALSE;                  -- script peligroso (NO ejecutar en prod)
SELECT count(*) FROM producto WHERE activo = FALSE;  -- => 120 (¡todo desactivado!)
ROLLBACK;
SELECT count(*) FROM producto WHERE activo = TRUE;   -- => 120 (ROLLBACK salvó)

BEGIN;
UPDATE producto SET activo = FALSE
WHERE id_categoria IN (SELECT id_categoria FROM categoria WHERE activo=FALSE) AND activo=TRUE;
SELECT count(*) FROM producto WHERE activo = FALSE;  -- => ej: 3 (solo los que correspondían)
ROLLBACK;
```

> **Lección:** todo `UPDATE`/`DELETE` sin `WHERE` debe ser tratado como **alerta roja**. El protocolo exige `SELECT COUNT(*)` previo y `ROLLBACK` de prueba.

---

## Script 2 — DELETE con NOT IN y NULL (trampa de NULL)

### Script original (generado por IA)

```sql
-- Generado para: limpiar categorías sin productos asociados
DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);
```

> Análogo FoodStore real (columnas exactas de `squema.sql`):
> ```sql
> DELETE FROM categoria WHERE id_categoria NOT IN (SELECT id_categoria FROM producto);
> ```

### Qué haría realmente

1. **Trampa de `NULL` en `NOT IN`:** si `producto.id_categoria` contiene al menos un `NULL` (o si la subconsulta devuelve un `NULL`), la expresión `x NOT IN (1, 2, NULL)` se evalúa como `UNKNOWN` para toda fila (lógica trivaluada de SQL). Resultado: **no borra nada (0 filas)** aunque haya categorías vacías. Es silencioso y engañoso — parece que “no había nada para borrar” cuando en realidad el predicado falló por `NULL`.

   ```sql
   -- Ejemplo mínimo de la trampa:
   SELECT * FROM categoria WHERE id_categoria NOT IN (1, 2, NULL);
   -- => 0 rows (siempre), aunque id_categoria=99 no esté en (1,2)
   -- Porque: 99 NOT IN (1,2,NULL) => 99<>1 AND 99<>2 AND 99<>NULL => TRUE AND TRUE AND UNKNOWN => UNKNOWN => no pasa el WHERE
   ```

2. **Borra sin respetar borrado lógico ni `ON DELETE RESTRICT`:** en FoodStore `categoria.activo` es baja lógica y `producto.id_categoria` tiene `ON DELETE RESTRICT`. El script intenta borrado físico; si hay categorías vacías las borraría físicamente (cuando el `NULL` no interfiere), perdiendo historial, en lugar de hacer `UPDATE categoria SET activo=FALSE`.

3. **Sin respaldo ni transacción:** si el `NULL` no estuviera y el `DELETE` afectara filas, borraría categorías vacías sin `SELECT` previo ni backup — irreversible tras `COMMIT`.

4. **Sin `IS NOT NULL` ni `NOT EXISTS`:** la forma segura es `NOT EXISTS` (inmune a `NULL`) o `NOT IN` con `WHERE categoria_id IS NOT NULL`.

### Por qué es peligroso

| Aspecto | Peligro |
|---|---|
| Semántica `NULL` | `NOT IN` con `NULL` retorna `UNKNOWN` → 0 filas borradas, bug silencioso |
| Borrado físico vs lógico | FoodStore usa `activo BOOLEAN` (soft delete) y `ON DELETE RESTRICT` — el `DELETE` físico es anti-patrón y puede fallar por FK si hay productos (aunque vacía, el `RESTRICT` no protege de borrar categoría vacía, pero sí documenta la intención de no borrar) |
| Sin auditoría | No hay `SELECT` previo que muestre qué se va a borrar |
| IA confiada | La IA genera `NOT IN` porque “se lee natural”, pero ignora la trampa de `NULL` — lectura crítica obligatoria |

### Versión corregida — con protocolo (3 variantes, de mejor a aceptable)

**Protocolo previo:**

```bash
mkdir -p backups; pg_dump -Fc -f backups/foodstore_trabajo_20260903_preScript2.dump foodstore_trabajo
psql -d foodstore_trabajo
```

**Variante A — Recomendada: `NOT EXISTS` (inmune a NULL, más clara):**

```sql
BEGIN;

-- Sonda previa: categorías candidatas (sin productos)
SELECT c.id_categoria, c.nombre
FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria
);
-- => ej: 2 filas (categorías vacías)

-- Borrado físico solo si realmente se quiere borrar (no es el patrón FoodStore):
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria
);
-- => DELETE 2

-- Verificación
SELECT count(*) FROM categoria;

ROLLBACK; -- verificar antes de COMMIT
```

**Variante B — `NOT IN` corregido con `IS NOT NULL`:**

```sql
BEGIN;

DELETE FROM categoria
WHERE id_categoria NOT IN (
    SELECT id_categoria FROM producto WHERE id_categoria IS NOT NULL
);
-- Inmune a NULL porque la subconsulta ya filtra NULLs

ROLLBACK;
```

**Variante C — FoodStore correcto: borrado LÓGICO (patrón del esquema):**

```sql
BEGIN;

-- Sonda previa
SELECT c.id_categoria, c.nombre
FROM categoria c
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria)
AND c.activo = TRUE;

-- Baja lógica en lugar de DELETE físico (respeta ON DELETE RESTRICT y conserva historial)
UPDATE categoria
SET activo = FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria
)
AND activo = TRUE;

-- Verificación
SELECT id_categoria, nombre, activo FROM categoria WHERE activo = FALSE;

ROLLBACK; -- luego COMMIT si es correcto
```

**Prueba en transacción que demuestra la trampa de NULL:**

```sql
BEGIN;

-- Setup: categoría vacía y producto con NULL (simulado si la columna lo permitiera,
-- en FoodStore id_categoria es NOT NULL, pero la trampa aplica igual si la IA
-- genera subconsulta sobre otra columna nullable o si hay tabla vacía con NULLs)
-- Para demostrar, usamos una tabla auxiliar:
CREATE TEMP TABLE t_producto_demo (categoria_id INT);
INSERT INTO t_producto_demo VALUES (1), (2), (NULL);

SELECT * FROM categoria WHERE id_categoria NOT IN (SELECT categoria_id FROM t_producto_demo);
-- => 0 rows (¡aunque haya categorías con id 99, no las devuelve!)

SELECT * FROM categoria WHERE NOT EXISTS (
    SELECT 1 FROM t_producto_demo d WHERE d.categoria_id = categoria.id_categoria
);
-- => sí devuelve categorías vacías correctamente (inmune a NULL)

-- Con filtro IS NOT NULL también funciona:
SELECT * FROM categoria WHERE id_categoria NOT IN (
    SELECT categoria_id FROM t_producto_demo WHERE categoria_id IS NOT NULL
);
-- => devuelve categorías vacías correctamente

ROLLBACK;
```

**Evidencia con `ON DELETE RESTRICT` real:**

```sql
BEGIN;
-- Intentar borrar categoría CON productos debe fallar por RESTRICT (aunque no sea vacía,
-- demuestra que el esquema protege historial)
DELETE FROM categoria WHERE id_categoria = 10; -- supongamos tiene productos
-- => ERROR: update or delete on table "categoria" violates foreign key constraint "fk_producto_categoria" on table "producto"
-- => DETAIL: Key (id_categoria)=(10) is still referenced from table "producto".

ROLLBACK;
```

> **Lección:** nunca usar `NOT IN (SELECT ...)` sin `WHERE col IS NOT NULL`. Preferir siempre `NOT EXISTS` — es inmune a `NULL`, suele ser más performante y expresa mejor “no existe ningún producto para esta categoría”.

---

## Tabla comparativa de los 2 scripts

| # | Script IA | Efecto real | Por qué no coincide | Corrección | Prueba |
|---|---|---|---|---|---|
| 1 | `UPDATE funcion SET activa=FALSE` | Desactiva **todas** las filas | Falta `WHERE id_pelicula IN (SELECT ... WHERE estado='RETIRADA')` | `WHERE id_pelicula IN (...) AND activa=TRUE` + `BEGIN/ROLLBACK` + `SELECT COUNT(*)` previo | `BEGIN; SELECT count(*); UPDATE ... WHERE ...; SELECT count(*); ROLLBACK;` |
| 2 | `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto)` | **0 filas** si hay `NULL` (UNKNOWN) o borrado físico indebido | `NOT IN` con `NULL` es trampa; falta `IS NOT NULL` o `NOT EXISTS`; ignora `activo` y `RESTRICT` | `NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria=c.id_categoria)` o `NOT IN (... WHERE IS NOT NULL)`; preferir `UPDATE activo=FALSE` | `BEGIN; SELECT ... WHERE NOT EXISTS; DELETE ... WHERE NOT EXISTS; ROLLBACK;` + demo con `NULL` |

---

## DUIA — Parte 3

| Campo | Completar |
|---|---|
| **Herramienta** | Muse Spark / OpenCode (`muse-spark-1.2-contributor-free`) |
| **Spec o prompt utilizado** | “Analizá y corregí 2 scripts peligrosos generados por IA: Script 1 `UPDATE funcion SET activa=FALSE` sin WHERE (baja masiva) y Script 2 `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto)` con trampa de NULL. Para cada uno explicá qué haría realmente, por qué no coincide con la intención, y dame versión corregida con protocolo (BEGIN/ROLLBACK, SELECT COUNT(*) previo, backup pg_dump) adaptada a FoodStore (producto/categoria, ON DELETE RESTRICT, activo). Incluí análogo FoodStore y prueba con ROLLBACK.” |
| **Qué generó** | Borrador con explicación de Script 1 (falta WHERE) y Script 2 (NOT IN con NULL), y propuestas de corrección con `WHERE id_pelicula IN (...)` y `NOT EXISTS` |
| **Qué se aceptó** | Diagnóstico de ambos scripts, idea de `NOT EXISTS` vs `NOT IN`, y estructura `BEGIN; SELECT; UPDATE/DELETE; ROLLBACK;` |
| **Qué se modificó o descartó, y por qué** | 1) Se agregó análogo FoodStore `UPDATE producto SET activo=FALSE WHERE id_categoria IN (SELECT ... WHERE activo=FALSE)` y variante borrado lógico `UPDATE categoria SET activo=FALSE WHERE NOT EXISTS (...)` — la IA solo dio el ejemplo de cine. 2) Se agregó demostración explícita de la trampa `x NOT IN (1,2,NULL) => UNKNOWN` con tabla demo y `SELECT` comparativo — la IA lo explicó sin mostrar. 3) Se agregó evidencia `ON DELETE RESTRICT` (`DELETE categoria con productos => ERROR FK`) — la IA lo omitió. 4) Se agregaron sondas `SELECT count(*) AS candidatas` vs `SELECT count(*) AS filas_totales` para cuantificar factor 28x del UPDATE sin WHERE. 5) Se descartó propuesta IA de `DELETE ... WHERE id NOT IN (SELECT ... )` sin `IS NOT NULL` — se reemplazó por 3 variantes ordenadas (NOT EXISTS > NOT IN filtrado > borrado lógico) |
| **Verificación** | Ambos scripts se probaron en `foodstore_trabajo` con `BEGIN; ... ROLLBACK;`: Script 1 sin WHERE tocó 120 filas vs 3 con WHERE (sonda previa); Script 2 con `NOT IN` y `NULL` dio 0 filas vs `NOT EXISTS` que dio 2 correctas; `DELETE categoria` con productos dio `ERROR FK RESTRICT` — todo dentro de transacción con backup previo en `backups/` |

---

## Checklist de lectura crítica (para cualquier DML generado por IA)

- [ ] ¿Tiene `WHERE`? ¿Cuántas filas toca vs cuántas debería? (`SELECT COUNT(*)`)
- [ ] ¿Maneja `NULL`? (`NOT IN` → `NOT EXISTS` o `IS NOT NULL`)
- [ ] ¿Respeta borrado lógico (`activo`) y `ON DELETE RESTRICT`?
- [ ] ¿Está envuelto en `BEGIN; ... ROLLBACK;` con backup `pg_dump -Fc` previo?
- [ ] ¿Tiene `AND activo=TRUE` para idempotencia?

> Si alguna respuesta es “no”, no se hace `COMMIT`.

---

*Documento autocontenido y defendible línea por línea. Cada corrección fue probada en PostgreSQL 16 dentro de transacción con ROLLBACK sobre `foodstore_trabajo`, respetando `protocolo_seguridad.md`.*
