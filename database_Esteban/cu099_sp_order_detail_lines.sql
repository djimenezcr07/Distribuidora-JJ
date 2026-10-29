-- ============================================================
-- CU-099: sp_Admin_GetOrderDetailLines
-- Devuelve las líneas de detalle de un pedido con stock actual.
-- Separado de sp_Admin_GetOrderHeader (que ya solo devuelve cabecera).
-- Prerequisito: cu098 aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderDetailLines
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pd.PedidoDetalleId,         -- 0  Int
        pr.Nombre   AS Producto,    -- 1  String
        pd.ProductoId,              -- 2  Int
        pd.Cantidad,                -- 3  Int
        pd.PrecioUnitario,          -- 4  Decimal
        pd.Subtotal,                -- 5  Decimal (columna computada)
        pr.Stock    AS StockActual  -- 6  Int
    FROM dbo.PedidoDetalle pd
    INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
    WHERE pd.PedidoId = @PedidoId
    ORDER BY pr.Nombre;
END;
GO

PRINT 'CU-099 aplicado: sp_Admin_GetOrderDetailLines creado.';
GO
