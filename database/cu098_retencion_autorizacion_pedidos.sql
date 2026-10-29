/* =========================================================
   CU-098 — Retención, autorización/rechazo y auto-factura
            (CU-071 mejora + CU-073 + CU-091)

   Cambios estructurales:
   ─ ALTER TABLE Pedidos: agrega MotivoRechazo NVARCHAR(500) NULL
   ─ Nuevos estados válidos: 'Retenido', 'Liberado', 'Rechazado'
   ─ Nuevo rol: Gerente
   ─ Nuevo permiso: PEDIDOS_AUTORIZAR_RECHAZAR

   SPs REEMPLAZADOS (CREATE OR ALTER — firma compatible):
   ─ sp_Seller_CreateOrder   : retención por umbral + inventario
                               + auto-factura (CU-091) + offline GUID
   ─ sp_Admin_UpdateOrderStatus : acepta nuevos estados y transiciones
   ─ sp_Admin_GetOrderHeader : devuelve MotivoRechazo (col 14)

   SPs NUEVOS:
   ─ sp_Manager_GetRetainedOrders
   ─ sp_Manager_ApproveOrder
   ─ sp_Manager_RejectOrder
   ─ sp_Seller_GetMyOrders
   ─ sp_Admin_GetInvoiceSummaryByOrder
   ========================================================= */

USE DistribuidoraJJ_DB;
GO

-- =========================================================
-- 1. SCHEMA: columna MotivoRechazo en Pedidos
-- =========================================================
IF COL_LENGTH('dbo.Pedidos', 'MotivoRechazo') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD MotivoRechazo NVARCHAR(500) NULL;
END;
GO

-- =========================================================
-- 2. ROL: Gerente
-- =========================================================
IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Gerente')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES (N'Gerente', N'Gerente de ventas. Autoriza o rechaza pedidos retenidos.', 1);
END;
GO

-- =========================================================
-- 3. PERMISO: PEDIDOS_AUTORIZAR_RECHAZAR
-- =========================================================
MERGE dbo.Permisos AS target
USING (VALUES (
    N'PEDIDOS_AUTORIZAR_RECHAZAR',
    N'Pedidos',
    N'Autorizar o rechazar pedidos retenidos',
    N'Permite al Gerente aprobar o rechazar pedidos marcados como irregulares.'
)) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET Modulo      = source.Modulo,
               Nombre      = source.Nombre,
               Descripcion = source.Descripcion,
               Activo      = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-073'
FROM dbo.Perfiles p
INNER JOIN dbo.Permisos pe ON pe.Codigo = N'PEDIDOS_AUTORIZAR_RECHAZAR'
WHERE p.Nombre IN (N'Administrador', N'Gerente')
  AND pe.Activo = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.PerfilPermisos pp
      WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId
  );
GO

-- =========================================================
-- 4. sp_Seller_CreateOrder
--    Reemplaza cu072. Firma 100 % compatible + @UmbralRetencion.
--    — Idempotencia por @PedidoOfflineGuid (igual que cu072)
--    — Si total > umbral → Retenido (sin inventario ni factura)
--    — Si total ≤ umbral → Pendiente + inventario + auto-factura
--    — Devuelve: PedidoId, Estado, FacturaId, NumeroFactura
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Seller_CreateOrder
    @ClienteUsuarioId      INT,
    @VendedorUsuarioId     INT,
    @VendedorNombre        NVARCHAR(150),
    @TipoEntrega           NVARCHAR(100),
    @DireccionEntrega      NVARCHAR(500)   = NULL,
    @Observaciones         NVARCHAR(500)   = NULL,
    @IdentificacionCliente NVARCHAR(100)   = NULL,
    @ItemsJson             NVARCHAR(MAX),
    @PedidoOfflineGuid     UNIQUEIDENTIFIER = NULL,
    @CanalPedido           NVARCHAR(50)    = NULL,
    @UmbralRetencion       DECIMAL(18,2)   = 50000.00
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @PedidoId        INT,
        @Total           DECIMAL(18,2),
        @Estado          NVARCHAR(30),
        @DescuentaInv    BIT           = 0,
        @FacturaId       INT           = NULL,
        @NumeroFactura   NVARCHAR(30)  = NULL,
        @ClienteNombre   NVARCHAR(150),
        @ClienteCorreo   NVARCHAR(150),
        @Subtotal        DECIMAL(18,2),
        @Impuesto        DECIMAL(18,2),
        @TotalFactura    DECIMAL(18,2),
        @CanalFinal      NVARCHAR(50)  = ISNULL(NULLIF(LTRIM(RTRIM(@CanalPedido)), N''), N'Venta móvil');

    /* ── Idempotencia offline: si el GUID ya existe, devolver el resultado existente ── */
    IF @PedidoOfflineGuid IS NOT NULL
    BEGIN
        DECLARE
            @ExistingFacturaId     INT           = NULL,
            @ExistingNumeroFactura NVARCHAR(30)  = NULL,
            @ExistingEstado        NVARCHAR(30)  = NULL;

        SELECT @PedidoId = p.PedidoId, @ExistingEstado = p.Estado
        FROM dbo.Pedidos p
        WHERE p.PedidoOfflineGuid = @PedidoOfflineGuid;

        IF @PedidoId IS NOT NULL
        BEGIN
            SELECT @ExistingFacturaId = FacturaId, @ExistingNumeroFactura = NumeroFactura
            FROM dbo.Facturas
            WHERE PedidoId = @PedidoId;

            SELECT
                @PedidoId                              AS PedidoId,
                @ExistingEstado                        AS Estado,
                ISNULL(@ExistingFacturaId, 0)          AS FacturaId,
                ISNULL(@ExistingNumeroFactura, N'')    AS NumeroFactura;
            RETURN;
        END;
    END;

    /* ── Validaciones ── */
    IF NOT EXISTS (
        SELECT 1
        FROM   dbo.Usuarios u
        INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
        WHERE  u.UsuarioId = @ClienteUsuarioId
          AND  u.Activo    = 1
          AND  p.Nombre    = N'Cliente'
    )
        THROW 50710, 'El cliente seleccionado no existe o está inactivo.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios
        WHERE UsuarioId = @VendedorUsuarioId AND Activo = 1
    )
        THROW 50711, 'El vendedor que registra el pedido no es válido.', 1;

    IF ISNULL(@ItemsJson, N'') = N''
        THROW 50712, 'Debe seleccionar al menos un producto.', 1;

    /* ── Parseo del carrito ── */
    DECLARE @Items TABLE (
        ProductoId     INT             NOT NULL,
        Cantidad       INT             NOT NULL,
        Precio         DECIMAL(18,2)   NULL,
        StockAnterior  INT             NULL,
        StockNuevo     INT             NULL,
        ProductoNombre NVARCHAR(150)   NULL
    );

    INSERT INTO @Items (ProductoId, Cantidad)
    SELECT ProductoId, SUM(Cantidad)
    FROM OPENJSON(@ItemsJson)
    WITH (
        ProductoId INT '$.productoId',
        Cantidad   INT '$.cantidad'
    )
    WHERE ISNULL(Cantidad, 0) > 0
    GROUP BY ProductoId;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 50713, 'Debe indicar cantidades mayores a cero.', 1;

    /* ── Inicio de transacción ── */
    BEGIN TRANSACTION;

    UPDATE i
    SET    Precio         = p.Precio,
           StockAnterior  = p.Stock,
           ProductoNombre = p.Nombre
    FROM   @Items i
    INNER JOIN dbo.Productos p WITH (UPDLOCK, HOLDLOCK)
           ON p.ProductoId = i.ProductoId
    WHERE  p.Activo = 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE Precio IS NULL OR StockAnterior IS NULL)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50714, 'Uno o más productos no están disponibles.', 1;
    END;

    IF EXISTS (SELECT 1 FROM @Items WHERE Cantidad > StockAnterior)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50715, 'No hay stock suficiente para uno o más productos.', 1;
    END;

    SELECT @Total = SUM(Precio * Cantidad) FROM @Items;

    /* ── Regla de retención ── */
    IF @Total > @UmbralRetencion
    BEGIN
        SET @Estado      = N'Retenido';
        SET @DescuentaInv = 0;
    END
    ELSE
    BEGIN
        SET @Estado      = N'Pendiente';
        SET @DescuentaInv = 1;
    END;

    SELECT @ClienteNombre = NombreCompleto, @ClienteCorreo = Correo
    FROM   dbo.Usuarios
    WHERE  UsuarioId = @ClienteUsuarioId;

    /* ── Insertar pedido ── */
    INSERT INTO dbo.Pedidos (
        UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega,
        Total, Observaciones, IdentificacionCliente,
        VendedorUsuarioId, VendedorNombre, CanalPedido, FechaActualizacion,
        PedidoOfflineGuid, MetodoPago, EstadoPago, InventarioDescontado
    )
    VALUES (
        @ClienteUsuarioId, SYSDATETIME(), @Estado,
        @TipoEntrega, LEFT(ISNULL(@DireccionEntrega, N''), 255),
        @Total, LEFT(ISNULL(@Observaciones, N''), 255), @IdentificacionCliente,
        @VendedorUsuarioId, @VendedorNombre, @CanalFinal, SYSDATETIME(),
        @PedidoOfflineGuid, N'Crédito vendedor', N'Pendiente', @DescuentaInv
    );

    SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, ProductoId, Cantidad, Precio
    FROM   @Items;

    /* ── Solo para pedidos NO retenidos: inventario + CU-091 auto-factura ── */
    IF @DescuentaInv = 1
    BEGIN
        UPDATE p
        SET    p.Stock = p.Stock - i.Cantidad
        FROM   dbo.Productos p
        INNER JOIN @Items i ON i.ProductoId = p.ProductoId
        WHERE  p.Stock >= i.Cantidad;

        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Items)
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50716, 'Concurrencia de stock detectada. Intente nuevamente.', 1;
        END;

        UPDATE i
        SET StockNuevo = p.Stock
        FROM @Items i
        INNER JOIN dbo.Productos p ON p.ProductoId = i.ProductoId;

        INSERT INTO dbo.MovimientosInventario (
            ProductoId, ProductoNombre, TipoMovimiento, Cantidad,
            StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre, FechaMovimiento
        )
        SELECT
            ProductoId, ProductoNombre, N'Salida', Cantidad,
            StockAnterior, StockNuevo,
            CONCAT(N'Pedido móvil #', @PedidoId, N' - vendedor: ', @VendedorNombre),
            @VendedorUsuarioId, @VendedorNombre, SYSDATETIME()
        FROM @Items;

        /* CU-091: auto-factura */
        SET @NumeroFactura = CONCAT(
            N'FAC-',
            FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'),
            N'-',
            RIGHT(CONCAT(N'0000', CAST(@PedidoId AS NVARCHAR(4))), 4)
        );

        SELECT @Subtotal = SUM(Precio * Cantidad) FROM @Items;
        SET @Impuesto    = ROUND(@Subtotal * 0.13, 2);
        SET @TotalFactura = @Subtotal + @Impuesto;

        INSERT INTO dbo.Facturas (
            PedidoId, NumeroFactura, UsuarioId,
            ClienteNombre, ClienteCorreo,
            Subtotal, Impuesto, Total, Estado
        )
        VALUES (
            @PedidoId, @NumeroFactura, @ClienteUsuarioId,
            @ClienteNombre, @ClienteCorreo,
            @Subtotal, @Impuesto, @TotalFactura, N'Generada'
        );

        SET @FacturaId = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO dbo.FacturaDetalle (
            FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario
        )
        SELECT @FacturaId, ProductoId, ProductoNombre, Cantidad, Precio
        FROM   @Items;
    END;

    COMMIT TRANSACTION;

    SELECT
        @PedidoId                      AS PedidoId,
        @Estado                        AS Estado,
        ISNULL(@FacturaId, 0)          AS FacturaId,
        ISNULL(@NumeroFactura, N'')    AS NumeroFactura;
END;
GO

-- =========================================================
-- 5. sp_Admin_UpdateOrderStatus (extiende cu097)
--    Agrega Retenido, Liberado, Rechazado como estados válidos.
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId      INT,
    @NuevoEstado   NVARCHAR(50),
    @UsuarioId     INT           = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @EstadoActual         NVARCHAR(30),
        @TieneFactura         BIT = 0,
        @InventarioDescontado BIT = 0;

    SET @NuevoEstado = NULLIF(LTRIM(RTRIM(@NuevoEstado)), N'');

    IF @PedidoId IS NULL OR @PedidoId <= 0
        THROW 51001, 'El pedido indicado no es válido.', 1;

    IF @NuevoEstado IS NULL
       OR @NuevoEstado NOT IN (
           N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado', N'Cancelado',
           N'Retenido',  N'Liberado', N'Rechazado'
       )
        THROW 51002, 'El estado indicado no es válido.', 1;

    DECLARE @Restore TABLE (
        ProductoId     INT             NOT NULL PRIMARY KEY,
        ProductoNombre NVARCHAR(150)   NOT NULL,
        Cantidad       INT             NOT NULL,
        StockAnterior  INT             NOT NULL,
        StockNuevo     INT             NULL
    );

    BEGIN TRANSACTION;

    SELECT
        @EstadoActual         = Estado,
        @InventarioDescontado = InventarioDescontado
    FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
    WHERE PedidoId = @PedidoId;

    IF @EstadoActual IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51003, 'No se encontró el pedido solicitado.', 1;
    END;

    SELECT @TieneFactura = CASE
        WHEN EXISTS (
            SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId
        ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT)
    END;

    IF @TieneFactura = 1 AND @NuevoEstado <> N'Entregado'
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51004, 'El pedido facturado debe permanecer como Entregado.', 1;
    END;

    IF @EstadoActual IN (N'Cancelado', N'Rechazado') AND @EstadoActual <> @NuevoEstado
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51005, 'No se puede cambiar el estado de un pedido cancelado o rechazado.', 1;
    END;

    IF @TieneFactura = 0
       AND @EstadoActual <> @NuevoEstado
       AND NOT (
           (@EstadoActual = N'Pendiente'  AND @NuevoEstado IN (N'Aprobado',  N'Cancelado'))
        OR (@EstadoActual = N'Aprobado'   AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
        OR (@EstadoActual = N'EnProceso'  AND @NuevoEstado IN (N'Entregado', N'Cancelado'))
        OR (@EstadoActual = N'Entregado'  AND @NuevoEstado =   N'Cancelado')
        OR (@EstadoActual = N'Retenido'   AND @NuevoEstado IN (N'Liberado',  N'Rechazado', N'Cancelado'))
        OR (@EstadoActual = N'Liberado'   AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51006, 'La transición de estado solicitada no es válida.', 1;
    END;

    IF @NuevoEstado IN (N'Cancelado', N'Rechazado')
       AND @InventarioDescontado = 1
       AND @TieneFactura = 0
    BEGIN
        DECLARE @MovId  INT           = ISNULL(NULLIF(@UsuarioId, 0), 1);
        DECLARE @MovNom NVARCHAR(150);

        SET @MovNom = NULLIF(LTRIM(RTRIM(@UsuarioNombre)), N'');
        IF @MovNom IS NULL
            SELECT @MovNom = NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @MovId;

        INSERT INTO @Restore (ProductoId, ProductoNombre, Cantidad, StockAnterior)
        SELECT d.ProductoId, p.Nombre, SUM(d.Cantidad), p.Stock
        FROM   dbo.PedidoDetalle d
        INNER JOIN dbo.Productos p WITH (UPDLOCK, HOLDLOCK) ON p.ProductoId = d.ProductoId
        WHERE  d.PedidoId = @PedidoId
        GROUP  BY d.ProductoId, p.Nombre, p.Stock;

        UPDATE p SET p.Stock = p.Stock + r.Cantidad
        FROM dbo.Productos p INNER JOIN @Restore r ON r.ProductoId = p.ProductoId;

        UPDATE r SET StockNuevo = p.Stock
        FROM @Restore r INNER JOIN dbo.Productos p ON p.ProductoId = r.ProductoId;

        INSERT INTO dbo.MovimientosInventario (
            ProductoId, ProductoNombre, TipoMovimiento, Cantidad,
            StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre, FechaMovimiento
        )
        SELECT ProductoId, ProductoNombre, N'Entrada', Cantidad,
               StockAnterior, StockNuevo,
               CONCAT(N'Cancelación/Rechazo de pedido #', @PedidoId),
               @MovId, ISNULL(@MovNom, N'Sistema'), SYSDATETIME()
        FROM @Restore;
    END;

    UPDATE dbo.Pedidos
    SET Estado               = @NuevoEstado,
        FechaActualizacion   = SYSDATETIME(),
        InventarioDescontado = CASE
            WHEN @NuevoEstado IN (N'Cancelado', N'Rechazado') AND @TieneFactura = 0
            THEN 0 ELSE InventarioDescontado
        END
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;
END;
GO

-- =========================================================
-- 6. sp_Admin_GetOrderHeader (agrega MotivoRechazo col 14)
-- =========================================================
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
        p.Observaciones,
        p.Total,
        ISNULL(p.MetodoPago,    N'') AS MetodoPago,
        ISNULL(p.EstadoPago,    N'') AS EstadoPago,
        p.ReferenciaPago,
        p.FechaPago,
        p.MotivoRechazo                         -- col 14 (nuevo)
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;
END;
GO

-- =========================================================
-- 7. sp_Admin_GetInvoiceSummaryByOrder
--    Devuelve FacturaId + NumeroFactura para pantallas de confirmación
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceSummaryByOrder
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT FacturaId, NumeroFactura
    FROM   dbo.Facturas
    WHERE  PedidoId = @PedidoId;
END;
GO

-- =========================================================
-- 8. sp_Manager_GetRetainedOrders
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Manager_GetRetainedOrders
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PedidoId,
        u.NombreCompleto                    AS Cliente,
        u.Correo,
        p.FechaPedido,
        ISNULL(p.VendedorNombre, N'—')      AS VendedorNombre,
        p.Total,
        ISNULL(p.TipoEntrega, N'')          AS TipoEntrega,
        ISNULL(p.CanalPedido, N'')          AS CanalPedido,
        (SELECT COUNT(*) FROM dbo.PedidoDetalle d WHERE d.PedidoId = p.PedidoId) AS TotalLineas
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.Estado = N'Retenido'
      AND (
          @Buscar IS NULL
          OR u.NombreCompleto  LIKE N'%' + @Buscar + N'%'
          OR u.Correo          LIKE N'%' + @Buscar + N'%'
          OR p.VendedorNombre  LIKE N'%' + @Buscar + N'%'
          OR CAST(p.PedidoId AS NVARCHAR) = @Buscar
      )
    ORDER BY p.FechaPedido ASC;
END;
GO

-- =========================================================
-- 9. sp_Manager_ApproveOrder
--    Retenido → Liberado + inventario + CU-091 auto-factura
--    Devuelve: PedidoId, Estado, FacturaId, NumeroFactura
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Manager_ApproveOrder
    @PedidoId      INT,
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @EstadoActual  NVARCHAR(30),
        @ClienteId     INT,
        @ClienteNombre NVARCHAR(150),
        @ClienteCorreo NVARCHAR(150),
        @FacturaId     INT,
        @NumeroFactura NVARCHAR(30),
        @Subtotal      DECIMAL(18,2),
        @Impuesto      DECIMAL(18,2),
        @TotalFactura  DECIMAL(18,2);

    IF @PedidoId IS NULL OR @PedidoId <= 0
        THROW 50730, 'El pedido indicado no es válido.', 1;

    DECLARE @Items TABLE (
        ProductoId     INT             NOT NULL PRIMARY KEY,
        ProductoNombre NVARCHAR(150)   NOT NULL,
        Cantidad       INT             NOT NULL,
        PrecioUnitario DECIMAL(18,2)   NOT NULL,
        StockAnterior  INT             NOT NULL,
        StockNuevo     INT             NULL
    );

    BEGIN TRANSACTION;

    SELECT
        @EstadoActual  = p.Estado,
        @ClienteId     = p.UsuarioId,
        @ClienteNombre = u.NombreCompleto,
        @ClienteCorreo = u.Correo
    FROM dbo.Pedidos p WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;

    IF @EstadoActual IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 50731, 'No se encontró el pedido solicitado.', 1; END;

    IF @EstadoActual <> N'Retenido'
    BEGIN ROLLBACK TRANSACTION; THROW 50732, 'Solo se pueden aprobar pedidos en estado Retenido.', 1; END;

    IF EXISTS (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId)
    BEGIN ROLLBACK TRANSACTION; THROW 50733, 'El pedido ya tiene una factura asociada.', 1; END;

    INSERT INTO @Items (ProductoId, ProductoNombre, Cantidad, PrecioUnitario, StockAnterior)
    SELECT d.ProductoId, pr.Nombre, SUM(d.Cantidad), MAX(d.PrecioUnitario), pr.Stock
    FROM dbo.PedidoDetalle d
    INNER JOIN dbo.Productos pr WITH (UPDLOCK, HOLDLOCK) ON pr.ProductoId = d.ProductoId
    WHERE d.PedidoId = @PedidoId
    GROUP BY d.ProductoId, pr.Nombre, pr.Stock;

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN ROLLBACK TRANSACTION; THROW 50734, 'El pedido no tiene líneas para procesar.', 1; END;

    IF EXISTS (SELECT 1 FROM @Items WHERE StockAnterior < Cantidad)
    BEGIN ROLLBACK TRANSACTION; THROW 50735, 'Stock insuficiente para uno o más productos al momento de aprobar.', 1; END;

    UPDATE pr
    SET    pr.Stock = pr.Stock - i.Cantidad
    FROM   dbo.Productos pr
    INNER JOIN @Items i ON i.ProductoId = pr.ProductoId
    WHERE  pr.Stock >= i.Cantidad;

    IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Items)
    BEGIN ROLLBACK TRANSACTION; THROW 50736, 'Error de concurrencia de stock. Intente nuevamente.', 1; END;

    UPDATE i SET StockNuevo = pr.Stock
    FROM @Items i INNER JOIN dbo.Productos pr ON pr.ProductoId = i.ProductoId;

    INSERT INTO dbo.MovimientosInventario (
        ProductoId, ProductoNombre, TipoMovimiento, Cantidad,
        StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre, FechaMovimiento
    )
    SELECT ProductoId, ProductoNombre, N'Salida', Cantidad, StockAnterior, StockNuevo,
           CONCAT(N'Pedido #', @PedidoId, N' liberado por ', @UsuarioNombre),
           @UsuarioId, @UsuarioNombre, SYSDATETIME()
    FROM @Items;

    SET @NumeroFactura = CONCAT(
        N'FAC-',
        FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'),
        N'-',
        RIGHT(CONCAT(N'0000', CAST(@PedidoId AS NVARCHAR(4))), 4)
    );

    SELECT @Subtotal = SUM(PrecioUnitario * Cantidad) FROM @Items;
    SET @Impuesto    = ROUND(@Subtotal * 0.13, 2);
    SET @TotalFactura = @Subtotal + @Impuesto;

    INSERT INTO dbo.Facturas (
        PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo,
        Subtotal, Impuesto, Total, Estado
    )
    VALUES (
        @PedidoId, @NumeroFactura, @ClienteId, @ClienteNombre, @ClienteCorreo,
        @Subtotal, @Impuesto, @TotalFactura, N'Generada'
    );

    SET @FacturaId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
    SELECT @FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario
    FROM   @Items;

    UPDATE dbo.Pedidos
    SET Estado               = N'Liberado',
        FechaActualizacion   = SYSDATETIME(),
        InventarioDescontado = 1
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;

    SELECT
        @PedidoId      AS PedidoId,
        N'Liberado'    AS Estado,
        @FacturaId     AS FacturaId,
        @NumeroFactura AS NumeroFactura;
END;
GO

-- =========================================================
-- 10. sp_Manager_RejectOrder
--     Retenido → Rechazado + MotivoRechazo
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Manager_RejectOrder
    @PedidoId      INT,
    @MotivoRechazo NVARCHAR(500),
    @UsuarioId     INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoActual NVARCHAR(30);

    IF @PedidoId IS NULL OR @PedidoId <= 0
        THROW 50740, 'El pedido indicado no es válido.', 1;

    IF NULLIF(LTRIM(RTRIM(@MotivoRechazo)), N'') IS NULL
        THROW 50741, 'El motivo de rechazo es obligatorio.', 1;

    BEGIN TRANSACTION;

    SELECT @EstadoActual = Estado
    FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
    WHERE PedidoId = @PedidoId;

    IF @EstadoActual IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 50742, 'No se encontró el pedido solicitado.', 1; END;

    IF @EstadoActual <> N'Retenido'
    BEGIN ROLLBACK TRANSACTION; THROW 50743, 'Solo se pueden rechazar pedidos en estado Retenido.', 1; END;

    UPDATE dbo.Pedidos
    SET Estado             = N'Rechazado',
        MotivoRechazo      = LEFT(LTRIM(RTRIM(@MotivoRechazo)), 500),
        FechaActualizacion = SYSDATETIME()
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;

    SELECT @PedidoId AS PedidoId, N'Rechazado' AS Estado;
END;
GO

-- =========================================================
-- 11. sp_Seller_GetMyOrders
--     Panel de notificaciones del vendedor
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetMyOrders
    @VendedorUsuarioId INT,
    @Top               INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        p.PedidoId,
        u.NombreCompleto                    AS Cliente,
        p.FechaPedido,
        p.Estado,
        p.Total,
        ISNULL(p.MotivoRechazo, N'')        AS MotivoRechazo,
        ISNULL(f.NumeroFactura, N'')         AS NumeroFactura,
        p.FechaActualizacion
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u  ON u.UsuarioId  = p.UsuarioId
    LEFT  JOIN dbo.Facturas f  ON f.PedidoId   = p.PedidoId
    WHERE p.VendedorUsuarioId = @VendedorUsuarioId
    ORDER BY p.FechaPedido DESC;
END;
GO

PRINT 'CU-098 aplicado correctamente: retención, autorización/rechazo y auto-factura (CU-071+CU-073+CU-091).';
GO
