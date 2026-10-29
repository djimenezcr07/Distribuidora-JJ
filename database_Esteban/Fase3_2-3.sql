-- ============================================================
-- FASE 3 — BLOQUE 2/3
-- Módulos: Vendedor, Gerente, Tienda/Cliente,
--          Clientes, Créditos, Consultas
-- CREATE OR ALTER — idempotente.
-- ============================================================

USE DistribuidoraJJ_DB;
GO

-- ===========================================================
-- MÓDULO: PEDIDOS (VENDEDOR / SELLER)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetClientsForOrder
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = N'Cliente'
      AND u.Activo = 1
      AND (@Filtro IS NULL
           OR u.NombreCompleto LIKE N'%' + @Filtro + N'%'
           OR u.Correo         LIKE N'%' + @Filtro + N'%'
           OR u.Telefono       LIKE N'%' + @Filtro + N'%')
    ORDER BY u.NombreCompleto;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetProductsForOrder
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.ProductoId,
        p.Nombre,
        p.Categoria,
        p.Precio,
        p.Stock,
        p.ImagenUrl
    FROM dbo.Productos p
    WHERE p.Activo = 1
      AND p.Stock  > 0
      AND (@Filtro IS NULL OR p.Nombre LIKE N'%' + @Filtro + N'%'
                           OR p.Categoria LIKE N'%' + @Filtro + N'%')
    ORDER BY p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_CreateOrder
    @UsuarioClienteId      INT,
    @VendedorUsuarioId     INT,
    @VendedorNombre        NVARCHAR(150),
    @MetodoPago            NVARCHAR(40),
    @TipoEntrega           NVARCHAR(50)     = NULL,
    @DireccionEntrega      NVARCHAR(255)    = NULL,
    @Observaciones         NVARCHAR(255)    = NULL,
    @IdentificacionCliente NVARCHAR(100)    = NULL,
    @PedidoOfflineGuid     UNIQUEIDENTIFIER = NULL,
    @Detalles              NVARCHAR(MAX)    -- JSON: [{ProductoId, Cantidad, PrecioUnitario}]
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Idempotencia offline: si el GUID ya existe, devolver el pedido existente
        IF @PedidoOfflineGuid IS NOT NULL
           AND EXISTS (SELECT 1 FROM dbo.Pedidos WHERE PedidoOfflineGuid = @PedidoOfflineGuid)
        BEGIN
            SELECT PedidoId, 0 AS EsNuevo
            FROM dbo.Pedidos WHERE PedidoOfflineGuid = @PedidoOfflineGuid;
            COMMIT; RETURN;
        END

        -- Calcular total
        DECLARE @Total DECIMAL(18,2) = 0;
        SELECT @Total = SUM(CAST(j.Cantidad AS INT) * CAST(j.PrecioUnitario AS DECIMAL(18,2)))
        FROM OPENJSON(@Detalles) WITH (
            Cantidad       INT           '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        ) j;

        INSERT INTO dbo.Pedidos
            (UsuarioId, VendedorUsuarioId, VendedorNombre, Estado, CanalPedido,
             TipoEntrega, DireccionEntrega, Observaciones, Total,
             IdentificacionCliente, MetodoPago, EstadoPago,
             PedidoOfflineGuid, InventarioDescontado)
        VALUES
            (@UsuarioClienteId, @VendedorUsuarioId, @VendedorNombre,
             N'Pendiente', N'Venta móvil offline',
             @TipoEntrega, @DireccionEntrega, @Observaciones, @Total,
             @IdentificacionCliente, @MetodoPago, N'Pendiente',
             @PedidoOfflineGuid, 0);

        DECLARE @PedidoId INT = SCOPE_IDENTITY();

        -- Insertar líneas de detalle
        INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
        SELECT
            @PedidoId,
            CAST(j.ProductoId     AS INT),
            CAST(j.Cantidad       AS INT),
            CAST(j.PrecioUnitario AS DECIMAL(18,2))
        FROM OPENJSON(@Detalles) WITH (
            ProductoId     INT           '$.ProductoId',
            Cantidad       INT           '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        ) j;

        -- Descontar inventario
        UPDATE pr
        SET pr.Stock = pr.Stock - pd.Cantidad
        FROM dbo.Productos pr
        INNER JOIN dbo.PedidoDetalle pd ON pd.ProductoId = pr.ProductoId
        WHERE pd.PedidoId = @PedidoId;

        UPDATE dbo.Pedidos SET InventarioDescontado = 1 WHERE PedidoId = @PedidoId;

        -- Registrar movimientos de inventario
        INSERT INTO dbo.MovimientosInventario
            (ProductoId, UsuarioId, ProductoNombre, TipoMovimiento,
             Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre)
        SELECT
            pd.ProductoId,
            @VendedorUsuarioId,
            pr.Nombre,
            N'Salida',
            pd.Cantidad,
            pr.Stock + pd.Cantidad,
            pr.Stock,
            N'Venta móvil offline — pedido #' + CAST(@PedidoId AS NVARCHAR),
            @VendedorNombre
        FROM dbo.PedidoDetalle pd
        INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
        WHERE pd.PedidoId = @PedidoId;

        COMMIT;
        SELECT @PedidoId AS PedidoId, 1 AS EsNuevo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetMyOrders
    @VendedorUsuarioId INT,
    @Estado            NVARCHAR(30) = NULL,
    @Desde             DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PedidoId,
        u.NombreCompleto AS ClienteNombre,
        p.Total,
        p.Estado,
        p.MetodoPago,
        p.EstadoPago,
        p.CanalPedido,
        p.FechaPedido,
        p.FechaActualizacion,
        p.MotivoRechazo
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.VendedorUsuarioId = @VendedorUsuarioId
      AND (@Estado IS NULL OR p.Estado = @Estado)
      AND (@Desde  IS NULL OR CAST(p.FechaPedido AS DATE) >= @Desde)
    ORDER BY p.FechaPedido DESC;
END
GO

-- ===========================================================
-- MÓDULO: PEDIDOS (GERENTE / MANAGER)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Manager_GetRetainedOrders
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PedidoId,
        u.NombreCompleto  AS ClienteNombre,
        u.Correo          AS ClienteCorreo,
        p.Total,
        p.Estado,
        p.CanalPedido,
        p.MetodoPago,
        p.EstadoPago,
        p.VendedorNombre,
        p.Observaciones,
        p.FechaPedido,
        p.FechaActualizacion,
        (SELECT COUNT(*) FROM dbo.PedidoDetalle pd WHERE pd.PedidoId = p.PedidoId) AS TotalLineas
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.Estado = N'Retenido'
    ORDER BY p.FechaPedido ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Manager_ApproveOrder
    @PedidoId      INT,
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Pedidos
    SET Estado = N'Liberado', FechaActualizacion = SYSDATETIME()
    WHERE PedidoId = @PedidoId AND Estado = N'Retenido';

    IF @@ROWCOUNT = 0
        RAISERROR(N'El pedido no está en estado Retenido o no existe.', 16, 1);
    ELSE
        SELECT 1 AS Exito;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Manager_RejectOrder
    @PedidoId      INT,
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150),
    @Motivo        NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @InvDesc BIT;
        SELECT @InvDesc = InventarioDescontado
        FROM dbo.Pedidos WITH (UPDLOCK)
        WHERE PedidoId = @PedidoId AND Estado = N'Retenido';

        IF @InvDesc IS NULL
        BEGIN
            RAISERROR(N'El pedido no está en estado Retenido o no existe.', 16, 1);
            ROLLBACK; RETURN;
        END

        IF @InvDesc = 1
        BEGIN
            UPDATE pr SET pr.Stock = pr.Stock + pd.Cantidad
            FROM dbo.Productos pr
            INNER JOIN dbo.PedidoDetalle pd ON pd.ProductoId = pr.ProductoId
            WHERE pd.PedidoId = @PedidoId;

            INSERT INTO dbo.MovimientosInventario
                (ProductoId, UsuarioId, ProductoNombre, TipoMovimiento,
                 Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioNombre)
            SELECT
                pd.ProductoId, @UsuarioId, pr.Nombre, N'Entrada',
                pd.Cantidad, pr.Stock - pd.Cantidad, pr.Stock,
                N'Restauración por rechazo de pedido #' + CAST(@PedidoId AS NVARCHAR),
                @UsuarioNombre
            FROM dbo.PedidoDetalle pd
            INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
            WHERE pd.PedidoId = @PedidoId;

            UPDATE dbo.Pedidos SET InventarioDescontado = 0 WHERE PedidoId = @PedidoId;
        END

        UPDATE dbo.Pedidos
        SET Estado = N'Rechazado', MotivoRechazo = @Motivo, FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT;
        SELECT 1 AS Exito;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

-- ===========================================================
-- MÓDULO: TIENDA EN LÍNEA (STORE / PORTAL CLIENTE)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar    NVARCHAR(100) = NULL,
    @Take      INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Take IS NOT NULL AND @Take > 0
        SELECT TOP (@Take)
            p.ProductoId, p.Nombre, p.Categoria, p.Descripcion,
            p.Precio, p.Stock, p.EstadoStock, p.ImagenUrl, p.EsDestacado
        FROM dbo.Productos p
        WHERE p.Activo = 1 AND p.Stock > 0
          AND (@Categoria IS NULL OR p.Categoria = @Categoria)
          AND (@Buscar    IS NULL OR p.Nombre    LIKE N'%' + @Buscar + N'%')
        ORDER BY p.EsDestacado DESC, p.Nombre;
    ELSE
        SELECT
            p.ProductoId, p.Nombre, p.Categoria, p.Descripcion,
            p.Precio, p.Stock, p.EstadoStock, p.ImagenUrl, p.EsDestacado
        FROM dbo.Productos p
        WHERE p.Activo = 1 AND p.Stock > 0
          AND (@Categoria IS NULL OR p.Categoria = @Categoria)
          AND (@Buscar    IS NULL OR p.Nombre    LIKE N'%' + @Buscar + N'%')
        ORDER BY p.EsDestacado DESC, p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProductById
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.ProductoId, p.Nombre, p.Categoria, p.Descripcion,
        p.Precio, p.Stock, p.EstadoStock, p.ImagenUrl, p.EsDestacado
    FROM dbo.Productos p
    WHERE p.ProductoId = @ProductoId AND p.Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT c.CategoriaId, c.Nombre
    FROM dbo.Categorias c
    INNER JOIN dbo.Productos p ON p.CategoriaId = c.CategoriaId
    WHERE c.Activo = 1 AND p.Activo = 1 AND p.Stock > 0
    ORDER BY c.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_CreateOrder
    @UsuarioId        INT,
    @MetodoPago       NVARCHAR(40),
    @TipoEntrega      NVARCHAR(50)  = NULL,
    @DireccionEntrega NVARCHAR(255) = NULL,
    @ReferenciaPago   NVARCHAR(80)  = NULL,
    @Detalles         NVARCHAR(MAX) -- JSON: [{ProductoId, Cantidad, PrecioUnitario}]
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Total DECIMAL(18,2) = 0;
        SELECT @Total = SUM(CAST(j.Cantidad AS INT) * CAST(j.PrecioUnitario AS DECIMAL(18,2)))
        FROM OPENJSON(@Detalles) WITH (
            Cantidad       INT           '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        ) j;

        INSERT INTO dbo.Pedidos
            (UsuarioId, Estado, CanalPedido, TipoEntrega, DireccionEntrega,
             Total, MetodoPago, EstadoPago, ReferenciaPago, FechaPago, InventarioDescontado)
        VALUES
            (@UsuarioId, N'Pendiente', N'Tienda en línea',
             @TipoEntrega, @DireccionEntrega,
             @Total, @MetodoPago, N'Confirmado simulado', @ReferenciaPago,
             SYSDATETIME(), 0);

        DECLARE @PedidoId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
        SELECT
            @PedidoId,
            CAST(j.ProductoId     AS INT),
            CAST(j.Cantidad       AS INT),
            CAST(j.PrecioUnitario AS DECIMAL(18,2))
        FROM OPENJSON(@Detalles) WITH (
            ProductoId     INT           '$.ProductoId',
            Cantidad       INT           '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        ) j;

        -- Descontar inventario al confirmar checkout
        UPDATE pr
        SET pr.Stock = pr.Stock - pd.Cantidad
        FROM dbo.Productos pr
        INNER JOIN dbo.PedidoDetalle pd ON pd.ProductoId = pr.ProductoId
        WHERE pd.PedidoId = @PedidoId;

        UPDATE dbo.Pedidos SET InventarioDescontado = 1 WHERE PedidoId = @PedidoId;

        COMMIT;
        SELECT @PedidoId AS PedidoId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetMyOrders
    @UsuarioId INT,
    @Estado    NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PedidoId,
        p.FechaPedido,
        p.Estado,
        p.Total,
        p.MetodoPago,
        p.EstadoPago,
        p.CanalPedido,
        p.TipoEntrega,
        p.FechaActualizacion,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.Facturas f WHERE f.PedidoId = p.PedidoId)
             THEN 1 ELSE 0 END AS TieneFactura
    FROM dbo.Pedidos p
    WHERE p.UsuarioId = @UsuarioId
      AND (@Estado IS NULL OR p.Estado = @Estado)
    ORDER BY p.FechaPedido DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_CancelPendingOrder
    @PedidoId  INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Estado NVARCHAR(30), @InvDesc BIT, @Propietario INT;
        SELECT @Estado = Estado, @InvDesc = InventarioDescontado, @Propietario = UsuarioId
        FROM dbo.Pedidos WITH (UPDLOCK)
        WHERE PedidoId = @PedidoId;

        IF @Propietario IS NULL OR @Propietario <> @UsuarioId
        BEGIN 
            RAISERROR(N'Pedido no encontrado o sin permiso.', 16, 1); 
            ROLLBACK; 
            RETURN;
        END

        IF @Estado <> N'Pendiente'
        BEGIN 
            RAISERROR(N'Solo se pueden cancelar pedidos en estado Pendiente.', 16, 1);
            ROLLBACK; 
            RETURN;
        END

        IF @InvDesc = 1
        BEGIN
            UPDATE pr SET pr.Stock = pr.Stock + pd.Cantidad
            FROM dbo.Productos pr
            INNER JOIN dbo.PedidoDetalle pd ON pd.ProductoId = pr.ProductoId
            WHERE pd.PedidoId = @PedidoId;

            UPDATE dbo.Pedidos SET InventarioDescontado = 0 WHERE PedidoId = @PedidoId;
        END

        UPDATE dbo.Pedidos
        SET Estado = N'Cancelado', FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT;
        SELECT 1 AS Exito;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetInvoiceHeaderByOrder
    @PedidoId  INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        f.FacturaId, f.NumeroFactura, f.ClienteNombre, f.ClienteCorreo,
        f.FechaFactura, f.Subtotal, f.Impuesto, f.Total, f.Estado
    FROM dbo.Facturas f
    INNER JOIN dbo.Pedidos p ON p.PedidoId = f.PedidoId
    WHERE f.PedidoId  = @PedidoId
      AND p.UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetInvoiceLinesByOrder
    @PedidoId  INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        fd.FacturaDetalleId, fd.ProductoNombre,
        fd.Cantidad, fd.PrecioUnitario, fd.Subtotal
    FROM dbo.FacturaDetalle fd
    INNER JOIN dbo.Facturas f ON f.FacturaId  = fd.FacturaId
    INNER JOIN dbo.Pedidos  p ON p.PedidoId   = f.PedidoId
    WHERE f.PedidoId  = @PedidoId
      AND p.UsuarioId = @UsuarioId;
END
GO

-- ===========================================================
-- MÓDULO: CLIENTES
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClients
    @Filtro      NVARCHAR(100) = NULL,
    @SoloActivos BIT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UsuarioId, u.NombreCompleto, u.Correo, u.Telefono,
        u.Direccion, u.Activo, u.FechaRegistro, u.MotivoInactivacion,
        (SELECT COUNT(*) FROM dbo.Pedidos pe WHERE pe.UsuarioId = u.UsuarioId) AS TotalPedidos
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = N'Cliente'
      AND (@SoloActivos IS NULL OR u.Activo = @SoloActivos)
      AND (@Filtro IS NULL
           OR u.NombreCompleto LIKE N'%' + @Filtro + N'%'
           OR u.Correo         LIKE N'%' + @Filtro + N'%'
           OR u.Telefono       LIKE N'%' + @Filtro + N'%')
    ORDER BY u.NombreCompleto;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientById
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UsuarioId, u.NombreCompleto, u.Correo, u.Telefono,
        u.Direccion, u.Activo, u.FechaRegistro, u.MotivoInactivacion,
        p.PerfilId, p.Nombre AS NombrePerfil
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientDetail
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Datos del cliente
    SELECT
        u.UsuarioId, u.NombreCompleto, u.Correo,
        u.Telefono, u.Direccion, u.Activo, u.FechaRegistro
    FROM dbo.Usuarios u WHERE u.UsuarioId = @UsuarioId;

    -- Últimos 10 pedidos
    SELECT TOP 10
        p.PedidoId, p.FechaPedido, p.Estado, p.Total, p.CanalPedido
    FROM dbo.Pedidos p
    WHERE p.UsuarioId = @UsuarioId
    ORDER BY p.FechaPedido DESC;

    -- Crédito asignado
    SELECT cc.LimiteCredito, cc.CreditoActivo, cc.CreditoBloqueado, cc.MotivoBloqueo
    FROM dbo.ClienteCreditos cc
    WHERE cc.UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateClient
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

    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
    VALUES (@PerfilId, @NombreCompleto, @Correo, @Contrasena, @Telefono, @Direccion);

    DECLARE @NuevoId INT = SCOPE_IDENTITY();

    INSERT INTO dbo.ClienteCreditos (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
    VALUES (@NuevoId, 0, 0, 0);

    SELECT @NuevoId AS UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateClient
    @UsuarioId      INT,
    @NombreCompleto NVARCHAR(150),
    @Telefono       NVARCHAR(30)  = NULL,
    @Direccion      NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuarios
    SET NombreCompleto     = @NombreCompleto,
        Telefono           = @Telefono,
        Direccion          = @Direccion,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleClientStatus
    @UsuarioId          INT,
    @Activo             BIT,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuarios
    SET Activo             = @Activo,
        MotivoInactivacion = CASE WHEN @Activo = 0 THEN @MotivoInactivacion ELSE NULL END,
        FechaInactivacion  = CASE WHEN @Activo = 0 THEN SYSDATETIME()       ELSE NULL END,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId;
END
GO

-- ===========================================================
-- MÓDULO: CRÉDITOS
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientCredits
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cc.ClienteCreditoId,
        cc.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        cc.LimiteCredito,
        cc.CreditoActivo,
        cc.CreditoBloqueado,
        cc.MotivoBloqueo,
        cc.FechaCreacion,
        cc.FechaActualizacion,
        ISNULL((
            SELECT SUM(
                CASE cm.TipoMovimiento
                    WHEN N'Cargo'          THEN  cm.Monto
                    WHEN N'Abono'          THEN -cm.Monto
                    WHEN N'AjustePositivo' THEN  cm.Monto
                    ELSE                       -cm.Monto
                END)
            FROM dbo.ClienteCreditoMovimientos cm
            WHERE cm.UsuarioId = cc.UsuarioId
        ), 0) AS SaldoActual
    FROM dbo.ClienteCreditos cc
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = cc.UsuarioId
    WHERE (@Filtro IS NULL
           OR u.NombreCompleto LIKE N'%' + @Filtro + N'%'
           OR u.Correo         LIKE N'%' + @Filtro + N'%')
    ORDER BY u.NombreCompleto;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientCreditDetail
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Cabecera de crédito
    SELECT
        cc.ClienteCreditoId, cc.UsuarioId,
        u.NombreCompleto, u.Correo,
        cc.LimiteCredito, cc.CreditoActivo, cc.CreditoBloqueado,
        cc.MotivoBloqueo, cc.FechaCreacion, cc.FechaActualizacion
    FROM dbo.ClienteCreditos cc
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = cc.UsuarioId
    WHERE cc.UsuarioId = @UsuarioId;

    -- Historial de movimientos
    SELECT
        cm.CreditoMovimientoId, cm.TipoMovimiento, cm.Monto,
        cm.Descripcion, cm.Referencia, cm.RegistradoPorNombre, cm.FechaMovimiento
    FROM dbo.ClienteCreditoMovimientos cm
    WHERE cm.UsuarioId = @UsuarioId
    ORDER BY cm.FechaMovimiento DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateClientCreditSettings
    @UsuarioId        INT,
    @LimiteCredito    DECIMAL(18,2),
    @CreditoActivo    BIT,
    @CreditoBloqueado BIT,
    @MotivoBloqueo    NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.ClienteCreditos WHERE UsuarioId = @UsuarioId)
        INSERT INTO dbo.ClienteCreditos
            (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado, MotivoBloqueo)
        VALUES
            (@UsuarioId, @LimiteCredito, @CreditoActivo, @CreditoBloqueado, @MotivoBloqueo);
    ELSE
        UPDATE dbo.ClienteCreditos
        SET LimiteCredito      = @LimiteCredito,
            CreditoActivo      = @CreditoActivo,
            CreditoBloqueado   = @CreditoBloqueado,
            MotivoBloqueo      = @MotivoBloqueo,
            FechaActualizacion = SYSDATETIME()
        WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_RegisterClientCreditMovement
    @UsuarioId              INT,
    @TipoMovimiento         NVARCHAR(30),
    @Monto                  DECIMAL(18,2),
    @Descripcion            NVARCHAR(500),
    @Referencia             NVARCHAR(100) = NULL,
    @RegistradoPorUsuarioId INT,
    @RegistradoPorNombre    NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ClienteCreditoMovimientos
        (UsuarioId, RegistradoPorUsuarioId, TipoMovimiento,
         Monto, Descripcion, Referencia, RegistradoPorNombre)
    VALUES
        (@UsuarioId, @RegistradoPorUsuarioId, @TipoMovimiento,
         @Monto, @Descripcion, @Referencia, @RegistradoPorNombre);

    SELECT SCOPE_IDENTITY() AS CreditoMovimientoId;
END
GO

-- ===========================================================
-- MÓDULO: CONSULTAS
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateConsultation
    @Nombre  NVARCHAR(100),
    @Correo  NVARCHAR(150),
    @Asunto  NVARCHAR(120),
    @Mensaje NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Consultas (Nombre, Correo, Asunto, Mensaje)
    VALUES (@Nombre, @Correo, @Asunto, @Mensaje);
    SELECT SCOPE_IDENTITY() AS ConsultaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetConsultations
    @Estado NVARCHAR(30)  = NULL,
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ConsultaId, c.Nombre, c.Correo, c.Asunto,
        c.Estado, c.AtendidoPorNombre, c.FechaAtencion, c.FechaCreacion
    FROM dbo.Consultas c
    WHERE (@Estado IS NULL OR c.Estado = @Estado)
      AND (@Filtro IS NULL
           OR c.Nombre LIKE N'%' + @Filtro + N'%'
           OR c.Asunto LIKE N'%' + @Filtro + N'%'
           OR c.Correo LIKE N'%' + @Filtro + N'%')
    ORDER BY c.FechaCreacion DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetConsultationById
    @ConsultaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ConsultaId, c.Nombre, c.Correo, c.Asunto, c.Mensaje,
        c.Estado, c.RespuestaInterna, c.AtendidoPorNombre,
        c.FechaAtencion, c.FechaCreacion
    FROM dbo.Consultas c
    WHERE c.ConsultaId = @ConsultaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateConsultationStatus
    @ConsultaId           INT,
    @Estado               NVARCHAR(30),
    @RespuestaInterna     NVARCHAR(1000) = NULL,
    @AtendidoPorUsuarioId INT,
    @AtendidoPorNombre    NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Consultas
    SET Estado               = @Estado,
        RespuestaInterna     = @RespuestaInterna,
        AtendidoPorUsuarioId = @AtendidoPorUsuarioId,
        AtendidoPorNombre    = @AtendidoPorNombre,
        FechaAtencion        = SYSDATETIME()
    WHERE ConsultaId = @ConsultaId;
END
GO

PRINT '?? FASE 3 — Bloque 2/3 OK (Vendedor, Gerente, Tienda, Clientes, Créditos, Consultas)';
GO