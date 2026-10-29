-- ============================================================
-- FASE 3: STORED PROCEDURES — DistribuidoraJJ_DB
-- Usa CREATE OR ALTER (SQL Server 2016+). Idempotente.
-- Prerequisito: Fases 1 y 2 ejecutadas sin errores.
-- ============================================================

USE DistribuidoraJJ_DB;
GO

-- ===========================================================
-- MÓDULO: AUTENTICACIÓN
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ValidateUser
    @Correo     NVARCHAR(150),
    @Contrasena NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.PerfilId,
        p.Nombre AS NombrePerfil,
        u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Correo     = @Correo
      AND u.Contrasena = @Contrasena
      AND u.Activo     = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_RegisterUser
    @NombreCompleto NVARCHAR(150),
    @Correo         NVARCHAR(150),
    @Contrasena     NVARCHAR(255),
    @Telefono       NVARCHAR(30)  = NULL,
    @Direccion      NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
    BEGIN
        RAISERROR(N'El correo ya está registrado.', 16, 1);
        RETURN;
    END

    DECLARE @PerfilId INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');

    IF @PerfilId IS NULL
    BEGIN
        RAISERROR(N'Perfil Cliente no configurado.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
    VALUES (@PerfilId, @NombreCompleto, @Correo, @Contrasena, @Telefono, @Direccion);

    DECLARE @NuevoId INT = SCOPE_IDENTITY();

    INSERT INTO dbo.ClienteCreditos (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
    VALUES (@NuevoId, 0, 0, 0);

    SELECT @NuevoId AS UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ChangePassword
    @UsuarioId        INT,
    @ContrasenaActual NVARCHAR(255),
    @ContrasenaNueva  NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios
        WHERE UsuarioId = @UsuarioId AND Contrasena = @ContrasenaActual
    )
    BEGIN
        RAISERROR(N'Contraseña actual incorrecta.', 16, 1);
        RETURN;
    END
    UPDATE dbo.Usuarios
    SET Contrasena = @ContrasenaNueva, FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_CreatePasswordResetToken
    @Correo          NVARCHAR(150),
    @Token           NVARCHAR(120),
    @HorasExpiracion INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UsuarioId INT = (
        SELECT UsuarioId FROM dbo.Usuarios WHERE Correo = @Correo AND Activo = 1
    );
    IF @UsuarioId IS NULL
    BEGIN
        SELECT 0 AS Exito, NULL AS NombreCompleto, NULL AS Correo;
        RETURN;
    END
    UPDATE dbo.PasswordResetTokens SET Usado = 1
    WHERE UsuarioId = @UsuarioId AND Usado = 0;

    INSERT INTO dbo.PasswordResetTokens (UsuarioId, Token, FechaExpiracion)
    VALUES (@UsuarioId, @Token, DATEADD(HOUR, @HorasExpiracion, SYSDATETIME()));

    SELECT 1 AS Exito, u.NombreCompleto, u.Correo
    FROM dbo.Usuarios u WHERE u.UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ValidateResetToken
    @Token NVARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.PasswordResetTokenId,
        t.UsuarioId,
        t.FechaExpiracion,
        t.Usado,
        CASE WHEN t.Usado = 0 AND t.FechaExpiracion > SYSDATETIME() THEN 1 ELSE 0 END AS EsValido
    FROM dbo.PasswordResetTokens t
    WHERE t.Token = @Token;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ResetPassword
    @Token           NVARCHAR(120),
    @ContrasenaNueva NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UsuarioId INT;
    SELECT @UsuarioId = UsuarioId
    FROM dbo.PasswordResetTokens
    WHERE Token = @Token AND Usado = 0 AND FechaExpiracion > SYSDATETIME();

    IF @UsuarioId IS NULL
    BEGIN
        RAISERROR(N'Token inválido o expirado.', 16, 1);
        RETURN;
    END
    UPDATE dbo.Usuarios
    SET Contrasena = @ContrasenaNueva, FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId;

    UPDATE dbo.PasswordResetTokens SET Usado = 1 WHERE Token = @Token;

    SELECT 1 AS Exito;
END
GO

-- ===========================================================
-- MÓDULO: DASHBOARD
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardSummary
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1)
            AS TotalProductos,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1 AND Stock > 0 AND Stock <= StockMinimo)
            AS ProductosBajoStock,
        (SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1 AND Stock = 0)
            AS ProductosAgotados,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = N'Pendiente')
            AS PedidosPendientes,
        (SELECT COUNT(*) FROM dbo.Pedidos WHERE Estado = N'Retenido')
            AS PedidosRetenidos,
        (SELECT COUNT(*) FROM dbo.Pedidos
         WHERE CAST(FechaPedido AS DATE) = CAST(SYSDATETIME() AS DATE))
            AS PedidosHoy,
        (SELECT COUNT(*) FROM dbo.Facturas)
            AS TotalFacturas,
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Facturas
         WHERE MONTH(FechaFactura) = MONTH(SYSDATETIME())
           AND YEAR(FechaFactura)  = YEAR(SYSDATETIME()))
            AS VentasMes,
        (SELECT COUNT(*) FROM dbo.Usuarios u
         INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
         WHERE p.Nombre = N'Cliente' AND u.Activo = 1)
            AS TotalClientes,
        (SELECT COUNT(*) FROM dbo.Empleados WHERE Activo = 1)
            AS TotalEmpleados;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardLowStock
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 10
        p.ProductoId,
        p.Nombre,
        p.Categoria,
        p.Stock,
        p.StockMinimo,
        p.EstadoStock
    FROM dbo.Productos p
    WHERE p.Activo = 1 AND p.Stock <= p.StockMinimo
    ORDER BY p.Stock ASC, p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DashboardRecentOrders
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 8
        ped.PedidoId,
        u.NombreCompleto AS ClienteNombre,
        ped.Total,
        ped.Estado,
        ped.CanalPedido,
        ped.FechaPedido
    FROM dbo.Pedidos ped
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = ped.UsuarioId
    ORDER BY ped.FechaPedido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetTopSellingProducts
    @TopN INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        pr.ProductoId,
        pr.Nombre,
        pr.Categoria,
        SUM(pd.Cantidad)  AS TotalVendido,
        SUM(pd.Subtotal)  AS TotalIngresos
    FROM dbo.PedidoDetalle pd
    INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
    INNER JOIN dbo.Pedidos   pe ON pe.PedidoId   = pd.PedidoId
    WHERE pe.Estado NOT IN (N'Cancelado', N'Rechazado')
    GROUP BY pr.ProductoId, pr.Nombre, pr.Categoria
    ORDER BY TotalVendido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetMonthlySales
    @Anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Anio = ISNULL(@Anio, YEAR(SYSDATETIME()));
    SELECT
        MONTH(f.FechaFactura) AS Mes,
        COUNT(*)              AS TotalFacturas,
        SUM(f.Total)          AS TotalVentas
    FROM dbo.Facturas f
    WHERE YEAR(f.FechaFactura) = @Anio
    GROUP BY MONTH(f.FechaFactura)
    ORDER BY Mes;
END
GO

-- ===========================================================
-- MÓDULO: CATEGORÍAS
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.CategoriaId, c.Nombre, c.Activo, c.FechaCreacion,
        COUNT(p.ProductoId) AS TotalProductos
    FROM dbo.Categorias c
    LEFT JOIN dbo.Productos p ON p.CategoriaId = c.CategoriaId AND p.Activo = 1
    GROUP BY c.CategoriaId, c.Nombre, c.Activo, c.FechaCreacion
    ORDER BY c.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateCategory
    @Nombre NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE Nombre = @Nombre)
    BEGIN
        RAISERROR(N'Ya existe una categoría con ese nombre.', 16, 1);
        RETURN;
    END
    INSERT INTO dbo.Categorias (Nombre) VALUES (@Nombre);
    SELECT SCOPE_IDENTITY() AS CategoriaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateCategory
    @CategoriaId INT,
    @Nombre      NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE Nombre = @Nombre AND CategoriaId <> @CategoriaId)
    BEGIN
        RAISERROR(N'Ya existe otra categoría con ese nombre.', 16, 1);
        RETURN;
    END
    UPDATE dbo.Categorias SET Nombre = @Nombre WHERE CategoriaId = @CategoriaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleCategoryStatus
    @CategoriaId INT,
    @Activo      BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Categorias SET Activo = @Activo WHERE CategoriaId = @CategoriaId;
END
GO

-- ===========================================================
-- MÓDULO: PRODUCTOS
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProducts
    @Filtro      NVARCHAR(100) = NULL,
    @Categoria   NVARCHAR(100) = NULL,
    @SoloActivos BIT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.ProductoId, p.CategoriaId, p.Nombre, p.Categoria,
        p.Descripcion, p.Precio, p.Stock, p.StockMinimo,
        p.EstadoStock, p.Activo, p.FechaCreacion, p.ImagenUrl, p.EsDestacado
    FROM dbo.Productos p
    WHERE (@Filtro      IS NULL OR p.Nombre      LIKE N'%' + @Filtro    + N'%'
                                OR p.Descripcion LIKE N'%' + @Filtro    + N'%')
      AND (@Categoria   IS NULL OR p.Categoria   = @Categoria)
      AND (@SoloActivos IS NULL OR p.Activo      = @SoloActivos)
    ORDER BY p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetActiveProductsForSelect
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductoId, Nombre, Precio, Stock, Categoria
    FROM dbo.Productos
    WHERE Activo = 1 AND Stock > 0
    ORDER BY Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetProductById
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.ProductoId, p.CategoriaId, p.Nombre, p.Categoria,
        p.Descripcion, p.Precio, p.Stock, p.StockMinimo,
        p.EstadoStock, p.Activo, p.FechaCreacion, p.ImagenUrl, p.EsDestacado
    FROM dbo.Productos p
    WHERE p.ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateProduct
    @CategoriaId   INT,
    @Nombre        NVARCHAR(150),
    @Categoria     NVARCHAR(100),
    @Descripcion   NVARCHAR(255) = NULL,
    @Precio        DECIMAL(18,2),
    @Stock         INT           = 0,
    @StockMinimo   INT           = 5,
    @ImagenUrl     NVARCHAR(255) = NULL,
    @EsDestacado   BIT           = 0,
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Productos
        (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, ImagenUrl, EsDestacado)
    VALUES
        (@CategoriaId, @Nombre, @Categoria, @Descripcion, @Precio, @Stock, @StockMinimo, @ImagenUrl, @EsDestacado);

    DECLARE @NuevoId INT = SCOPE_IDENTITY();

    IF @Stock > 0
        INSERT INTO dbo.MovimientosInventario
            (ProductoId, UsuarioId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre)
        VALUES
            (@NuevoId, @UsuarioId, @Nombre, N'Entrada', @Stock, 0, @Stock, N'Stock inicial al crear producto', @UsuarioNombre);

    SELECT @NuevoId AS ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateProduct
    @ProductoId  INT,
    @CategoriaId INT,
    @Nombre      NVARCHAR(150),
    @Categoria   NVARCHAR(100),
    @Descripcion NVARCHAR(255) = NULL,
    @Precio      DECIMAL(18,2),
    @StockMinimo INT,
    @ImagenUrl   NVARCHAR(255) = NULL,
    @EsDestacado BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos
    SET CategoriaId = @CategoriaId, Nombre = @Nombre, Categoria = @Categoria,
        Descripcion = @Descripcion, Precio = @Precio, StockMinimo = @StockMinimo,
        ImagenUrl   = @ImagenUrl,   EsDestacado = @EsDestacado
    WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleProductStatus
    @ProductoId INT,
    @Activo     BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Productos SET Activo = @Activo WHERE ProductoId = @ProductoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_DeleteProductPermanently
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.PedidoDetalle  WHERE ProductoId = @ProductoId)
    OR EXISTS (SELECT 1 FROM dbo.FacturaDetalle WHERE ProductoId = @ProductoId)
    BEGIN
        RAISERROR(N'No se puede eliminar: el producto tiene historial de pedidos o facturas.', 16, 1);
        RETURN;
    END
    DELETE FROM dbo.MovimientosInventario WHERE ProductoId = @ProductoId;
    DELETE FROM dbo.Productos             WHERE ProductoId = @ProductoId;
    SELECT 1 AS Eliminado;
END
GO

-- ===========================================================
-- MÓDULO: INVENTARIO
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_AdjustStock
    @ProductoId     INT,
    @TipoMovimiento NVARCHAR(30),
    @Cantidad       INT,
    @Motivo         NVARCHAR(250) = NULL,
    @UsuarioId      INT,
    @UsuarioNombre  NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @StockActual INT, @NombreProducto NVARCHAR(150);
        SELECT @StockActual = Stock, @NombreProducto = Nombre
        FROM dbo.Productos WITH (UPDLOCK)
        WHERE ProductoId = @ProductoId AND Activo = 1;

        IF @StockActual IS NULL
        BEGIN RAISERROR(N'Producto no encontrado o inactivo.', 16, 1); ROLLBACK; RETURN; END

        DECLARE @StockNuevo INT;
        IF      @TipoMovimiento = N'Entrada' SET @StockNuevo = @StockActual + @Cantidad;
        ELSE IF @TipoMovimiento = N'Salida'
        BEGIN
            IF @StockActual < @Cantidad
            BEGIN RAISERROR(N'Stock insuficiente.', 16, 1); ROLLBACK; RETURN; END
            SET @StockNuevo = @StockActual - @Cantidad;
        END
        ELSE SET @StockNuevo = @Cantidad; -- Ajuste directo

        UPDATE dbo.Productos SET Stock = @StockNuevo WHERE ProductoId = @ProductoId;

        INSERT INTO dbo.MovimientosInventario
            (ProductoId, UsuarioId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre)
        VALUES
            (@ProductoId, @UsuarioId, @NombreProducto, @TipoMovimiento, @Cantidad, @StockActual, @StockNuevo, @Motivo, @UsuarioNombre);

        COMMIT;
        SELECT @StockNuevo AS StockResultante;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInventoryMovements
    @ProductoId INT  = NULL,
    @Desde      DATE = NULL,
    @Hasta      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        m.MovimientoId, m.ProductoNombre, m.TipoMovimiento,
        m.Cantidad, m.StockAnterior, m.StockNuevo,
        m.Motivo, m.UsuarioNombre, m.FechaMovimiento
    FROM dbo.MovimientosInventario m
    WHERE (@ProductoId IS NULL OR m.ProductoId = @ProductoId)
      AND (@Desde      IS NULL OR CAST(m.FechaMovimiento AS DATE) >= @Desde)
      AND (@Hasta      IS NULL OR CAST(m.FechaMovimiento AS DATE) <= @Hasta)
    ORDER BY m.FechaMovimiento DESC;
END
GO

-- ===========================================================
-- MÓDULO: PEDIDOS (ADMIN)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrders
    @Estado NVARCHAR(30)  = NULL,
    @Filtro NVARCHAR(100) = NULL,
    @Desde  DATE          = NULL,
    @Hasta  DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PedidoId, p.UsuarioId,
        u.NombreCompleto AS ClienteNombre,
        u.Correo         AS ClienteCorreo,
        p.FechaPedido, p.Estado, p.Total,
        p.CanalPedido, p.MetodoPago, p.EstadoPago,
        p.TipoEntrega, p.VendedorNombre, p.FechaActualizacion
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE (@Estado IS NULL OR p.Estado = @Estado)
      AND (@Filtro IS NULL OR u.NombreCompleto LIKE N'%' + @Filtro + N'%'
                           OR CAST(p.PedidoId AS NVARCHAR) = @Filtro)
      AND (@Desde  IS NULL OR CAST(p.FechaPedido AS DATE) >= @Desde)
      AND (@Hasta  IS NULL OR CAST(p.FechaPedido AS DATE) <= @Hasta)
    ORDER BY p.FechaPedido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderHeader
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PedidoId, p.UsuarioId,
        u.NombreCompleto AS ClienteNombre, u.Correo AS ClienteCorreo, u.Telefono AS ClienteTelefono,
        p.FechaPedido, p.Estado, p.TipoEntrega, p.DireccionEntrega, p.Total,
        p.Observaciones, p.CanalPedido, p.VendedorNombre, p.VendedorUsuarioId,
        p.MetodoPago, p.EstadoPago, p.ReferenciaPago, p.FechaPago,
        p.IdentificacionCliente, p.MotivoRechazo, p.FechaActualizacion
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;

    SELECT
        pd.PedidoDetalleId, pd.ProductoId,
        pr.Nombre AS ProductoNombre,
        pd.Cantidad, pd.PrecioUnitario, pd.Subtotal
    FROM dbo.PedidoDetalle pd
    INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
    WHERE pd.PedidoId = @PedidoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId      INT,
    @NuevoEstado   NVARCHAR(30),
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150),
    @Motivo        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @EstadoActual NVARCHAR(30), @InvDesc BIT;
        SELECT @EstadoActual = Estado, @InvDesc = InventarioDescontado
        FROM dbo.Pedidos WITH (UPDLOCK) WHERE PedidoId = @PedidoId;

        IF @EstadoActual IS NULL
        BEGIN RAISERROR(N'Pedido no encontrado.', 16, 1); ROLLBACK; RETURN; END

        IF @NuevoEstado IN (N'Cancelado', N'Rechazado') AND @InvDesc = 1
        BEGIN
            UPDATE pr SET pr.Stock = pr.Stock + pd.Cantidad
            FROM dbo.Productos pr
            INNER JOIN dbo.PedidoDetalle pd ON pd.ProductoId = pr.ProductoId
            WHERE pd.PedidoId = @PedidoId;

            INSERT INTO dbo.MovimientosInventario
                (ProductoId, UsuarioId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre)
            SELECT pd.ProductoId, @UsuarioId, pr.Nombre, N'Entrada', pd.Cantidad,
                   pr.Stock - pd.Cantidad, pr.Stock,
                   N'Restauración por ' + @NuevoEstado + ' de pedido #' + CAST(@PedidoId AS NVARCHAR),
                   @UsuarioNombre
            FROM dbo.PedidoDetalle pd
            INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
            WHERE pd.PedidoId = @PedidoId;

            UPDATE dbo.Pedidos SET InventarioDescontado = 0 WHERE PedidoId = @PedidoId;
        END

        UPDATE dbo.Pedidos
        SET Estado = @NuevoEstado,
            MotivoRechazo = CASE WHEN @NuevoEstado = N'Rechazado' THEN @Motivo ELSE MotivoRechazo END,
            FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT;
        SELECT 1 AS Exito;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_OrderHasInvoice
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.Facturas WHERE PedidoId = @PedidoId)
                THEN 1 ELSE 0 END AS TieneFactura;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GenerateInvoiceFromOrder
    @PedidoId           INT,
    @UsuarioId          INT,
    @UsuarioNombre      NVARCHAR(150),
    @PorcentajeImpuesto DECIMAL(5,2) = 13.00
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.Facturas WHERE PedidoId = @PedidoId)
        BEGIN RAISERROR(N'El pedido ya tiene factura.', 16, 1); ROLLBACK; RETURN; END

        DECLARE @Estado NVARCHAR(30);
        SELECT @Estado = Estado FROM dbo.Pedidos WHERE PedidoId = @PedidoId;
        IF @Estado NOT IN (N'Aprobado', N'EnProceso', N'Entregado', N'Liberado')
        BEGIN RAISERROR(N'Estado del pedido no permite facturación.', 16, 1); ROLLBACK; RETURN; END

        DECLARE @ClienteNombre NVARCHAR(150), @ClienteCorreo NVARCHAR(150), @TotalPedido DECIMAL(18,2);
        SELECT @ClienteNombre = u.NombreCompleto, @ClienteCorreo = u.Correo, @TotalPedido = p.Total
        FROM dbo.Pedidos p INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
        WHERE p.PedidoId = @PedidoId;

        DECLARE @Subtotal  DECIMAL(18,2) = ROUND(@TotalPedido / (1 + @PorcentajeImpuesto / 100.0), 2);
        DECLARE @Impuesto  DECIMAL(18,2) = @TotalPedido - @Subtotal;
        DECLARE @Seq       INT           = (SELECT ISNULL(MAX(FacturaId), 0) + 1 FROM dbo.Facturas);
        DECLARE @NumFact   NVARCHAR(30)  = N'FACT-' + CAST(YEAR(SYSDATETIME()) AS NVARCHAR)
                                         + N'-' + RIGHT(N'000000' + CAST(@Seq AS NVARCHAR), 6);

        INSERT INTO dbo.Facturas
            (PedidoId, UsuarioId, NumeroFactura, ClienteNombre, ClienteCorreo, Subtotal, Impuesto, Total)
        VALUES (@PedidoId, @UsuarioId, @NumFact, @ClienteNombre, @ClienteCorreo, @Subtotal, @Impuesto, @TotalPedido);

        DECLARE @FacturaId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
        SELECT @FacturaId, pd.ProductoId, pr.Nombre, pd.Cantidad, pd.PrecioUnitario
        FROM dbo.PedidoDetalle pd
        INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
        WHERE pd.PedidoId = @PedidoId;

        UPDATE dbo.Pedidos
        SET Estado = N'Entregado', FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId AND Estado <> N'Entregado';

        COMMIT;
        SELECT @FacturaId AS FacturaId, @NumFact AS NumeroFactura;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoices
    @Filtro NVARCHAR(100) = NULL,
    @Desde  DATE          = NULL,
    @Hasta  DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        f.FacturaId, f.NumeroFactura, f.ClienteNombre, f.ClienteCorreo,
        f.FechaFactura, f.Subtotal, f.Impuesto, f.Total, f.Estado, f.PedidoId
    FROM dbo.Facturas f
    WHERE (@Filtro IS NULL OR f.NumeroFactura LIKE N'%' + @Filtro + N'%'
                           OR f.ClienteNombre LIKE N'%' + @Filtro + N'%')
      AND (@Desde  IS NULL OR CAST(f.FechaFactura AS DATE) >= @Desde)
      AND (@Hasta  IS NULL OR CAST(f.FechaFactura AS DATE) <= @Hasta)
    ORDER BY f.FechaFactura DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceByOrderId
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FacturaId, f.NumeroFactura, f.ClienteNombre, f.ClienteCorreo,
           f.FechaFactura, f.Subtotal, f.Impuesto, f.Total, f.Estado, f.PedidoId
    FROM dbo.Facturas f WHERE f.PedidoId = @PedidoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceSummaryByOrder
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FacturaId, f.NumeroFactura, f.ClienteNombre, f.ClienteCorreo,
           f.FechaFactura, f.Subtotal, f.Impuesto, f.Total, f.Estado
    FROM dbo.Facturas f WHERE f.PedidoId = @PedidoId;

    SELECT fd.FacturaDetalleId, fd.ProductoNombre, fd.Cantidad, fd.PrecioUnitario, fd.Subtotal
    FROM dbo.FacturaDetalle fd
    INNER JOIN dbo.Facturas f ON f.FacturaId = fd.FacturaId
    WHERE f.PedidoId = @PedidoId;
END
GO

PRINT '?? Bloque 1/3 de Fase 3 OK (Auth, Dashboard, Categorías, Productos, Inventario, Pedidos Admin, Facturas)';
GO