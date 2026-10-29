/*
  Prueba funcional de 0012 para una base LocalDB desechable.
  Ejecuta escrituras dentro de una única transacción y siempre hace ROLLBACK.
  No ejecutar en Azure DEV, producción ni una base compartida.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @AdministradorId INT =
        (SELECT TOP (1) UsuarioId FROM dbo.Usuarios WHERE Activo = 1 ORDER BY UsuarioId);
    DECLARE @ClienteId INT =
        (SELECT TOP (1) UsuarioId FROM dbo.Usuarios
         WHERE Activo = 1 AND UsuarioId <> @AdministradorId ORDER BY UsuarioId);
    DECLARE @Producto1Id INT =
        (SELECT TOP (1) ProductoId FROM dbo.Productos WHERE Activo = 1 ORDER BY ProductoId);
    DECLARE @Producto2Id INT =
        (SELECT TOP (1) ProductoId FROM dbo.Productos
         WHERE Activo = 1 AND ProductoId <> @Producto1Id ORDER BY ProductoId);
    DECLARE @ComboId INT;
    DECLARE @PedidoFacturableId INT;
    DECLARE @PedidoCanceladoId INT;
    DECLARE @TokenFacturable UNIQUEIDENTIFIER = NEWID();
    DECLARE @TokenCancelacion UNIQUEIDENTIFIER = NEWID();
    DECLARE @ItemsMixtos NVARCHAR(MAX);
    DECLARE @ItemsCombo NVARCHAR(MAX);
    DECLARE @ComponentesJson NVARCHAR(MAX);
    DECLARE @ReferenciaTransformacion UNIQUEIDENTIFIER;
    DECLARE @AnioActual INT = YEAR(SYSDATETIME());

    IF @AdministradorId IS NULL OR @ClienteId IS NULL
       OR @Producto1Id IS NULL OR @Producto2Id IS NULL
        THROW 54720, N'La fixture requiere dos usuarios y dos productos activos.', 1;

    UPDATE dbo.Productos
    SET Stock = 100
    WHERE ProductoId IN (@Producto1Id, @Producto2Id);
    SET @ComponentesJson = CONCAT
    (
        N'[{"productoId":', @Producto1Id, N',"cantidad":2},',
        N'{"productoId":', @Producto2Id, N',"cantidad":1}]'
    );

    EXEC dbo.sp_Admin_CreateCombo
        @Nombre = N'QA local 0012',
        @Descripcion = N'Combo transaccional de prueba',
        @Precio = 1500.00,
        @ComponentesJson = @ComponentesJson,
        @UsuarioId = @AdministradorId,
        @UsuarioNombre = N'QA Local',
        @NuevoComboId = @ComboId OUTPUT;

    SET @ItemsMixtos = CONCAT(
        N'[{"tipo":"Producto","productoId":', @Producto1Id, N',"comboId":null,"cantidad":1},',
        N'{"tipo":"Combo","productoId":null,"comboId":', @ComboId, N',"cantidad":1}]');

    EXEC dbo.sp_Store_CreateOrderWithPromotions
        @UsuarioId = @ClienteId,
        @TipoEntrega = N'Retiro en tienda',
        @IdentificacionCliente = N'QA-LOCAL-0012',
        @ItemsJson = @ItemsMixtos,
        @TokenOperacion = @TokenFacturable;

    SELECT @PedidoFacturableId = PedidoId
    FROM dbo.CheckoutOperaciones
    WHERE UsuarioId = @ClienteId AND TokenOperacion = @TokenFacturable;

    IF @PedidoFacturableId IS NULL
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id) <> 97
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id) <> 99
       OR NOT EXISTS (SELECT 1 FROM dbo.PedidoCombos WHERE PedidoId = @PedidoFacturableId)
       OR (SELECT COUNT(*) FROM dbo.PedidoComboDetalle component
           INNER JOIN dbo.PedidoCombos combo ON combo.PedidoComboId = component.PedidoComboId
           WHERE combo.PedidoId = @PedidoFacturableId) <> 2
        THROW 54721, N'El checkout mixto no descontó ni persistió los snapshots esperados.', 1;

    EXEC dbo.sp_Store_CreateOrderWithPromotions
        @UsuarioId = @ClienteId,
        @TipoEntrega = N'Retiro en tienda',
        @IdentificacionCliente = N'QA-LOCAL-0012',
        @ItemsJson = @ItemsMixtos,
        @TokenOperacion = @TokenFacturable;

    IF (SELECT COUNT(*) FROM dbo.CheckoutOperaciones
        WHERE UsuarioId = @ClienteId AND TokenOperacion = @TokenFacturable) <> 1
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id) <> 97
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id) <> 99
        THROW 54722, N'El reintento idempotente creó otro pedido o descontó stock nuevamente.', 1;

    EXEC dbo.sp_Admin_GenerateInvoiceFromOrder
        @PedidoId = @PedidoFacturableId,
        @UsuarioId = @AdministradorId,
        @UsuarioNombre = N'QA Local';

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.FacturaCombos invoiceCombo
        INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = invoiceCombo.FacturaId
        WHERE invoice.PedidoId = @PedidoFacturableId
    )
        THROW 54724, N'La factura no conservó el snapshot del combo.', 1;

    SET @ItemsCombo = CONCAT(
        N'[{"tipo":"Combo","productoId":null,"comboId":', @ComboId, N',"cantidad":1}]');

    EXEC dbo.sp_Store_CreateOrderWithPromotions
        @UsuarioId = @ClienteId,
        @TipoEntrega = N'Retiro en tienda',
        @IdentificacionCliente = N'QA-LOCAL-0012',
        @ItemsJson = @ItemsCombo,
        @TokenOperacion = @TokenCancelacion;

    SELECT @PedidoCanceladoId = PedidoId
    FROM dbo.CheckoutOperaciones
    WHERE UsuarioId = @ClienteId AND TokenOperacion = @TokenCancelacion;

    EXEC dbo.sp_Client_CancelPendingOrder @PedidoId = @PedidoCanceladoId, @UsuarioId = @ClienteId;

    IF (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id) <> 97
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id) <> 99
       OR EXISTS
       (
           SELECT 1 FROM dbo.Pedidos
           WHERE PedidoId = @PedidoCanceladoId
             AND (Estado <> N'Cancelado' OR InventarioDescontado <> 0)
       )
        THROW 54725, N'La cancelación no restauró los componentes del combo.', 1;

    EXEC dbo.sp_Inventory_TransformStockAtomic
        @ProductoOrigenId = @Producto1Id,
        @CantidadOrigen = 2,
        @ProductoDestinoId = @Producto2Id,
        @CantidadDestino = 6,
        @Motivo = N'QA local 0012',
        @UsuarioId = @AdministradorId,
        @UsuarioNombre = N'QA Local';

    SELECT TOP (1) @ReferenciaTransformacion = ReferenciaTransformacion
    FROM dbo.InventarioTransformaciones
    ORDER BY InventarioTransformacionId DESC;

    IF @ReferenciaTransformacion IS NULL
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id) <> 95
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id) <> 105
       OR (SELECT COUNT(*) FROM dbo.MovimientosInventario
           WHERE Motivo LIKE N'%' + CONVERT(NVARCHAR(36), @ReferenciaTransformacion) + N'%') <> 2
        THROW 54726, N'La transformación no fue atómica o no dejó los dos movimientos relacionados.', 1;

    DECLARE @Tendencia TABLE
    (
        NumeroMes INT,
        NombreMes NVARCHAR(20),
        TotalVendido DECIMAL(18,2),
        UnidadesVendidas INT
    );
    INSERT INTO @Tendencia
    EXEC dbo.sp_Admin_GetSeasonalSalesTrend
        @AnioInicio = @AnioActual,
        @AnioFin = @AnioActual;

    IF (SELECT COUNT(*) FROM @Tendencia) <> 12
       OR (SELECT COUNT(DISTINCT NumeroMes) FROM @Tendencia) <> 12
        THROW 54727, N'La tendencia estacional no devolvió exactamente doce meses.', 1;

    ROLLBACK TRANSACTION;
    SELECT N'0012 functional local test passed; all writes rolled back.' AS Resultado;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
