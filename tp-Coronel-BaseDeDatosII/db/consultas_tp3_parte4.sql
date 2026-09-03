-- =============================================================================
-- FoodStore — consultas_tp3_parte4.sql — Parte 4: specs precisas + equivalencia
-- UTN TUP BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
-- Cada spec fija: tablas, filtro borrado lógico, columnas salida, orden, corte
-- Verificación: EXCEPT en ambas direcciones = 0 filas
-- =============================================================================

-- -------------------------------------------------------------------------
-- SPEC 1 — Resumen (agregación) — Spec precisa entregada a IA
-- -------------------------------------------------------------------------
-- "Genera una consulta SQL sobre FoodStore que devuelva, para cada categoría
--  VIGENTE (categoria.activo=TRUE), el nombre de la categoría y la cantidad
--  de productos VIGENTES (producto.activo=TRUE) que tiene, INCLUYENDO
--  categorías sin productos vigentes con cantidad 0. Columnas: categoria_nombre
--  (categoria.nombre), cantidad_productos (COUNT). Ordená de mayor a menor
--  cantidad, desempate alfabético por categoria_nombre. No uses SELECT *."
--
-- SQL generado por IA a partir de esa spec (versión A — JOIN + GROUP BY):
-- -------------------------------------------------------------------------

-- Versión A — IA (JOIN LEFT + GROUP BY)
SELECT
    c.nombre AS categoria_nombre,
    count(p.id_producto) AS cantidad_productos
FROM categoria c
LEFT JOIN producto p
    ON p.id_categoria = c.id_categoria
    AND p.activo = TRUE
WHERE c.activo = TRUE
GROUP BY c.id_categoria, c.nombre
ORDER BY cantidad_productos DESC, categoria_nombre ASC;

-- Versión B — Alternativa propia (subconsulta correlacionada) — misma spec
SELECT
    c.nombre AS categoria_nombre,
    (SELECT count(*) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo = TRUE) AS cantidad_productos
FROM categoria c
WHERE c.activo = TRUE
ORDER BY cantidad_productos DESC, categoria_nombre ASC;

-- Verificación equivalencia Spec 1 (debe dar 0 en ambas)
-- (SELECT c.nombre, count(p.id_producto) FROM categoria c LEFT JOIN producto p ON p.id_categoria=c.id_categoria AND p.activo=TRUE WHERE c.activo=TRUE GROUP BY c.id_categoria,c.nombre ORDER BY 2 DESC,1)
-- EXCEPT
-- (SELECT c.nombre, (SELECT count(*) FROM producto p WHERE p.id_categoria=c.id_categoria AND p.activo=TRUE) FROM categoria c WHERE c.activo=TRUE ORDER BY 2 DESC,1);
-- Y viceversa. Ejecutada abajo con CTEs para contar:

WITH q_a AS (
    SELECT c.nombre AS categoria_nombre, count(p.id_producto) AS cantidad_productos
    FROM categoria c LEFT JOIN producto p ON p.id_categoria=c.id_categoria AND p.activo=TRUE
    WHERE c.activo=TRUE GROUP BY c.id_categoria,c.nombre
),
q_b AS (
    SELECT c.nombre AS categoria_nombre, (SELECT count(*) FROM producto p WHERE p.id_categoria=c.id_categoria AND p.activo=TRUE) AS cantidad_productos
    FROM categoria c WHERE c.activo=TRUE
)
SELECT 'A EXCEPT B' AS direccion, count(*) AS filas_diferencia FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A', count(*) FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 0, 0

-- -------------------------------------------------------------------------
-- SPEC 2 — Subconsulta — Spec precisa entregada a IA
-- -------------------------------------------------------------------------
-- "Genera una consulta SQL sobre FoodStore que devuelva los clientes vigentes
--  (cliente.activo=TRUE) que NUNCA hicieron un pedido (no existe pedido con
--  id_cliente = cliente.id_cliente). Tablas: cliente, pedido. Columnas:
--  id_cliente, nombre, email. Filtro borrado lógico en cliente. Ordená por
--  id_cliente ASC. No uses SELECT *."
--
-- SQL generado por IA a partir de esa spec (versión A — NOT EXISTS):
-- -------------------------------------------------------------------------

-- Versión A — IA (NOT EXISTS — recomendada, inmune a NULL)
SELECT id_cliente, nombre, email
FROM cliente c
WHERE c.activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_cliente = c.id_cliente)
ORDER BY id_cliente ASC;

-- Versión B — Alternativa propia (LEFT JOIN + IS NULL) — misma pregunta, distinta estructura
SELECT c.id_cliente, c.nombre, c.email
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
WHERE c.activo = TRUE
  AND p.id_pedido IS NULL
ORDER BY c.id_cliente ASC;

-- Tercera variante descartada (NOT IN) — vulnerable a NULL, no usada:
-- SELECT id_cliente, nombre, email FROM cliente WHERE activo=TRUE AND id_cliente NOT IN (SELECT id_cliente FROM pedido); -- si pedido.id_cliente tiene NULL, retorna 0 filas por lógica trivaluada

-- Verificación equivalencia Spec 2
WITH q_a AS (
    SELECT id_cliente, nombre, email FROM cliente c WHERE c.activo=TRUE AND NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_cliente=c.id_cliente)
),
q_b AS (
    SELECT c.id_cliente, c.nombre, c.email FROM cliente c LEFT JOIN pedido p ON p.id_cliente=c.id_cliente WHERE c.activo=TRUE AND p.id_pedido IS NULL
)
SELECT 'A EXCEPT B' AS direccion, count(*) AS filas_diferencia FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A', count(*) FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 0, 0

-- -------------------------------------------------------------------------
-- Ejecución completa de verificación (una sola query para informe):
-- -------------------------------------------------------------------------
-- SELECT * FROM (SELECT ...q_a...) EXCEPT (SELECT ...q_b...)  — ambas 0 filas = equivalentes
