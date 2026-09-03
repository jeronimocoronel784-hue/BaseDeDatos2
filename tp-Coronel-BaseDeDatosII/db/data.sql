-- =============================================================================
-- FoodStore — data.sql — Seed mínimo idempotente (pre-carga masiva)
-- UTN TUP — BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
-- Propósito: poblar lo indispensable para que la carga masiva pueda
--            distribuir equitativamente y respetar FKs. No reemplaza
--            la carga masiva de 50k/20k/200k.
-- Idempotencia: INSERT ... ON CONFLICT DO NOTHING / WHERE NOT EXISTS
-- Protocolo: ejecutar dentro de BEGIN; ... ROLLBACK; primero, luego COMMIT.
-- =============================================================================

-- Categorías base (si la base está vacía, garantiza >=5 para distribución equitativa)
INSERT INTO categoria (nombre, activo)
SELECT c.nombre, TRUE
FROM (VALUES ('Lácteos'),('Panadería'),('Bebidas'),('Almacén'),('Congelados'),('Frutas'),('Carnes'),('Limpieza')) AS c(nombre)
WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE categoria.nombre = c.nombre);

-- Clientes semilla (20) — emails UNIQUE, nombres variados
INSERT INTO cliente (nombre, email, activo)
SELECT 'Cliente Seed ' || g, 'seed.cliente.' || g || '@foodstore.test', TRUE
FROM generate_series(1,20) AS g
ON CONFLICT (email) DO NOTHING;

-- Productos semilla (30) — 1 por categoría round-robin, precio/stock válidos (CHECK >=0)
INSERT INTO producto (id_categoria, nombre, precio, stock, activo)
SELECT
    cat.id_categoria,
    'Producto Seed ' || g,
    500 + (random()*4500)::int,          -- 500–5000
    (random()*200)::int,                 -- 0–200
    TRUE
FROM generate_series(1,30) AS g
JOIN LATERAL (
    SELECT id_categoria FROM categoria WHERE activo = TRUE ORDER BY id_categoria
    OFFSET ( (g-1) % (SELECT count(*) FROM categoria WHERE activo=TRUE) ) LIMIT 1
) cat ON TRUE
WHERE NOT EXISTS (SELECT 1 FROM producto WHERE producto.nombre = 'Producto Seed ' || g);

-- Pedidos semilla (20) — 1 por cliente seed, fecha últimos 30 días, forma_pago aleatoria
INSERT INTO pedido (id_cliente, fecha, forma_pago)
SELECT
    cli.id_cliente,
    now() - (random()*30 || ' days')::interval,
    (ARRAY['EFECTIVO','TARJETA','TRANSFERENCIA']::forma_pago_enum[])[1+floor(random()*3)::int]
FROM (SELECT id_cliente FROM cliente WHERE email LIKE 'seed.cliente.%@%' ORDER BY id_cliente LIMIT 20) cli
WHERE NOT EXISTS (SELECT 1 FROM pedido WHERE pedido.id_cliente = cli.id_cliente AND pedido.fecha::date = now()::date);

-- Detalle semilla — 1 línea por pedido seed (PK compuesta, CHECK cantidad>0)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT ped.id_pedido, prod.id_producto, 1 + (random()*3)::int, prod.precio
FROM (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 20) ped
JOIN LATERAL (SELECT id_producto, precio FROM producto WHERE activo=TRUE ORDER BY random() LIMIT 1) prod ON TRUE
ON CONFLICT (id_pedido, id_producto) DO NOTHING;

-- Refrescar estadísticas para que EXPLAIN use histogramas reales
ANALYZE categoria; ANALYZE cliente; ANALYZE producto; ANALYZE pedido; ANALYZE detalle_pedido;

-- Verificación rápida (fuera de transacción):
-- SELECT 'categoria' AS tabla, count(*) FROM categoria UNION ALL
-- SELECT 'cliente', count(*) FROM cliente UNION ALL
-- SELECT 'producto', count(*) FROM producto UNION ALL
-- SELECT 'pedido', count(*) FROM pedido UNION ALL
-- SELECT 'detalle_pedido', count(*) FROM detalle_pedido;
