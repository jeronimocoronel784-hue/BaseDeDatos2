# Parte 4 — Competencia de optimización — FoodStore (EJEMPLO SINTÉTICO VEROSÍMIL)

> UTN TUP BD II — Semana 4 — Parte 4 — Autor: Jerónimo Coronel — 2026-09-03 — **EJEMPLO SINTÉTICO**
> Base: `foodstore_trabajo` masiva (50 030 productos / 20 020 clientes / 200 020 pedidos / 200 020 detalle_pedido) — `ANALYZE` aplicado — PostgreSQL 16.8
> Índices base Semana 3: `idx_producto_categoria_activo_precio`, `idx_pedido_cliente_fecha`, `idx_pedido_fecha`
> Índices Parte 1 (ejemplo): `idx_pedido_fecha_id`, `idx_producto_categoria_activo`, `idx_cliente_activo_true`
> **ADVERTENCIA:** Planes y tiempos son sintéticos verosímiles para practicar el protocolo de competencia sin base real.

## Consigna común (cátedra — ejemplo sintético)

Todos los equipos reciben la **misma consulta lenta** — fijada por cátedra sobre base masiva común — y compiten por mejor plan (IA como asistente, **decisión y justificación humana**). Gana mejor **tiempo real** (`EXPLAIN (ANALYZE, BUFFERS)` → `Execution Time` / `actual time`), no costo estimado (`cost`).

**Consulta común elegida (sintética — coincide con Q1 de Parte 1 para trazabilidad):**
```sql
-- Consulta común — 4 JOINs + agregación + ORDER BY + LIMIT — con activo=TRUE, sin SELECT *
SELECT
    c.nombre                             AS categoria,
    date_trunc('month', p.fecha)         AS mes,
    sum(dp.cantidad * dp.precio_unitario) AS facturacion,
    count(DISTINCT p.id_pedido)           AS pedidos
FROM categoria c
JOIN producto pr        ON pr.id_categoria = c.id_categoria
JOIN detalle_pedido dp  ON dp.id_producto = pr.id_producto
JOIN pedido p           ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
  AND pr.activo = TRUE
  AND p.fecha BETWEEN now() - interval '6 months' AND now()
GROUP BY c.nombre, mes
ORDER BY facturacion DESC
LIMIT 20;
-- Sin optimización: Hash Join (build 4MB) + Merge Join + Sort 3201kB + Seq Scan con 150k Rows Removed
-- cost ~8124, actual ~178ms, Buffers 4821 hit, Execution 180ms
-- EXPLAIN (ANALYZE, BUFFERS) antes y después — guardar planes completos
```

**Protocolo competencia:**
1. `EXPLAIN (ANALYZE, BUFFERS)` **antes** — guardar `cost`, `actual time`, `Buffers`, `Planning/Execution Time` (`C:\Users\jeron\AppData\Local\Temp\plan_TP4_competencia_antes.txt` — en este ejemplo, idéntico a `plan_TP4_Q1_antes.txt`).
2. Propuesta con IA — justificar qué nodo join se ataca (externa/interna, build/probe) y qué cambio de algoritmo se espera (Hash → Nested Loop, Seq Scan → Index Scan).
3. Aplicar `CREATE INDEX` / reescritura **comprendida** — `ANALYZE` + `EXPLAIN (ANALYZE, BUFFERS)` **después** (`plan_TP4_competencia_despues.txt` — idéntico a `plan_TP4_Q1_despues.txt` en este ejemplo).
4. Decidir con datos: menor `Execution Time` gana, aunque `cost` sea mayor. Documentar `cost` vs `actual time` explícitamente.

## Estrategias probadas (bitácora — incluye descartadas) — EJEMPLO

| # | Estrategia IA propuesta | ¿Qué nodo atacaba? | ¿Se aplicó? | Resultado medido (`cost` estimado / `actual time` real / `Buffers`) | Por qué se aceptó/descartó |
|---|---|---|---|---|---|
| 1 | `CREATE INDEX idx_pedido_fecha_id ON pedido (fecha, id_cliente)` | `Seq Scan on pedido p` con `Filter: fecha BETWEEN` + `Rows Removed 150000` (`actual 48ms`, `cost 0..3890`, `hit 2890`) | ✅ Sí | `cost 8124 → 4890` (−40%), `Execution 180.5ms → 45.8ms` (**3.94×**), `Buffers hit 4821 → 512` (9×) — `Index Scan Index Cond: fecha BETWEEN`, `Rows Removed 0` | **Aceptado** — ataca nodo exacto, cambia `Hash Join (build detalle 4MB, probe pedido)` → `Nested Loop (externa pedido Index Scan loops=1, interna detalle Index Scan loops=48210)`, defendible: selectividad fecha 24% + `loops` moderado hace Nested Loop óptimo. Sin spill `Batches 1`. |
| 2 | `CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo) INCLUDE (precio)` | `Seq Scan on producto` + `Sort 3201kB` previo a `Merge Join` (`actual 18..22ms`) | ✅ Sí (junto con #1) | Mismo plan después que #1 — `Sort 3201kB` desaparece, `Buffers 1204→~150` en rama producto, `cost` del `Merge Join` eliminado | **Aceptado** — índice compuesto ordenado + covering evita Sort y reduce Hash; tamaño ~3MB, no duplica heap. |
| 3 | `CREATE INDEX idx_pedido_fecha_id ON pedido (fecha) INCLUDE (id_cliente, forma_pago)` — covering total | `Heap Fetches` del `Index Scan` (visibilidad) | ❌ No | Estimado `cost` similar a #1, `Buffers` marginalmente menor (512→490) pero `size` 14MB vs 8MB de #1 | **Descartado** — mejora marginal vs costo de mantenimiento; el `INCLUDE` extra no cambia algoritmo join, solo evita 1 heap fetch por fila (no justifica tamaño doble). |
| 4 | Reescritura a CTE con `date_trunc` pre-agregado + `LATERAL JOIN` | `HashAggregate` + `Sort top-N heapsort 31kB` | ❌ No | `cost` sube a 9100, `actual` 52ms (peor que #1), `Buffers` similar | **Descartado** — el `HashAggregate` ya es eficiente (73kB, `Batches 1`); la reescritura no empuja el filtro y el planner ya elige `top-N heapsort` óptimo. |

> Cada estrategia debe tener su `EXPLAIN (ANALYZE, BUFFERS)` antes/después. No ocultar propuestas que no mejoraron — documentar "qué se esperaba, qué pasó, por qué". En este ejemplo, las estrategias 3 y 4 se descartaron con medición.

## Registro de la competencia (entrega — ejemplo con 3 equipos ficticios)

| Equipo | Estrategia aplicada | Tiempo **antes** (`Execution Time` real) | Tiempo **después** (`Execution Time` real) | Mejora (×) | Algoritmo join antes → después |
|---|---|---|---|---|---|
| **Coronel — FoodStore (ejemplo)** | `idx_pedido_fecha_id (fecha,id_cliente)` + `idx_producto_categoria_activo (id_categoria,activo) INCLUDE(precio)` + `ANALYZE` | `180.512 ms` (`cost 8124`, `Buffers hit 4821`, `Hash Join build 4MB` + `Merge Join` + `Sort 3201kB`) | `45.820 ms` (`cost 4890`, `Buffers hit 512`, `Nested Loop externa pedido Index Scan loops=1 / interna detalle+producto Index Scan loops=48210`) | **3.94×** | `Hash Join (build detalle probe pedido)` + `Merge Join` → `Nested Loop (Index Scan)` |
| Equipo B (ficticio) | Solo `idx_pedido_fecha_id` sin segundo índice | `180.512 ms` | `78.340 ms` (`cost 6100`, `Buffers 1200`) — mantiene `Hash Join` con producto | **2.30×** | `Hash Join` → `Nested Loop` parcial (pedido) pero mantiene `Hash` con producto |
| Equipo C (ficticio) | `idx_pedido_fecha` existente (solo fecha) sin `id_cliente` | `180.512 ms` | `110.200 ms` (`cost 7200`, `Buffers 2100`) — `Bitmap Heap Scan` en lugar de `Index Scan` | **1.64×** | `Seq Scan` → `Bitmap Heap Scan` (no llega a `Nested Loop`) |

> Gana **menor `Execution Time` (tiempo real)** — en este ejemplo gana **Coronel** con 45.82ms (3.94×). El `cost` estimado también baja (8124→4890) pero no es el criterio; si un plan tuviera `cost` mayor y `actual time` menor, ganaría igual. Aclarar siempre `cost` (planificación, unidades abstractas) vs `actual time` (medición, ms) y `Buffers` (páginas 8KB).

## Evidencia (flujo completo medido — sintético)

- Planes antes/después: `C:\Users\jeron\AppData\Local\Temp\plan_TP4_competencia_antes.txt` (= `plan_TP4_Q1_antes.txt` Parte 1), `C:\Users\jeron\AppData\Local\Temp\plan_TP4_competencia_despues.txt` (= `plan_TP4_Q1_despues.txt`)
- Índices y definiciones:
```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('producto','pedido','detalle_pedido','cliente','categoria')
ORDER BY tablename, indexname;

-- Esperado:
-- pedido   | idx_pedido_fecha_id              | CREATE INDEX idx_pedido_fecha_id ON pedido USING btree (fecha, id_cliente)
-- producto | idx_producto_categoria_activo    | CREATE INDEX idx_producto_categoria_activo ON producto USING btree (id_categoria, activo) INCLUDE (precio)
-- cliente  | idx_cliente_activo_true          | CREATE INDEX idx_cliente_activo_true ON cliente USING btree (id_cliente) WHERE (activo = TRUE)
```
- Tamaños:
```sql
SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE relname IN ('pedido','producto','cliente')
ORDER BY pg_relation_size(indexrelid) DESC;
-- idx_pedido_fecha_id ~8MB, idx_producto_categoria_activo ~3MB, idx_cliente_activo_true ~400kB
```
- `ANALYZE` aplicado antes de cada medición:
```sql
ANALYZE pedido; ANALYZE producto; ANALYZE cliente; ANALYZE categoria; ANALYZE detalle_pedido;
```

## Declaración de Uso de IA — competencia (resumen)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode (Muse Spark) | Proponer estrategia para consulta común (4 JOINs + filtro fecha) | *"Dado este plan EXPLAIN (ANALYZE, BUFFERS) de la consulta común (4 JOINs, Seq Scan pedido con 150k Rows Removed, Hash Join 4MB, Merge Join + Sort 3201kB), proponé índice/reescritura justificando nodo join atacado (externa/interna o build/probe) y qué cambio de algoritmo esperás. No confundas cost con actual time."* | ✅ **Aceptado** — estrategia #1+#2 (dos índices) → `180.5ms → 45.8ms` (3.94×), `cost 8124→4890` (−40%), `Buffers 4821→512`. Ataca `Seq Scan` exacto con `Index Cond`. |
| Kiro | Segunda opinión — alternativa covering | *"Misma consulta y plan — proponé alternativa distinta (covering vs parcial) y compará tamaño vs Buffers."* | ⚠️ **Descartado** — covering total `INCLUDE (id_cliente, forma_pago)` 14MB vs 8MB con mejora marginal 512→490 Buffers; se eligió índice lean. |

> Detalle completo en `docs/DUIA_TP4.md`. Protocolo: medir antes → proponer con IA → entender línea por línea → medir después → decidir con `Execution Time`.
