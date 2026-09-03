-- =============================================================================
-- FoodStore — queries.sql — Consultas base para laboratorio de optimización
-- UTN TUP — BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
-- Propósito: 3 consultas reales que se vuelven lentas a escala masiva
--            (50k productos / 20k clientes / 200k pedidos) y que disparan
--            Seq Scan / Sort sin índice óptimo.
-- Uso: EXPLAIN ANALYZE antes/después de cada índice. Medir nodo + cost +
--      actual time. Ver docs/protocolo_seguridad.md y carga_masiva_tp3.sql
-- =============================================================================

-- Q1 — Listado de productos vigentes por categoría con filtro de precio y orden
-- Patrón: WHERE id_categoria = $1 AND activo = TRUE AND precio BETWEEN $2 AND $3 ORDER BY precio
-- Índice base idx_producto_categoria_activo(id_categoria, activo) NO cubre precio ni ORDER BY → Sort caro
-- Esperable sin optimización: Seq Scan o Index Scan parcial + Filter + Sort (cost alto, Rows Removed by Filter)
-- Optimización candidata: índice compuesto (id_categoria, activo, precio) o covering
EXPLAIN ANALYZE
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE id_categoria = 1
  AND activo = TRUE
  AND precio BETWEEN 500 AND 2000
ORDER BY precio
LIMIT 100;

-- Variante Q1b — misma idea sin LIMIT (peor caso Sort en memoria/disco)
-- SELECT id_producto, nombre, precio FROM producto WHERE id_categoria = 2 AND activo = TRUE AND precio BETWEEN 1000 AND 3000 ORDER BY precio;

-- Q2 — Historial de pedidos por usuario (cliente) con JOIN a detalle y producto
-- Patrón: pedido JOIN detalle_pedido JOIN producto, filtro por id_cliente
-- Índice base idx_pedido_cliente(id_cliente) ayuda a pedido pero falta índice en detalle_pedido(id_producto) y pedido(fecha)
-- Esperable: Nested Loop + Seq Scan en detalle_pedido o Hash Join sin índice covering
SELECT p.id_pedido, p.fecha, p.forma_pago, dp.cantidad, dp.precio_unitario, pr.nombre AS producto
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
JOIN producto pr       ON pr.id_producto = dp.id_producto
WHERE p.id_cliente = 1
ORDER BY p.fecha DESC
LIMIT 50;

-- EXPLAIN ANALYZE de Q2 (descomentar para medir)
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT ... -- misma query con EXPLAIN

-- Q3 — Agregación / resumen: total gastado y cantidad de pedidos por cliente en rango de fechas
-- Patrón: GROUP BY + JOIN + filtro fecha — típica consulta resumen que pide la Parte 4
-- Sin índice en pedido(fecha) ni en pedido(id_cliente, fecha) → Seq Scan + HashAggregate caro
SELECT p.id_cliente, c.nombre, count(*) AS cantidad_pedidos, sum(dp.cantidad * dp.precio_unitario) AS total_gastado
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE p.fecha BETWEEN now() - interval '90 days' AND now()
  AND c.activo = TRUE
GROUP BY p.id_cliente, c.nombre
HAVING sum(dp.cantidad * dp.precio_unitario) > 10000
ORDER BY total_gastado DESC
LIMIT 20;

-- Q3 EXPLAIN candidato
-- EXPLAIN ANALYZE SELECT p.id_cliente, ... (misma Q3)

-- =============================================================================
-- Notas para el laboratorio (Parte 2.1):
-- 1) Correr cada Q con EXPLAIN (ANALYZE, BUFFERS) ANTES de crear índices nuevos
--    y guardar plan completo (texto). Ej:
--    EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
-- 2) Pasar el plan a la IA, pedir propuesta justificada por nodo (qué nodo ataca).
-- 3) Aplicar solo CREATE INDEX comprendido línea por línea, en foodstore_trabajo
--    dentro de BEGIN; ... ROLLBACK; primero.
-- 4) Volver a EXPLAIN ANALYZE y comparar: nodo (Seq Scan → Index Scan), cost, actual time, Buffers.
-- =============================================================================
