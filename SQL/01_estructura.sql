-- =====================================================
-- 01 - Estructura de Tablas - Última Milla (MySQL)
-- Base de datos: DBMySQLGrupo1a
-- =====================================================
-- En DBeaver: Ctrl+A luego Alt+X
-- =====================================================

-- PASO 1: Eliminar tablas existentes
DROP TABLE IF EXISTS seguimiento;
DROP TABLE IF EXISTS geolocalizacion;
DROP TABLE IF EXISTS item;
DROP TABLE IF EXISTS vehiculos;
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS conductor;
DROP TABLE IF EXISTS bodega;
DROP TABLE IF EXISTS usuarios;

-- PASO 2: Crear tablas sin foreign keys

CREATE TABLE usuarios (
    id_usuario  INT NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100) NOT NULL,
    apellidos   VARCHAR(150),
    email       VARCHAR(150),
    telefono    VARCHAR(50),
    direccion   VARCHAR(255),
    rol         VARCHAR(50),
    PRIMARY KEY (id_usuario),
    UNIQUE KEY uk_usuario_email (email)
) ENGINE=InnoDB;

CREATE TABLE clientes (
    id_cliente  INT NOT NULL AUTO_INCREMENT,
    id_usuario  INT,
    direccion   VARCHAR(255),
    telefono    VARCHAR(50),
    email       VARCHAR(150),
    PRIMARY KEY (id_cliente),
    UNIQUE KEY uk_cliente_usuario (id_usuario)
) ENGINE=InnoDB;

CREATE TABLE bodega (
    id_bodega       INT NOT NULL AUTO_INCREMENT,
    nombre_bodega   VARCHAR(150) NOT NULL,
    ubicacion_gps   VARCHAR(100),
    direccion       VARCHAR(255),
    PRIMARY KEY (id_bodega)
) ENGINE=InnoDB;

CREATE TABLE conductor (
    id_conductor    INT NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(150),
    nro_licencia    VARCHAR(100),
    estado          VARCHAR(50),
    PRIMARY KEY (id_conductor),
    UNIQUE KEY uk_conductor_licencia (nro_licencia)
) ENGINE=InnoDB;

CREATE TABLE pedidos (
    id_pedido       INT NOT NULL AUTO_INCREMENT,
    id_usuario      INT,
    id_conductor    INT,
    id_bodega       INT,
    fecha_creacion  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_actual   VARCHAR(50),
    PRIMARY KEY (id_pedido)
) ENGINE=InnoDB;

CREATE TABLE geolocalizacion (
    id_geolocalizacion  INT NOT NULL AUTO_INCREMENT,
    id_pedido           INT NOT NULL,
    latitud             DECIMAL(10,7) NOT NULL,
    longitud            DECIMAL(10,7) NOT NULL,
    descripcion_zona    VARCHAR(200),
    PRIMARY KEY (id_geolocalizacion)
) ENGINE=InnoDB;

CREATE TABLE seguimiento (
    id_seguimiento      INT NOT NULL AUTO_INCREMENT,
    id_pedido           INT NOT NULL,
    id_geolocalizacion  INT NOT NULL,
    fecha_hora          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comentario          TEXT,
    PRIMARY KEY (id_seguimiento)
) ENGINE=InnoDB;

CREATE TABLE item (
    id_item       INT NOT NULL AUTO_INCREMENT,
    id_pedido     INT NOT NULL,
    descripcion   TEXT NOT NULL,
    peso          DECIMAL(10,2),
    cantidad      INT NOT NULL,
    PRIMARY KEY (id_item)
) ENGINE=InnoDB;

CREATE TABLE vehiculos (
    id_vehiculo     INT NOT NULL AUTO_INCREMENT,
    conductor_id    INT,
    placa           VARCHAR(20) NOT NULL,
    modelo          VARCHAR(100),
    capacidad_kg    DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_vehiculo),
    UNIQUE KEY uk_vehiculo_placa (placa)
) ENGINE=InnoDB;

-- PASO 3: Agregar foreign keys con ALTER TABLE

ALTER TABLE clientes
    ADD CONSTRAINT fk_cliente_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario);

ALTER TABLE pedidos
    ADD CONSTRAINT fk_pedido_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario),
    ADD CONSTRAINT fk_pedido_conductor FOREIGN KEY (id_conductor) REFERENCES conductor (id_conductor),
    ADD CONSTRAINT fk_pedido_bodega FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega);

ALTER TABLE geolocalizacion
    ADD CONSTRAINT fk_geo_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos (id_pedido) ON DELETE CASCADE;

ALTER TABLE seguimiento
    ADD CONSTRAINT fk_seg_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos (id_pedido) ON DELETE CASCADE,
    ADD CONSTRAINT fk_seg_geo FOREIGN KEY (id_geolocalizacion) REFERENCES geolocalizacion (id_geolocalizacion) ON DELETE CASCADE;

ALTER TABLE item
    ADD CONSTRAINT fk_item_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos (id_pedido) ON DELETE CASCADE;

ALTER TABLE vehiculos
    ADD CONSTRAINT fk_vehiculo_conductor FOREIGN KEY (conductor_id) REFERENCES conductor (id_conductor) ON DELETE SET NULL;
