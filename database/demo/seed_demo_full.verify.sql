/* Read-only verification for DEMO-2026-08. */
SET NOCOUNT ON;
DECLARE @BatchCode nvarchar(30)=N'DEMO-2026-08';
DECLARE @CostaRicaToday date=DATEFROMPARTS(2026,8,12);

IF DB_NAME()<>N'DistribuidoraJJ_DB_DEV' THROW 56010,N'La verificación solo acepta DistribuidoraJJ_DB_DEV.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DemoSeedBatches WHERE BatchCode=@BatchCode) THROW 56011,N'No se encontró el lote DEMO-2026-08.',1;

SELECT EntityName,COUNT(*) AS RegistrosInsertados
FROM dbo.DemoSeedRows WHERE BatchCode=@BatchCode
GROUP BY EntityName ORDER BY EntityName;

SELECT
  VentasHistoricas=COUNT(CASE WHEN CAST(FechaPedido AS date)<@CostaRicaToday THEN 1 END),
  VentasCostaRicaHoy=COUNT(CASE WHEN CAST(FechaPedido AS date)=@CostaRicaToday THEN 1 END),
  PrimeraVenta=MIN(FechaPedido),UltimaVenta=MAX(FechaPedido),TotalVentas=SUM(Total)
FROM dbo.Pedidos WHERE Observaciones LIKE N'DEMO-2026-08:%';

SELECT CAST(FechaPedido AS date) AS Fecha,COUNT(*) AS Ventas,SUM(Total) AS Total
FROM dbo.Pedidos WHERE Observaciones LIKE N'DEMO-2026-08:%'
GROUP BY CAST(FechaPedido AS date) ORDER BY Fecha;

IF OBJECT_ID(N'dbo.PlanillaCalculos',N'U') IS NOT NULL
SELECT Estado,COUNT(*) AS CalculosQA
FROM dbo.PlanillaCalculos
WHERE IdempotencyKey IN
(
 CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001101'),
 CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001102'),
 CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001103')
)
GROUP BY Estado ORDER BY Estado;

IF (SELECT COUNT(*) FROM dbo.Pedidos WHERE Observaciones LIKE N'DEMO-2026-08:%' AND CAST(FechaPedido AS date)=@CostaRicaToday)<4
  THROW 56012,N'Faltan las cuatro ventas QA del 12 de agosto de 2026 (Costa Rica).',1;
IF EXISTS(SELECT 1 FROM dbo.Pedidos p WHERE p.Observaciones LIKE N'DEMO-2026-08:%' AND NOT EXISTS(SELECT 1 FROM dbo.PedidoDetalle d WHERE d.PedidoId=p.PedidoId))
  THROW 56013,N'Hay un pedido QA sin detalle.',1;
IF EXISTS(SELECT 1 FROM dbo.Facturas f JOIN dbo.Pedidos p ON p.PedidoId=f.PedidoId WHERE p.Observaciones LIKE N'DEMO-2026-08:%' AND NOT EXISTS(SELECT 1 FROM dbo.FacturaDetalle d WHERE d.FacturaId=f.FacturaId))
  THROW 56014,N'Hay una factura QA sin detalle.',1;
