SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL
    THROW 54670,N'Falta el ledger de migraciones.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0013_purchasing_suppliers_orders' AND Status=N'Applied' AND LEN(FileSha256)=64)
    THROW 54671,N'0013 no figura aplicada con SHA-256 válido.',1;
IF OBJECT_ID(N'dbo.Proveedores',N'U') IS NULL OR OBJECT_ID(N'dbo.OrdenesCompra',N'U') IS NULL
   OR OBJECT_ID(N'dbo.DetalleOrdenCompra',N'U') IS NULL OR OBJECT_ID(N'dbo.ComprasRecepcionOperaciones',N'U') IS NULL
   OR OBJECT_ID(N'dbo.ComprasAuditoria',N'U') IS NULL
    THROW 54672,N'Faltan tablas del módulo de compras.',1;
IF EXISTS(SELECT 1 FROM dbo.DetalleOrdenCompra WHERE CantidadOrdenada<=0 OR CantidadRecibida<0 OR CantidadRecibida>CantidadOrdenada OR PrecioUnitario<=0)
    THROW 54673,N'Existen detalles de compra inválidos.',1;
IF EXISTS(SELECT 1 FROM dbo.DetalleOrdenCompra GROUP BY OrdenCompraId,ProductoId HAVING COUNT(*)>1)
    THROW 54674,N'Existen productos duplicados por orden.',1;
IF EXISTS(SELECT 1 FROM dbo.OrdenesCompra WHERE Estado NOT IN(N'Pendiente',N'RecibidaParcial',N'Recibida',N'CerradaConDiscrepancia',N'Cancelada'))
    THROW 54675,N'Existen estados de orden inválidos.',1;
IF OBJECT_ID(N'dbo.sp_Compras_GuardarProveedor',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Compras_CrearOrden',N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Compras_RecibirDetalle',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Compras_CerrarConDiscrepancia',N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Compras_CancelarOrden',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Compras_HistoricoPrecios',N'P') IS NULL
    THROW 54676,N'Faltan procedimientos del módulo de compras.',1;
IF (SELECT COUNT(*) FROM dbo.Permisos WHERE Codigo IN
    (N'PROVEEDORES_VER',N'PROVEEDORES_GESTIONAR',N'COMPRAS_ORDENES_VER',N'COMPRAS_ORDENES_CREAR',N'COMPRAS_ORDENES_RECIBIR',N'COMPRAS_ORDENES_CERRAR',N'COMPRAS_ORDENES_CANCELAR',N'COMPRAS_SUGERENCIAS_VER',N'COMPRAS_PRECIOS_VER') AND Activo=1)<>9
    THROW 54677,N'Faltan permisos exactos del módulo.',1;

SELECT
    (SELECT COUNT(*) FROM dbo.Proveedores) Proveedores,
    (SELECT COUNT(*) FROM dbo.OrdenesCompra) Ordenes,
    (SELECT COUNT(*) FROM dbo.DetalleOrdenCompra) Lineas,
    (SELECT COUNT(*) FROM dbo.ComprasRecepcionOperaciones) Recepciones,
    (SELECT COUNT(*) FROM dbo.ComprasAuditoria) EventosAuditoria;
