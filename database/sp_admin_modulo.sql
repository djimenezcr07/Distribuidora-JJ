USE DistribuidoraJJ_DB;
GO

/* =========================================================
   PRODUCTOS / TIENDA
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Categoria
    FROM dbo.Productos
    WHERE Activo = 1
      AND Categoria IS NOT NULL
      AND LTRIM(RTRIM(Categoria)) <> ''
    ORDER BY Categoria ASC;
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
        '~/img/product-1.jpg' AS ImagenUrl
    FROM dbo.Productos
    WHERE Activo = 1
      AND (@Categoria IS NULL OR Categoria = @Categoria)
      AND (
            @Buscar IS NULL
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Categoria LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
      )
    ORDER BY Nombre ASC;
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
        EstadoStock,
        Activo,
        FechaCreacion
    FROM dbo.Productos
    WHERE (
            @Filtro IS NULL
            OR Nombre LIKE '%' + @Filtro + '%'
            OR Categoria LIKE '%' + @Filtro + '%'
          )
    ORDER BY Activo DESC, Nombre ASC;
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
        EstadoStock,
        Activo,
        FechaCreacion
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
        Activo
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateProduct
    @Nombre NVARCHAR(200),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(MAX) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo
    )
    VALUES
    (
        LTRIM(RTRIM(@Nombre)),
        LTRIM(RTRIM(@Categoria)),
        NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
        @Precio,
        @Stock,
        @Activo
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateProduct
    @ProductoId INT,
    @Nombre NVARCHAR(200),
    @Categoria NVARCHAR(100),
    @Descripcion NVARCHAR(MAX) = NULL,
    @Precio DECIMAL(18,2),
    @Stock INT,
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Productos
    SET Nombre = LTRIM(RTRIM(@Nombre)),
        Categoria = LTRIM(RTRIM(@Categoria)),
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
        Precio = @Precio,
        Stock = @Stock,
        Activo = @Activo
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

/* =========================================================
   MOVIMIENTOS DE INVENTARIO
   ========================================================= */

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

    INSERT INTO dbo.MovimientosInventario
    (
        ProductoId,
        ProductoNombre,
        TipoMovimiento,
        Cantidad,
        StockAnterior,
        StockNuevo,
        Motivo,
        UsuarioId,
        UsuarioNombre
    )
    VALUES
    (
        @ProductoId,
        @ProductoNombre,
        @TipoMovimiento,
        @Cantidad,
        @StockAnterior,
        @StockNuevo,
        NULLIF(LTRIM(RTRIM(@Motivo)), ''),
        @UsuarioId,
        @UsuarioNombre
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInventoryMovements
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 200
        MovimientoId,
        ProductoId,
        ProductoNombre,
        TipoMovimiento,
        Cantidad,
        StockAnterior,
        StockNuevo,
        Motivo,
        UsuarioNombre,
        FechaMovimiento
    FROM dbo.MovimientosInventario
    ORDER BY FechaMovimiento DESC, MovimientoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetActiveProductForMovement
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Nombre,
        Stock
    FROM dbo.Productos
    WHERE ProductoId = @ProductoId
      AND Activo = 1;
END
GO

/* =========================================================
   DASHBOARD
   ========================================================= */

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
        ISNULL((SELECT SUM(Total)
                FROM dbo.Facturas
                WHERE Estado = 'Generada'
                  AND YEAR(FechaFactura) = YEAR(GETDATE())
                  AND MONTH(FechaFactura) = MONTH(GETDATE())), 0) AS VentasMesActual;
END
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
        EstadoStock
    FROM dbo.Productos
    WHERE Activo = 1
      AND Stock <= 5
    ORDER BY Stock ASC, Nombre ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardRecentOrders
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 5
        p.PedidoId,
        u.NombreCompleto,
        p.FechaPedido,
        p.Estado,
        p.Total
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    ORDER BY p.FechaPedido DESC;
END
GO

/* =========================================================
   PEDIDOS
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrders
    @Estado NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PedidoId,
        u.NombreCompleto,
        u.Correo,
        p.FechaPedido,
        p.Estado,
        p.TipoEntrega,
        p.DireccionEntrega,
        p.Total,
        (SELECT COUNT(*)
         FROM dbo.PedidoDetalle d
         WHERE d.PedidoId = p.PedidoId) AS TotalLineas
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

    SELECT
        p.PedidoId,
        p.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        p.FechaPedido,
        p.Estado,
        p.TipoEntrega,
        p.DireccionEntrega,
        p.Total,
        p.Observaciones
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

    SELECT
        d.PedidoDetalleId,
        pr.Nombre,
        d.ProductoId,
        d.Cantidad,
        d.PrecioUnitario,
        d.Subtotal,
        pr.Stock
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

/* =========================================================
   FACTURACION
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Admin_SalesSummary
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL((SELECT SUM(Total) FROM dbo.Facturas WHERE Estado = 'Generada'), 0) AS VentasTotales,
        ISNULL((SELECT SUM(Total)
                FROM dbo.Facturas
                WHERE Estado = 'Generada'
                  AND YEAR(FechaFactura) = YEAR(GETDATE())
                  AND MONTH(FechaFactura) = MONTH(GETDATE())), 0) AS VentasMesActual,
        (SELECT COUNT(*) FROM dbo.Facturas) AS TotalFacturas,
        (SELECT COUNT(*)
         FROM dbo.Facturas
         WHERE YEAR(FechaFactura) = YEAR(GETDATE())
           AND MONTH(FechaFactura) = MONTH(GETDATE())) AS FacturasMesActual,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = 'Entregado') AS PedidosEntregados;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoices
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 50
        FacturaId,
        PedidoId,
        NumeroFactura,
        ClienteNombre,
        FechaFactura,
        Subtotal,
        Impuesto,
        Total,
        Estado
    FROM dbo.Facturas
    ORDER BY FechaFactura DESC, FacturaId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetTopSellingProducts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 10
        fd.ProductoNombre,
        SUM(fd.Cantidad) AS CantidadVendida,
        SUM(fd.Subtotal) AS MontoVendido
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

    SELECT
        FORMAT(FechaFactura, 'yyyy-MM') AS Periodo,
        SUM(Total) AS Total
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

    SELECT
        FacturaId,
        PedidoId,
        NumeroFactura,
        ClienteNombre,
        ClienteCorreo,
        FechaFactura,
        Subtotal,
        Impuesto,
        Total,
        Estado
    FROM dbo.Facturas
    WHERE FacturaId = @FacturaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceLines
    @FacturaId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ProductoNombre,
        Cantidad,
        PrecioUnitario,
        Subtotal
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

    INSERT INTO dbo.Facturas
    (
        PedidoId,
        NumeroFactura,
        UsuarioId,
        ClienteNombre,
        ClienteCorreo,
        Subtotal,
        Impuesto,
        Total,
        Estado
    )
    VALUES
    (
        @PedidoId,
        @NumeroFactura,
        @UsuarioId,
        @ClienteNombre,
        @ClienteCorreo,
        @Subtotal,
        @Impuesto,
        @Total,
        'Generada'
    );

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

    INSERT INTO dbo.FacturaDetalle
    (
        FacturaId,
        ProductoId,
        ProductoNombre,
        Cantidad,
        PrecioUnitario
    )
    VALUES
    (
        @FacturaId,
        @ProductoId,
        @ProductoNombre,
        @Cantidad,
        @PrecioUnitario
    );
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
    WHERE PedidoId = @PedidoId
      AND (Total = 0 OR Total IS NULL);
END
GO