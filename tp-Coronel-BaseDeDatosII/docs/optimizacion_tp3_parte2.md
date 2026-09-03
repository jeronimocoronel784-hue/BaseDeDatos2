# Parte 2 — Laboratorio EXPLAIN ANALYZE — FoodStore masivo

> UTN TUP BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
> Base: foodstore_trabajo (50030 productos, 20020 clientes, 200020 pedidos/detalles) — `ANALYZE` aplicado

## Protocolo

1. `EXPLAIN (ANALYZE, BUFFERS)` antes de cada cambio — plan completo guardado en `C:\Users\jeron\AppData\Local\Temp\plan_Q*_antes.txt`
2. Propuesta justificada por nodo (qué nodo ataca, por qué esperaría cambio)
3. `CREATE INDEX` solo si se entiende línea por línea — `BEGIN; ... ROLLBACK;` no aplica a índices CONCURRENTLY, se verifica con `SELECT * FROM pg_stat_progress_create_index`
4. `ANALYZE` y `EXPLAIN` después — comparación nodo/cost/tiempo/buffers

## Q1 — Listado productos por categoría + precio con ORDER BY

**SQL:** `SELECT id_producto, nombre, precio, stock FROM producto WHERE id_categoria=1 AND activo=TRUE AND precio BETWEEN 500 AND 2000 ORDER BY precio LIMIT 100`

**Plan ANTES (cost 779.11..779.36, exec 2.87ms, buffers 528):**
```
Limit → Sort (cost 779, top-N heapsort 36kB) → Bitmap Heap Scan (cost 84..703 rows 1971, Filter precio, Rows Removed 3940, Heap Blocks 516, Buffers 525) → Bitmap Index Scan on idx_producto_categoria_activo (rows 5927)
```

**Nodo atacado:** `Sort (779.11)` + `Bitmap Heap Scan con Filter (Rows Removed 3940)` — el índice base `(id_categoria, activo)` no cubre `precio`, obliga a recargar 516 heap blocks y filtrar 3940 filas en memoria, luego ordenar por `precio`.

**Propuesta 1 — Índice compuesto con orden:**
```sql
CREATE INDEX idx_producto_categoria_activo_precio ON producto (id_categoria, activo, precio);
```
**Justificación técnica:** Postgres puede usar `Index Scan` sobre `(id_categoria, activo, precio)` donde `precio` ya está ordenado físicamente dentro del prefijo `(1, TRUE)`. El `ORDER BY precio` se satisface sin `Sort` (Index Cond incluye `precio BETWEEN`), y `Filter` desaparece (Index Cond exacto). Esperado: `Sort` eliminado, `Bitmap Heap Scan` → `Index Scan`, `Rows Removed by Filter: 0`, `Buffers` 528→~50, `cost` 779→~120, `Execution` 2.8ms→~0.9ms. No reescritura SQL necesaria — el optimizador elige el índice por selectividad (1971/50030 ≈3.9%).

**Alternativa descartada:** `INCLUDE (nombre, stock)` covering index — ahorra heap fetches pero duplica tamaño índice y no elimina `Sort`; se prioriza ordenar sobre covering.

---

## Q2 — Historial pedidos por cliente con JOIN

**SQL:** `SELECT p.id_pedido, p.fecha, dp.cantidad, pr.nombre FROM pedido p JOIN detalle_pedido dp ON dp.id_pedido=p.id_pedido JOIN producto pr ON pr.id_producto=dp.id_producto WHERE p.id_cliente=1 ORDER BY p.fecha DESC LIMIT 50`

**Plan ANTES (cost 252.20..252.23, exec 1.08ms, buffers 136):**
```
Limit → Sort (cost 252, quicksort 26kB, Sort Key: fecha DESC) → Nested Loop → Bitmap Heap Scan on pedido (Filter id_cliente=1, rows 21, Heap Blocks 20) → Index Scan detalle_pedido_pkey (21 loops) → Index Scan producto_pkey (11 loops)
```

**Nodo atacado:** `Sort (252.20)` sobre `fecha DESC` — aunque `Bitmap Index Scan on idx_pedido_cliente (id_cliente)` encuentra las 21 filas, luego hay que ordenarlas por `fecha` en memoria (quicksort 26kB). Con 10 pedidos/cliente promedio no es lento, pero a 100+ pedidos/cliente (cliente activo) el Sort crece.

**Propuesta 2 — Índice compuesto con orden descendente:**
```sql
CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha DESC);
-- Opcional INCLUDE para covering: INCLUDE (forma_pago)
```
**Justificación:** Índice `(id_cliente, fecha DESC)` permite `Index Scan` que devuelve filas ya ordenadas por `fecha`, eliminando `Sort`. El planner cambia `Bitmap Heap Scan + Sort` → `Index Scan using idx_pedido_cliente_fecha (Index Cond: id_cliente=1, Order: fecha DESC)`. Esperado: `Sort` eliminado, `cost` 252→~12, `Execution` 1.08→~0.35ms, `Buffers` 136→~30. Reescritura alternativa `ORDER BY p.fecha DESC` ya está óptima — no hace falta reescribir, el índice hace el trabajo.

**Reescritura considerada y descartada:** Subconsulta `SELECT * FROM pedido WHERE id_cliente=1 ORDER BY fecha DESC LIMIT 50` + `JOIN LATERAL` — misma semántica, pero el índice la hace innecesaria.

---

## Q3 — Agregación 90 días con HAVING (consulta lenta real)

**SQL:** `SELECT p.id_cliente, c.nombre, count(*), sum(dp.cantidad*dp.precio_unitario) FROM pedido p JOIN cliente c ON c.id_cliente=p.id_cliente JOIN detalle_pedido dp ON dp.id_pedido=p.id_pedido WHERE p.fecha BETWEEN now()-'90 days' AND now() AND c.activo=TRUE GROUP BY ... HAVING sum>10000 ORDER BY total DESC LIMIT 20`

**Plan ANTES (cost 16504.48, exec 97.42ms, buffers 4912):**
```
Limit → Sort (top-N 27kB) → HashAggregate (Batches 1, Memory 6161kB, Rows Removed by Filter 6298) → Gather (1 worker) → Hash Join (Hash Cond p.id_cliente=c.id_cliente, Buffers 4909) → Parallel Hash Join (Hash Cond dp.id_pedido=p.id_pedido) → Parallel Seq Scan on detalle_pedido (1471 buffers) → Parallel Hash → Parallel Seq Scan on pedido (Filter fecha, Rows Removed: 175388, Buffers 2942) → Hash → Seq Scan on cliente (Filter activo, Rows Removed 604, Buffers 496)
```

**Nodos atacados:**
1. `Parallel Seq Scan on pedido (cost 0..8236, Rows Removed 175388, Buffers 2942)` — el cuello de botella. Filtro `fecha BETWEEN 90 days` descarta 87% de filas (175k de 200k) pero sin índice obliga a leer toda la tabla en paralelo.
2. `Seq Scan on cliente (Rows Removed 604)` — filtro `activo=TRUE` sin índice parcial.

**Propuesta 3 — Índice sobre fecha (y covering):**
```sql
CREATE INDEX idx_pedido_fecha ON pedido (fecha);
-- Mejor aún para esta query: (fecha, id_cliente) para cubrir GROUP BY y evitar Hash extra
CREATE INDEX idx_pedido_fecha_cliente ON pedido (fecha, id_cliente);

CREATE INDEX idx_cliente_activo ON cliente (activo) WHERE activo = TRUE; -- partial
```
**Justificación:** Con `idx_pedido_fecha`, el planner cambia `Parallel Seq Scan` → `Bitmap Index Scan on idx_pedido_fecha (Index Cond: fecha BETWEEN ...)` o `Index Scan`, leyendo solo 24k filas del rango 90 días en lugar de 200k. `Rows Removed by Filter` pasa de 175388 a ~0 (Index Cond exacto). `Buffers` 2942→~300, `cost` 8236→~400, `Gather` paralelo puede volverse innecesario (seq scan ya no es bottleneck). `Execution` esperado 97ms→~25-35ms. El índice parcial `idx_cliente_activo WHERE activo=TRUE` ataca `Seq Scan on cliente` — pasa a `Index Scan` o `Bitmap`, eliminando 604 Rows Removed y 496 buffers.

**Reescritura alternativa:** Filtrar primero pedidos en CTE `WITH pedidos_90d AS (SELECT * FROM pedido WHERE fecha BETWEEN ...) SELECT ... FROM pedidos_90d ...` — semánticamente equivalente, pero el índice ya permite al optimizador hacer predicate pushdown sin reescribir.

---

## Resultados medidos (EXPLAIN ANALYZE después)

### Q1 — DESPUÉS (cost 0.41..105.78, exec 0.429ms, buffers 103)
```
Limit (cost 0.41..105.78 rows 100) → Index Scan using idx_producto_categoria_activo_precio (cost 0.41..2129.91 rows 2021, Index Cond: id_categoria=1 AND activo=true AND precio BETWEEN 500 AND 2000, Buffers 103)
```
**Cambio real:** `Sort` eliminado completamente, `Bitmap Heap Scan (516 blocks, Filter RowsRemoved 3940)` → `Index Scan` sin `Filter` ni `Recheck`. `Planning 2.29→3.45ms` (índice nuevo), `Execution 2.87→0.429ms` **(6.7x mejora)**.

### Q2 — DESPUÉS (cost 252.20..252.23, exec 0.618ms, buffers 133)
```
Limit → Sort (cost 252, quicksort 26kB, Buffers 133) → Nested Loop → Bitmap Heap Scan on pedido (cost 4.58..79.88 rows 21, Buffers 23) → Bitmap Index Scan on idx_pedido_cliente_fecha (cost 0..4.57 rows 21, Buffers 3)
```
**Cambio real:** Índice `idx_pedido_cliente_fecha` SÍ es usado (`Bitmap Index Scan` ahora sobre el nuevo índice), pero el planner mantuvo `Bitmap Heap Scan + Sort` en lugar de `Index Scan` ordenado. **Por qué:** con 21 filas promedio por cliente, el costo de `Bitmap` (lectura secuencial de 20 heap blocks) es menor que `Index Scan` (lectura aleatoria ordenada). El `Sort` de 21 filas es despreciable (quicksort 26kB). **Conclusión defendible:** mejora marginal (1.083→0.618ms, 1.75x) pero no elimina `Sort`; para clientes con 1000+ pedidos sí lo eliminaría. Documentado como propuesta "no mejora como se esperaba" según criterio cátedra.

### Q3 — DESPUÉS (cost 11422.62, exec 90.23ms, buffers 4667)
```
Limit (cost 11422) → Sort (89.18ms) → HashAggregate (83.46ms, Filter RowsRemoved 6298) → Hash Join → Hash Join (dp=pedido) → Seq Scan detalle_pedido (1471 buffers) → Hash → Bitmap Heap Scan on pedido (cost 1056..5115 rows 49609, Recheck Cond fecha, Buffers 2945) → Bitmap Index Scan on idx_pedido_fecha (rows 49243, Buffers 3) → Seq Scan cliente (RowsRemoved 604, Buffers 248)
```
**Cambio real:** `Parallel Seq Scan on pedido (cost 8236, RowsRemoved 175388, Buffers 2942 + Gather 1 worker)` → `Bitmap Heap Scan + Bitmap Index Scan on idx_pedido_fecha (cost 1056, Buffers 2945, RowsRemoved 0 — Index Cond exacto, no Filter)`. **Mejora moderada:** `cost` 16504→11422 (30% menos), `Execution` 97.42→90.23ms (7% mejor), `Buffers` 4912→4667. **Por qué mejora menor a lo esperado:** el cuello pasó a `HashAggregate + Hash Join con detalle_pedido Seq Scan (1471 buffers)` y `Seq Scan cliente (248 buffers)` — el índice parcial `idx_cliente_activo WHERE activo=TRUE` no fue elegido porque 97% de clientes son activos (selectividad baja, Seq Scan más barato). Para ganar más habría que atacar `detalle_pedido` (ej: `idx_detalle_pedido_id_pedido` ya existe como PK).

## Tabla comparativa final — Parte 2.2 (entrega)

| Consulta | Plan ANTES (nodo, cost, tiempo real) | Cambio aplicado | Plan DESPUÉS (nodo, cost, tiempo real) | Mejora (x) | ¿Aceptado? |
|---|---|---|---|---|---|
| **Q1** producto por categoría+precio | `Sort 779.11` + `Bitmap Heap Scan Filter RowsRemoved 3940, Heap Blocks 516` — cost 779.36, Planning 2.29ms, **Exec 2.871ms**, Buffers 528 | `CREATE INDEX idx_producto_categoria_activo_precio ON producto (id_categoria, activo, precio)` — índice compuesto que deja `precio` ordenado | `Index Scan using idx_producto_categoria_activo_precio` sin `Sort` ni `Filter`, Index Cond exacto — cost 105.78, Planning 3.45ms, **Exec 0.429ms**, Buffers 103 | **6.7x** (2.87→0.43ms) | ✅ **Aceptado** — ataca `Sort+Filter` y elimina ambos, defendible |
| **Q2** historial por cliente | `Sort 252.20 (quicksort 26kB, Sort Key fecha DESC)` + `Bitmap Heap Scan id_cliente=1 (Heap Blocks 20)` — cost 252.23, **Exec 1.083ms**, Buffers 136 | `CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha DESC)` | `Bitmap Index Scan on idx_pedido_cliente_fecha` pero **Sort persiste** (21 filas, quicksort 26kB) — cost 252.23, **Exec 0.618ms**, Buffers 133 | 1.75x (1.08→0.61ms) | ⚠️ **Parcial** — índice usado pero no elimina `Sort` por baja cardinalidad; se documenta como "no mejora esperada", no se revierte por ser inocuo |
| **Q3** agregación 90 días | `Parallel Seq Scan on pedido cost 8236, Filter fecha, RowsRemoved 175388, Buffers 2942` + `Gather (1 worker)` + `Seq Scan cliente 448 (RowsRemoved 604)` — cost 16504, **Exec 97.424ms**, Buffers 4912 | `CREATE INDEX idx_pedido_fecha ON pedido (fecha)` + `idx_cliente_activo WHERE activo` (partial) | `Bitmap Heap Scan on pedido (cost 1056, Index Cond fecha BETWEEN, RowsRemoved 0) + Bitmap Index Scan idx_pedido_fecha` + `Seq Scan cliente` (parcial no usado) — cost 11422, **Exec 90.235ms**, Buffers 4667 | 1.08x (97.4→90.2ms) | ✅ **Aceptado con matices** — ataca `Seq Scan pedido` (30% menos cost), pero `idx_cliente_activo` no aporta (97% activos) → se propone DROP |

## Criterio de aceptación (cátedra)

Ningún índice se aplica "porque lo dijo la IA": se aplica solo si puedo explicar por qué ataca ESE nodo y la medición posterior lo confirma. Q1 confirma hipótesis (Sort eliminado). Q2 y Q3 confirman parcialmente — se documenta "qué se esperaba, qué pasó, por qué" en lugar de ocultar. Q1 es el caso ganador para defensa oral.

## Archivos de evidencia

- Planes antes: `C:\Users\jeron\AppData\Local\Temp\plan_Q*_antes.txt`
- Planes después: `C:\Users\jeron\AppData\Local\Temp\plan_Q*_despues.txt`
- Índices: `pg_indexes WHERE tablename IN ('producto','pedido')` — 4 índices creados (2 base + 2 nuevos útiles)

## Recomendación competencia Parte 5

Para la consulta común de la cátedra (listado por categoría con precio y orden), usar `idx_producto_categoria_activo_precio` — es el que da **6.7x** con `Index Scan` sin `Sort`.
