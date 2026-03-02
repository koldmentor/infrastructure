-- =====================================================
-- 02 - Datos de Prueba - Última Milla (MySQL)
-- Base de datos: DBMySQLGrupo1a
-- =====================================================
-- Ejecutar DESPUES de 01_estructura.sql
-- En DBeaver: Ctrl+A luego Alt+X
-- =====================================================

-- Limpiar datos existentes
DELETE FROM seguimiento;
DELETE FROM geolocalizacion;
DELETE FROM item;
DELETE FROM vehiculos;
DELETE FROM pedidos;
DELETE FROM clientes;
DELETE FROM conductor;
DELETE FROM bodega;
DELETE FROM usuarios;

-- Reiniciar auto_increment
ALTER TABLE usuarios AUTO_INCREMENT = 1;
ALTER TABLE clientes AUTO_INCREMENT = 1;
ALTER TABLE bodega AUTO_INCREMENT = 1;
ALTER TABLE conductor AUTO_INCREMENT = 1;
ALTER TABLE pedidos AUTO_INCREMENT = 1;
ALTER TABLE geolocalizacion AUTO_INCREMENT = 1;
ALTER TABLE seguimiento AUTO_INCREMENT = 1;
ALTER TABLE item AUTO_INCREMENT = 1;
ALTER TABLE vehiculos AUTO_INCREMENT = 1;

-- Insertar datos

INSERT INTO usuarios (nombre, apellidos, email, telefono, direccion, rol) VALUES
('Carlos', 'Gomez Rios', 'carlos.gomez@email.com', '3001234567', 'Calle 10 #45-20, Medellin', 'admin'),
('Maria', 'Lopez Torres', 'maria.lopez@email.com', '3109876543', 'Carrera 50 #30-15, Medellin', 'cliente'),
('Juan', 'Perez Muñoz', 'juan.perez@email.com', '3205551234', 'Avenida 80 #12-30, Medellin', 'conductor');

INSERT INTO clientes (id_usuario, direccion, telefono, email) VALUES
(1, 'Carrera 50 #30-15, Medellin', '3109876543', 'maria.lopez@email.com');

INSERT INTO bodega (nombre_bodega, ubicacion_gps, direccion) VALUES
('Bodega Central', '6.2442,-75.5812', 'Zona Industrial, Medellin'),
('Bodega Norte', '6.2890,-75.5650', 'Barrio Aranjuez, Medellin');

INSERT INTO conductor (nombre, apellido, nro_licencia, estado) VALUES
('Juan', 'Perez Muñoz', 'LIC-001234', 'disponible'),
('Andrea', 'Martinez Silva', 'LIC-005678', 'en_ruta');

INSERT INTO pedidos (id_usuario, id_conductor, id_bodega, estado_actual) VALUES
(1, 1, 1, 'en_transito'),
(1, 2, 2, 'pendiente');

INSERT INTO geolocalizacion (id_pedido, latitud, longitud, descripcion_zona) VALUES
(1, 6.2442000, -75.5812000, 'Zona Industrial - Salida'),
(1, 6.2518000, -75.5730000, 'Barrio Colombia - En camino');

INSERT INTO seguimiento (id_pedido, id_geolocalizacion, comentario) VALUES
(1, 1, 'Pedido recogido en bodega central'),
(1, 2, 'En camino hacia destino');

INSERT INTO item (id_pedido, descripcion, peso, cantidad) VALUES
(1, 'Caja de documentos', 2.50, 1),
(1, 'Paquete electronico', 1.20, 2),
(2, 'Sobre certificado', 0.30, 3);

INSERT INTO vehiculos (conductor_id, placa, modelo, capacidad_kg) VALUES
(1, 'ABC123', 'Chevrolet NHR 2022', 3500.00),
(2, 'XYZ789', 'Kia K2700 2021', 2700.00);

-- Verificar
SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'bodega', COUNT(*) FROM bodega
UNION ALL SELECT 'conductor', COUNT(*) FROM conductor
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'geolocalizacion', COUNT(*) FROM geolocalizacion
UNION ALL SELECT 'seguimiento', COUNT(*) FROM seguimiento
UNION ALL SELECT 'item', COUNT(*) FROM item
UNION ALL SELECT 'vehiculos', COUNT(*) FROM vehiculos;
