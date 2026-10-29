-- =============================================
-- SCRIPT CONSOLIDADO LIMPIO PARA EJECUCION UNICA
-- Base de datos: DistribuidoraJJ_DB
-- ADVERTENCIA P0: contiene DROP TABLE y no es una migracion incremental.
-- No ejecutar contra Azure SQL DEV. Requiere respaldo y aprobacion explicita.
-- =============================================

PRINT 'Paso 1/5: estructura base y datos iniciales';
GO
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
IF OBJECT_ID('dbo.Categorias', 'U') IS NOT NULL DROP TABLE dbo.Categorias;
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

CREATE TABLE dbo.Categorias (
    CategoriaId INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL UNIQUE,
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE dbo.Productos (
    ProductoId INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(150) NOT NULL,
    Categoria NVARCHAR(100) NOT NULL,
    CategoriaId INT NULL,
    Descripcion NVARCHAR(255) NULL,
    Precio DECIMAL(18,2) NOT NULL,
    Stock INT NOT NULL DEFAULT 0,
    ImagenUrl NVARCHAR(300) NULL,
    EsDestacado BIT NOT NULL CONSTRAINT DF_Productos_EsDestacado DEFAULT(0),
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
    IdentificacionCliente NVARCHAR(100) NULL,
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

PRINT 'Paso 2/5: datos base';
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
(2, 'Cliente Demo', 'cliente@distribuidorajj.com', @DemoPassword, '8888-1111', 'San JosÃ© Centro'),
(2, 'Cliente Tienda', 'ventas@clientejj.com', @DemoPassword, '8888-2222', 'Desamparados');
GO

INSERT INTO dbo.Empleados (UsuarioId, Puesto, Salario, FechaContratacion, Activo)
VALUES
(1, 'Administrador del sistema', 950000, '2025-01-01', 1);
GO

INSERT INTO dbo.Categorias (Nombre)
VALUES
('Licorera'),
('Supermercado'),
('Mayoreo'),
('Ron'),
('Vodka'),
('Tequila'),
('Cerveza'),
('Whisky'),
('Vino');
GO

INSERT INTO dbo.Productos (Nombre, Categoria, CategoriaId, Descripcion, Precio, Stock, ImagenUrl, EsDestacado, Activo)
VALUES
('Cacique 750ml', 'Licorera', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Licorera'), 'Licor nacional 750ml', 6500, 20, NULL, 0, 1),
('Coca-Cola 2.5L', 'Supermercado', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Supermercado'), 'Bebida gaseosa retornable', 1850, 35, NULL, 0, 1),
('Cerveza Pilsen 6 Pack', 'Mayoreo', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Mayoreo'), 'Pack de 6 cervezas', 4200, 15, NULL, 0, 1),
('Whisky Black Label 750ml', 'Whisky', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Whisky'), 'Whisky premium 12 aÃ±os', 35900, 4, '~/img/DES-Whisky Black Label.png', 1, 1),
('Vino Tinto Reserva 750ml', 'Vino', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Vino'), 'Vino reserva nacional', 8900, 0, '~/img/DES-Vino Tinto Reserva 750ml.png', 1, 1),
('Agua 600ml', 'Supermercado', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Supermercado'), 'Botella de agua purificada', 650, 48, NULL, 0, 1),
('Ron AÃ±ejo 750ml', 'Ron', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Ron'), 'Ron aÃ±ejo de presentaciÃ³n estÃ¡ndar.', 12900, 20, '~/img/CAT- Ron.png', 0, 1),
('Vodka Premium 750ml', 'Vodka', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Vodka'), 'Vodka clÃ¡sico de 750ml.', 10900, 18, '~/img/CAT-Vodka.webp', 0, 1),
('Tequila Reposado 750ml', 'Tequila', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Tequila'), 'Tequila reposado de 750ml.', 16900, 12, '~/img/CAT-Tequila.webp', 0, 1),
('Pack Cervezas 6 unidades', 'Cerveza', (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre='Cerveza'), 'Pack de 6 cervezas.', 6900, 30, '~/img/DES-Pack Cervezas (6 unidades).webp', 1, 1);
GO

INSERT INTO dbo.MovimientosInventario (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre)
SELECT ProductoId, Nombre, 'Entrada', Stock, 0, Stock, 'Carga inicial del inventario.', 1, 'Administrador General'
FROM dbo.Productos;
GO

INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total, Observaciones)
VALUES
(2, DATEADD(DAY, -2, SYSDATETIME()), 'Pendiente', 'Entrega a domicilio', 'San JosÃ© Centro', 16600, 'Cliente solicita entrega en horas de la tarde.'),
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

PRINT 'Paso 3/5: FK y ajustes';
GO
ALTER TABLE dbo.Productos
ADD CONSTRAINT FK_Productos_Categorias FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias(CategoriaId);
GO

PRINT 'Paso 4/5: procedimientos almacenados';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Nombre
    FROM dbo.Categorias
    WHERE Activo = 1
      AND Nombre IS NOT NULL
      AND LTRIM(RTRIM(Nombre)) <> ''
    ORDER BY Nombre ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        ISNULL(NULLIF(LTRIM(RTRIM(ImagenUrl)), ''), '~/img/whisky-premium.webp') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado
    FROM dbo.Productos
    WHERE Activo = 1
      AND (@Categoria IS NULL OR Categoria = @Categoria OR Categoria LIKE '%' + @Categoria + '%')
      AND (@Buscar IS NULL OR Nombre LIKE '%' + @Buscar + '%' OR Categoria LIKE '%' + @Buscar + '%' OR Descripcion LIKE '%' + @Buscar + '%')
    ORDER BY Nombre ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProductById
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        ISNULL(NULLIF(LTRIM(RTRIM(ImagenUrl)), ''), '~/img/whisky-premium.webp') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId
      AND Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProducts
    @Filtro NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        CASE WHEN Stock <= 0 THEN 'Agotado' WHEN Stock <= 5 THEN 'Stock bajo' ELSE 'Disponible' END AS EstadoStock,
        Activo,
        FechaCreacion,
        ISNULL(ImagenUrl, '') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado
    FROM dbo.Productos
    WHERE @Filtro IS NULL OR Nombre LIKE '%' + @Filtro + '%' OR Categoria LIKE '%' + @Filtro + '%'
    ORDER BY ProductoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetActiveProductsForSelect
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        CASE WHEN Stock <= 0 THEN 'Agotado' WHEN Stock <= 5 THEN 'Stock bajo' ELSE 'Disponible' END AS EstadoStock,
        Activo,
        FechaCreacion,
        ISNULL(ImagenUrl, '') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado
    FROM dbo.Productos
    WHERE Activo = 1
    ORDER BY Nombre ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProductById
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ISNULL(ImagenUrl, '') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateProduct
    @Nombre NVARCHAR(150),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(255) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @Activo BIT,
    @ImagenUrl NVARCHAR(255) = NULL,
    @EsDestacado BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Productos (Nombre, Categoria, Descripcion, Precio, Stock, Activo, ImagenUrl, EsDestacado)
    VALUES (@Nombre, @Categoria, @Descripcion, @Precio, @Stock, @Activo, @ImagenUrl, @EsDestacado);
    SELECT CAST(SCOPE_IDENTITY() AS INT);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateProduct
    @ProductoId INT,
    @Nombre NVARCHAR(200),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(MAX) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @Activo BIT,
    @ImagenUrl NVARCHAR(255) = NULL,
    @EsDestacado BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos
    SET Nombre = LTRIM(RTRIM(@Nombre)),
        Categoria = LTRIM(RTRIM(@Categoria)),
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
        Precio = @Precio,
        Stock = @Stock,
        Activo = @Activo,
        ImagenUrl = NULLIF(LTRIM(RTRIM(@ImagenUrl)), ''),
        EsDestacado = @EsDestacado
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleProductStatus
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos
    SET Activo = CASE WHEN Activo = 1 THEN 0 ELSE 1 END
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProductStock
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Stock
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateProductStock
    @ProductoId INT,
    @NuevoStock INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos
    SET Stock = @NuevoStock
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProductNameById
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Nombre
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateInventoryMovement
    @ProductoId INT,
    @ProductoNombre NVARCHAR(200),
    @TipoMovimiento NVARCHAR(50),
    @Cantidad INT,
    @StockAnterior INT,
    @StockNuevo INT,
    @Motivo NVARCHAR(500) = NULL,
    @UsuarioId INT,
    @UsuarioNombre NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.MovimientosInventario (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre)
    VALUES (@ProductoId, @ProductoNombre, @TipoMovimiento, @Cantidad, @StockAnterior, @StockNuevo, NULLIF(LTRIM(RTRIM(@Motivo)), ''), @UsuarioId, @UsuarioNombre);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInventoryMovements
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 200 MovimientoId, ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre, FechaMovimiento
    FROM dbo.MovimientosInventario
    ORDER BY FechaMovimiento DESC, MovimientoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetActiveProductForMovement
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Nombre, Stock
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId
      AND Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardSummary
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Productos) AS TotalProductos,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1) AS ProductosActivos,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Stock BETWEEN 1 AND 5 AND Activo = 1) AS StockBajo,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Stock <= 0 AND Activo = 1) AS ProductosAgotados,
        (SELECT COUNT(*) FROM dbo.Pedidos) AS TotalPedidos,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Pendiente') AS PedidosPendientes,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'EnProceso') AS PedidosEnProceso,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Entregado') AS PedidosEntregados,
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada'), 0) AS VentasTotales,
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada' AND YEAR(FechaFactura) = YEAR(GETDATE()) AND MONTH(FechaFactura) = MONTH(GETDATE())), 0) AS VentasMesActual;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardLowStock
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 5 ProductoId, Nombre, Categoria, Stock,
        CASE WHEN Stock <= 0 THEN 'Agotado' WHEN Stock <= 5 THEN 'Stock bajo' ELSE 'Disponible' END AS EstadoStock
    FROM dbo.Productos
    WHERE Activo = 1 AND Stock <= 5
    ORDER BY Stock ASC, Nombre ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardRecentOrders
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 5 p.PedidoId, u.NombreCompleto, p.FechaPedido, p.Estado, p.Total
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    ORDER BY p.FechaPedido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrders
    @Estado NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PedidoId, u.NombreCompleto, u.Correo, p.FechaPedido, p.Estado, p.TipoEntrega, p.DireccionEntrega, p.Total,
           (SELECT COUNT(*) FROM dbo.PedidoDetalle d WHERE d.PedidoId = p.PedidoId) AS TotalLineas
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE (@Estado IS NULL OR p.Estado = @Estado)
    ORDER BY p.FechaPedido DESC, p.PedidoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderHeader
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PedidoId, p.UsuarioId, u.NombreCompleto, u.Correo, p.FechaPedido, p.Estado, p.TipoEntrega, p.DireccionEntrega, p.Total, p.Observaciones
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderDetailLines
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.PedidoDetalleId, pr.Nombre, d.ProductoId, d.Cantidad, d.PrecioUnitario, d.Subtotal, pr.Stock
    FROM dbo.PedidoDetalle d
    INNER JOIN dbo.Productos pr ON pr.ProductoId = d.ProductoId
    WHERE d.PedidoId = @PedidoId
    ORDER BY d.PedidoDetalleId ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId INT,
    @Estado NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Pedidos
    SET Estado = @Estado
    WHERE PedidoId = @PedidoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_SalesSummary
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada'), 0) AS VentasTotales,
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada' AND YEAR(FechaFactura) = YEAR(GETDATE()) AND MONTH(FechaFactura) = MONTH(GETDATE())), 0) AS VentasMesActual,
        (SELECT COUNT(*) FROM dbo.Facturas) AS TotalFacturas,
        (SELECT COUNT(*) FROM dbo.Facturas WHERE YEAR(FechaFactura) = YEAR(GETDATE()) AND MONTH(FechaFactura) = MONTH(GETDATE())) AS FacturasMesActual,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Entregado') AS PedidosEntregados;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoices
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 50 FacturaId, PedidoId, NumeroFactura, ClienteNombre, FechaFactura, Subtotal, Impuesto, Total, Estado
    FROM dbo.Facturas
    ORDER BY FechaFactura DESC, FacturaId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetTopSellingProducts
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 10 fd.ProductoNombre, SUM(fd.Cantidad) AS CantidadVendida, SUM(fd.Subtotal) AS MontoVendido
    FROM dbo.FacturaDetalle fd
    INNER JOIN dbo.Facturas f ON f.FacturaId = fd.FacturaId
    WHERE f.Estado = 'Generada'
    GROUP BY fd.ProductoNombre
    ORDER BY CantidadVendida DESC, MontoVendido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetMonthlySales
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FORMAT(FechaFactura, 'yyyy-MM') AS Periodo, SUM(Total) AS Total
    FROM dbo.Facturas
    WHERE Estado = 'Generada'
    GROUP BY FORMAT(FechaFactura, 'yyyy-MM')
    ORDER BY Periodo DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceHeader
    @FacturaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FacturaId, PedidoId, NumeroFactura, ClienteNombre, ClienteCorreo, FechaFactura, Subtotal, Impuesto, Total, Estado
    FROM dbo.Facturas
    WHERE FacturaId = @FacturaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceLines
    @FacturaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductoNombre, Cantidad, PrecioUnitario, Subtotal
    FROM dbo.FacturaDetalle
    WHERE FacturaId = @FacturaId
    ORDER BY FacturaDetalleId ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceByOrderId
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FacturaId
    FROM dbo.Facturas
    WHERE PedidoId = @PedidoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateInvoice
    @PedidoId INT,
    @NumeroFactura NVARCHAR(50),
    @UsuarioId INT,
    @ClienteNombre NVARCHAR(200),
    @ClienteCorreo NVARCHAR(200),
    @Subtotal DECIMAL(18,2),
    @Impuesto DECIMAL(18,2),
    @Total DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Facturas (PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo, Subtotal, Impuesto, Total, Estado)
    VALUES (@PedidoId, @NumeroFactura, @UsuarioId, @ClienteNombre, @ClienteCorreo, @Subtotal, @Impuesto, @Total, 'Generada');
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS FacturaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateInvoiceLine
    @FacturaId INT,
    @ProductoId INT,
    @ProductoNombre NVARCHAR(200),
    @Cantidad INT,
    @PrecioUnitario DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
    VALUES (@FacturaId, @ProductoId, @ProductoNombre, @Cantidad, @PrecioUnitario);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdatePedidoTotalIfNeeded
    @PedidoId INT,
    @Total DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Pedidos
    SET Total = @Total
    WHERE PedidoId = @PedidoId AND (Total = 0 OR Total IS NULL);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ValidateUser @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 u.UsuarioId, u.NombreCompleto, u.Correo, u.Contrasena, p.Nombre AS PerfilNombre, u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo AND u.Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_EmailExists @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1) FROM dbo.Usuarios WHERE Correo = @Correo;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_RegisterClient @NombreCompleto NVARCHAR(200), @Correo NVARCHAR(200), @Contrasena NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Activo)
    VALUES ((SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente'), @NombreCompleto, @Correo, @Contrasena, 1);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetUserByEmail @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 u.UsuarioId, u.NombreCompleto, u.Correo, u.Contrasena, p.Nombre AS PerfilNombre, u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_CreatePasswordResetToken @UsuarioId INT, @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.PasswordResetTokens (UsuarioId, Token, FechaExpiracion, Usado)
    VALUES (@UsuarioId, @Token, DATEADD(MINUTE, 30, SYSDATETIME()), 0);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetValidResetToken @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 t.UsuarioId, u.NombreCompleto, u.Correo, t.Token, t.FechaExpiracion, t.Usado
    FROM dbo.PasswordResetTokens t
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = t.UsuarioId
    WHERE t.Token = @Token;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UpdatePassword @UsuarioId INT, @Contrasena NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuarios SET Contrasena = @Contrasena WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UseResetToken @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PasswordResetTokens SET Usado = 1 WHERE Token = @Token;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Account_ValidateUser @Correo NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 u.UsuarioId, u.PerfilId, p.Nombre AS PerfilNombre, u.NombreCompleto, u.Correo, u.Contrasena, u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo AND u.Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Account_EmailExists @Correo NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1) FROM dbo.Usuarios WHERE Correo = @Correo;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Account_RegisterClient @NombreCompleto NVARCHAR(200), @Correo NVARCHAR(256), @Contrasena NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Activo)
    VALUES ((SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente'), @NombreCompleto, @Correo, @Contrasena, 1);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_CreateOrder
    @UsuarioId INT,
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @PedidoId INT, @Total DECIMAL(18,2);

    IF ISNULL(@ItemsJson, '') = ''
    BEGIN
        RAISERROR('El carrito estÃ¡ vacÃ­o.', 16, 1);
        RETURN;
    END

    DECLARE @Items TABLE (ProductoId INT NOT NULL, Cantidad INT NOT NULL, Precio DECIMAL(18,2) NULL, StockActual INT NULL);

    INSERT INTO @Items (ProductoId, Cantidad)
    SELECT ProductoId, Cantidad
    FROM OPENJSON(@ItemsJson)
    WITH (ProductoId INT '$.productoId', Cantidad INT '$.cantidad');

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN
        RAISERROR('El carrito estÃ¡ vacÃ­o.', 16, 1);
        RETURN;
    END

    UPDATE i
    SET Precio = p.Precio, StockActual = p.Stock
    FROM @Items i
    INNER JOIN dbo.Productos p ON p.ProductoId = i.ProductoId
    WHERE p.Activo = 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE Precio IS NULL OR StockActual IS NULL)
    BEGIN
        RAISERROR('Uno o mÃ¡s productos no estÃ¡n disponibles.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Items WHERE StockActual < Cantidad)
    BEGIN
        RAISERROR('No hay stock suficiente para uno o mÃ¡s productos.', 16, 1);
        RETURN;
    END

    SELECT @Total = SUM(Precio * Cantidad) FROM @Items;

    BEGIN TRANSACTION;
    INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total, Observaciones, IdentificacionCliente)
    VALUES (@UsuarioId, SYSDATETIME(), 'Pendiente', @TipoEntrega, @DireccionEntrega, @Total, @Observaciones, @IdentificacionCliente);
    SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);
    INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, ProductoId, Cantidad, Precio FROM @Items;
    COMMIT TRANSACTION;
    SELECT @PedidoId;
END
GO

PRINT 'Paso 5/5: verificacion';
GO
SELECT DISTINCT Categoria FROM dbo.Productos WHERE Activo = 1 ORDER BY Categoria;
GO
SELECT TOP 10 ProductoId, Nombre, EsDestacado, ImagenUrl FROM dbo.Productos ORDER BY ProductoId DESC;
GO




