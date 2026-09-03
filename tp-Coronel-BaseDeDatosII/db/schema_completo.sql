-- =============================================================================
-- FoodStore — schema_completo.sql
-- UTN TUP — Base de Datos II — Unidad 2 Semana 3 — Optimización
-- Autor: Jerónimo Coronel — Motor: PostgreSQL 16/18 — Fecha: 2026-09-03
-- Origen canónico: db/schema.sql (72 líneas, commit 80ad8a2 R100)
-- Propósito: snapshot completo para la cátedra (schema + índices base).
--            La Parte 1 de carga masiva NO modifica este DDL — solo inserta.
-- Protocolo: ejecutar solo sobre foodstore_trabajo (copia), nunca sobre
--             foodstore_original. Ver docs/protocolo_seguridad.md §3.
-- =============================================================================

-- Dominio cerrado — forma de pago
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'forma_pago_enum') THEN
        CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');
    END IF;
END $$;

-- Entidad: Categoria
CREATE TABLE IF NOT EXISTS categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Entidad: Cliente  (enunciado Parte 1 dice "usuarios" → tabla real: cliente)
CREATE TABLE IF NOT EXISTS cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Entidad: Producto
CREATE TABLE IF NOT EXISTS producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    stock INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_producto_precio CHECK (precio >= 0),
    CONSTRAINT chk_producto_stock  CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id_categoria) ON DELETE RESTRICT
);

-- Entidad: Pedido  (enunciado Parte 1 dice "pedidos" → tabla real: pedido)
CREATE TABLE IF NOT EXISTS pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE RESTRICT
);

-- Entidad Asociativa: Detalle Pedido
CREATE TABLE IF NOT EXISTS detalle_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio   CHECK (precio_unitario >= 0),
    CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedido (id_pedido)     ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto (id_producto) ON DELETE RESTRICT
);

-- Índices base del modelo (existen en schema.sql:68)
CREATE INDEX IF NOT EXISTS idx_pedido_cliente ON pedido (id_cliente);
CREATE INDEX IF NOT EXISTS idx_producto_categoria_activo ON producto (id_categoria, activo);

-- Nota TP3: ningún índice adicional se crea aquí. Los índices de optimización
-- de la Parte 2 se proponen DESPUÉS de medir EXPLAIN ANALYZE y se documentan
-- en docs/optimizacion_tp3.md con nodo atacado + cost + tiempo real.
