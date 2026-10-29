SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_OrderHasInvoice
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM dbo.Facturas
                    WHERE PedidoId = @PedidoId
                )
                THEN 1
                ELSE 0
            END AS BIT
        ) AS HasInvoice;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetInvoiceHeaderByOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        f.FacturaId,
        f.PedidoId,
        f.NumeroFactura,
        f.ClienteNombre,
        f.ClienteCorreo,
        f.FechaFactura,
        f.Subtotal,
        f.Impuesto,
        f.Total,
        f.Estado
    FROM dbo.Facturas f
    INNER JOIN dbo.Pedidos p
        ON p.PedidoId = f.PedidoId
    WHERE f.PedidoId = @PedidoId
      AND f.UsuarioId = @UsuarioId
      AND p.UsuarioId = @UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetInvoiceLinesByOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fd.ProductoNombre,
        fd.Cantidad,
        fd.PrecioUnitario,
        fd.Subtotal
    FROM dbo.FacturaDetalle fd
    INNER JOIN dbo.Facturas f
        ON f.FacturaId = fd.FacturaId
    INNER JOIN dbo.Pedidos p
        ON p.PedidoId = f.PedidoId
    WHERE f.PedidoId = @PedidoId
      AND f.UsuarioId = @UsuarioId
      AND p.UsuarioId = @UsuarioId
    ORDER BY fd.FacturaDetalleId ASC;
END;
GO
