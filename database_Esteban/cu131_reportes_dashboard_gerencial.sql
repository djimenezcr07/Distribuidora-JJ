-- ============================================================
-- CU-131  —  TABLERO GERENCIAL DE INDICADORES
-- BLOQUE 4/4: STORED PROCEDURES  (reportes / dashboard)
--
--   E1 Dashboard cargado : ventas del período, stock bajo,
--                          pedidos en ruta y cobros pendientes.
--   E2 Sin datos del día : bandera HayDatos = 0 cuando el período
--                          no tiene transacciones.
--   E3 Filtrado por fecha: parámetros @Desde / @Hasta (hoy, semana, mes).
--
-- Solo lectura. No modifica el dashboard admin existente
-- (dbo.sp_Admin_DashboardSummary permanece intacto).
-- CREATE OR ALTER — idempotente.
-- Prerrequisito: cu081/cu082 aplicados (para "pedidos en ruta").
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

/* =========================================================
   1. sp_Reportes_DashboardKpis   (CU-131 E1 + E2 + E3)
      Indicadores clave para el rango [@Desde, @Hasta] (por fecha).
      - Ventas / facturas / pedidos: filtrados por período.
      - Stock bajo / pedidos en ruta / cobros pendientes: estado actual.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Reportes_DashboardKpis
    @Desde DATE = NULL,
    @Hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Rango por defecto: hoy
    IF @Desde IS NULL SET @Desde = CAST(GETDATE() AS DATE);
    IF @Hasta IS NULL SET @Hasta = CAST(GETDATE() AS DATE);

    -- Normalizar rango invertido
    IF @Desde > @Hasta
    BEGIN
        DECLARE @Tmp DATE = @Desde; SET @Desde = @Hasta; SET @Hasta = @Tmp;
    END;

    DECLARE
        @VentasPeriodo   DECIMAL(18,2),
        @FacturasPeriodo INT,
        @PedidosPeriodo  INT,
        @TicketPromedio  DECIMAL(18,2),
        @StockBajo       INT,
        @Agotados        INT,
        @PedidosEnRuta   INT,
        @CobrosPendientes DECIMAL(18,2);

    -- Ventas del período (facturas generadas)
    SELECT
        @VentasPeriodo   = ISNULL(SUM(f.Total), 0),
        @FacturasPeriodo = COUNT(*)
    FROM dbo.Facturas f
    WHERE f.Estado = N'Generada'
      AND CAST(f.FechaFactura AS DATE) BETWEEN @Desde AND @Hasta;

    -- Pedidos registrados en el período
    SELECT @PedidosPeriodo = COUNT(*)
    FROM dbo.Pedidos p
    WHERE CAST(p.FechaPedido AS DATE) BETWEEN @Desde AND @Hasta;

    SET @TicketPromedio = CASE WHEN @FacturasPeriodo > 0
                               THEN ROUND(@VentasPeriodo / @FacturasPeriodo, 2)
                               ELSE 0 END;

    -- Stock bajo / agotados (estado actual, reutiliza columna EstadoStock)
    SELECT
        @StockBajo = SUM(CASE WHEN EstadoStock = N'Bajo'    THEN 1 ELSE 0 END),
        @Agotados  = SUM(CASE WHEN EstadoStock = N'Agotado' THEN 1 ELSE 0 END)
    FROM dbo.Productos
    WHERE Activo = 1;

    -- Pedidos en ruta (estado actual de entregas)
    SET @PedidosEnRuta = (
        SELECT COUNT(*) FROM dbo.RutaPedidos rp
        WHERE rp.EstadoEntrega = N'EnRuta'
    );

    -- Cobros pendientes (suma de saldos deudores de clientes)
    SET @CobrosPendientes = (
        SELECT ISNULL(SUM(CASE WHEN saldo.SaldoActual > 0 THEN saldo.SaldoActual ELSE 0 END), 0)
        FROM (
            SELECT cc.UsuarioId,
                   ISNULL((
                       SELECT SUM(CASE cm.TipoMovimiento
                                       WHEN N'Cargo'          THEN  cm.Monto
                                       WHEN N'Abono'          THEN -cm.Monto
                                       WHEN N'AjustePositivo' THEN  cm.Monto
                                       ELSE                       -cm.Monto
                                  END)
                       FROM dbo.ClienteCreditoMovimientos cm
                       WHERE cm.UsuarioId = cc.UsuarioId
                   ), 0) AS SaldoActual
            FROM dbo.ClienteCreditos cc
        ) AS saldo
    );

    SELECT
        @Desde              AS Desde,
        @Hasta              AS Hasta,
        @VentasPeriodo      AS VentasPeriodo,
        @FacturasPeriodo    AS FacturasPeriodo,
        @PedidosPeriodo     AS PedidosPeriodo,
        @TicketPromedio     AS TicketPromedio,
        @StockBajo          AS StockBajo,
        @Agotados           AS ProductosAgotados,
        @PedidosEnRuta      AS PedidosEnRuta,
        @CobrosPendientes   AS CobrosPendientes,
        CAST(CASE WHEN (@FacturasPeriodo > 0 OR @PedidosPeriodo > 0) THEN 1 ELSE 0 END AS BIT) AS HayDatos;
END;
GO

/* =========================================================
   2. sp_Reportes_DashboardVentasSerie   (apoyo a E1/E3)
      Serie diaria de ventas facturadas dentro del rango,
      para un mini-gráfico de tendencia.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Reportes_DashboardVentasSerie
    @Desde DATE = NULL,
    @Hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Desde IS NULL SET @Desde = CAST(GETDATE() AS DATE);
    IF @Hasta IS NULL SET @Hasta = CAST(GETDATE() AS DATE);
    IF @Desde > @Hasta
    BEGIN
        DECLARE @Tmp DATE = @Desde; SET @Desde = @Hasta; SET @Hasta = @Tmp;
    END;

    SELECT
        CAST(f.FechaFactura AS DATE) AS Dia,
        SUM(f.Total)                 AS Total,
        COUNT(*)                     AS Facturas
    FROM dbo.Facturas f
    WHERE f.Estado = N'Generada'
      AND CAST(f.FechaFactura AS DATE) BETWEEN @Desde AND @Hasta
    GROUP BY CAST(f.FechaFactura AS DATE)
    ORDER BY Dia ASC;
END;
GO

PRINT 'CU-131 (SPs del tablero gerencial) aplicado correctamente.';
GO
