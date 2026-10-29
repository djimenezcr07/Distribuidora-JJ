-- ADVERTENCIA P0: contiene DROP TABLE y no es una migracion incremental.
-- No ejecutar contra Azure SQL DEV. Requiere respaldo y aprobacion explicita.
IF DB_ID('DistribuidoraJJ_DB') IS NULL
BEGIN
    CREATE DATABASE DistribuidoraJJ_DB;
END
GO

USE DistribuidoraJJ_DB;
GO

IF OBJECT_ID('dbo.FacturaDetalle', 'U') IS NOT NULL DROP TABLE dbo.FacturaDetalle;
IF OBJECT_ID('dbo.Facturas', 'U') IS NOT NULL DROP TABLE dbo.Facturas;
IF OBJECT_ID('dbo.MovimientosInventario', 'U') IS NOT NULL DROP TABLE dbo.MovimientosInventario;
IF OBJECT_ID('dbo.PasswordResetTokens', 'U') IS NOT NULL DROP TABLE dbo.PasswordResetTokens;
IF OBJECT_ID('dbo.PedidoDetalle', 'U') IS NOT NULL DROP TABLE dbo.PedidoDetalle;
IF OBJECT_ID('dbo.Pedidos', 'U') IS NOT NULL DROP TABLE dbo.Pedidos;
IF OBJECT_ID('dbo.Productos', 'U') IS NOT NULL DROP TABLE dbo.Productos;
IF OBJECT_ID('dbo.Empleados', 'U') IS NOT NULL DROP TABLE dbo.Empleados;
IF OBJECT_ID('dbo.Usuarios', 'U') IS NOT NULL DROP TABLE dbo.Usuarios;
IF OBJECT_ID('dbo.Perfiles', 'U') IS NOT NULL DROP TABLE dbo.Perfiles;
IF OBJECT_ID('dbo.ErrorLog', 'U') IS NOT NULL DROP TABLE dbo.ErrorLog;
GO

CREATE TABLE dbo.Perfiles (
    PerfilId INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(50) NOT NULL UNIQUE,
    Descripcion NVARCHAR(255) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE dbo.Usuarios (
    UsuarioId INT IDENTITY(1,1) PRIMARY KEY,
    PerfilId INT NOT NULL,
    NombreCompleto NVARCHAR(150) NOT NULL,
    Correo NVARCHAR(150) NOT NULL UNIQUE,
    Contrasena NVARCHAR(255) NOT NULL,
    Telefono NVARCHAR(30) NULL,
    Direccion NVARCHAR(255) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Usuarios_Perfiles FOREIGN KEY (PerfilId) REFERENCES dbo.Perfiles(PerfilId)
);
GO

CREATE TABLE dbo.Empleados (
    EmpleadoId INT IDENTITY(1,1) PRIMARY KEY,
    UsuarioId INT NOT NULL UNIQUE,
    Puesto NVARCHAR(100) NOT NULL,
    Salario DECIMAL(18,2) NULL,
    FechaContratacion DATE NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Empleados_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);
GO

CREATE TABLE dbo.Productos (
    ProductoId INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(150) NOT NULL,
    Categoria NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(255) NULL,
    Precio DECIMAL(18,2) NOT NULL,
    Stock INT NOT NULL DEFAULT 0,
    EstadoStock AS (
        CASE
            WHEN Stock <= 0 THEN 'Agotado'
            WHEN Stock <= 5 THEN 'Bajo'
            ELSE 'Normal'
        END
    ),
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE dbo.Pedidos (
    PedidoId INT IDENTITY(1,1) PRIMARY KEY,
    UsuarioId INT NOT NULL,
    FechaPedido DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    Estado NVARCHAR(30) NOT NULL DEFAULT 'Pendiente',
    TipoEntrega NVARCHAR(50) NULL,
    DireccionEntrega NVARCHAR(255) NULL,
    Total DECIMAL(18,2) NOT NULL DEFAULT 0,
    Observaciones NVARCHAR(255) NULL,
    CONSTRAINT FK_Pedidos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);
GO

CREATE TABLE dbo.PedidoDetalle (
    PedidoDetalleId INT IDENTITY(1,1) PRIMARY KEY,
    PedidoId INT NOT NULL,
    ProductoId INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18,2) NOT NULL,
    Subtotal AS (Cantidad * PrecioUnitario),
    CONSTRAINT FK_PedidoDetalle_Pedidos FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos(PedidoId),
    CONSTRAINT FK_PedidoDetalle_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId)
);
GO

CREATE TABLE dbo.MovimientosInventario (
    MovimientoId INT IDENTITY(1,1) PRIMARY KEY,
    ProductoId INT NOT NULL,
    ProductoNombre NVARCHAR(150) NOT NULL,
    TipoMovimiento NVARCHAR(30) NOT NULL,
    Cantidad INT NOT NULL,
    StockAnterior INT NOT NULL,
    StockNuevo INT NOT NULL,
    Motivo NVARCHAR(250) NULL,
    UsuarioId INT NOT NULL,
    UsuarioNombre NVARCHAR(150) NOT NULL,
    FechaMovimiento DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_MovimientosInventario_Producto FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId),
    CONSTRAINT FK_MovimientosInventario_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);
GO

CREATE TABLE dbo.Facturas (
    FacturaId INT IDENTITY(1,1) PRIMARY KEY,
    PedidoId INT NOT NULL UNIQUE,
    NumeroFactura NVARCHAR(30) NOT NULL UNIQUE,
    UsuarioId INT NOT NULL,
    ClienteNombre NVARCHAR(150) NOT NULL,
    ClienteCorreo NVARCHAR(150) NOT NULL,
    FechaFactura DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    Subtotal DECIMAL(18,2) NOT NULL,
    Impuesto DECIMAL(18,2) NOT NULL,
    Total DECIMAL(18,2) NOT NULL,
    Estado NVARCHAR(20) NOT NULL DEFAULT 'Generada',
    CONSTRAINT FK_Facturas_Pedido FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos(PedidoId),
    CONSTRAINT FK_Facturas_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);
GO

CREATE TABLE dbo.FacturaDetalle (
    FacturaDetalleId INT IDENTITY(1,1) PRIMARY KEY,
    FacturaId INT NOT NULL,
    ProductoId INT NOT NULL,
    ProductoNombre NVARCHAR(150) NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18,2) NOT NULL,
    Subtotal AS (Cantidad * PrecioUnitario),
    CONSTRAINT FK_FacturaDetalle_Factura FOREIGN KEY (FacturaId) REFERENCES dbo.Facturas(FacturaId),
    CONSTRAINT FK_FacturaDetalle_Producto FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId)
);
GO

CREATE TABLE dbo.PasswordResetTokens (
    PasswordResetTokenId INT IDENTITY(1,1) PRIMARY KEY,
    UsuarioId INT NOT NULL,
    Token NVARCHAR(120) NOT NULL UNIQUE,
    FechaExpiracion DATETIME2 NOT NULL,
    Usado BIT NOT NULL DEFAULT 0,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_PasswordResetTokens_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);
GO

CREATE TABLE dbo.ErrorLog (
    ErrorId INT IDENTITY(1,1) PRIMARY KEY,
    Mensaje NVARCHAR(500) NOT NULL,
    Origen NVARCHAR(255) NULL,
    StackTrace NVARCHAR(MAX) NULL,
    Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

INSERT INTO dbo.Perfiles (Nombre, Descripcion)
VALUES
('Administrador', 'Acceso completo al sistema'),
('Cliente', 'Cliente registrado para realizar pedidos'),
('Empleado', 'Personal interno de la distribuidora');
GO

DECLARE @DemoPassword NVARCHAR(256) = N'<SET_AT_EXECUTION>';
IF @DemoPassword = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 51000, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
VALUES
(1, 'Administrador General', 'admin@distribuidorajj.com', @DemoPassword, '0000-0000', 'Oficina Central'),
(2, 'Cliente Demo', 'cliente@distribuidorajj.com', @DemoPassword, '8888-1111', 'San José Centro'),
(2, 'Cliente Tienda', 'ventas@clientejj.com', @DemoPassword, '8888-2222', 'Desamparados');
GO

INSERT INTO dbo.Empleados (UsuarioId, Puesto, Salario, FechaContratacion, Activo)
VALUES
(1, 'Administrador del sistema', 950000, '2025-01-01', 1);
GO

INSERT INTO dbo.Productos (Nombre, Categoria, Descripcion, Precio, Stock)
VALUES
('Cacique 750ml', 'Licorera', 'Licor nacional 750ml', 6500, 20),
('Coca-Cola 2.5L', 'Supermercado', 'Bebida gaseosa retornable', 1850, 35),
('Cerveza Pilsen 6 Pack', 'Mayoreo', 'Pack de 6 cervezas', 4200, 15),
('Whisky Black Label 750ml', 'Licorera', 'Whisky premium 12 años', 35900, 4),
('Vino Tinto Reserva 750ml', 'Licorera', 'Vino reserva nacional', 8900, 0),
('Agua 600ml', 'Supermercado', 'Botella de agua purificada', 650, 48);
GO

INSERT INTO dbo.MovimientosInventario (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre)
SELECT ProductoId, Nombre, 'Entrada', Stock, 0, Stock, 'Carga inicial del inventario.', 1, 'Administrador General'
FROM dbo.Productos;
GO

INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total, Observaciones)
VALUES
(2, DATEADD(DAY, -2, SYSDATETIME()), 'Pendiente', 'Entrega a domicilio', 'San José Centro', 16600, 'Cliente solicita entrega en horas de la tarde.'),
(3, DATEADD(DAY, -1, SYSDATETIME()), 'Entregado', 'Retiro en tienda', 'Sucursal principal', 13000, 'Pedido retirado personalmente.');
GO

INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
VALUES
(1, 1, 2, 6500),
(1, 2, 2, 1850),
(2, 1, 2, 6500);
GO

INSERT INTO dbo.Facturas (PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo, FechaFactura, Subtotal, Impuesto, Total, Estado)
VALUES
(2, 'FAC-000002', 3, 'Cliente Tienda', 'ventas@clientejj.com', DATEADD(DAY, -1, SYSDATETIME()), 13000, 1690, 14690, 'Generada');
GO

INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
VALUES
(1, 1, 'Cacique 750ml', 2, 6500);
GO
