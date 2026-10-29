USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-055 / CU-056
   Modificar producto con stock mínimo
   Inactivar, reactivar y eliminar producto de forma segura
   ========================================================= */

IF OBJECT_ID('dbo.Productos', 'U') IS NULL
BEGIN
    PRINT 'La tabla Productos no existe. Verifique la base de datos.';
    RETURN;
END;
GO

IF COL_LENGTH('dbo.Productos', 'StockMinimo') IS NULL
BEGIN
    ALTER TABLE dbo.Productos
    ADD StockMinimo INT NOT NULL
        CONSTRAINT DF_Productos_StockMinimo DEFAULT (5);

    PRINT 'Columna StockMinimo agregada a Productos.';
END
ELSE
BEGIN
    PRINT 'La columna StockMinimo ya existe en Productos.';
END;
GO

UPDATE dbo.Productos
SET StockMinimo = 5
WHERE StockMinimo IS NULL OR StockMinimo < 0;
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
        CASE
            WHEN Stock <= 0 THEN 'Agotado'
            WHEN Stock <= ISNULL(NULLIF(StockMinimo, 0), 5) THEN 'Stock bajo'
            ELSE 'Disponible'
        END AS EstadoStock,
        Activo,
        FechaCreacion,
        ISNULL(ImagenUrl, '') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado,
        ISNULL(StockMinimo, 5) AS StockMinimo
    FROM dbo.Productos
    WHERE @Filtro IS NULL
       OR Nombre LIKE '%' + @Filtro + '%'
       OR Categoria LIKE '%' + @Filtro + '%'
    ORDER BY Activo DESC, ProductoId DESC;
END;
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
        CASE
            WHEN Stock <= 0 THEN 'Agotado'
            WHEN Stock <= ISNULL(NULLIF(StockMinimo, 0), 5) THEN 'Stock bajo'
            ELSE 'Disponible'
        END AS EstadoStock,
        Activo,
        FechaCreacion,
        ISNULL(ImagenUrl, '') AS ImagenUrl,
        ISNULL(EsDestacado, 0) AS EsDestacado,
        ISNULL(StockMinimo, 5) AS StockMinimo
    FROM dbo.Productos
    WHERE Activo = 1
    ORDER BY Nombre ASC;
END;
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
        ISNULL(EsDestacado, 0) AS EsDestacado,
        ISNULL(StockMinimo, 5) AS StockMinimo
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateProduct
    @Nombre NVARCHAR(150),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(255) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @StockMinimo INT = 5,
    @Activo BIT,
    @ImagenUrl NVARCHAR(255) = NULL,
    @EsDestacado BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Stock < 0
    BEGIN
        THROW 51001, 'El stock no puede ser negativo.', 1;
    END;

    IF @StockMinimo < 0
    BEGIN
        THROW 51002, 'El stock mínimo no puede ser negativo.', 1;
    END;

    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        StockMinimo,
        Activo,
        ImagenUrl,
        EsDestacado
    )
    VALUES
    (
        LTRIM(RTRIM(@Nombre)),
        LTRIM(RTRIM(@Categoria)),
        NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
        @Precio,
        @Stock,
        ISNULL(@StockMinimo, 5),
        @Activo,
        NULLIF(LTRIM(RTRIM(@ImagenUrl)), ''),
        @EsDestacado
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateProduct
    @ProductoId INT,
    @Nombre NVARCHAR(200),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(MAX) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @StockMinimo INT = 5,
    @Activo BIT,
    @ImagenUrl NVARCHAR(255) = NULL,
    @EsDestacado BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Stock < 0
    BEGIN
        THROW 51003, 'El stock no puede ser negativo.', 1;
    END;

    IF @StockMinimo < 0
    BEGIN
        THROW 51004, 'El stock mínimo no puede ser negativo.', 1;
    END;

    UPDATE dbo.Productos
    SET Nombre = LTRIM(RTRIM(@Nombre)),
        Categoria = LTRIM(RTRIM(@Categoria)),
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
        Precio = @Precio,
        Stock = @Stock,
        StockMinimo = ISNULL(@StockMinimo, 5),
        Activo = @Activo,
        ImagenUrl = NULLIF(LTRIM(RTRIM(@ImagenUrl)), ''),
        EsDestacado = @EsDestacado
    WHERE ProductoId = @ProductoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleProductStatus
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE ProductoId = @ProductoId)
    BEGIN
        THROW 51005, 'El producto indicado no existe.', 1;
    END;

    UPDATE dbo.Productos
    SET Activo = CASE WHEN Activo = 1 THEN 0 ELSE 1 END
    WHERE ProductoId = @ProductoId;

    SELECT Activo
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DeleteProductPermanently
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Nombre NVARCHAR(150);

    SELECT @Nombre = Nombre
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;

    IF @Nombre IS NULL
    BEGIN
        THROW 51006, 'El producto indicado no existe.', 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.PedidoDetalle WHERE ProductoId = @ProductoId)
       OR EXISTS (SELECT 1 FROM dbo.FacturaDetalle WHERE ProductoId = @ProductoId)
       OR EXISTS (SELECT 1 FROM dbo.MovimientosInventario WHERE ProductoId = @ProductoId)
    BEGIN
        THROW 51007, 'No se puede eliminar este producto porque tiene pedidos, facturas o movimientos de inventario asociados. Use Inactivar para ocultarlo del catálogo sin perder el historial.', 1;
    END;

    DELETE FROM dbo.Productos
    WHERE ProductoId = @ProductoId;

    SELECT @Nombre AS ProductoEliminado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardSummary
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        (SELECT COUNT(*) FROM dbo.Productos) AS TotalProductos,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1) AS ProductosActivos,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Stock > 0 AND Stock <= ISNULL(NULLIF(StockMinimo, 0), 5) AND Activo = 1) AS StockBajo,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Stock <= 0 AND Activo = 1) AS ProductosAgotados,
        (SELECT COUNT(*) FROM dbo.Pedidos) AS TotalPedidos,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Pendiente') AS PedidosPendientes,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'EnProceso') AS PedidosEnProceso,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Entregado') AS PedidosEntregados,
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada'), 0) AS VentasTotales,
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada' AND YEAR(FechaFactura) = YEAR(GETDATE()) AND MONTH(FechaFactura) = MONTH(GETDATE())), 0) AS VentasMesActual;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardLowStock
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 5
        ProductoId,
        Nombre,
        Categoria,
        Stock,
        CASE
            WHEN Stock <= 0 THEN 'Agotado'
            WHEN Stock <= ISNULL(NULLIF(StockMinimo, 0), 5) THEN 'Stock bajo'
            ELSE 'Disponible'
        END AS EstadoStock,
        ISNULL(StockMinimo, 5) AS StockMinimo
    FROM dbo.Productos
    WHERE Activo = 1
      AND (Stock <= 0 OR Stock <= ISNULL(NULLIF(StockMinimo, 0), 5))
    ORDER BY Stock ASC, Nombre ASC;
END;
GO

PRINT 'CU-055/CU-056 aplicado correctamente: stock mínimo, inactivar/reactivar y eliminación segura de productos.';
GO
