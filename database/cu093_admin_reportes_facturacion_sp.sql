/* =========================================================
   CU-093 - Reportes agregados de facturacion administrativa

   Objetivo:
   - Asegurar procedimientos para productos mas vendidos.
   - Asegurar procedimientos para ventas mensuales.
   - Evitar calculos en memoria basados solo en facturas recientes.
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetTopSellingProducts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 10
        fd.ProductoNombre,
        SUM(fd.Cantidad) AS CantidadVendida,
        SUM(fd.Subtotal) AS MontoVendido
    FROM dbo.FacturaDetalle fd
    INNER JOIN dbo.Facturas f
        ON f.FacturaId = fd.FacturaId
    WHERE f.Estado = 'Generada'
    GROUP BY fd.ProductoNombre
    ORDER BY CantidadVendida DESC, MontoVendido DESC;
END;
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
END;
GO
