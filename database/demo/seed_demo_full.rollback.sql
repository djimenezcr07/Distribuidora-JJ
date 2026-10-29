/* Compensating rollback. It only deletes identifiers recorded for DEMO-2026-08. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @BatchCode nvarchar(30)=N'DEMO-2026-08';
IF DB_NAME()<>N'DistribuidoraJJ_DB_DEV' THROW 56020,N'El rollback solo acepta DistribuidoraJJ_DB_DEV.',1;

BEGIN TRY
 BEGIN TRANSACTION;
 /* Dependants first; every predicate is an exact seed-row identity. */
 IF OBJECT_ID(N'dbo.FacturaDetalle',N'U') IS NOT NULL DELETE x FROM dbo.FacturaDetalle x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'FacturaDetalle' AND r.EntityId=x.FacturaDetalleId;
 IF OBJECT_ID(N'dbo.Facturas',N'U') IS NOT NULL DELETE x FROM dbo.Facturas x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Facturas' AND r.EntityId=x.FacturaId;
 IF OBJECT_ID(N'dbo.PedidoDetalle',N'U') IS NOT NULL DELETE x FROM dbo.PedidoDetalle x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PedidoDetalle' AND r.EntityId=x.PedidoDetalleId;
 IF OBJECT_ID(N'dbo.Pedidos',N'U') IS NOT NULL DELETE x FROM dbo.Pedidos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Pedidos' AND r.EntityId=x.PedidoId;
 IF OBJECT_ID(N'dbo.ComboDetalle',N'U') IS NOT NULL DELETE x FROM dbo.ComboDetalle x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ComboDetalle' AND r.EntityId=x.ComboDetalleId;
 IF OBJECT_ID(N'dbo.Combos',N'U') IS NOT NULL DELETE x FROM dbo.Combos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Combos' AND r.EntityId=x.ComboId;
 IF OBJECT_ID(N'dbo.Promociones',N'U') IS NOT NULL DELETE x FROM dbo.Promociones x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Promociones' AND r.EntityId=x.PromocionId;
 IF OBJECT_ID(N'dbo.ComprasRecepcionOperaciones',N'U') IS NOT NULL DELETE x FROM dbo.ComprasRecepcionOperaciones x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ComprasRecepcionOperaciones' AND r.EntityId=x.RecepcionOperacionId;
 IF OBJECT_ID(N'dbo.DetalleOrdenCompra',N'U') IS NOT NULL DELETE x FROM dbo.DetalleOrdenCompra x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'DetalleOrdenCompra' AND r.EntityId=x.DetalleOrdenCompraId;
 IF OBJECT_ID(N'dbo.OrdenesCompra',N'U') IS NOT NULL DELETE x FROM dbo.OrdenesCompra x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'OrdenesCompra' AND r.EntityId=x.OrdenCompraId;
 IF OBJECT_ID(N'dbo.Proveedores',N'U') IS NOT NULL DELETE x FROM dbo.Proveedores x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Proveedores' AND r.EntityId=x.ProveedorId;
 IF OBJECT_ID(N'dbo.GastosOperativos',N'U') IS NOT NULL DELETE x FROM dbo.GastosOperativos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'GastosOperativos' AND r.EntityId=x.GastoId;
 IF OBJECT_ID(N'dbo.PresupuestoDetalles',N'U') IS NOT NULL DELETE d FROM dbo.PresupuestoDetalles d JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PresupuestosAnuales' AND r.EntityId=d.PresupuestoId;
 IF OBJECT_ID(N'dbo.PresupuestosAnuales',N'U') IS NOT NULL DELETE x FROM dbo.PresupuestosAnuales x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PresupuestosAnuales' AND r.EntityId=x.PresupuestoId;
 IF OBJECT_ID(N'dbo.ChatDepartamentoMensajes',N'U') IS NOT NULL DELETE x FROM dbo.ChatDepartamentoMensajes x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ChatDepartamentoMensajes' AND r.EntityId=x.MensajeId;
 IF OBJECT_ID(N'dbo.ChatMensajes',N'U') IS NOT NULL DELETE x FROM dbo.ChatMensajes x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ChatMensajes' AND r.EntityId=x.MensajeId;
 IF OBJECT_ID(N'dbo.ChatConversaciones',N'U') IS NOT NULL DELETE x FROM dbo.ChatConversaciones x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ChatConversaciones' AND r.EntityId=x.ConversacionId;
 IF OBJECT_ID(N'dbo.ChatDepartamentoMiembros',N'U') IS NOT NULL DELETE m FROM dbo.ChatDepartamentoMiembros m JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ChatDepartamentos' AND r.EntityId=m.DepartamentoId;
 IF OBJECT_ID(N'dbo.ChatDepartamentos',N'U') IS NOT NULL DELETE x FROM dbo.ChatDepartamentos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ChatDepartamentos' AND r.EntityId=x.DepartamentoId;
 IF OBJECT_ID(N'dbo.PlanillaReglas',N'U') IS NOT NULL DELETE x FROM dbo.PlanillaReglas x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PlanillaReglas' AND r.EntityId=x.ReglaId;
 IF OBJECT_ID(N'dbo.PlanillaDetalle',N'U') IS NOT NULL DELETE x FROM dbo.PlanillaDetalle x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PlanillaDetalle' AND r.EntityId=x.DetalleId;
 IF OBJECT_ID(N'dbo.PlanillaCalculos',N'U') IS NOT NULL DELETE x FROM dbo.PlanillaCalculos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PlanillaCalculos' AND r.EntityId=x.CalculoId;
 IF OBJECT_ID(N'dbo.PlanillaPeriodos',N'U') IS NOT NULL DELETE x FROM dbo.PlanillaPeriodos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'PlanillaPeriodos' AND r.EntityId=x.PeriodoId;
 IF OBJECT_ID(N'dbo.EmpleadoJornadas',N'U') IS NOT NULL DELETE x FROM dbo.EmpleadoJornadas x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'EmpleadoJornadas' AND r.EntityId=x.JornadaId;
 IF OBJECT_ID(N'dbo.EmpleadoSolicitudesTiempoLibre',N'U') IS NOT NULL DELETE x FROM dbo.EmpleadoSolicitudesTiempoLibre x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'EmpleadoSolicitudesTiempoLibre' AND r.EntityId=x.SolicitudId;
 IF OBJECT_ID(N'dbo.EmpleadoTareas',N'U') IS NOT NULL DELETE x FROM dbo.EmpleadoTareas x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'EmpleadoTareas' AND r.EntityId=x.TareaId;
 IF OBJECT_ID(N'dbo.Empleados',N'U') IS NOT NULL DELETE x FROM dbo.Empleados x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Empleados' AND r.EntityId=x.EmpleadoId;
 IF OBJECT_ID(N'dbo.ClienteCreditoMovimientos',N'U') IS NOT NULL DELETE x FROM dbo.ClienteCreditoMovimientos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ClienteCreditoMovimientos' AND r.EntityId=x.CreditoMovimientoId;
 IF OBJECT_ID(N'dbo.ClienteCreditos',N'U') IS NOT NULL DELETE x FROM dbo.ClienteCreditos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'ClienteCreditos' AND r.EntityId=x.ClienteCreditoId;
 IF OBJECT_ID(N'dbo.MovimientosInventario',N'U') IS NOT NULL DELETE x FROM dbo.MovimientosInventario x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'MovimientosInventario' AND r.EntityId=x.MovimientoId;
 IF OBJECT_ID(N'dbo.Productos',N'U') IS NOT NULL DELETE x FROM dbo.Productos x JOIN dbo.DemoSeedRows r ON r.BatchCode=@BatchCode AND r.EntityName=N'Productos' AND r.EntityId=x.ProductoId;
 DELETE FROM dbo.DemoSeedRows WHERE BatchCode=@BatchCode;
 DELETE FROM dbo.DemoSeedBatches WHERE BatchCode=@BatchCode;
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
