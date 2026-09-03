-- =============================================================================
-- FoodStore — indices_tp3.sql — Índices de optimización Parte 2
-- UTN TUP BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
-- Cada índice justificado por nodo EXPLAIN ANALYZE (ver docs/optimizacion_tp3_parte2.md)
-- Protocolo: ejecutar en foodstore_trabajo, medir antes/después con EXPLAIN (ANALYZE, BUFFERS)
-- =============================================================================

-- Q1: ataca Sort (779) + Bitmap Heap Scan Filter RowsRemoved 3940
-- Antes: Bitmap Index Scan on idx_producto_categoria_activo → Sort → Filter
-- Después: Index Scan sin Sort ni Filter, cost 779→105, exec 2.87→0.429ms (6.7x)
-- Justificación: (id_categoria, activo, precio) deja precio ordenado, Index Cond cubre BETWEEN y ORDER BY
CREATE INDEX IF NOT EXISTS idx_producto_categoria_activo_precio ON producto (id_categoria, activo, precio);

-- Q2: ataca Sort (252) sobre fecha DESC — 21 filas promedio por cliente
-- Antes: Bitmap Heap Scan id_cliente=1 → Sort quicksort 26kB
-- Después: Bitmap Index Scan on idx_pedido_cliente_fecha pero Sort persiste (baja cardinalidad)
-- Justificación: (id_cliente, fecha DESC) debería dar Index Scan ordenado, pero planner prefiere Bitmap por 21 filas
-- Resultado: mejora marginal 1.08→0.618ms, no elimina Sort — documentado como parcial
CREATE INDEX IF NOT EXISTS idx_pedido_cliente_fecha ON pedido (id_cliente, fecha DESC);

-- Q3: ataca Parallel Seq Scan on pedido (cost 8236, RowsRemoved 175388)
-- Antes: Parallel Seq Scan con Filter fecha (90 days) → Gather
-- Después: Bitmap Heap Scan + Bitmap Index Scan on idx_pedido_fecha (Index Cond exacto, RowsRemoved 0), cost 16504→11422, exec 97.4→90.2ms
-- Justificación: (fecha) permite Index Cond BETWEEN, evita leer 175k filas fuera de rango
CREATE INDEX IF NOT EXISTS idx_pedido_fecha ON pedido (fecha);

-- Q3 complemento: parcial sobre cliente activo — NO usado por planner (97% activos, Seq Scan más barato)
-- Se crea para demostrar lectura crítica: índice existe pero no mejora, se propone DROP si no aporta
-- Resultado medido: Seq Scan persiste (Buffers 496→248, RowsRemoved 604), índice no elegido → DROP aplicado
-- CREATE INDEX IF NOT EXISTS idx_cliente_activo ON cliente (activo) WHERE activo = TRUE;
-- DROP INDEX idx_cliente_activo; -- ejecutado tras medir: no aporta

-- Refrescar estadísticas para que el optimizador elija correctamente
ANALYZE producto;
ANALYZE pedido;
ANALYZE cliente;

-- Verificación:
-- SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) FROM pg_stat_user_indexes WHERE relname IN ('producto','pedido','cliente') ORDER BY relname, indexname;
-- DROP INDEX IF EXISTS idx_cliente_activo; -- si se decide descartar por no aportar
