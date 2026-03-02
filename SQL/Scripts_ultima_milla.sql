-- =====================================================
-- Script Completo - Base de Datos Última Milla (MySQL)
-- =====================================================

-- 1. Usuarios
CREATE TABLE usuarios (
    id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(150),
    email           VARCHAR(150) UNIQUE,
    telefono        VARCHAR(50),
    direccion       VARCHAR(255),
    rol             VARCHAR(50)
);

-- 2. Clientes
CREATE TABLE clientes (
    id_cliente  INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario  INT UNIQUE,
    direccion   VARCHAR(255),
    telefono    VARCHAR(50),
    email       VARCHAR(150),

    CONSTRAINT fk_cliente_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
);

-- 3. Bodega
CREATE TABLE bodega (
    id_bodega       INT AUTO_INCREMENT PRIMARY KEY,
    nombre_bodega   VARCHAR(150) NOT NULL,
    ubicacion_gps   VARCHAR(100),
    direccion       VARCHAR(255)
);

-- 4. Conductor
CREATE TABLE conductor (
    id_conductor    INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(150),
    nro_licencia    VARCHAR(100) UNIQUE,
    estado          VARCHAR(50)
);

-- 5. Pedidos
CREATE TABLE pedidos (
    id_pedido       INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario      INT,
    id_conductor    INT,
    id_bodega       INT,
    fecha_creacion  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_actual   VARCHAR(50),

    CONSTRAINT fk_pedido_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario),

    CONSTRAINT fk_pedido_conductor
        FOREIGN KEY (id_conductor)
        REFERENCES conductor(id_conductor),

    CONSTRAINT fk_pedido_bodega
        FOREIGN KEY (id_bodega)
        REFERENCES bodega(id_bodega)
);

-- 6. Geolocalizacion (se crea antes de seguimiento porque seguimiento la referencia)
CREATE TABLE geolocalizacion (
    id_geolocalizacion INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido          INT NOT NULL,
    latitud            DECIMAL(10,7) NOT NULL,
    longitud           DECIMAL(10,7) NOT NULL,
    descripcion_zona   VARCHAR(200),

    CONSTRAINT fk_geo_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE
);

-- 7. Seguimiento
CREATE TABLE seguimiento (
    id_seguimiento     INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido          INT NOT NULL,
    id_geolocalizacion INT NOT NULL,
    fecha_hora         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comentario         TEXT,

    CONSTRAINT fk_seg_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE,

    CONSTRAINT fk_seg_geo
        FOREIGN KEY (id_geolocalizacion)
        REFERENCES geolocalizacion(id_geolocalizacion)
        ON DELETE CASCADE
);

-- 8. Items del pedido
CREATE TABLE item (
    id_item           INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido         INT NOT NULL,
    descripcion       TEXT NOT NULL,
    peso              DECIMAL(10,2),
    cantidad          INT NOT NULL CHECK (cantidad > 0),

    CONSTRAINT fk_item_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE
);

-- 9. Vehiculos
CREATE TABLE vehiculos (
    id_vehiculo       INT AUTO_INCREMENT PRIMARY KEY,
    conductor_id      INT,
    placa             VARCHAR(20) UNIQUE NOT NULL,
    modelo            VARCHAR(100),
    capacidad_kg      DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_vehiculo_conductor
        FOREIGN KEY (conductor_id)
        REFERENCES conductor(id_conductor)
        ON DELETE SET NULL
);
