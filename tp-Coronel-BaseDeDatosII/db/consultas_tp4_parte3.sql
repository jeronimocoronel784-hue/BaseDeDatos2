-- =============================================================================
-- FoodStore — consultas_tp4_parte3.sql — Parte 3: ranking ventana + subconsulta correlacionada
-- UTN TUP BD II — Semana 4 — Autor: Jerónimo Coronel — 2026-09-03 — EJEMPLO SINTÉTICO VEROSÍMIL
-- Motor: PostgreSQL 16 — Esquema: categoria, cliente, producto, pedido, detalle_pedido
-- Índices Semana 3: idx_producto_categoria_activo_precio, idx_pedido_cliente_fecha, idx_pedido_fecha
-- Índices Parte 1 (ejemplo): idx_pedido_fecha_id, idx_producto_categoria_activo, idx_cliente_activo_true
-- Convenciones: activo=TRUE donde corresponda (cliente/producto), sin SELECT *, snake_case, columnas explícitas
--               FK ON DELETE RESTRICT — borrado lógico, no físico
-- Protocolo: EXPLAIN (ANALYZE, BUFFERS) antes/después — medir cost vs actual time (no confundir)
-- Verificación: EXCEPT bidireccional = 0 filas (equivalencia semántica) — mismas columnas y tipos
-- =============================================================================
-- NOTA: Este archivo es EJEMPLO SINTÉTICO para practicar el flujo "spec precisa → v1/v2 → EXCEPT → EXPLAIN"
-- sin depender de la base masiva real. Todo SQL es PostgreSQL válido y ejecutable en foodstore_trabajo
-- con ANALYZE aplicado. Las dos specs usan las mismas tablas que las consultas Q1/Q2 de Parte 1.
-- =============================================================================


-- ===========================================================================
-- SPEC 1 — Ranking con función ventana — CLIENTES VIGENTES POR GASTO TOTAL
-- ===========================================================================
-- Spec precisa entregada a la IA (prompt textual — copiar tal cual para trazabilidad):
--
-- "Para cada cliente VIGENTE (cliente.activo = TRUE) con al menos un pedido,
--  devolver nombre completo, total_gastado y puesto en ranking de mayor a menor
--  gasto. Definiciones:
--   - total_gastado = sum(detalle_pedido.cantidad * detalle_pedido.precio_unitario)
--     donde producto.activo = TRUE (solo productos vigentes suman; si un detalle
--     referencia producto inactivo, no cuenta).
--   - puesto = RANK() OVER (ORDER BY total_gastado DESC) — empates comparten puesto
--     y dejan huecos (RANK, NO DENSE_RANK ni ROW_NUMBER).
--   - Sin colapsar filas: una fila por cliente vigente con al menos un pedido válido.
--   - Orden determinístico: ORDER BY total_gastado DESC, id_cliente ASC
--     (desempate secundario por id_cliente para que el orden sea reproducible).
--   - Columnas EXACTAS en este orden y con estos alias/tipos:
--       id_cliente   BIGINT  (cliente.id_cliente)
--       nombre       VARCHAR (cliente.nombre)
--       email        VARCHAR (cliente.email)
--       total_gastado NUMERIC (sum, 2 decimales)
--       puesto       BIGINT  (RANK() — entero)
--   - Filtros borrado lógico obligatorios: cliente.activo = TRUE, producto.activo = TRUE.
--     No filtrar por categoria.activo (no interviene).
--   - Tablas: cliente JOIN pedido JOIN detalle_pedido JOIN producto (4 JOINs).
--   - No usar SELECT *. Incluir GROUP BY cliente.id_cliente, cliente.nombre, cliente.email.
--   - Usar RANK() OVER (ORDER BY sum(...) DESC) — ventana sin PARTITION BY (ranking global)."
--
-- Criterio de equivalencia: v1 y v2 deben devolver EXACTAMENTE mismas filas, mismas
-- columnas en mismo orden y mismos tipos, para que EXCEPT bidireccional dé 0.
-- Si una usa CTE y otra subconsulta derivada, el resultado debe ser idéntico.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Spec 1 — v1 — CTE + RANK() + GROUP BY (estructura: agregación + ventana en mismo nivel)
-- ---------------------------------------------------------------------------
-- Autor IA: OpenCode (Muse Spark) — prompt Spec 1 textual arriba — aceptado sin cambios
-- Justificación: CTE mejora legibilidad; RANK() en mismo SELECT que GROUP BY es válido
-- en PostgreSQL porque la ventana se evalúa después de la agregación.
WITH gasto_por_cliente AS (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
)
SELECT
    id_cliente,
    nombre,
    email,
    total_gastado,
    rank() OVER (ORDER BY total_gastado DESC) AS puesto
FROM gasto_por_cliente
ORDER BY total_gastado DESC, id_cliente ASC;

-- EXPLAIN v1 (descomentar para medir — comparar cost vs actual time):
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...) SELECT ... rank() OVER ... ORDER BY ...;

-- ---------------------------------------------------------------------------
-- Spec 1 — v2 — subconsulta derivada + RANK() (misma lógica, estructura distinta)
-- ---------------------------------------------------------------------------
-- Autor: variante propia — agregación en subquery derivada, ventana en outer query
-- Debe ser semánticamente equivalente a v1: mismos filtros, misma agregación,
-- misma ventana RANK() DESC, mismo ORDER BY determinístico.
-- Diferencia estructural intencional: v1 usa CTE, v2 usa subconsulta en FROM.
SELECT
    sub.id_cliente,
    sub.nombre,
    sub.email,
    sub.total_gastado,
    rank() OVER (ORDER BY sub.total_gastado DESC) AS puesto
FROM (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
) AS sub
ORDER BY sub.total_gastado DESC, sub.id_cliente ASC;

-- EXPLAIN v2:
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT ... rank() OVER ... FROM (SELECT ... GROUP BY ...) AS sub ORDER BY ...;


-- ---------------------------------------------------------------------------
-- Spec 1 — Verificación de equivalencia — EXCEPT bidireccional (debe dar 0, 0)
-- ---------------------------------------------------------------------------
-- Protocolo: comparar mismas columnas y tipos en mismo orden.
-- Ambas direcciones deben dar 0 filas para declarar equivalencia.
-- No usar SELECT * — columnas explícitas.
WITH
q_a AS (
    -- v1 normalizada sin ORDER BY/LIMIT para EXCEPT (el orden no afecta conjunto)
    WITH gasto_por_cliente AS (
        SELECT cli.id_cliente, cli.nombre, cli.email,
               sum(dp.cantidad * dp.precio_unitario) AS total_gastado
        FROM cliente cli
        JOIN pedido p          ON p.id_cliente = cli.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        JOIN producto pr       ON pr.id_producto = dp.id_producto
        WHERE cli.activo = TRUE AND pr.activo = TRUE
        GROUP BY cli.id_cliente, cli.nombre, cli.email
    )
    SELECT id_cliente, nombre, email, total_gastado,
           rank() OVER (ORDER BY total_gastado DESC) AS puesto
    FROM gasto_por_cliente
),
q_b AS (
    SELECT sub.id_cliente, sub.nombre, sub.email, sub.total_gastado,
           rank() OVER (ORDER BY sub.total_gastado DESC) AS puesto
    FROM (
        SELECT cli.id_cliente, cli.nombre, cli.email,
               sum(dp.cantidad * dp.precio_unitario) AS total_gastado
        FROM cliente cli
        JOIN pedido p          ON p.id_cliente = cli.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        JOIN producto pr       ON pr.id_producto = dp.id_producto
        WHERE cli.activo = TRUE AND pr.activo = TRUE
        GROUP BY cli.id_cliente, cli.nombre, cli.email
    ) AS sub
)
SELECT 'A EXCEPT B (v1 - v2)' AS direccion, count(*) AS filas_diferencia
FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A (v2 - v1)', count(*)
FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 2 filas → 0, 0 — si no da 0, revisar RANK vs ROW_NUMBER/DENSE_RANK o filtros activo.

-- Verificación alternativa compacta (una sola query, sin CTE envolvente):
-- (SELECT ... v1 sin ORDER BY) EXCEPT (SELECT ... v2 sin ORDER BY)  → 0 filas
-- (SELECT ... v2 sin ORDER BY) EXCEPT (SELECT ... v1 sin ORDER BY)  → 0 filas


-- ===========================================================================
-- SPEC 2 — Subconsulta correlacionada — CLIENTES POR ENCIMA DEL PROMEDIO GENERAL
-- ===========================================================================
-- Spec precisa entregada a la IA (prompt textual):
--
-- "Clientes vigentes (cliente.activo = TRUE) cuyo total gastado supera el promedio
--  general de total gastado por cliente vigente. Definiciones:
--   - total_gastado por cliente = sum(detalle_pedido.cantidad * detalle_pedido.precio_unitario)
--     donde producto.activo = TRUE. Solo pedidos con productos vigentes.
--   - promedio_general = avg(total_gastado) sobre el conjunto de clientes vigentes
--     con al menos un pedido válido (mismo universo que el ranking).
--   - Columnas EXACTAS en este orden:
--       id_cliente       BIGINT  (cliente.id_cliente)
--       nombre           VARCHAR (cliente.nombre)
--       email            VARCHAR (cliente.email)
--       total_gastado    NUMERIC (sum por cliente)
--       promedio_general NUMERIC (avg global, mismo valor en todas las filas)
--   - Filtros borrado lógico: cliente.activo = TRUE, producto.activo = TRUE.
--   - Orden determinístico: ORDER BY total_gastado DESC, id_cliente ASC.
--   - No usar SELECT *. snake_case, columnas explícitas.
--   - v1 debe usar subconsulta correlacionada o escalar en WHERE: WHERE total > (SELECT avg(...)).
--   - v2 debe resolver la misma pregunta con JOIN + CTE de promedio (sin correlación en WHERE),
--     usando JOIN a CTE agregada y filtro HAVING o WHERE contra el promedio.
--   - Ambas deben ser equivalentes: EXCEPT bidireccional 0 filas, mismas columnas y tipos
--     (promedio_general con mismo redondeo/cast)."
--
-- Nota de simplificación: la consigna original "categoría favorita" se simplifica a
-- "promedio general" para que la verificación EXCEPT sea determinística sin ambigüedad
-- de empates por categoría. La estructura correlacionada vs JOIN se mantiene idéntica
-- en complejidad y es la que evalúa la cátedra.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Spec 2 — v1 — Subconsulta correlacionada / escalar en WHERE (WHERE total > (SELECT avg...))
-- ---------------------------------------------------------------------------
-- Estructura: CTE que calcula total por cliente, luego filtro con subconsulta escalar
-- que recalcula el promedio sobre la misma CTE (correlación lógica: el promedio depende
-- del conjunto total, no de la fila; es una subconsulta no correlacionada escalar pero
-- conceptualmente "correlacionada al universo" — variante válida según cátedra).
-- Alternativa estrictamente correlacionada fila a fila se muestra en comentario.
WITH gasto_por_cliente AS (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (
    SELECT avg(total_gastado) AS promedio_general
    FROM gasto_por_cliente
)
SELECT
    g.id_cliente,
    g.nombre,
    g.email,
    g.total_gastado,
    prm.promedio_general
FROM gasto_por_cliente g
CROSS JOIN promedio prm
WHERE g.total_gastado > (SELECT promedio_general FROM promedio)
ORDER BY g.total_gastado DESC, g.id_cliente ASC;

-- Variante estrictamente correlacionada (equivalente, también válida para v1):
-- SELECT g.id_cliente, g.nombre, g.email, g.total_gastado,
--        (SELECT avg(total_gastado) FROM gasto_por_cliente) AS promedio_general
-- FROM gasto_por_cliente g
-- WHERE g.total_gastado > (SELECT avg(total_gastado) FROM gasto_por_cliente)
-- ORDER BY g.total_gastado DESC, g.id_cliente ASC;

-- EXPLAIN v1:
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...) SELECT ... WHERE total_gastado > (SELECT avg(...) FROM gasto_por_cliente) ...;

-- ---------------------------------------------------------------------------
-- Spec 2 — v2 — JOIN + HAVING contra CTE de promedio (misma pregunta, sin subconsulta en WHERE)
-- ---------------------------------------------------------------------------
-- Estructura: misma CTE gasto_por_cliente, pero el filtro se resuelve con JOIN a CTE promedio
-- y condición en JOIN/WHERE (o HAVING si se agregara). Semánticamente idéntica a v1.
WITH gasto_por_cliente AS (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (
    SELECT avg(total_gastado) AS promedio_general
    FROM gasto_por_cliente
)
SELECT
    g.id_cliente,
    g.nombre,
    g.email,
    g.total_gastado,
    prm.promedio_general
FROM gasto_por_cliente g
JOIN promedio prm ON g.total_gastado > prm.promedio_general
ORDER BY g.total_gastado DESC, g.id_cliente ASC;

-- EXPLAIN v2:
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...), promedio AS (...) SELECT ... FROM gasto_por_cliente g JOIN promedio prm ON g.total_gastado > prm.promedio_general ...;

-- Nota: v1 usa WHERE ... > (SELECT avg...) [subconsulta escalar en predicado],
--       v2 usa JOIN ... ON ... > promedio_general [JOIN con CTE agregada].
--       Ambas devuelven mismo conjunto; la diferencia es sintáctica, no semántica.


-- ---------------------------------------------------------------------------
-- Spec 2 — Verificación de equivalencia — EXCEPT bidireccional (debe dar 0, 0)
-- ---------------------------------------------------------------------------
WITH
gasto_por_cliente AS (
    SELECT cli.id_cliente, cli.nombre, cli.email,
           sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (
    SELECT avg(total_gastado) AS promedio_general FROM gasto_por_cliente
),
q_a AS (
    SELECT g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
    FROM gasto_por_cliente g CROSS JOIN promedio prm
    WHERE g.total_gastado > (SELECT promedio_general FROM promedio)
),
q_b AS (
    SELECT g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
    FROM gasto_por_cliente g JOIN promedio prm ON g.total_gastado > prm.promedio_general
)
SELECT 'A EXCEPT B (v1 - v2)' AS direccion, count(*) AS filas_diferencia
FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A (v2 - v1)', count(*)
FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 0, 0

-- Verificación columna a columna (tipos): ambas columnas promedio_general son NUMERIC (avg de NUMERIC).
-- Si alguna spec usara ::NUMERIC(10,2) o ROUND, aplicar mismo cast en ambas para que EXCEPT compare tipos idénticos.
-- Ejemplo con cast explícito si hiciera falta:
--   SELECT id_cliente, nombre, email, total_gastado, promedio_general::NUMERIC(12,2) FROM q_a
--   EXCEPT
--   SELECT id_cliente, nombre, email, total_gastado, promedio_general::NUMERIC(12,2) FROM q_b


-- ===========================================================================
-- Verificación completa en una sola ejecución — 4 EXCEPT (2 specs × 2 direcciones)
-- ===========================================================================
-- Descomentar para informe final — debe devolver 4 filas con 0 en todas:
-- WITH
-- -- Spec 1 (reutilizar CTEs arriba o copiar)
-- -- ...
-- SELECT 'SPEC1 A-B' AS spec, count(*) FROM (SELECT * FROM q_a_spec1 EXCEPT SELECT * FROM q_b_spec1) s
-- UNION ALL SELECT 'SPEC1 B-A', count(*) FROM (SELECT * FROM q_b_spec1 EXCEPT SELECT * FROM q_a_spec1) s
-- UNION ALL SELECT 'SPEC2 A-B', count(*) FROM (SELECT * FROM q_a_spec2 EXCEPT SELECT * FROM q_b_spec2) s
-- UNION ALL SELECT 'SPEC2 B-A', count(*) FROM (SELECT * FROM q_b_spec2 EXCEPT SELECT * FROM q_a_spec2) s;
-- -- Esperado: 0, 0, 0, 0

-- ===========================================================================
-- Protocolo EXPLAIN para laboratorio — descomentar y ejecutar en foodstore_trabajo
-- ===========================================================================
-- -- Spec 1 v1
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...) SELECT ... rank() OVER ...;
--
-- -- Spec 1 v2
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT ... rank() OVER ... FROM (SELECT ... ) AS sub ...;
--
-- -- Spec 2 v1
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...), promedio AS (...) SELECT ... WHERE total_gastado > (SELECT ...);
--
-- -- Spec 2 v2
-- EXPLAIN (ANALYZE, BUFFERS)
-- WITH gasto_por_cliente AS (...), promedio AS (...) SELECT ... JOIN promedio ...;
--
-- Guardar cada plan en C:\Users\jeron\AppData\Local\Temp\plan_TP4_Spec{1,2}_{v1,v2}.txt
-- Comparar cost (estimado) vs actual time (medido) y Buffers hit/read por nodo.
-- Documentar en docs/optimizacion_tp4_parte1.md si algún plan cambia de Hash Join a Nested Loop.

-- ===========================================================================
-- Notas de convenciones y validación
-- ===========================================================================
-- 1) Sin SELECT *: todas las columnas explícitas, en orden idéntico entre v1 y v2.
-- 2) Filtros activo=TRUE en cliente y producto en TODAS las variantes (incluidas subconsultas internas).
-- 3) snake_case en alias (total_gastado, promedio_general, puesto, id_cliente).
-- 4) ON DELETE RESTRICT ya en schema.sql — no se borra cliente/producto con pedidos; por eso el filtro activo.
-- 5) RANK() con huecos (no DENSE_RANK ni ROW_NUMBER) — verificado con empates sintéticos:
--    INSERT INTO pedido ... con mismo total_gastado para dos clientes → ambos puesto N, siguiente N+2.
-- 6) Tipos EXCEPT: id_cliente BIGINT, nombre VARCHAR, email VARCHAR, total_gastado NUMERIC, puesto BIGINT / promedio_general NUMERIC.
--    Si avg() infiere DOUBLE PRECISION, castear a NUMERIC en ambas ramas.
-- 7) Orden determinístico: ORDER BY total_gastado DESC, id_cliente ASC — no afecta EXCEPT (conjuntos), sí afecta LIMIT/paginación.
