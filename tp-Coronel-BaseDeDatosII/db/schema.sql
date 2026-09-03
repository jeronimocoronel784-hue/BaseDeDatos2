-- Creacion de dominios cerrados mediante un tipo enumerado
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- Entidad: Categoria
CREATE TABLE categoria (
    -- Identificador numerico con clave autogenerada
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    -- Marca de baja logica en verdadero por defecto para conservar historial
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Entidad: Cliente
CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    -- Restriccion UNIQUE para reflejar la clave candidata identificada (R6)
    email VARCHAR(150) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Entidad: Producto
CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    -- Monto monetario con precision fija
    precio NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    -- Restricciones CHECK para expresar reglas de negocio (R5: precio y stock no negativos)
    CONSTRAINT chk_producto_precio CHECK (precio >= 0),
    CONSTRAINT chk_producto_stock CHECK (stock >= 0),
    -- Se elige ON DELETE RESTRICT para no perder el historial de pedidos que los referencian en caso de intento de borrado fisico
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) 
        REFERENCES categoria (id_categoria) ON DELETE RESTRICT
);

-- Entidad: Pedido
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL,
    -- Fecha de creacion en el momento de la insercion con zona horaria
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    -- Se elige ON DELETE RESTRICT por regla de negocio para no perder pedidos historicos ante un borrado de cliente
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) 
        REFERENCES cliente (id_cliente) ON DELETE RESTRICT
);

-- Entidad Asociativa: Detalle Pedido
CREATE TABLE detalle_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL,
    -- Clave primaria compuesta para cumplir la regla de que un producto no se repita en mas de una linea dentro del mismo pedido
    PRIMARY KEY (id_pedido, id_producto),
    -- Restriccion CHECK adicional para cantidad positiva
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio CHECK (precio_unitario >= 0),
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido) 
        REFERENCES pedido (id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) 
        REFERENCES producto (id_producto) ON DELETE RESTRICT
);

-- Indice 1: Acelera la busqueda de los pedidos de un cliente especifico
CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);

-- Indice 2: Acelera el listado de productos vigentes dentro de una categoria
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo);