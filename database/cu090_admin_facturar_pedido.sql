/* =========================================================
   CU-090 - Facturacion segura de pedidos desde administracion

   Objetivo:
   - Generar factura desde un pedido existente.
   - Evitar doble facturacion por PedidoId.
   - Bloquear pedidos cancelados o sin lineas.
   - Mantener la operacion en una transaccion.

   Importante:
   - No descuenta inventario. El flujo actual de checkout valida stock,
     pero no descuenta inventario al crear el pedido.
   ========================================================= */

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

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GenerateInvoiceFromOrder
    @PedidoId INT,
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @PedidoUsuarioId INT,
        @Estado NVARCHAR(30),
        @ClienteNombre NVARCHAR(150),
        @ClienteCorreo NVARCHAR(150),
        @Subtotal DECIMAL(18,2),
        @Impuesto DECIMAL(18,2),
        @Total DECIMAL(18,2),
        @FacturaId INT,
        @NumeroFactura NVARCHAR(30);

    IF @PedidoId IS NULL OR @PedidoId <= 0
    BEGIN
        THROW 50901, 'El pedido indicado no es valido.', 1;
    END

    BEGIN TRANSACTION;

    SELECT
        @PedidoUsuarioId = p.UsuarioId,
        @Estado = p.Estado,
        @ClienteNombre = u.NombreCompleto,
        @ClienteCorreo = u.Correo
    FROM dbo.Pedidos p WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;

    IF @PedidoUsuarioId IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50902, 'No se encontro el pedido solicitado.', 1;
    END

    IF @Estado NOT IN ('Pendiente', 'Aprobado', 'EnProceso', 'Entregado')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50903, 'El estado del pedido no permite facturacion.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50904, 'El pedido ya tiene una factura asociada.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.PedidoDetalle WHERE PedidoId = @PedidoId)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50905, 'El pedido no tiene lineas para facturar.', 1;
    END

    SELECT @Subtotal = SUM(Cantidad * PrecioUnitario)
    FROM dbo.PedidoDetalle
    WHERE PedidoId = @PedidoId;

    SET @Subtotal = ISNULL(@Subtotal, 0);
    SET @Impuesto = ROUND(@Subtotal * 0.13, 2);
    SET @Total = @Subtotal + @Impuesto;
    SET @NumeroFactura = CONCAT(
        'FAC-',
        FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'),
        '-',
        RIGHT(CONCAT('0000', @PedidoId), 4)
    );

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
        @PedidoUsuarioId,
        @ClienteNombre,
        @ClienteCorreo,
        @Subtotal,
        @Impuesto,
        @Total,
        'Generada'
    );

    SET @FacturaId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.FacturaDetalle
    (
        FacturaId,
        ProductoId,
        ProductoNombre,
        Cantidad,
        PrecioUnitario
    )
    SELECT
        @FacturaId,
        d.ProductoId,
        p.Nombre,
        d.Cantidad,
        d.PrecioUnitario
    FROM dbo.PedidoDetalle d
    INNER JOIN dbo.Productos p ON p.ProductoId = d.ProductoId
    WHERE d.PedidoId = @PedidoId;

    UPDATE dbo.Pedidos
    SET Estado = 'Entregado'
    WHERE PedidoId = @PedidoId
      AND Estado <> 'Entregado';

    COMMIT TRANSACTION;

    SELECT
        @FacturaId AS FacturaId,
        @PedidoId AS PedidoId,
        @NumeroFactura AS NumeroFactura,
        'Entregado' AS EstadoPedido;
END
GO
