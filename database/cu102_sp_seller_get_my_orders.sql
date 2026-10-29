USE DistribuidoraJJ_DB;
GO

/*
    CU-102: Script minimo para corregir /SellerOrders/MyOrders.

    Proposito:
    - Crear dbo.sp_Seller_GetMyOrders requerido por AdminDbService.GetSellerMyOrdersAsync.

    Alcance:
    - No reemplaza CU-098.
    - No modifica tablas.
    - No modifica datos.
    - No crea roles.
    - No crea permisos.
    - No cambia inventario, facturacion ni estados de pedidos.
    - No depende de Pedidos.MotivoRechazo, porque esa columna no existe en la DB actual.
*/
CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetMyOrders
    @VendedorUsuarioId INT,
    @Top INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Limite INT = CASE
        WHEN @Top IS NULL OR @Top <= 0 THEN 20
        ELSE @Top
    END;

    SELECT TOP (@Limite)
        p.PedidoId,
        ISNULL(u.NombreCompleto, N'') AS Cliente,
        p.FechaPedido,
        ISNULL(p.Estado, N'') AS Estado,
        p.Total,
        CAST(N'' AS NVARCHAR(500)) AS MotivoRechazo,
        ISNULL(f.NumeroFactura, N'') AS NumeroFactura,
        p.FechaActualizacion
    FROM dbo.Pedidos AS p
    INNER JOIN dbo.Usuarios AS u
        ON u.UsuarioId = p.UsuarioId
    OUTER APPLY (
        SELECT TOP (1)
            fac.NumeroFactura
        FROM dbo.Facturas AS fac
        WHERE fac.PedidoId = p.PedidoId
        ORDER BY fac.FacturaId DESC
    ) AS f
    WHERE p.VendedorUsuarioId = @VendedorUsuarioId
    ORDER BY p.FechaPedido DESC;
END;
GO
