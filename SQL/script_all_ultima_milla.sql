CREATE TABLE seguimiento (
    id_seguimiento     SERIAL PRIMARY KEY,
    id_pedido          INTEGER NOT NULL,
    id_geolocalizacion INTEGER NOT NULL,
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
/
CREATE TABLE geolocalizacion (
    id_geolocalizacion SERIAL PRIMARY KEY,
    id_pedido          INTEGER NOT NULL,
    latitud            NUMERIC(10,7) NOT NULL,
    longitud           NUMERIC(10,7) NOT NULL,
    descripcion_zona   VARCHAR(200),

    CONSTRAINT fk_geo_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE
);
/
CREATE TABLE item (
    id_item           SERIAL PRIMARY KEY,
    id_pedido         INTEGER NOT NULL,
    descripcion       TEXT NOT NULL,
    peso              NUMERIC(10,2),
    cantidad          INTEGER NOT NULL CHECK (cantidad > 0),

    CONSTRAINT fk_item_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedidos(id_pedido)
        ON DELETE CASCADE
);
/
CREATE TABLE vehiculos (
    id_vehiculo       SERIAL PRIMARY KEY,
    conductor_id      INTEGER NOT NULL,
    placa             VARCHAR(20) UNIQUE NOT NULL,
    modelo            VARCHAR(100),
    capacidad_kg      NUMERIC(10,2) NOT NULL,

    CONSTRAINT fk_vehiculo_conductor
        FOREIGN KEY (conductor_id)
        REFERENCES conductor(id_conductor)
        ON DELETE SET NULL
);