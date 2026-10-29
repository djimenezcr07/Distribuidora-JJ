SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserId INT=(SELECT TOP(1) UsuarioId FROM dbo.Usuarios ORDER BY UsuarioId);
DECLARE @ProductId INT=(SELECT TOP(1) ProductoId FROM dbo.Productos WHERE Activo=1 ORDER BY ProductoId);
DECLARE @SupplierId INT,@OrderId INT,@OrderReplayId INT;
DECLARE @OrderToken UNIQUEIDENTIFIER=NEWID(),@ReceiveToken UNIQUEIDENTIFIER=NEWID(),@CloseToken UNIQUEIDENTIFIER=NEWID();
DECLARE @Lines NVARCHAR(MAX)=CONCAT(N'[{"ProductoId":',@ProductId,N',"Cantidad":5,"PrecioUnitario":100.00}]');
DECLARE @Hash BINARY(32)=HASHBYTES('SHA2_256',N'qa-order');

EXEC dbo.sp_Compras_GuardarProveedor @ProveedorId=NULL,@Nombre=N'Proveedor funcional QA',@Activo=1,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
SELECT @SupplierId=ProveedorId FROM dbo.Proveedores WHERE NombreNormalizado=N'PROVEEDOR FUNCIONAL QA';

EXEC dbo.sp_Compras_CrearOrden @ProveedorId=@SupplierId,@TokenOperacion=@OrderToken,@SolicitudHash=@Hash,@LineasJson=@Lines,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
SELECT @OrderId=OrdenCompraId FROM dbo.OrdenesCompra WHERE TokenOperacion=@OrderToken;
EXEC dbo.sp_Compras_CrearOrden @ProveedorId=@SupplierId,@TokenOperacion=@OrderToken,@SolicitudHash=@Hash,@LineasJson=@Lines,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
SELECT @OrderReplayId=OrdenCompraId FROM dbo.OrdenesCompra WHERE TokenOperacion=@OrderToken;
IF @OrderId<>@OrderReplayId THROW 54680,N'El reintento de creación no devolvió la misma orden.',1;

DECLARE @DetailId INT=(SELECT DetalleOrdenCompraId FROM dbo.DetalleOrdenCompra WHERE OrdenCompraId=@OrderId);
DECLARE @StockBefore INT=(SELECT Stock FROM dbo.Productos WHERE ProductoId=@ProductId);
EXEC dbo.sp_Compras_RecibirDetalle @OrdenCompraId=@OrderId,@DetalleOrdenCompraId=@DetailId,@CantidadRecibidaAhora=2,@TokenOperacion=@ReceiveToken,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
EXEC dbo.sp_Compras_RecibirDetalle @OrdenCompraId=@OrderId,@DetalleOrdenCompraId=@DetailId,@CantidadRecibidaAhora=2,@TokenOperacion=@ReceiveToken,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
IF (SELECT Stock FROM dbo.Productos WHERE ProductoId=@ProductId)<>@StockBefore+2 THROW 54681,N'El reintento de recepción alteró inventario dos veces.',1;
IF (SELECT CantidadRecibida FROM dbo.DetalleOrdenCompra WHERE DetalleOrdenCompraId=@DetailId)<>2 THROW 54682,N'La recepción parcial no quedó registrada.',1;

BEGIN TRY
    DECLARE @OverflowToken UNIQUEIDENTIFIER=NEWID();
    EXEC dbo.sp_Compras_RecibirDetalle @OrdenCompraId=@OrderId,@DetalleOrdenCompraId=@DetailId,@CantidadRecibidaAhora=4,@TokenOperacion=@OverflowToken,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
    THROW 54683,N'Se permitió exceder la cantidad ordenada.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>54643 THROW; END CATCH;

EXEC dbo.sp_Compras_CerrarConDiscrepancia @OrdenCompraId=@OrderId,@Motivo=N'Proveedor entregó tres unidades menos.',@TokenOperacion=@CloseToken,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
EXEC dbo.sp_Compras_CerrarConDiscrepancia @OrdenCompraId=@OrderId,@Motivo=N'Proveedor entregó tres unidades menos.',@TokenOperacion=@CloseToken,@UsuarioId=@UserId,@UsuarioNombre=N'QA Compras';
IF (SELECT Estado FROM dbo.OrdenesCompra WHERE OrdenCompraId=@OrderId)<>N'CerradaConDiscrepancia' THROW 54684,N'No se cerró con discrepancia.',1;
IF (SELECT COUNT(*) FROM dbo.MovimientosInventario WHERE Motivo=CONCAT(N'Recepción orden #',@OrderId,N'.'))<>1 THROW 54685,N'La recepción no produjo exactamente un movimiento.',1;
IF (SELECT COUNT(*) FROM dbo.ComprasAuditoria WHERE Entidad=N'OrdenCompra' AND EntidadId=@OrderId)<3 THROW 54686,N'Falta auditoría transaccional.',1;

SELECT N'0013 functional local passed' Resultado;
