/* =========================================================
   CU-097 - Pago simulado e inventario en checkout

   Objetivo:
   - Agregar datos de pago simulado al pedido.
   - Descontar inventario al crear el pedido desde checkout.
   - Evitar stock negativo en concurrencia.
   - Registrar movimientos de inventario por venta/cancelacion.
   - Restaurar stock al cancelar pedidos pendientes no facturados.

   Importante:
   - No integra pasarelas reales.
   - No guarda numeros de tarjeta, CVV ni datos bancarios.
   - La facturacion no descuenta inventario.
   ========================================================= */

USE DistribuidoraJJ_DB;
GO

IF COL_LENGTH('dbo.Pedidos', 'MetodoPago') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD MetodoPago NVARCHAR(40) NOT NULL
        CONSTRAINT DF_Pedidos_MetodoPago DEFAULT N'No especificado' WITH VALUES;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'EstadoPago') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD EstadoPago NVARCHAR(30) NOT NULL
        CONSTRAINT DF_Pedidos_EstadoPago DEFAULT N'Pendiente' WITH VALUES;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'ReferenciaPago') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD ReferenciaPago NVARCHAR(80) NULL;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'FechaPago') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD FechaPago DATETIME2 NULL;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'InventarioDescontado') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD InventarioDescontado BIT NOT NULL
        CONSTRAINT DF_Pedidos_InventarioDescontado DEFAULT 0 WITH VALUES;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_CreateOrder
    @UsuarioId INT,
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX),
    @MetodoPago NVARCHAR(40) = N'Efectivo contra entrega',
    @ReferenciaPago NVARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @PedidoId INT,
        @Total DECIMAL(18,2),
        @UsuarioNombre NVARCHAR(150),
        @FechaPago DATETIME2 = SYSDATETIME();

    SET @MetodoPago = NULLIF(LTRIM(RTRIM(@MetodoPago)), N'');
    SET @ReferenciaPago = NULLIF(LTRIM(RTRIM(@ReferenciaPago)), N'');

    IF @MetodoPago IS NULL
    BEGIN
        SET @MetodoPago = N'Efectivo contra entrega';
    END;

    IF @MetodoPago NOT IN
    (
        N'Efectivo contra entrega',
        N'SINPE Móvil simulado',
        N'Tarjeta demo',
        N'Transferencia simulada'
    )
    BEGIN
        THROW 51101, 'El metodo de pago indicado no es valido.', 1;
    END;

    IF @ItemsJson IS NULL OR LTRIM(RTRIM(@ItemsJson)) = N''
    BEGIN
        THROW 51102, 'El carrito esta vacio.', 1;
    END;

    DECLARE @Items TABLE
    (
        ProductoId INT NOT NULL PRIMARY KEY,
        Cantidad INT NOT NULL,
        Precio DECIMAL(18,2) NULL,
        StockAnterior INT NULL,
        StockNuevo INT NULL,
        ProductoNombre NVARCHAR(150) NULL
    );

    INSERT INTO @Items (ProductoId, Cantidad)
    SELECT ProductoId, SUM(Cantidad)
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        ProductoId INT '$.productoId',
        Cantidad INT '$.cantidad'
    )
    WHERE ProductoId IS NOT NULL
      AND Cantidad IS NOT NULL
      AND Cantidad > 0
    GROUP BY ProductoId;

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN
        THROW 51103, 'El carrito esta vacio.', 1;
    END;

    BEGIN TRANSACTION;

    SELECT @UsuarioNombre = NombreCompleto
    FROM dbo.Usuarios WITH (UPDLOCK, HOLDLOCK)
    WHERE UsuarioId = @UsuarioId;

    IF @UsuarioNombre IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51104, 'El usuario del pedido no es valido.', 1;
    END;

    UPDATE i
    SET
        Precio = p.Precio,
        StockAnterior = p.Stock,
        ProductoNombre = p.Nombre
    FROM @Items i
    INNER JOIN dbo.Productos p WITH (UPDLOCK, HOLDLOCK)
        ON p.ProductoId = i.ProductoId
    WHERE p.Activo = 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE Precio IS NULL OR StockAnterior IS NULL OR ProductoNombre IS NULL)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51105, 'Uno o mas productos no estan disponibles.', 1;
    END;

    IF EXISTS (SELECT 1 FROM @Items WHERE StockAnterior < Cantidad)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51106, 'No hay stock suficiente para uno o mas productos.', 1;
    END;

    SELECT @Total = SUM(Precio * Cantidad)
    FROM @Items;

    INSERT INTO dbo.Pedidos
    (
        UsuarioId,
        FechaPedido,
        Estado,
        TipoEntrega,
        DireccionEntrega,
        Total,
        Observaciones,
        IdentificacionCliente,
        MetodoPago,
        EstadoPago,
        ReferenciaPago,
        FechaPago,
        InventarioDescontado
    )
    VALUES
    (
        @UsuarioId,
        SYSDATETIME(),
        N'Pendiente',
        @TipoEntrega,
        @DireccionEntrega,
        @Total,
        @Observaciones,
        @IdentificacionCliente,
        @MetodoPago,
        N'Confirmado simulado',
        @ReferenciaPago,
        @FechaPago,
        0
    );

    SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, ProductoId, Cantidad, Precio
    FROM @Items;

    UPDATE p
    SET p.Stock = p.Stock - i.Cantidad
    FROM dbo.Productos p
    INNER JOIN @Items i
        ON i.ProductoId = p.ProductoId
    WHERE p.Stock >= i.Cantidad;

    IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Items)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51107, 'No hay stock suficiente para completar el pedido.', 1;
    END;

    UPDATE i
    SET StockNuevo = p.Stock
    FROM @Items i
    INNER JOIN dbo.Productos p
        ON p.ProductoId = i.ProductoId;

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
        UsuarioNombre,
        FechaMovimiento
    )
    SELECT
        ProductoId,
        ProductoNombre,
        N'Salida',
        Cantidad,
        StockAnterior,
        StockNuevo,
        CONCAT(N'Pedido #', @PedidoId, N' - pago simulado'),
        @UsuarioId,
        @UsuarioNombre,
        SYSDATETIME()
    FROM @Items;

    UPDATE dbo.Pedidos
    SET InventarioDescontado = 1
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;

    SELECT @PedidoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_CancelPendingOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Estado NVARCHAR(30),
        @InventarioDescontado BIT,
        @UsuarioNombre NVARCHAR(150);

    IF @PedidoId <= 0 OR @UsuarioId <= 0
    BEGIN
        SELECT CAST(0 AS BIT) AS Cancelado;
        RETURN;
    END;

    DECLARE @Restore TABLE
    (
        ProductoId INT NOT NULL PRIMARY KEY,
        ProductoNombre NVARCHAR(150) NOT NULL,
        Cantidad INT NOT NULL,
        StockAnterior INT NOT NULL,
        StockNuevo INT NULL
    );

    BEGIN TRANSACTION;

    SELECT
        @Estado = p.Estado,
        @InventarioDescontado = p.InventarioDescontado,
        @UsuarioNombre = u.NombreCompleto
    FROM dbo.Pedidos p WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN dbo.Usuarios u
        ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId
      AND p.UsuarioId = @UsuarioId;

    IF @Estado IS NULL
       OR @Estado <> N'Pendiente'
       OR EXISTS (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId)
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT CAST(0 AS BIT) AS Cancelado;
        RETURN;
    END;

    IF @InventarioDescontado = 1
    BEGIN
        INSERT INTO @Restore (ProductoId, ProductoNombre, Cantidad, StockAnterior)
        SELECT
            d.ProductoId,
            p.Nombre,
            SUM(d.Cantidad),
            p.Stock
        FROM dbo.PedidoDetalle d
        INNER JOIN dbo.Productos p WITH (UPDLOCK, HOLDLOCK)
            ON p.ProductoId = d.ProductoId
        WHERE d.PedidoId = @PedidoId
        GROUP BY d.ProductoId, p.Nombre, p.Stock;

        UPDATE p
        SET p.Stock = p.Stock + r.Cantidad
        FROM dbo.Productos p
        INNER JOIN @Restore r
            ON r.ProductoId = p.ProductoId;

        UPDATE r
        SET StockNuevo = p.Stock
        FROM @Restore r
        INNER JOIN dbo.Productos p
            ON p.ProductoId = r.ProductoId;

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
            UsuarioNombre,
            FechaMovimiento
        )
        SELECT
            ProductoId,
            ProductoNombre,
            N'Entrada',
            Cantidad,
            StockAnterior,
            StockNuevo,
            CONCAT(N'Cancelacion de pedido #', @PedidoId),
            @UsuarioId,
            ISNULL(@UsuarioNombre, N'Cliente'),
            SYSDATETIME()
        FROM @Restore;
    END;

    UPDATE dbo.Pedidos
    SET
        Estado = N'Cancelado',
        InventarioDescontado = 0
    WHERE PedidoId = @PedidoId
      AND UsuarioId = @UsuarioId
      AND Estado = N'Pendiente';

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT CAST(0 AS BIT) AS Cancelado;
        RETURN;
    END;

    COMMIT TRANSACTION;

    SELECT CAST(1 AS BIT) AS Cancelado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId INT,
    @NuevoEstado NVARCHAR(50),
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @EstadoActual NVARCHAR(30),
        @TieneFactura BIT = 0,
        @InventarioDescontado BIT = 0,
        @MovimientoUsuarioId INT,
        @MovimientoUsuarioNombre NVARCHAR(150);

    SET @NuevoEstado = NULLIF(LTRIM(RTRIM(@NuevoEstado)), N'');

    IF @PedidoId IS NULL OR @PedidoId <= 0
    BEGIN
        THROW 51001, 'El pedido indicado no es valido.', 1;
    END;

    IF @NuevoEstado IS NULL
       OR @NuevoEstado NOT IN (N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado', N'Cancelado')
    BEGIN
        THROW 51002, 'El estado indicado no es valido.', 1;
    END;

    DECLARE @Restore TABLE
    (
        ProductoId INT NOT NULL PRIMARY KEY,
        ProductoNombre NVARCHAR(150) NOT NULL,
        Cantidad INT NOT NULL,
        StockAnterior INT NOT NULL,
        StockNuevo INT NULL
    );

    BEGIN TRANSACTION;

    SELECT
        @EstadoActual = Estado,
        @InventarioDescontado = InventarioDescontado
    FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
    WHERE PedidoId = @PedidoId;

    IF @EstadoActual IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51003, 'No se encontro el pedido solicitado.', 1;
    END;

    SELECT @TieneFactura =
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK)
                WHERE PedidoId = @PedidoId
            )
            THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END;

    IF @TieneFactura = 1 AND @NuevoEstado <> N'Entregado'
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51004, 'El pedido facturado debe permanecer como Entregado.', 1;
    END;

    IF @EstadoActual = N'Cancelado' AND @NuevoEstado <> N'Cancelado'
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51005, 'No se puede reactivar un pedido cancelado.', 1;
    END;

    IF @TieneFactura = 0
       AND @EstadoActual <> @NuevoEstado
       AND NOT
       (
           (@EstadoActual = N'Pendiente' AND @NuevoEstado IN (N'Aprobado', N'Cancelado'))
        OR (@EstadoActual = N'Aprobado' AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
        OR (@EstadoActual = N'EnProceso' AND @NuevoEstado IN (N'Entregado', N'Cancelado'))
        OR (@EstadoActual = N'Entregado' AND @NuevoEstado = N'Cancelado')
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51006, 'La transicion de estado solicitada no es valida.', 1;
    END;

    IF @TieneFactura = 0 AND @NuevoEstado = N'Cancelado' AND @InventarioDescontado = 1
    BEGIN
        INSERT INTO @Restore (ProductoId, ProductoNombre, Cantidad, StockAnterior)
        SELECT
            d.ProductoId,
            p.Nombre,
            SUM(d.Cantidad),
            p.Stock
        FROM dbo.PedidoDetalle d
        INNER JOIN dbo.Productos p WITH (UPDLOCK, HOLDLOCK)
            ON p.ProductoId = d.ProductoId
        WHERE d.PedidoId = @PedidoId
        GROUP BY d.ProductoId, p.Nombre, p.Stock;

        UPDATE p
        SET p.Stock = p.Stock + r.Cantidad
        FROM dbo.Productos p
        INNER JOIN @Restore r
            ON r.ProductoId = p.ProductoId;

        UPDATE r
        SET StockNuevo = p.Stock
        FROM @Restore r
        INNER JOIN dbo.Productos p
            ON p.ProductoId = r.ProductoId;

        SET @MovimientoUsuarioId = ISNULL(NULLIF(@UsuarioId, 0), 1);
        SET @MovimientoUsuarioNombre = NULLIF(LTRIM(RTRIM(@UsuarioNombre)), N'');

        IF @MovimientoUsuarioNombre IS NULL
        BEGIN
            SELECT @MovimientoUsuarioNombre = NombreCompleto
            FROM dbo.Usuarios
            WHERE UsuarioId = @MovimientoUsuarioId;
        END;

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
            UsuarioNombre,
            FechaMovimiento
        )
        SELECT
            ProductoId,
            ProductoNombre,
            N'Entrada',
            Cantidad,
            StockAnterior,
            StockNuevo,
            CONCAT(N'Cancelacion administrativa de pedido #', @PedidoId),
            @MovimientoUsuarioId,
            ISNULL(@MovimientoUsuarioNombre, N'Sistema'),
            SYSDATETIME()
        FROM @Restore;
    END;

    UPDATE dbo.Pedidos
    SET
        Estado = @NuevoEstado,
        InventarioDescontado = CASE
            WHEN @NuevoEstado = N'Cancelado' AND @TieneFactura = 0 THEN 0
            ELSE InventarioDescontado
        END
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;
END;
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
        p.Observaciones,
        p.Total,
        p.MetodoPago,
        p.EstadoPago,
        p.ReferenciaPago,
        p.FechaPago
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u
        ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;
END;
GO
