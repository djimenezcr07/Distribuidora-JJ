SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

/*
  Sprint 4 CU-181, CU-182, CU-241, CU-242 y CU-243.
  Cambios aditivos: combos, snapshots de pedido/factura, checkout idempotente,
  transformación atómica e inteligencia basada en pedidos reales.

  Ejecución: usar sqlcmd -b contra la base seleccionada explícitamente. No incluye USE.
  Rollback: no eliminar datos. Retirar primero la aplicación y preparar una migración
  compensatoria; restaurar un BACPAC verificado es el último recurso.
*/

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 54500, N'Falta dbo.SchemaMigrationHistory. Aplique primero la migración 0001.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0012_inventory_combos_transformations_intelligence'
      AND Status = N'Applied'
)
    THROW 54501, N'La migración 0012 ya figura como aplicada. No debe repetirse en este ambiente.', 1;

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Pedidos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PedidoDetalle', N'U') IS NULL
   OR OBJECT_ID(N'dbo.MovimientosInventario', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Facturas', N'U') IS NULL
   OR OBJECT_ID(N'dbo.FacturaDetalle', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Permisos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Perfiles', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Promociones', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PromocionAplicaciones', N'U') IS NULL
    THROW 54502, N'El esquema base no contiene las dependencias de inventario, pedidos, facturación, permisos y promociones.', 1;

IF COL_LENGTH(N'dbo.Productos', N'StockMinimo') IS NULL
   OR COL_LENGTH(N'dbo.Productos', N'FechaCreacion') IS NULL
   OR COL_LENGTH(N'dbo.Pedidos', N'InventarioDescontado') IS NULL
   OR COL_LENGTH(N'dbo.Pedidos', N'MetodoPago') IS NULL
   OR COL_LENGTH(N'dbo.Pedidos', N'EstadoPago') IS NULL
   OR COL_LENGTH(N'dbo.Pedidos', N'FechaActualizacion') IS NULL
   OR COL_LENGTH(N'dbo.Usuarios', N'SegmentoCliente') IS NULL
   OR COL_LENGTH(N'dbo.Promociones', N'Prioridad') IS NULL
    THROW 54503, N'El esquema base es incompatible: faltan columnas requeridas de productos o pedidos.', 1;

BEGIN TRANSACTION;
GO

IF OBJECT_ID(N'dbo.Combos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Combos
    (
        ComboId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Combos PRIMARY KEY,
        Nombre NVARCHAR(150) NOT NULL,
        Descripcion NVARCHAR(500) NULL,
        Precio DECIMAL(18,2) NOT NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Combos_Activo DEFAULT (1),
        RegistradoPorUsuarioId INT NOT NULL,
        RegistradoPorNombre NVARCHAR(150) NOT NULL,
        FechaCreacionUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Combos_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        ActualizadoPorUsuarioId INT NOT NULL,
        ActualizadoPorNombre NVARCHAR(150) NOT NULL,
        FechaActualizacionUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Combos_FechaActualizacionUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_Combos_Precio CHECK (Precio > 0),
        CONSTRAINT FK_Combos_RegistradoPor FOREIGN KEY (RegistradoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_Combos_ActualizadoPor FOREIGN KEY (ActualizadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;

IF COL_LENGTH(N'dbo.Combos', N'FechaCreacionUtc') IS NULL
   AND COL_LENGTH(N'dbo.Combos', N'FechaCreacion') IS NOT NULL
BEGIN
    EXEC sys.sp_rename N'dbo.Combos.FechaCreacion', N'FechaCreacionUtc', N'COLUMN';
END;

IF COL_LENGTH(N'dbo.Combos', N'ActualizadoPorUsuarioId') IS NULL
    ALTER TABLE dbo.Combos ADD ActualizadoPorUsuarioId INT NULL;
IF COL_LENGTH(N'dbo.Combos', N'ActualizadoPorNombre') IS NULL
    ALTER TABLE dbo.Combos ADD ActualizadoPorNombre NVARCHAR(150) NULL;
IF COL_LENGTH(N'dbo.Combos', N'FechaActualizacionUtc') IS NULL
    ALTER TABLE dbo.Combos ADD FechaActualizacionUtc DATETIME2(7) NULL;

IF OBJECT_ID(N'dbo.ComboDetalle', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ComboDetalle
    (
        ComboDetalleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComboDetalle PRIMARY KEY,
        ComboId INT NOT NULL,
        ProductoId INT NOT NULL,
        Cantidad INT NOT NULL,
        CONSTRAINT UQ_ComboDetalle_ComboProducto UNIQUE (ComboId, ProductoId),
        CONSTRAINT CK_ComboDetalle_Cantidad CHECK (Cantidad > 0),
        CONSTRAINT FK_ComboDetalle_Combo FOREIGN KEY (ComboId) REFERENCES dbo.Combos(ComboId),
        CONSTRAINT FK_ComboDetalle_Producto FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId)
    );
END;

IF OBJECT_ID(N'dbo.PedidoCombos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PedidoCombos
    (
        PedidoComboId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PedidoCombos PRIMARY KEY,
        PedidoId INT NOT NULL,
        ComboId INT NOT NULL,
        ComboNombreSnapshot NVARCHAR(150) NOT NULL,
        ComboDescripcionSnapshot NVARCHAR(500) NULL,
        Cantidad INT NOT NULL,
        PrecioUnitario DECIMAL(18,2) NOT NULL,
        Subtotal AS CONVERT(DECIMAL(18,2), Cantidad * PrecioUnitario) PERSISTED,
        FechaCreacionUtc DATETIME2(7) NOT NULL CONSTRAINT DF_PedidoCombos_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_PedidoCombos_Cantidad CHECK (Cantidad > 0),
        CONSTRAINT CK_PedidoCombos_Precio CHECK (PrecioUnitario > 0),
        CONSTRAINT FK_PedidoCombos_Pedido FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos(PedidoId),
        CONSTRAINT FK_PedidoCombos_Combo FOREIGN KEY (ComboId) REFERENCES dbo.Combos(ComboId)
    );
END;

IF COL_LENGTH(N'dbo.PedidoCombos', N'ComboNombreSnapshot') IS NULL
   AND COL_LENGTH(N'dbo.PedidoCombos', N'ComboNombre') IS NOT NULL
BEGIN
    EXEC sys.sp_rename N'dbo.PedidoCombos.ComboNombre', N'ComboNombreSnapshot', N'COLUMN';
END;

IF COL_LENGTH(N'dbo.PedidoCombos', N'ComboDescripcionSnapshot') IS NULL
    ALTER TABLE dbo.PedidoCombos ADD ComboDescripcionSnapshot NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.PedidoCombos', N'FechaCreacionUtc') IS NULL
    ALTER TABLE dbo.PedidoCombos ADD FechaCreacionUtc DATETIME2(7) NULL;

IF OBJECT_ID(N'dbo.PedidoComboDetalle', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PedidoComboDetalle
    (
        PedidoComboDetalleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PedidoComboDetalle PRIMARY KEY,
        PedidoComboId INT NOT NULL,
        ProductoId INT NOT NULL,
        ProductoNombreSnapshot NVARCHAR(150) NOT NULL,
        CantidadPorCombo INT NOT NULL,
        CantidadTotal INT NOT NULL,
        CONSTRAINT UQ_PedidoComboDetalle_ComboProducto UNIQUE (PedidoComboId, ProductoId),
        CONSTRAINT CK_PedidoComboDetalle_Cantidades CHECK (CantidadPorCombo > 0 AND CantidadTotal > 0),
        CONSTRAINT FK_PedidoComboDetalle_PedidoCombo FOREIGN KEY (PedidoComboId) REFERENCES dbo.PedidoCombos(PedidoComboId),
        CONSTRAINT FK_PedidoComboDetalle_Producto FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId)
    );
END;

IF OBJECT_ID(N'dbo.FacturaCombos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FacturaCombos
    (
        FacturaComboId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FacturaCombos PRIMARY KEY,
        FacturaId INT NOT NULL,
        PedidoComboId INT NOT NULL,
        ComboNombreSnapshot NVARCHAR(150) NOT NULL,
        Cantidad INT NOT NULL,
        PrecioUnitario DECIMAL(18,2) NOT NULL,
        Subtotal AS CONVERT(DECIMAL(18,2), Cantidad * PrecioUnitario) PERSISTED,
        CONSTRAINT UQ_FacturaCombos_PedidoCombo UNIQUE (FacturaId, PedidoComboId),
        CONSTRAINT CK_FacturaCombos_Cantidad CHECK (Cantidad > 0),
        CONSTRAINT CK_FacturaCombos_Precio CHECK (PrecioUnitario > 0),
        CONSTRAINT FK_FacturaCombos_Factura FOREIGN KEY (FacturaId) REFERENCES dbo.Facturas(FacturaId),
        CONSTRAINT FK_FacturaCombos_PedidoCombo FOREIGN KEY (PedidoComboId) REFERENCES dbo.PedidoCombos(PedidoComboId)
    );
END;

IF OBJECT_ID(N'dbo.CheckoutOperaciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CheckoutOperaciones
    (
        CheckoutOperacionId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CheckoutOperaciones PRIMARY KEY,
        UsuarioId INT NOT NULL,
        TokenOperacion UNIQUEIDENTIFIER NOT NULL,
        SolicitudHash BINARY(32) NOT NULL,
        PedidoId INT NOT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_CheckoutOperaciones_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_CheckoutOperaciones_UsuarioToken UNIQUE (UsuarioId, TokenOperacion),
        CONSTRAINT FK_CheckoutOperaciones_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_CheckoutOperaciones_Pedido FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos(PedidoId)
    );
END;

IF OBJECT_ID(N'dbo.InventarioTransformaciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InventarioTransformaciones
    (
        InventarioTransformacionId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventarioTransformaciones PRIMARY KEY,
        ReferenciaTransformacion UNIQUEIDENTIFIER NOT NULL CONSTRAINT UQ_InventarioTransformaciones_Referencia UNIQUE,
        ProductoOrigenId INT NOT NULL,
        CantidadOrigen INT NOT NULL,
        ProductoDestinoId INT NOT NULL,
        CantidadDestino INT NOT NULL,
        UsuarioId INT NOT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        Motivo NVARCHAR(300) NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_InventarioTransformaciones_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_InventarioTransformaciones_Productos CHECK (ProductoOrigenId <> ProductoDestinoId),
        CONSTRAINT CK_InventarioTransformaciones_Cantidades CHECK (CantidadOrigen > 0 AND CantidadDestino > 0),
        CONSTRAINT FK_InventarioTransformaciones_Origen FOREIGN KEY (ProductoOrigenId) REFERENCES dbo.Productos(ProductoId),
        CONSTRAINT FK_InventarioTransformaciones_Destino FOREIGN KEY (ProductoDestinoId) REFERENCES dbo.Productos(ProductoId),
        CONSTRAINT FK_InventarioTransformaciones_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;

IF OBJECT_ID(N'dbo.InventarioOperacionAuditoria', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InventarioOperacionAuditoria
    (
        AuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventarioOperacionAuditoria PRIMARY KEY,
        Modulo NVARCHAR(50) NOT NULL,
        EntidadId INT NULL,
        Accion NVARCHAR(50) NOT NULL,
        UsuarioId INT NOT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        Detalle NVARCHAR(500) NOT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_InventarioOperacionAuditoria_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_InventarioOperacionAuditoria_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;

IF COL_LENGTH(N'dbo.PedidoDetalle', N'PedidoComboId') IS NULL
BEGIN
    ALTER TABLE dbo.PedidoDetalle
    ADD PedidoComboId INT NULL;
END;

IF COL_LENGTH(N'dbo.PedidoDetalle', N'ProductoNombreSnapshot') IS NULL
BEGIN
    ALTER TABLE dbo.PedidoDetalle
    ADD ProductoNombreSnapshot NVARCHAR(150) NULL;
END;
GO

IF COL_LENGTH(N'dbo.Combos', N'ComboId') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'Nombre') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'Descripcion') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'Precio') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'Activo') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'RegistradoPorUsuarioId') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'RegistradoPorNombre') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'FechaCreacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'ActualizadoPorUsuarioId') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'ActualizadoPorNombre') IS NULL
   OR COL_LENGTH(N'dbo.Combos', N'FechaActualizacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.ComboDetalle', N'ComboDetalleId') IS NULL
   OR COL_LENGTH(N'dbo.ComboDetalle', N'ComboId') IS NULL
   OR COL_LENGTH(N'dbo.ComboDetalle', N'ProductoId') IS NULL
   OR COL_LENGTH(N'dbo.ComboDetalle', N'Cantidad') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'PedidoComboId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'PedidoId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'ComboId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'ComboNombreSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'ComboDescripcionSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'Cantidad') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'PrecioUnitario') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'FechaCreacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.PedidoDetalle', N'PedidoComboId') IS NULL
    THROW 54504, N'Existe un objeto parcial o incompatible de la migración 0012.', 1;
GO

/*
  Reconciliación del esquema legado de combos. Cada validación precede a la
  restricción correspondiente; los datos ambiguos provocan THROW y rollback.
*/
UPDATE dbo.Combos
SET ActualizadoPorUsuarioId = RegistradoPorUsuarioId
WHERE ActualizadoPorUsuarioId IS NULL;

UPDATE dbo.Combos
SET ActualizadoPorNombre = RegistradoPorNombre
WHERE ActualizadoPorNombre IS NULL;

UPDATE dbo.Combos
SET FechaActualizacionUtc = FechaCreacionUtc
WHERE FechaActualizacionUtc IS NULL;

ALTER TABLE dbo.Combos ALTER COLUMN Descripcion NVARCHAR(500) NULL;

IF EXISTS
(
    SELECT 1
    FROM dbo.Combos combo
    LEFT JOIN dbo.Usuarios registeredUser
        ON registeredUser.UsuarioId = combo.RegistradoPorUsuarioId
    LEFT JOIN dbo.Usuarios updatedUser
        ON updatedUser.UsuarioId = combo.ActualizadoPorUsuarioId
    WHERE combo.Precio <= 0
       OR combo.Nombre IS NULL
       OR combo.RegistradoPorNombre IS NULL
       OR combo.FechaCreacionUtc IS NULL
       OR combo.ActualizadoPorUsuarioId IS NULL
       OR combo.ActualizadoPorNombre IS NULL
       OR combo.FechaActualizacionUtc IS NULL
       OR registeredUser.UsuarioId IS NULL
       OR updatedUser.UsuarioId IS NULL
)
    THROW 54505, N'Los combos legados contienen datos inválidos o referencias huérfanas.', 1;

ALTER TABLE dbo.Combos ALTER COLUMN ActualizadoPorUsuarioId INT NOT NULL;
ALTER TABLE dbo.Combos ALTER COLUMN ActualizadoPorNombre NVARCHAR(150) NOT NULL;
ALTER TABLE dbo.Combos ALTER COLUMN FechaActualizacionUtc DATETIME2(7) NOT NULL;

DECLARE @DefaultConstraint SYSNAME;
DECLARE @DropDefaultSql NVARCHAR(776);
IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND name = N'DF_Combos_Activo'
)
BEGIN
    SELECT @DefaultConstraint = constraintObject.name
    FROM sys.default_constraints constraintObject
    INNER JOIN sys.columns columnObject
        ON columnObject.object_id = constraintObject.parent_object_id
       AND columnObject.column_id = constraintObject.parent_column_id
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND columnObject.name = N'Activo';

    IF @DefaultConstraint IS NOT NULL
    BEGIN
        SET @DropDefaultSql =
            N'ALTER TABLE dbo.Combos DROP CONSTRAINT ' + QUOTENAME(@DefaultConstraint) + N';';
        EXEC sys.sp_executesql @DropDefaultSql;
    END;

    ALTER TABLE dbo.Combos
    ADD CONSTRAINT DF_Combos_Activo DEFAULT (1) FOR Activo;
END;

SET @DefaultConstraint = NULL;
IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND name = N'DF_Combos_FechaCreacionUtc'
)
BEGIN
    SELECT @DefaultConstraint = constraintObject.name
    FROM sys.default_constraints constraintObject
    INNER JOIN sys.columns columnObject
        ON columnObject.object_id = constraintObject.parent_object_id
       AND columnObject.column_id = constraintObject.parent_column_id
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND columnObject.name = N'FechaCreacionUtc';

    IF @DefaultConstraint IS NOT NULL
    BEGIN
        SET @DropDefaultSql =
            N'ALTER TABLE dbo.Combos DROP CONSTRAINT ' + QUOTENAME(@DefaultConstraint) + N';';
        EXEC sys.sp_executesql @DropDefaultSql;
    END;

    ALTER TABLE dbo.Combos
    ADD CONSTRAINT DF_Combos_FechaCreacionUtc DEFAULT SYSUTCDATETIME() FOR FechaCreacionUtc;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND name = N'DF_Combos_FechaActualizacionUtc'
)
BEGIN
    ALTER TABLE dbo.Combos
    ADD CONSTRAINT DF_Combos_FechaActualizacionUtc DEFAULT SYSUTCDATETIME() FOR FechaActualizacionUtc;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND name = N'CK_Combos_Precio'
)
BEGIN
    ALTER TABLE dbo.Combos WITH CHECK
    ADD CONSTRAINT CK_Combos_Precio CHECK (Precio > 0);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.Combos'), N'RegistradoPorUsuarioId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Usuarios')
      AND foreignKeyColumn.referenced_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.Usuarios'), N'UsuarioId', N'ColumnId')
)
BEGIN
    ALTER TABLE dbo.Combos WITH CHECK
    ADD CONSTRAINT FK_Combos_RegistradoPor
        FOREIGN KEY (RegistradoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.Combos')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.Combos'), N'ActualizadoPorUsuarioId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Usuarios')
      AND foreignKeyColumn.referenced_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.Usuarios'), N'UsuarioId', N'ColumnId')
)
BEGIN
    ALTER TABLE dbo.Combos WITH CHECK
    ADD CONSTRAINT FK_Combos_ActualizadoPor
        FOREIGN KEY (ActualizadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId);
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.ComboDetalle detail
    LEFT JOIN dbo.Combos combo ON combo.ComboId = detail.ComboId
    LEFT JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
    WHERE detail.Cantidad <= 0
       OR combo.ComboId IS NULL
       OR product.ProductoId IS NULL
)
    THROW 54506, N'ComboDetalle contiene cantidades inválidas o referencias huérfanas.', 1;

IF EXISTS
(
    SELECT ComboId, ProductoId
    FROM dbo.ComboDetalle
    GROUP BY ComboId, ProductoId
    HAVING COUNT(*) > 1
)
    THROW 54507, N'ComboDetalle contiene productos duplicados dentro de un combo.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ComboDetalle')
      AND name = N'UQ_ComboDetalle_ComboProducto'
)
BEGIN
    ALTER TABLE dbo.ComboDetalle
    ADD CONSTRAINT UQ_ComboDetalle_ComboProducto UNIQUE (ComboId, ProductoId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.ComboDetalle')
      AND name = N'CK_ComboDetalle_Cantidad'
)
BEGIN
    ALTER TABLE dbo.ComboDetalle WITH CHECK
    ADD CONSTRAINT CK_ComboDetalle_Cantidad CHECK (Cantidad > 0);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.ComboDetalle')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.ComboDetalle'), N'ComboId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Combos')
)
BEGIN
    ALTER TABLE dbo.ComboDetalle WITH CHECK
    ADD CONSTRAINT FK_ComboDetalle_Combo
        FOREIGN KEY (ComboId) REFERENCES dbo.Combos(ComboId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.ComboDetalle')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.ComboDetalle'), N'ProductoId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Productos')
)
BEGIN
    ALTER TABLE dbo.ComboDetalle WITH CHECK
    ADD CONSTRAINT FK_ComboDetalle_Producto
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId);
END;
GO

IF COL_LENGTH(N'dbo.PedidoCombos', N'ComboNombre') IS NOT NULL
BEGIN
    EXEC
    (
        N'IF EXISTS
          (
              SELECT 1
              FROM dbo.PedidoCombos
              WHERE ComboNombreSnapshot IS NOT NULL
                AND ComboNombre IS NOT NULL
                AND ComboNombreSnapshot <> ComboNombre
          )
              THROW 54508, N''PedidoCombos contiene nombres legado y canónico contradictorios.'', 1;

          UPDATE dbo.PedidoCombos
          SET ComboNombreSnapshot = ComboNombre
          WHERE ComboNombreSnapshot IS NULL;

          ALTER TABLE dbo.PedidoCombos
          ALTER COLUMN ComboNombre NVARCHAR(150) NULL;'
    );
END;

UPDATE comboOrder
SET ComboDescripcionSnapshot = combo.Descripcion
FROM dbo.PedidoCombos comboOrder
INNER JOIN dbo.Combos combo ON combo.ComboId = comboOrder.ComboId
WHERE comboOrder.ComboDescripcionSnapshot IS NULL;

UPDATE comboOrder
SET FechaCreacionUtc = orders.FechaPedido
FROM dbo.PedidoCombos comboOrder
INNER JOIN dbo.Pedidos orders ON orders.PedidoId = comboOrder.PedidoId
WHERE comboOrder.FechaCreacionUtc IS NULL;

IF EXISTS
(
    SELECT 1
    FROM dbo.PedidoCombos comboOrder
    LEFT JOIN dbo.Pedidos orders ON orders.PedidoId = comboOrder.PedidoId
    LEFT JOIN dbo.Combos combo ON combo.ComboId = comboOrder.ComboId
    WHERE comboOrder.ComboNombreSnapshot IS NULL
       OR comboOrder.Cantidad <= 0
       OR comboOrder.PrecioUnitario <= 0
       OR comboOrder.FechaCreacionUtc IS NULL
       OR orders.PedidoId IS NULL
       OR combo.ComboId IS NULL
)
    THROW 54509, N'PedidoCombos contiene datos inválidos o referencias huérfanas.', 1;

ALTER TABLE dbo.PedidoCombos ALTER COLUMN ComboNombreSnapshot NVARCHAR(150) NOT NULL;
ALTER TABLE dbo.PedidoCombos ALTER COLUMN FechaCreacionUtc DATETIME2(7) NOT NULL;

IF COL_LENGTH(N'dbo.PedidoCombos', N'Subtotal') IS NULL
BEGIN
    ALTER TABLE dbo.PedidoCombos
    ADD Subtotal AS CONVERT(DECIMAL(18,2), Cantidad * PrecioUnitario) PERSISTED;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND name = N'DF_PedidoCombos_FechaCreacionUtc'
)
BEGIN
    ALTER TABLE dbo.PedidoCombos
    ADD CONSTRAINT DF_PedidoCombos_FechaCreacionUtc DEFAULT SYSUTCDATETIME() FOR FechaCreacionUtc;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND name = N'CK_PedidoCombos_Cantidad'
)
BEGIN
    ALTER TABLE dbo.PedidoCombos WITH CHECK
    ADD CONSTRAINT CK_PedidoCombos_Cantidad CHECK (Cantidad > 0);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND name = N'CK_PedidoCombos_Precio'
)
BEGIN
    ALTER TABLE dbo.PedidoCombos WITH CHECK
    ADD CONSTRAINT CK_PedidoCombos_Precio CHECK (PrecioUnitario > 0);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoCombos'), N'PedidoId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Pedidos')
)
BEGIN
    ALTER TABLE dbo.PedidoCombos WITH CHECK
    ADD CONSTRAINT FK_PedidoCombos_Pedido
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos(PedidoId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoCombos'), N'ComboId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Combos')
)
BEGIN
    ALTER TABLE dbo.PedidoCombos WITH CHECK
    ADD CONSTRAINT FK_PedidoCombos_Combo
        FOREIGN KEY (ComboId) REFERENCES dbo.Combos(ComboId);
END;
GO

UPDATE detail
SET ProductoNombreSnapshot = product.Nombre
FROM dbo.PedidoDetalle detail
INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
WHERE detail.ProductoNombreSnapshot IS NULL;

IF COL_LENGTH(N'dbo.PedidoDetalle', N'EsRegalo') IS NULL
BEGIN
    ALTER TABLE dbo.PedidoDetalle
    ADD EsRegalo BIT NOT NULL
        CONSTRAINT DF_PedidoDetalle_EsRegalo DEFAULT (0) WITH VALUES;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.PedidoDetalle')
      AND name = N'PedidoComboId'
      AND is_nullable = 0
)
BEGIN
    ALTER TABLE dbo.PedidoDetalle
    ALTER COLUMN PedidoComboId INT NULL;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.PedidoDetalle detail
    LEFT JOIN dbo.PedidoCombos comboOrder ON comboOrder.PedidoComboId = detail.PedidoComboId
    WHERE detail.PedidoComboId IS NOT NULL
      AND (comboOrder.PedidoComboId IS NULL OR comboOrder.PedidoId <> detail.PedidoId)
)
    THROW 54517, N'PedidoDetalle contiene una relación de combo huérfana o asociada a otro pedido.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.PedidoDetalle')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoDetalle'), N'PedidoComboId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND foreignKeyColumn.referenced_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoCombos'), N'PedidoComboId', N'ColumnId')
)
BEGIN
    ALTER TABLE dbo.PedidoDetalle WITH CHECK
    ADD CONSTRAINT FK_PedidoDetalle_PedidoCombo
        FOREIGN KEY (PedidoComboId) REFERENCES dbo.PedidoCombos(PedidoComboId);
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.PedidoDetalle detail
    WHERE detail.PedidoComboId IS NOT NULL
      AND detail.Cantidad <= 0
)
    THROW 54518, N'Los componentes históricos de combo contienen cantidades no positivas.', 1;

IF EXISTS
(
    SELECT detail.PedidoComboId, detail.ProductoId
    FROM dbo.PedidoDetalle detail
    WHERE detail.PedidoComboId IS NOT NULL
    GROUP BY detail.PedidoComboId, detail.ProductoId
    HAVING COUNT(DISTINCT NULLIF(LTRIM(RTRIM(detail.ProductoNombreSnapshot)), N'')) > 1
)
    THROW 54519, N'Los componentes históricos de combo contienen snapshots de producto contradictorios.', 1;

IF EXISTS
(
    SELECT detail.PedidoComboId, detail.ProductoId
    FROM dbo.PedidoDetalle detail
    INNER JOIN dbo.PedidoCombos comboOrder
        ON comboOrder.PedidoComboId = detail.PedidoComboId
    WHERE detail.PedidoComboId IS NOT NULL
    GROUP BY detail.PedidoComboId, detail.ProductoId, comboOrder.Cantidad
    HAVING SUM(CONVERT(BIGINT, detail.Cantidad)) % comboOrder.Cantidad <> 0
        OR SUM(CONVERT(BIGINT, detail.Cantidad)) / comboOrder.Cantidad <= 0
        OR SUM(CONVERT(BIGINT, detail.Cantidad)) > 2147483647
)
    THROW 54524, N'No es posible reconstruir cantidades enteras de los componentes históricos de combo.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.PedidoCombos comboOrder
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM dbo.PedidoComboDetalle component
              WHERE component.PedidoComboId = comboOrder.PedidoComboId
          )
      AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.PedidoDetalle detail
              WHERE detail.PedidoComboId = comboOrder.PedidoComboId
          )
)
    THROW 54525, N'Existe un PedidoCombo sin componentes canónicos ni detalle histórico reconstruible.', 1;

IF EXISTS
(
    SELECT component.PedidoComboId, component.ProductoId
    FROM dbo.PedidoComboDetalle component
    GROUP BY component.PedidoComboId, component.ProductoId
    HAVING COUNT(*) > 1
)
    THROW 54526, N'PedidoComboDetalle contiene componentes duplicados.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.PedidoComboDetalle component
    LEFT JOIN dbo.PedidoCombos comboOrder ON comboOrder.PedidoComboId = component.PedidoComboId
    LEFT JOIN dbo.Productos product ON product.ProductoId = component.ProductoId
    WHERE component.CantidadPorCombo <= 0
       OR component.CantidadTotal <= 0
       OR component.ProductoNombreSnapshot IS NULL
       OR comboOrder.PedidoComboId IS NULL
       OR product.ProductoId IS NULL
       OR CONVERT(BIGINT, component.CantidadPorCombo) * comboOrder.Cantidad <> component.CantidadTotal
)
    THROW 54527, N'PedidoComboDetalle contiene datos incompatibles con el pedido de combo.', 1;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT detail.PedidoComboId,
               detail.ProductoId,
               COALESCE
               (
                   MAX(NULLIF(LTRIM(RTRIM(detail.ProductoNombreSnapshot)), N'')),
                   MAX(product.Nombre)
               ) AS ProductoNombreSnapshot,
               CONVERT(INT, SUM(CONVERT(BIGINT, detail.Cantidad)) / comboOrder.Cantidad) AS CantidadPorCombo,
               CONVERT(INT, SUM(CONVERT(BIGINT, detail.Cantidad))) AS CantidadTotal
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.PedidoCombos comboOrder
            ON comboOrder.PedidoComboId = detail.PedidoComboId
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoComboId IS NOT NULL
        GROUP BY detail.PedidoComboId, detail.ProductoId, comboOrder.Cantidad
    ) derived
    INNER JOIN dbo.PedidoComboDetalle component
        ON component.PedidoComboId = derived.PedidoComboId
       AND component.ProductoId = derived.ProductoId
    WHERE component.CantidadPorCombo <> derived.CantidadPorCombo
       OR component.CantidadTotal <> derived.CantidadTotal
       OR component.ProductoNombreSnapshot <> derived.ProductoNombreSnapshot
)
    THROW 54528, N'PedidoComboDetalle contradice el detalle histórico disponible.', 1;

;WITH DerivedComponents AS
(
    SELECT detail.PedidoComboId,
           detail.ProductoId,
           COALESCE
           (
               MAX(NULLIF(LTRIM(RTRIM(detail.ProductoNombreSnapshot)), N'')),
               MAX(product.Nombre)
           ) AS ProductoNombreSnapshot,
           CONVERT(INT, SUM(CONVERT(BIGINT, detail.Cantidad)) / comboOrder.Cantidad) AS CantidadPorCombo,
           CONVERT(INT, SUM(CONVERT(BIGINT, detail.Cantidad))) AS CantidadTotal
    FROM dbo.PedidoDetalle detail
    INNER JOIN dbo.PedidoCombos comboOrder
        ON comboOrder.PedidoComboId = detail.PedidoComboId
    INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
    WHERE detail.PedidoComboId IS NOT NULL
    GROUP BY detail.PedidoComboId, detail.ProductoId, comboOrder.Cantidad
)
INSERT INTO dbo.PedidoComboDetalle
    (PedidoComboId, ProductoId, ProductoNombreSnapshot, CantidadPorCombo, CantidadTotal)
SELECT derived.PedidoComboId,
       derived.ProductoId,
       derived.ProductoNombreSnapshot,
       derived.CantidadPorCombo,
       derived.CantidadTotal
FROM DerivedComponents derived
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.PedidoComboDetalle component
    WHERE component.PedidoComboId = derived.PedidoComboId
      AND component.ProductoId = derived.ProductoId
);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PedidoComboDetalle')
      AND name = N'UQ_PedidoComboDetalle_ComboProducto'
)
BEGIN
    ALTER TABLE dbo.PedidoComboDetalle
    ADD CONSTRAINT UQ_PedidoComboDetalle_ComboProducto UNIQUE (PedidoComboId, ProductoId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.PedidoComboDetalle')
      AND name = N'CK_PedidoComboDetalle_Cantidades'
)
BEGIN
    ALTER TABLE dbo.PedidoComboDetalle WITH CHECK
    ADD CONSTRAINT CK_PedidoComboDetalle_Cantidades
        CHECK (CantidadPorCombo > 0 AND CantidadTotal > 0);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.PedidoComboDetalle')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoComboDetalle'), N'PedidoComboId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.PedidoCombos')
)
BEGIN
    ALTER TABLE dbo.PedidoComboDetalle WITH CHECK
    ADD CONSTRAINT FK_PedidoComboDetalle_PedidoCombo
        FOREIGN KEY (PedidoComboId) REFERENCES dbo.PedidoCombos(PedidoComboId);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_key_columns foreignKeyColumn
    WHERE foreignKeyColumn.parent_object_id = OBJECT_ID(N'dbo.PedidoComboDetalle')
      AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
          (OBJECT_ID(N'dbo.PedidoComboDetalle'), N'ProductoId', N'ColumnId')
      AND foreignKeyColumn.referenced_object_id = OBJECT_ID(N'dbo.Productos')
)
BEGIN
    ALTER TABLE dbo.PedidoComboDetalle WITH CHECK
    ADD CONSTRAINT FK_PedidoComboDetalle_Producto
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId);
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.FacturaCombos invoiceCombo
    LEFT JOIN dbo.Facturas invoice ON invoice.FacturaId = invoiceCombo.FacturaId
    LEFT JOIN dbo.PedidoCombos comboOrder ON comboOrder.PedidoComboId = invoiceCombo.PedidoComboId
    WHERE invoiceCombo.Cantidad <= 0
       OR invoiceCombo.PrecioUnitario <= 0
       OR invoiceCombo.ComboNombreSnapshot IS NULL
       OR invoice.FacturaId IS NULL
       OR comboOrder.PedidoComboId IS NULL
       OR invoice.PedidoId <> comboOrder.PedidoId
)
    THROW 54529, N'FacturaCombos contiene datos inválidos o referencias incompatibles.', 1;

IF COL_LENGTH(N'dbo.Combos', N'FechaActualizacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.ComboDetalle', N'Cantidad') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'ComboNombreSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'ComboDescripcionSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'Subtotal') IS NULL
   OR COL_LENGTH(N'dbo.PedidoCombos', N'FechaCreacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.PedidoComboDetalle', N'CantidadTotal') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'PedidoComboId') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'SolicitudHash') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'ReferenciaTransformacion') IS NULL
   OR COL_LENGTH(N'dbo.PedidoDetalle', N'ProductoNombreSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoDetalle', N'EsRegalo') IS NULL
   OR COL_LENGTH(N'dbo.PedidoDetalle', N'PedidoComboId') IS NULL
    THROW 54504, N'Existe un objeto parcial o incompatible de la migración 0012.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Combos') AND name = N'IX_Combos_Activo_Nombre')
    CREATE INDEX IX_Combos_Activo_Nombre ON dbo.Combos(Activo, Nombre) INCLUDE (Precio, Descripcion);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ComboDetalle') AND name = N'IX_ComboDetalle_ProductoId')
    CREATE INDEX IX_ComboDetalle_ProductoId ON dbo.ComboDetalle(ProductoId, ComboId) INCLUDE (Cantidad);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PedidoCombos') AND name = N'IX_PedidoCombos_PedidoId')
    CREATE INDEX IX_PedidoCombos_PedidoId ON dbo.PedidoCombos(PedidoId, PedidoComboId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PedidoComboDetalle') AND name = N'IX_PedidoComboDetalle_ProductoId')
    CREATE INDEX IX_PedidoComboDetalle_ProductoId ON dbo.PedidoComboDetalle(ProductoId, PedidoComboId) INCLUDE (CantidadTotal);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.InventarioTransformaciones') AND name = N'IX_InventarioTransformaciones_Productos_Fecha')
    CREATE INDEX IX_InventarioTransformaciones_Productos_Fecha ON dbo.InventarioTransformaciones(ProductoOrigenId, ProductoDestinoId, FechaCreacionUtc DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.InventarioOperacionAuditoria') AND name = N'IX_InventarioOperacionAuditoria_Modulo_Fecha')
    CREATE INDEX IX_InventarioOperacionAuditoria_Modulo_Fecha ON dbo.InventarioOperacionAuditoria(Modulo, FechaCreacionUtc DESC);

IF COL_LENGTH(N'dbo.PedidoComboDetalle', N'PedidoComboDetalleId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoComboDetalle', N'PedidoComboId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoComboDetalle', N'ProductoId') IS NULL
   OR COL_LENGTH(N'dbo.PedidoComboDetalle', N'ProductoNombreSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.PedidoComboDetalle', N'CantidadPorCombo') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'FacturaComboId') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'FacturaId') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'ComboNombreSnapshot') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'Cantidad') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'PrecioUnitario') IS NULL
   OR COL_LENGTH(N'dbo.FacturaCombos', N'Subtotal') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'CheckoutOperacionId') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'UsuarioId') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'TokenOperacion') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'PedidoId') IS NULL
   OR COL_LENGTH(N'dbo.CheckoutOperaciones', N'FechaCreacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'InventarioTransformacionId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'ProductoOrigenId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'CantidadOrigen') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'ProductoDestinoId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'CantidadDestino') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'UsuarioId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'UsuarioNombre') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'Motivo') IS NULL
   OR COL_LENGTH(N'dbo.InventarioTransformaciones', N'FechaCreacionUtc') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'AuditoriaId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'Modulo') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'EntidadId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'Accion') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'UsuarioId') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'UsuarioNombre') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'Detalle') IS NULL
   OR COL_LENGTH(N'dbo.InventarioOperacionAuditoria', N'FechaCreacionUtc') IS NULL
    THROW 54504, N'Existe un objeto parcial o incompatible de la migración 0012.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.PedidoCombos')
      AND name = N'Subtotal'
      AND is_persisted = 1
)
   OR NOT EXISTS
      (
          SELECT 1
          FROM sys.computed_columns
          WHERE object_id = OBJECT_ID(N'dbo.FacturaCombos')
            AND name = N'Subtotal'
            AND is_persisted = 1
      )
    THROW 54504, N'Los subtotales canónicos deben ser columnas computadas persistidas.', 1;

DECLARE @RequiredConstraint TABLE
(
    ConstraintName SYSNAME NOT NULL,
    ConstraintType CHAR(2) NOT NULL
);

INSERT INTO @RequiredConstraint (ConstraintName, ConstraintType)
VALUES
    (N'dbo.DF_Combos_Activo', N'D'),
    (N'dbo.DF_Combos_FechaCreacionUtc', N'D'),
    (N'dbo.DF_Combos_FechaActualizacionUtc', N'D'),
    (N'dbo.CK_Combos_Precio', N'C'),
    (N'dbo.UQ_ComboDetalle_ComboProducto', N'UQ'),
    (N'dbo.CK_ComboDetalle_Cantidad', N'C'),
    (N'dbo.DF_PedidoCombos_FechaCreacionUtc', N'D'),
    (N'dbo.CK_PedidoCombos_Cantidad', N'C'),
    (N'dbo.CK_PedidoCombos_Precio', N'C'),
    (N'dbo.UQ_PedidoComboDetalle_ComboProducto', N'UQ'),
    (N'dbo.CK_PedidoComboDetalle_Cantidades', N'C'),
    (N'dbo.UQ_FacturaCombos_PedidoCombo', N'UQ'),
    (N'dbo.CK_FacturaCombos_Cantidad', N'C'),
    (N'dbo.CK_FacturaCombos_Precio', N'C'),
    (N'dbo.UQ_CheckoutOperaciones_UsuarioToken', N'UQ'),
    (N'dbo.DF_CheckoutOperaciones_FechaCreacionUtc', N'D'),
    (N'dbo.UQ_InventarioTransformaciones_Referencia', N'UQ'),
    (N'dbo.CK_InventarioTransformaciones_Productos', N'C'),
    (N'dbo.CK_InventarioTransformaciones_Cantidades', N'C'),
    (N'dbo.DF_InventarioTransformaciones_FechaCreacionUtc', N'D'),
    (N'dbo.DF_InventarioOperacionAuditoria_FechaCreacionUtc', N'D'),
    (N'dbo.DF_PedidoDetalle_EsRegalo', N'D');

IF EXISTS
(
    SELECT 1
    FROM @RequiredConstraint requiredConstraint
    WHERE OBJECT_ID(requiredConstraint.ConstraintName, requiredConstraint.ConstraintType) IS NULL
)
    THROW 54504, N'Falta una restricción requerida de la migración 0012.', 1;

DECLARE @RequiredPrimaryKey TABLE
(
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL
);

INSERT INTO @RequiredPrimaryKey (TableName, ColumnName)
VALUES
    (N'Combos', N'ComboId'),
    (N'ComboDetalle', N'ComboDetalleId'),
    (N'PedidoCombos', N'PedidoComboId'),
    (N'PedidoComboDetalle', N'PedidoComboDetalleId'),
    (N'FacturaCombos', N'FacturaComboId'),
    (N'CheckoutOperaciones', N'CheckoutOperacionId'),
    (N'InventarioTransformaciones', N'InventarioTransformacionId'),
    (N'InventarioOperacionAuditoria', N'AuditoriaId');

IF EXISTS
(
    SELECT 1
    FROM @RequiredPrimaryKey requiredKey
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes primaryIndex
        INNER JOIN sys.index_columns indexColumn
            ON indexColumn.object_id = primaryIndex.object_id
           AND indexColumn.index_id = primaryIndex.index_id
        INNER JOIN sys.columns columnObject
            ON columnObject.object_id = indexColumn.object_id
           AND columnObject.column_id = indexColumn.column_id
        WHERE primaryIndex.object_id = OBJECT_ID(N'dbo.' + requiredKey.TableName)
          AND primaryIndex.is_primary_key = 1
          AND indexColumn.key_ordinal = 1
          AND columnObject.name = requiredKey.ColumnName
    )
)
    THROW 54504, N'Falta una clave primaria requerida de la migración 0012.', 1;

DECLARE @RequiredForeignKey TABLE
(
    ParentTable SYSNAME NOT NULL,
    ParentColumn SYSNAME NOT NULL,
    ReferencedTable SYSNAME NOT NULL,
    ReferencedColumn SYSNAME NOT NULL
);

INSERT INTO @RequiredForeignKey
    (ParentTable, ParentColumn, ReferencedTable, ReferencedColumn)
VALUES
    (N'Combos', N'RegistradoPorUsuarioId', N'Usuarios', N'UsuarioId'),
    (N'Combos', N'ActualizadoPorUsuarioId', N'Usuarios', N'UsuarioId'),
    (N'ComboDetalle', N'ComboId', N'Combos', N'ComboId'),
    (N'ComboDetalle', N'ProductoId', N'Productos', N'ProductoId'),
    (N'PedidoCombos', N'PedidoId', N'Pedidos', N'PedidoId'),
    (N'PedidoCombos', N'ComboId', N'Combos', N'ComboId'),
    (N'PedidoComboDetalle', N'PedidoComboId', N'PedidoCombos', N'PedidoComboId'),
    (N'PedidoComboDetalle', N'ProductoId', N'Productos', N'ProductoId'),
    (N'FacturaCombos', N'FacturaId', N'Facturas', N'FacturaId'),
    (N'FacturaCombos', N'PedidoComboId', N'PedidoCombos', N'PedidoComboId'),
    (N'PedidoDetalle', N'PedidoComboId', N'PedidoCombos', N'PedidoComboId'),
    (N'CheckoutOperaciones', N'UsuarioId', N'Usuarios', N'UsuarioId'),
    (N'CheckoutOperaciones', N'PedidoId', N'Pedidos', N'PedidoId'),
    (N'InventarioTransformaciones', N'ProductoOrigenId', N'Productos', N'ProductoId'),
    (N'InventarioTransformaciones', N'ProductoDestinoId', N'Productos', N'ProductoId'),
    (N'InventarioTransformaciones', N'UsuarioId', N'Usuarios', N'UsuarioId'),
    (N'InventarioOperacionAuditoria', N'UsuarioId', N'Usuarios', N'UsuarioId');

IF EXISTS
(
    SELECT 1
    FROM @RequiredForeignKey requiredKey
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys foreignKey
        INNER JOIN sys.foreign_key_columns foreignKeyColumn
            ON foreignKeyColumn.constraint_object_id = foreignKey.object_id
        WHERE foreignKey.parent_object_id = OBJECT_ID(N'dbo.' + requiredKey.ParentTable)
          AND foreignKey.referenced_object_id = OBJECT_ID(N'dbo.' + requiredKey.ReferencedTable)
          AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
              (OBJECT_ID(N'dbo.' + requiredKey.ParentTable), requiredKey.ParentColumn, N'ColumnId')
          AND foreignKeyColumn.referenced_column_id = COLUMNPROPERTY
              (OBJECT_ID(N'dbo.' + requiredKey.ReferencedTable), requiredKey.ReferencedColumn, N'ColumnId')
          AND foreignKey.is_disabled = 0
          AND foreignKey.is_not_trusted = 0
    )
)
    THROW 54504, N'Falta una clave foránea segura de la migración 0012.', 1;

MERGE dbo.Permisos AS target
USING
(
    VALUES
        (N'COMBOS_VER', N'Inventario', N'Ver combos', N'Consulta combos, componentes y disponibilidad.'),
        (N'COMBOS_GESTIONAR', N'Inventario', N'Gestionar combos', N'Crea y activa o inactiva combos.'),
        (N'INVENTARIO_TRANSFORMAR', N'Inventario', N'Transformar inventario', N'Convierte presentaciones mediante una operación atómica.'),
        (N'INVENTARIO_INTELIGENCIA_VER', N'Inventario', N'Ver inteligencia de inventario', N'Consulta abastecimiento, rotación y estacionalidad.')
) AS source(Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN UPDATE SET
    Modulo = source.Modulo,
    Nombre = source.Nombre,
    Descripcion = source.Descripcion,
    Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);

INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, permission.PermisoId, NULL, N'Migración 0012'
FROM dbo.Perfiles profile
CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre = N'Administrador'
  AND permission.Codigo IN
      (N'COMBOS_VER', N'COMBOS_GESTIONAR', N'INVENTARIO_TRANSFORMAR', N'INVENTARIO_INTELIGENCIA_VER')
  AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PerfilPermisos currentPermission
          WHERE currentPermission.PerfilId = profile.PerfilId
            AND currentPermission.PermisoId = permission.PermisoId
      );
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetCombos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT combo.ComboId,
           combo.Nombre,
           combo.Descripcion,
           combo.Precio,
           combo.Activo,
           combo.FechaCreacionUtc,
           combo.RegistradoPorNombre,
           availability.CantidadComponentes AS CantidadProductos,
           CONVERT(INT, CASE
               WHEN combo.Activo = 1
                AND availability.CantidadComponentes > 0
                AND availability.CantidadComponentesValidos = availability.CantidadComponentes
                   THEN ISNULL(availability.StockDisponible, 0)
               ELSE 0
           END) AS StockDisponibleCombo,
           CASE
               WHEN combo.Activo = 0 THEN N'Inactivo'
               WHEN availability.CantidadComponentes = 0 THEN N'Sin componentes'
               WHEN availability.CantidadComponentesValidos <> availability.CantidadComponentes
                    THEN N'Componente inactivo o faltante'
               WHEN ISNULL(availability.StockDisponible, 0) <= 0 THEN N'Sin existencias'
               ELSE N'Disponible'
           END AS EstadoDisponibilidad
    FROM dbo.Combos combo
    CROSS APPLY
    (
        SELECT COUNT(detail.ComboDetalleId) AS CantidadComponentes,
               SUM(CASE WHEN product.ProductoId IS NOT NULL
                             AND product.Activo = 1
                             AND detail.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos,
               NULLIF(MIN(CASE WHEN product.ProductoId IS NOT NULL
                                     AND product.Activo = 1
                                     AND detail.Cantidad > 0
                                THEN product.Stock / detail.Cantidad
                                ELSE 2147483647 END), 2147483647) AS StockDisponible
        FROM dbo.ComboDetalle detail
        LEFT JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.ComboId = combo.ComboId
    ) availability
    ORDER BY combo.FechaCreacionUtc DESC, combo.ComboId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetComboDetail
    @ComboId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT combo.ComboId,
           combo.Nombre,
           combo.Descripcion,
           combo.Precio,
           combo.Activo,
           combo.RegistradoPorNombre,
           combo.FechaCreacionUtc,
           CONVERT(INT, CASE
               WHEN combo.Activo = 1
                AND availability.CantidadComponentes > 0
                AND availability.CantidadComponentesValidos = availability.CantidadComponentes
                   THEN ISNULL(availability.StockDisponible, 0)
               ELSE 0
           END) AS StockDisponibleCombo,
           CASE
               WHEN combo.Activo = 0 THEN N'Inactivo'
               WHEN availability.CantidadComponentes = 0 THEN N'Sin componentes'
               WHEN availability.CantidadComponentesValidos <> availability.CantidadComponentes
                    THEN N'Componente inactivo o faltante'
               WHEN ISNULL(availability.StockDisponible, 0) <= 0 THEN N'Sin existencias'
               ELSE N'Disponible'
           END AS EstadoDisponibilidad
    FROM dbo.Combos combo
    CROSS APPLY
    (
        SELECT COUNT(detail.ComboDetalleId) AS CantidadComponentes,
               SUM(CASE WHEN product.ProductoId IS NOT NULL
                             AND product.Activo = 1
                             AND detail.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos,
               NULLIF(MIN(CASE WHEN product.ProductoId IS NOT NULL
                                     AND product.Activo = 1
                                     AND detail.Cantidad > 0
                                THEN product.Stock / detail.Cantidad
                                ELSE 2147483647 END), 2147483647) AS StockDisponible
        FROM dbo.ComboDetalle detail
        LEFT JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.ComboId = combo.ComboId
    ) availability
    WHERE combo.ComboId = @ComboId

    SELECT detail.ComboDetalleId,
           detail.ProductoId,
           product.Nombre AS ProductoNombre,
           detail.Cantidad,
           product.Stock AS StockDisponible,
           product.Activo AS ProductoActivo
    FROM dbo.ComboDetalle detail
    INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
    WHERE detail.ComboId = @ComboId
    ORDER BY product.Nombre, product.ProductoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateCombo
    @Nombre NVARCHAR(150),
    @Descripcion NVARCHAR(500) = NULL,
    @Precio DECIMAL(18,2),
    @ComponentesJson NVARCHAR(MAX),
    @UsuarioId INT,
    @UsuarioNombre NVARCHAR(150),
    @NuevoComboId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    SET @UsuarioNombre = NULLIF(LTRIM(RTRIM(@UsuarioNombre)), N'');
    IF @Nombre IS NULL OR @Precio <= 0 OR @UsuarioId <= 0 OR @UsuarioNombre IS NULL
        THROW 54510, N'Los datos del combo no son válidos.', 1;
    IF ISJSON(@ComponentesJson) <> 1
        THROW 54511, N'Los componentes del combo no son válidos.', 1;

    DECLARE @Components TABLE (ProductoId INT NOT NULL PRIMARY KEY, Cantidad INT NOT NULL);
    IF EXISTS
    (
        SELECT 1
        FROM OPENJSON(@ComponentesJson)
        WITH (ProductoId INT N'$.productoId', Cantidad INT N'$.cantidad') item
        WHERE item.ProductoId IS NULL OR item.ProductoId <= 0 OR item.Cantidad IS NULL OR item.Cantidad <= 0
    )
        THROW 54512, N'Cada componente debe tener producto y cantidad positiva.', 1;
    IF EXISTS
    (
        SELECT item.ProductoId
        FROM OPENJSON(@ComponentesJson)
        WITH (ProductoId INT N'$.productoId', Cantidad INT N'$.cantidad') item
        GROUP BY item.ProductoId
        HAVING COUNT(*) > 1
    )
        THROW 54513, N'Un producto no puede repetirse dentro del combo.', 1;

    INSERT INTO @Components (ProductoId, Cantidad)
    SELECT item.ProductoId, item.Cantidad
    FROM OPENJSON(@ComponentesJson)
    WITH (ProductoId INT N'$.productoId', Cantidad INT N'$.cantidad') item;

    IF NOT EXISTS (SELECT 1 FROM @Components)
        THROW 54514, N'El combo requiere al menos un componente.', 1;

    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WITH (UPDLOCK, HOLDLOCK) WHERE UsuarioId = @UsuarioId AND Activo = 1)
        THROW 54515, N'El usuario no está activo.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM @Components component
        LEFT JOIN dbo.Productos product WITH (UPDLOCK, HOLDLOCK) ON product.ProductoId = component.ProductoId AND product.Activo = 1
        WHERE product.ProductoId IS NULL
    )
        THROW 54516, N'Uno o más componentes no están disponibles.', 1;

    INSERT INTO dbo.Combos
        (Nombre, Descripcion, Precio, Activo, RegistradoPorUsuarioId, RegistradoPorNombre,
         ActualizadoPorUsuarioId, ActualizadoPorNombre)
    VALUES
        (@Nombre, @Descripcion, @Precio, 1, @UsuarioId, @UsuarioNombre, @UsuarioId, @UsuarioNombre);
    SET @NuevoComboId = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.ComboDetalle (ComboId, ProductoId, Cantidad)
    SELECT @NuevoComboId, ProductoId, Cantidad FROM @Components;

    INSERT INTO dbo.InventarioOperacionAuditoria
        (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
    VALUES
        (N'Combos', @NuevoComboId, N'Crear', @UsuarioId, @UsuarioNombre,
         CONCAT(N'Combo creado con ', (SELECT COUNT(*) FROM @Components), N' componentes.'));
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_AddComboDetail
    @ComboId INT,
    @ProductoId INT,
    @Cantidad INT,
    @UsuarioId INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ComboId <= 0 OR @ProductoId <= 0 OR @Cantidad <= 0
        THROW 54520, N'El componente indicado no es válido.', 1;

    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM dbo.Combos WITH (UPDLOCK, HOLDLOCK) WHERE ComboId = @ComboId)
        THROW 54521, N'El combo no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK) WHERE ProductoId = @ProductoId AND Activo = 1)
        THROW 54522, N'El producto no está disponible.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ComboDetalle WHERE ComboId = @ComboId AND ProductoId = @ProductoId)
        THROW 54523, N'El producto ya pertenece al combo.', 1;

    INSERT INTO dbo.ComboDetalle (ComboId, ProductoId, Cantidad)
    VALUES (@ComboId, @ProductoId, @Cantidad);
    UPDATE dbo.Combos
    SET ActualizadoPorUsuarioId = @UsuarioId,
        ActualizadoPorNombre = @UsuarioNombre,
        FechaActualizacionUtc = SYSUTCDATETIME()
    WHERE ComboId = @ComboId;
    INSERT INTO dbo.InventarioOperacionAuditoria
        (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
    VALUES (N'Combos', @ComboId, N'Agregar componente', @UsuarioId, @UsuarioNombre,
            CONCAT(N'Producto #', @ProductoId, N'; cantidad ', @Cantidad, N'.'));
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleComboStatus
    @ComboId INT,
    @UsuarioId INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    DECLARE @Current BIT;
    SELECT @Current = Activo FROM dbo.Combos WITH (UPDLOCK, HOLDLOCK) WHERE ComboId = @ComboId;
    IF @Current IS NULL THROW 54530, N'El combo no existe.', 1;
    IF @Current = 0 AND NOT EXISTS (SELECT 1 FROM dbo.ComboDetalle WHERE ComboId = @ComboId)
        THROW 54531, N'No se puede activar un combo sin componentes.', 1;

    UPDATE dbo.Combos
    SET Activo = IIF(@Current = 1, 0, 1),
        ActualizadoPorUsuarioId = @UsuarioId,
        ActualizadoPorNombre = @UsuarioNombre,
        FechaActualizacionUtc = SYSUTCDATETIME()
    WHERE ComboId = @ComboId;
    INSERT INTO dbo.InventarioOperacionAuditoria
        (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
    VALUES (N'Combos', @ComboId, IIF(@Current = 1, N'Inactivar', N'Activar'), @UsuarioId, @UsuarioNombre,
            IIF(@Current = 1, N'Combo inactivado.', N'Combo activado.'));
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetActiveCombos
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT combo.ComboId,
           combo.Nombre,
           combo.Descripcion,
           combo.Precio,
           availability.CantidadComponentes AS CantidadProductos,
           CONVERT(INT, availability.StockDisponible) AS StockDisponibleCombo,
           CONVERT(BIT, 1) AS ComponentesValidos,
           STRING_AGG(CONCAT(detail.Cantidad, N'× ', product.Nombre), N', ')
               WITHIN GROUP (ORDER BY product.Nombre, product.ProductoId) AS ComponentesResumen
    FROM dbo.Combos combo
    CROSS APPLY
    (
        SELECT COUNT(component.ComboDetalleId) AS CantidadComponentes,
               SUM(CASE WHEN componentProduct.ProductoId IS NOT NULL
                             AND componentProduct.Activo = 1
                             AND component.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos,
               NULLIF(MIN(CASE WHEN componentProduct.ProductoId IS NOT NULL
                                     AND componentProduct.Activo = 1
                                     AND component.Cantidad > 0
                                THEN componentProduct.Stock / component.Cantidad
                                ELSE 2147483647 END), 2147483647) AS StockDisponible
        FROM dbo.ComboDetalle component
        LEFT JOIN dbo.Productos componentProduct ON componentProduct.ProductoId = component.ProductoId
        WHERE component.ComboId = combo.ComboId
    ) availability
    INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = combo.ComboId
    INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
    WHERE combo.Activo = 1
      AND availability.CantidadComponentes > 0
      AND availability.CantidadComponentesValidos = availability.CantidadComponentes
      AND availability.StockDisponible > 0
      AND (@Buscar IS NULL OR combo.Nombre LIKE N'%' + @Buscar + N'%' OR combo.Descripcion LIKE N'%' + @Buscar + N'%')
    GROUP BY combo.ComboId, combo.Nombre, combo.Descripcion, combo.Precio,
             availability.CantidadComponentes, availability.StockDisponible
    ORDER BY combo.Nombre, combo.ComboId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetComboById
    @ComboId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT combo.ComboId,
           combo.Nombre,
           combo.Descripcion,
           combo.Precio,
           availability.CantidadComponentes AS CantidadProductos,
           CONVERT(INT, availability.StockDisponible) AS StockDisponibleCombo,
           CONVERT(BIT, 1) AS ComponentesValidos,
           STRING_AGG(CONCAT(detail.Cantidad, N'× ', product.Nombre), N', ')
               WITHIN GROUP (ORDER BY product.Nombre, product.ProductoId) AS ComponentesResumen
    FROM dbo.Combos combo
    CROSS APPLY
    (
        SELECT COUNT(component.ComboDetalleId) AS CantidadComponentes,
               SUM(CASE WHEN componentProduct.ProductoId IS NOT NULL
                             AND componentProduct.Activo = 1
                             AND component.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos,
               NULLIF(MIN(CASE WHEN componentProduct.ProductoId IS NOT NULL
                                     AND componentProduct.Activo = 1
                                     AND component.Cantidad > 0
                                THEN componentProduct.Stock / component.Cantidad
                                ELSE 2147483647 END), 2147483647) AS StockDisponible
        FROM dbo.ComboDetalle component
        LEFT JOIN dbo.Productos componentProduct ON componentProduct.ProductoId = component.ProductoId
        WHERE component.ComboId = combo.ComboId
    ) availability
    INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = combo.ComboId
    INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
    WHERE combo.ComboId = @ComboId
      AND combo.Activo = 1
      AND availability.CantidadComponentes > 0
      AND availability.CantidadComponentesValidos = availability.CantidadComponentes
      AND availability.StockDisponible > 0
    GROUP BY combo.ComboId, combo.Nombre, combo.Descripcion, combo.Precio,
             availability.CantidadComponentes, availability.StockDisponible;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Inventory_TransformStockAtomic
    @ProductoOrigenId INT,
    @CantidadOrigen INT,
    @ProductoDestinoId INT,
    @CantidadDestino INT,
    @Motivo NVARCHAR(300) = NULL,
    @UsuarioId INT,
    @UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ProductoOrigenId <= 0 OR @ProductoDestinoId <= 0
        THROW 54401, N'Los productos indicados no son válidos.', 1;
    IF @ProductoOrigenId = @ProductoDestinoId
        THROW 54402, N'El origen y destino deben ser diferentes.', 1;
    IF @CantidadOrigen <= 0 OR @CantidadDestino <= 0
        THROW 54403, N'Las cantidades deben ser positivas.', 1;

    DECLARE @LowId INT = IIF(@ProductoOrigenId < @ProductoDestinoId, @ProductoOrigenId, @ProductoDestinoId);
    DECLARE @HighId INT = IIF(@ProductoOrigenId < @ProductoDestinoId, @ProductoDestinoId, @ProductoOrigenId);
    DECLARE @LowName NVARCHAR(150), @HighName NVARCHAR(150), @LowStock INT, @HighStock INT;
    DECLARE @SourceName NVARCHAR(150), @DestinationName NVARCHAR(150), @SourceBefore INT, @DestinationBefore INT;
    DECLARE @Reference UNIQUEIDENTIFIER = NEWID();

    BEGIN TRANSACTION;
    SELECT @LowName = Nombre, @LowStock = Stock
    FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
    WHERE ProductoId = @LowId AND Activo = 1;
    SELECT @HighName = Nombre, @HighStock = Stock
    FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
    WHERE ProductoId = @HighId AND Activo = 1;
    IF @LowName IS NULL OR @HighName IS NULL
        THROW 54404, N'El producto de origen o destino no existe o está inactivo.', 1;

    SELECT @SourceName = IIF(@ProductoOrigenId = @LowId, @LowName, @HighName),
           @SourceBefore = IIF(@ProductoOrigenId = @LowId, @LowStock, @HighStock),
           @DestinationName = IIF(@ProductoDestinoId = @LowId, @LowName, @HighName),
           @DestinationBefore = IIF(@ProductoDestinoId = @LowId, @LowStock, @HighStock);
    IF @SourceBefore < @CantidadOrigen
        THROW 54405, N'No hay stock suficiente en el producto de origen.', 1;
    IF CONVERT(BIGINT, @DestinationBefore) + CONVERT(BIGINT, @CantidadDestino) > 2147483647
        THROW 54406, N'La transformación excede el límite de stock permitido.', 1;

    UPDATE dbo.Productos SET Stock = Stock - @CantidadOrigen WHERE ProductoId = @ProductoOrigenId;
    UPDATE dbo.Productos SET Stock = Stock + @CantidadDestino WHERE ProductoId = @ProductoDestinoId;

    INSERT INTO dbo.InventarioTransformaciones
        (ReferenciaTransformacion, ProductoOrigenId, CantidadOrigen, ProductoDestinoId, CantidadDestino,
         UsuarioId, UsuarioNombre, Motivo)
    VALUES
        (@Reference, @ProductoOrigenId, @CantidadOrigen, @ProductoDestinoId, @CantidadDestino,
         @UsuarioId, @UsuarioNombre, NULLIF(LTRIM(RTRIM(@Motivo)), N''));

    INSERT INTO dbo.MovimientosInventario
        (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
         Motivo, UsuarioId, UsuarioNombre, FechaMovimiento)
    VALUES
        (@ProductoOrigenId, @SourceName, N'TransformacionSalida', @CantidadOrigen,
         @SourceBefore, @SourceBefore - @CantidadOrigen,
         LEFT(CONCAT(N'Transformación ', CONVERT(NVARCHAR(36), @Reference), N'. ', COALESCE(@Motivo, N'')), 250),
         @UsuarioId, @UsuarioNombre, SYSDATETIME()),
        (@ProductoDestinoId, @DestinationName, N'TransformacionEntrada', @CantidadDestino,
         @DestinationBefore, @DestinationBefore + @CantidadDestino,
         LEFT(CONCAT(N'Transformación ', CONVERT(NVARCHAR(36), @Reference), N'. ', COALESCE(@Motivo, N'')), 250),
         @UsuarioId, @UsuarioNombre, SYSDATETIME());

    INSERT INTO dbo.InventarioOperacionAuditoria
        (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
    VALUES
        (N'Inventario', @ProductoOrigenId, N'Transformar', @UsuarioId, @UsuarioNombre,
         CONCAT(N'Referencia ', CONVERT(NVARCHAR(36), @Reference), N'; origen #', @ProductoOrigenId,
                N'; destino #', @ProductoDestinoId, N'.'));
    COMMIT TRANSACTION;

    SELECT @Reference AS ReferenciaTransformacion,
           @ProductoOrigenId AS ProductoOrigenId,
           @SourceName AS ProductoOrigenNombre,
           @SourceBefore AS StockOrigenAnterior,
           @SourceBefore - @CantidadOrigen AS StockOrigenNuevo,
           @ProductoDestinoId AS ProductoDestinoId,
           @DestinationName AS ProductoDestinoNombre,
           @DestinationBefore AS StockDestinoAnterior,
           @DestinationBefore + @CantidadDestino AS StockDestinoNuevo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetPurchaseSuggestions
    @MesesRecientes INT = 3,
    @MesesCobertura INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    IF @MesesRecientes NOT BETWEEN 1 AND 12 OR @MesesCobertura NOT BETWEEN 1 AND 12
        THROW 54540, N'La ventana o cobertura no es válida.', 1;

    ;WITH Sales AS
    (
        SELECT detail.ProductoId, detail.Cantidad, orders.FechaPedido
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = detail.PedidoId
        WHERE orders.Estado NOT IN (N'Cancelado', N'Rechazado')
          AND detail.PedidoComboId IS NULL
        UNION ALL
        SELECT component.ProductoId, component.CantidadTotal, orders.FechaPedido
        FROM dbo.PedidoComboDetalle component
        INNER JOIN dbo.PedidoCombos combo ON combo.PedidoComboId = component.PedidoComboId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = combo.PedidoId
        WHERE orders.Estado NOT IN (N'Cancelado', N'Rechazado')
    ), WindowSales AS
    (
        SELECT ProductoId, SUM(Cantidad) AS Units
        FROM Sales
        WHERE FechaPedido >= DATEADD(MONTH, -@MesesRecientes, CONVERT(DATE, SYSDATETIME()))
        GROUP BY ProductoId
    ), Calculation AS
    (
        SELECT product.ProductoId,
               product.Nombre,
               product.Stock AS StockActual,
               ISNULL(product.StockMinimo, 0) AS StockMinimo,
               CONVERT(INT, ISNULL(sales.Units, 0)) AS UnidadesVendidasVentana,
               CONVERT(DECIMAL(18,2), ISNULL(sales.Units, 0) / CONVERT(DECIMAL(18,4), @MesesRecientes)) AS PromedioVentaMensual,
               @MesesCobertura AS MesesCobertura,
               CONVERT(INT, CASE
                   WHEN CEILING(ISNULL(sales.Units, 0) / CONVERT(DECIMAL(18,4), @MesesRecientes) * @MesesCobertura)
                        + ISNULL(product.StockMinimo, 0) - product.Stock > 0
                   THEN CEILING(ISNULL(sales.Units, 0) / CONVERT(DECIMAL(18,4), @MesesRecientes) * @MesesCobertura)
                        + ISNULL(product.StockMinimo, 0) - product.Stock
                   ELSE 0 END) AS CantidadSugerida,
               CONVERT(BIT, IIF(sales.Units IS NULL, 1, 0)) AS DatosInsuficientes
        FROM dbo.Productos product
        LEFT JOIN WindowSales sales ON sales.ProductoId = product.ProductoId
        WHERE product.Activo = 1
    )
    SELECT ProductoId, Nombre, StockActual, StockMinimo, UnidadesVendidasVentana,
           PromedioVentaMensual, MesesCobertura, CantidadSugerida, DatosInsuficientes
    FROM Calculation
    WHERE CantidadSugerida > 0
    ORDER BY CantidadSugerida DESC, Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetSlowMovingProducts
    @VentanaDias INT = 60
AS
BEGIN
    SET NOCOUNT ON;
    IF @VentanaDias NOT BETWEEN 30 AND 365 THROW 54541, N'La ventana de rotación no es válida.', 1;

    ;WITH Sales AS
    (
        SELECT detail.ProductoId, detail.Cantidad, orders.FechaPedido
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = detail.PedidoId
        WHERE orders.Estado NOT IN (N'Cancelado', N'Rechazado')
          AND detail.PedidoComboId IS NULL
        UNION ALL
        SELECT component.ProductoId, component.CantidadTotal, orders.FechaPedido
        FROM dbo.PedidoComboDetalle component
        INNER JOIN dbo.PedidoCombos combo ON combo.PedidoComboId = component.PedidoComboId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = combo.PedidoId
        WHERE orders.Estado NOT IN (N'Cancelado', N'Rechazado')
    ), Rotation AS
    (
        SELECT product.ProductoId,
               MAX(sales.FechaPedido) AS LastSale,
               SUM(CASE WHEN sales.FechaPedido >= DATEADD(DAY, -@VentanaDias, CONVERT(DATE, SYSDATETIME()))
                        THEN sales.Cantidad ELSE 0 END) AS WindowUnits
        FROM dbo.Productos product
        LEFT JOIN Sales sales ON sales.ProductoId = product.ProductoId
        GROUP BY product.ProductoId
    )
    SELECT product.ProductoId,
           product.Nombre,
           product.Stock,
           product.FechaCreacion,
           rotation.LastSale AS UltimaVenta,
           DATEDIFF(DAY, COALESCE(rotation.LastSale, product.FechaCreacion), SYSDATETIME()) AS DiasSinMovimiento,
           CONVERT(INT, ISNULL(rotation.WindowUnits, 0)) AS VendidoEnVentana,
           CASE
               WHEN DATEDIFF(DAY, COALESCE(rotation.LastSale, product.FechaCreacion), SYSDATETIME()) >= 120 THEN N'Alto'
               WHEN DATEDIFF(DAY, COALESCE(rotation.LastSale, product.FechaCreacion), SYSDATETIME()) >= 90 THEN N'Medio'
               ELSE N'Bajo'
           END AS NivelRiesgo
    FROM dbo.Productos product
    INNER JOIN Rotation rotation ON rotation.ProductoId = product.ProductoId
    WHERE product.Activo = 1
      AND product.Stock > 0
      AND product.FechaCreacion <= DATEADD(DAY, -@VentanaDias, SYSDATETIME())
      AND ISNULL(rotation.WindowUnits, 0) = 0
    ORDER BY DiasSinMovimiento DESC, product.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetSeasonalSalesTrend
    @AnioInicio INT,
    @AnioFin INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @AnioInicio NOT BETWEEN 2000 AND 2100 OR @AnioFin NOT BETWEEN 2000 AND 2100
       OR @AnioInicio > @AnioFin OR @AnioFin - @AnioInicio > 9
        THROW 54542, N'El período estacional no es válido.', 1;

    ;WITH Months AS
    (
        SELECT number AS NumeroMes,
               CHOOSE(number, N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
                      N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre') AS NombreMes
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) valuesTable(number)
    ), Sales AS
    (
        SELECT MONTH(orders.FechaPedido) AS NumeroMes,
               CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario) AS Total,
               detail.Cantidad AS Units
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = detail.PedidoId
        WHERE YEAR(orders.FechaPedido) BETWEEN @AnioInicio AND @AnioFin
          AND orders.Estado NOT IN (N'Cancelado', N'Rechazado')
          AND detail.PedidoComboId IS NULL
        UNION ALL
        SELECT MONTH(orders.FechaPedido), combo.Subtotal, combo.Cantidad
        FROM dbo.PedidoCombos combo
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = combo.PedidoId
        WHERE YEAR(orders.FechaPedido) BETWEEN @AnioInicio AND @AnioFin
          AND orders.Estado NOT IN (N'Cancelado', N'Rechazado')
    )
    SELECT months.NumeroMes,
           months.NombreMes,
           CONVERT(DECIMAL(18,2), SUM(ISNULL(sales.Total, 0))) AS TotalVendido,
           CONVERT(INT, SUM(ISNULL(sales.Units, 0))) AS UnidadesVendidas
    FROM Months months
    LEFT JOIN Sales sales ON sales.NumeroMes = months.NumeroMes
    GROUP BY months.NumeroMes, months.NombreMes
    ORDER BY months.NumeroMes;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCheckoutResult
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pedidos
        WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId
    )
        THROW 54600, N'El pedido no pertenece al usuario indicado.', 1;

    SELECT PedidoId, Total
    FROM dbo.Pedidos
    WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId;

    SELECT result.TipoItem,
           result.ProductoId,
           result.ComboId,
           result.Nombre,
           result.Categoria,
           result.Descripcion,
           result.PrecioUnitario,
           result.Cantidad,
           result.ImagenUrl,
           result.MontoDescuento
    FROM
    (
        SELECT N'Producto' AS TipoItem,
               detail.ProductoId,
               CONVERT(INT, NULL) AS ComboId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre) AS Nombre,
               product.Categoria,
               product.Descripcion,
               detail.PrecioUnitario,
               detail.Cantidad,
               product.ImagenUrl,
               CONVERT(DECIMAL(18,2), ISNULL
               (
                   (
                       SELECT SUM(application.MontoDescontado)
                       FROM dbo.PromocionAplicaciones application
                       WHERE application.PedidoId = detail.PedidoId
                         AND application.ProductoId = detail.ProductoId
                         AND application.TipoBeneficio = N'Descuento'
                   ), 0
               )) AS MontoDescuento,
               1 AS SortOrder,
               detail.PedidoDetalleId AS SortId
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.EsRegalo = 0
          AND detail.PedidoComboId IS NULL

        UNION ALL

        SELECT N'Combo',
               CONVERT(INT, NULL),
               combo.ComboId,
               combo.ComboNombreSnapshot,
               N'Combo',
               combo.ComboDescripcionSnapshot,
               combo.PrecioUnitario,
               combo.Cantidad,
               CONVERT(NVARCHAR(300), NULL),
               CONVERT(DECIMAL(18,2), 0),
               2,
               combo.PedidoComboId
        FROM dbo.PedidoCombos combo
        WHERE combo.PedidoId = @PedidoId
    ) result
    ORDER BY result.SortOrder, result.SortId;

    SELECT gift.ProductoId,
           product.Nombre,
           SUM(gift.Cantidad) AS Cantidad,
           MAX(appliedPromotion.Nombre) AS PromocionNombre
    FROM dbo.PedidoDetalle gift
    INNER JOIN dbo.Productos product ON product.ProductoId = gift.ProductoId
    OUTER APPLY
    (
        SELECT TOP (1) promotion.Nombre
        FROM dbo.PromocionAplicaciones application
        INNER JOIN dbo.Promociones promotion ON promotion.PromocionId = application.PromocionId
        WHERE application.PedidoId = gift.PedidoId
          AND application.TipoBeneficio = N'Regalia'
          AND promotion.ProductoRegaloId = gift.ProductoId
        ORDER BY promotion.Prioridad DESC, promotion.PromocionId
    ) appliedPromotion
    WHERE gift.PedidoId = @PedidoId
      AND gift.EsRegalo = 1
      AND gift.PedidoComboId IS NULL
    GROUP BY gift.ProductoId, product.Nombre
    ORDER BY product.Nombre, gift.ProductoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_CreateOrderWithPromotions
    @UsuarioId INT,
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX),
    @MetodoPago NVARCHAR(40) = N'Efectivo contra entrega',
    @ReferenciaPago NVARCHAR(80) = NULL,
    @TokenOperacion UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TipoEntrega = NULLIF(LTRIM(RTRIM(@TipoEntrega)), N'');
    SET @DireccionEntrega = NULLIF(LTRIM(RTRIM(@DireccionEntrega)), N'');
    SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), N'');
    SET @IdentificacionCliente = NULLIF(LTRIM(RTRIM(@IdentificacionCliente)), N'');
    SET @MetodoPago = COALESCE(NULLIF(LTRIM(RTRIM(@MetodoPago)), N''), N'Efectivo contra entrega');
    SET @ReferenciaPago = NULLIF(LTRIM(RTRIM(@ReferenciaPago)), N'');

    IF @UsuarioId <= 0 OR @TokenOperacion IS NULL
        THROW 54601, N'El usuario o el identificador de checkout no es válido.', 1;
    IF @TipoEntrega IS NULL
        THROW 54602, N'El tipo de entrega es obligatorio.', 1;
    IF @MetodoPago NOT IN
       (N'Efectivo contra entrega', N'SINPE Móvil simulado', N'Tarjeta demo', N'Transferencia simulada')
        THROW 54603, N'El método de pago no es válido.', 1;
    IF ISJSON(@ItemsJson) <> 1
        THROW 54604, N'El carrito no tiene un formato válido.', 1;

    DECLARE @Items TABLE
    (
        Tipo NVARCHAR(20) NOT NULL,
        ItemId INT NOT NULL,
        ProductoId INT NULL,
        ComboId INT NULL,
        Cantidad INT NOT NULL,
        PRIMARY KEY (Tipo, ItemId)
    );

    IF EXISTS
    (
        SELECT 1
        FROM OPENJSON(@ItemsJson)
        WITH
        (
            Tipo NVARCHAR(20) N'$.tipo',
            ProductoId INT N'$.productoId',
            ComboId INT N'$.comboId',
            Cantidad INT N'$.cantidad'
        ) source
        WHERE source.Tipo IS NULL OR source.Tipo NOT IN (N'Producto', N'Combo')
           OR source.Cantidad IS NULL OR source.Cantidad NOT BETWEEN 1 AND 999
           OR (source.Tipo = N'Producto' AND (source.ProductoId IS NULL OR source.ProductoId <= 0 OR source.ComboId IS NOT NULL))
           OR (source.Tipo = N'Combo' AND (source.ComboId IS NULL OR source.ComboId <= 0 OR source.ProductoId IS NOT NULL))
    )
        THROW 54605, N'El carrito contiene una línea no válida.', 1;

    INSERT INTO @Items (Tipo, ItemId, ProductoId, ComboId, Cantidad)
    SELECT source.Tipo,
           IIF(source.Tipo = N'Producto', source.ProductoId, source.ComboId),
           source.ProductoId,
           source.ComboId,
           SUM(source.Cantidad)
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        Tipo NVARCHAR(20) N'$.tipo',
        ProductoId INT N'$.productoId',
        ComboId INT N'$.comboId',
        Cantidad INT N'$.cantidad'
    ) source
    GROUP BY source.Tipo, source.ProductoId, source.ComboId;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 54606, N'El carrito está vacío.', 1;
    IF EXISTS (SELECT 1 FROM @Items WHERE Cantidad NOT BETWEEN 1 AND 999)
        THROW 54607, N'La cantidad acumulada de una línea no es válida.', 1;

    DECLARE @CanonicalItems NVARCHAR(MAX);
    DECLARE @SolicitudHash BINARY(32);
    SELECT @CanonicalItems =
    (
        SELECT Tipo AS tipo,
               ProductoId AS productoId,
               ComboId AS comboId,
               Cantidad AS cantidad
        FROM @Items
        ORDER BY Tipo, ProductoId, ComboId
        FOR JSON PATH
    );
    SET @SolicitudHash = HASHBYTES
    (
        N'SHA2_256',
        CONCAT(@UsuarioId, N'|', @TipoEntrega, N'|', COALESCE(@DireccionEntrega, N''), N'|',
               COALESCE(@Observaciones, N''), N'|', COALESCE(@IdentificacionCliente, N''), N'|',
               @MetodoPago, N'|', COALESCE(@ReferenciaPago, N''), N'|', @CanonicalItems)
    );

    DECLARE @PedidoId INT;
    DECLARE @ExistingPedidoId INT;
    DECLARE @ExistingHash BINARY(32);
    DECLARE @NombreUsuario NVARCHAR(150);
    DECLARE @Segmento NVARCHAR(20);
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(255) = CONCAT(N'checkout:', @UsuarioId, N':', CONVERT(NVARCHAR(36), @TokenOperacion));

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 54608, N'No fue posible reservar el intento de checkout. Intente nuevamente.', 1;

        SELECT @ExistingPedidoId = operation.PedidoId,
               @ExistingHash = operation.SolicitudHash
        FROM dbo.CheckoutOperaciones operation WITH (UPDLOCK, HOLDLOCK)
        WHERE operation.UsuarioId = @UsuarioId
          AND operation.TokenOperacion = @TokenOperacion;

        IF @ExistingPedidoId IS NOT NULL
        BEGIN
            IF @ExistingHash <> @SolicitudHash
                THROW 54609, N'El identificador de checkout ya fue utilizado con otra solicitud.', 1;

            COMMIT TRANSACTION;
            EXEC dbo.sp_Store_GetCheckoutResult @PedidoId = @ExistingPedidoId, @UsuarioId = @UsuarioId;
            RETURN;
        END;

        SELECT @NombreUsuario = userAccount.NombreCompleto,
               @Segmento = ISNULL(NULLIF(userAccount.SegmentoCliente, N''), N'Minorista')
        FROM dbo.Usuarios userAccount WITH (UPDLOCK, HOLDLOCK)
        WHERE userAccount.UsuarioId = @UsuarioId AND userAccount.Activo = 1;
        IF @NombreUsuario IS NULL
            THROW 54610, N'El usuario del pedido no está disponible.', 1;

        DECLARE @CartCombos TABLE
        (
            ComboId INT NOT NULL PRIMARY KEY,
            Cantidad INT NOT NULL,
            Nombre NVARCHAR(150) NOT NULL,
            Descripcion NVARCHAR(500) NULL,
            Precio DECIMAL(18,2) NOT NULL
        );
        INSERT INTO @CartCombos (ComboId, Cantidad, Nombre, Descripcion, Precio)
        SELECT combo.ComboId, item.Cantidad, combo.Nombre, combo.Descripcion, combo.Precio
        FROM @Items item
        INNER JOIN dbo.Combos combo WITH (UPDLOCK, HOLDLOCK)
            ON combo.ComboId = item.ComboId AND combo.Activo = 1
        WHERE item.Tipo = N'Combo';
        IF (SELECT COUNT(*) FROM @CartCombos) <> (SELECT COUNT(*) FROM @Items WHERE Tipo = N'Combo')
            THROW 54611, N'Uno o más combos no están disponibles.', 1;
        IF EXISTS
        (
            SELECT 1
            FROM @CartCombos cart
            WHERE NOT EXISTS (SELECT 1 FROM dbo.ComboDetalle detail WHERE detail.ComboId = cart.ComboId)
        )
            THROW 54612, N'Uno o más combos no tienen componentes.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @CartCombos cart
            CROSS APPLY
            (
                SELECT COUNT(detail.ComboDetalleId) AS CantidadComponentes,
                       SUM(CASE WHEN product.ProductoId IS NOT NULL
                                     AND product.Activo = 1
                                     AND detail.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos
                FROM dbo.ComboDetalle detail
                LEFT JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
                WHERE detail.ComboId = cart.ComboId
            ) availability
            WHERE availability.CantidadComponentes = 0
               OR availability.CantidadComponentesValidos <> availability.CantidadComponentes
        )
            THROW 54612, N'Uno o más combos tienen componentes inactivos o inválidos.', 1;

        DECLARE @Candidates TABLE
        (
            PromocionId INT NOT NULL,
            ProductoId INT NOT NULL,
            Tipo NVARCHAR(25) NOT NULL,
            PorcentajeDescuento DECIMAL(5,2) NULL,
            ProductoRegaloId INT NULL,
            CantidadRegalo INT NULL,
            CantidadMinima INT NOT NULL,
            Prioridad INT NOT NULL,
            CantidadComprada INT NOT NULL,
            PRIMARY KEY (PromocionId, ProductoId)
        );
        ;WITH Ranked AS
        (
            SELECT promotion.PromocionId,
                   promotion.ProductoId,
                   promotion.Tipo,
                   promotion.PorcentajeDescuento,
                   promotion.ProductoRegaloId,
                   promotion.CantidadRegalo,
                   promotion.CantidadMinima,
                   promotion.Prioridad,
                   item.Cantidad AS CantidadComprada,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY promotion.ProductoId
                       ORDER BY promotion.Prioridad DESC, promotion.PromocionId
                   ) AS Position
            FROM @Items item
            INNER JOIN dbo.Promociones promotion WITH (UPDLOCK, HOLDLOCK)
                ON promotion.ProductoId = item.ProductoId
            WHERE item.Tipo = N'Producto'
              AND item.Cantidad >= promotion.CantidadMinima
              AND promotion.Estado = N'Activa'
              AND CONVERT(DATE, SYSDATETIME()) BETWEEN promotion.FechaInicio AND promotion.FechaFin
              AND promotion.SegmentoCliente IN (N'Todos', @Segmento)
        )
        INSERT INTO @Candidates
            (PromocionId, ProductoId, Tipo, PorcentajeDescuento, ProductoRegaloId,
             CantidadRegalo, CantidadMinima, Prioridad, CantidadComprada)
        SELECT PromocionId, ProductoId, Tipo, PorcentajeDescuento, ProductoRegaloId,
               CantidadRegalo, CantidadMinima, Prioridad, CantidadComprada
        FROM Ranked
        WHERE Position = 1;

        DECLARE @Requirements TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            CantidadCarrito BIGINT NOT NULL,
            CantidadRegalo BIGINT NOT NULL DEFAULT (0)
        );
        INSERT INTO @Requirements (ProductoId, CantidadCarrito)
        SELECT source.ProductoId, SUM(CONVERT(BIGINT, source.Cantidad))
        FROM
        (
            SELECT item.ProductoId, item.Cantidad
            FROM @Items item
            WHERE item.Tipo = N'Producto'
            UNION ALL
            SELECT detail.ProductoId,
                   CONVERT(BIGINT, detail.Cantidad) * cart.Cantidad
            FROM @CartCombos cart
            INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = cart.ComboId
        ) source
        GROUP BY source.ProductoId;

        INSERT INTO @Requirements (ProductoId, CantidadCarrito)
        SELECT DISTINCT candidate.ProductoRegaloId, 0
        FROM @Candidates candidate
        WHERE candidate.Tipo = N'RegaliaPorVolumen'
          AND candidate.ProductoRegaloId IS NOT NULL
          AND NOT EXISTS
              (SELECT 1 FROM @Requirements requirement WHERE requirement.ProductoId = candidate.ProductoRegaloId);

        DECLARE @LockedProducts TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            Nombre NVARCHAR(150) NOT NULL,
            Categoria NVARCHAR(100) NOT NULL,
            Descripcion NVARCHAR(255) NULL,
            Precio DECIMAL(18,2) NOT NULL,
            Stock INT NOT NULL,
            ImagenUrl NVARCHAR(300) NULL,
            Activo BIT NOT NULL
        );
        DECLARE @LockProductId INT;
        DECLARE @LockName NVARCHAR(150);
        DECLARE @LockCategory NVARCHAR(100);
        DECLARE @LockDescription NVARCHAR(255);
        DECLARE @LockPrice DECIMAL(18,2);
        DECLARE @LockStock INT;
        DECLARE @LockImage NVARCHAR(300);
        DECLARE @LockActive BIT;
        DECLARE inventory_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ProductoId FROM @Requirements ORDER BY ProductoId;
        OPEN inventory_cursor;
        FETCH NEXT FROM inventory_cursor INTO @LockProductId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @LockName = NULL, @LockCategory = NULL, @LockDescription = NULL,
                   @LockPrice = NULL, @LockStock = NULL, @LockImage = NULL, @LockActive = NULL;
            SELECT @LockName = product.Nombre,
                   @LockCategory = product.Categoria,
                   @LockDescription = product.Descripcion,
                   @LockPrice = product.Precio,
                   @LockStock = product.Stock,
                   @LockImage = product.ImagenUrl,
                   @LockActive = product.Activo
            FROM dbo.Productos product WITH (UPDLOCK, HOLDLOCK)
            WHERE product.ProductoId = @LockProductId;
            IF @LockName IS NOT NULL
            BEGIN
                INSERT INTO @LockedProducts
                    (ProductoId, Nombre, Categoria, Descripcion, Precio, Stock, ImagenUrl, Activo)
                VALUES
                    (@LockProductId, @LockName, @LockCategory, @LockDescription,
                     @LockPrice, @LockStock, @LockImage, @LockActive);
            END;
            FETCH NEXT FROM inventory_cursor INTO @LockProductId;
        END;
        CLOSE inventory_cursor;
        DEALLOCATE inventory_cursor;

        IF EXISTS
        (
            SELECT 1
            FROM @Requirements requirement
            LEFT JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
            WHERE requirement.CantidadCarrito > 0
              AND (product.ProductoId IS NULL OR product.Activo = 0)
        )
            THROW 54613, N'Uno o más productos o componentes no están disponibles.', 1;

        DECLARE @CartProducts TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            Cantidad INT NOT NULL,
            Nombre NVARCHAR(150) NOT NULL,
            Categoria NVARCHAR(100) NOT NULL,
            Descripcion NVARCHAR(255) NULL,
            Precio DECIMAL(18,2) NOT NULL,
            ImagenUrl NVARCHAR(300) NULL
        );
        INSERT INTO @CartProducts
            (ProductoId, Cantidad, Nombre, Categoria, Descripcion, Precio, ImagenUrl)
        SELECT item.ProductoId, item.Cantidad, product.Nombre, product.Categoria,
               product.Descripcion, product.Precio, product.ImagenUrl
        FROM @Items item
        INNER JOIN @LockedProducts product ON product.ProductoId = item.ProductoId AND product.Activo = 1
        WHERE item.Tipo = N'Producto';
        IF (SELECT COUNT(*) FROM @CartProducts) <> (SELECT COUNT(*) FROM @Items WHERE Tipo = N'Producto')
            THROW 54614, N'Uno o más productos no están disponibles.', 1;

        DECLARE @Applications TABLE
        (
            PromocionId INT NOT NULL,
            ProductoId INT NOT NULL,
            TipoBeneficio NVARCHAR(20) NOT NULL,
            MontoDescontado DECIMAL(18,2) NULL,
            UnidadesRegalo INT NULL,
            ProductoRegaloId INT NULL,
            Prioridad INT NOT NULL,
            PRIMARY KEY (PromocionId, ProductoId)
        );
        INSERT INTO @Applications
            (PromocionId, ProductoId, TipoBeneficio, MontoDescontado,
             UnidadesRegalo, ProductoRegaloId, Prioridad)
        SELECT candidate.PromocionId,
               candidate.ProductoId,
               IIF(candidate.Tipo = N'DescuentoPorcentual', N'Descuento', N'Regalia'),
               CASE WHEN candidate.Tipo = N'DescuentoPorcentual'
                    THEN ROUND(product.Cantidad * product.Precio * candidate.PorcentajeDescuento / 100.0, 2)
               END,
               CASE WHEN candidate.Tipo = N'RegaliaPorVolumen'
                    THEN (candidate.CantidadComprada / candidate.CantidadMinima) * candidate.CantidadRegalo
               END,
               candidate.ProductoRegaloId,
               candidate.Prioridad
        FROM @Candidates candidate
        INNER JOIN @CartProducts product ON product.ProductoId = candidate.ProductoId
        LEFT JOIN @LockedProducts gift
            ON gift.ProductoId = candidate.ProductoRegaloId AND gift.Activo = 1
        WHERE (candidate.Tipo = N'DescuentoPorcentual' AND candidate.PorcentajeDescuento > 0)
           OR (candidate.Tipo = N'RegaliaPorVolumen' AND gift.ProductoId IS NOT NULL
               AND candidate.CantidadRegalo > 0);

        ;WITH Allocation AS
        (
            SELECT application.PromocionId,
                   application.ProductoId,
                   CASE
                       WHEN locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ) <= 0 THEN 0
                       WHEN application.UnidadesRegalo <= locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ) THEN application.UnidadesRegalo
                       ELSE CONVERT(INT, locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ))
                   END AS Permitidas
            FROM @Applications application
            INNER JOIN @Requirements requirement ON requirement.ProductoId = application.ProductoRegaloId
            INNER JOIN @LockedProducts locked ON locked.ProductoId = application.ProductoRegaloId
            WHERE application.TipoBeneficio = N'Regalia'
        )
        UPDATE application
        SET UnidadesRegalo = allocation.Permitidas
        FROM @Applications application
        INNER JOIN Allocation allocation
            ON allocation.PromocionId = application.PromocionId
           AND allocation.ProductoId = application.ProductoId;
        DELETE FROM @Applications WHERE TipoBeneficio = N'Regalia' AND ISNULL(UnidadesRegalo, 0) <= 0;

        UPDATE requirement
        SET CantidadRegalo = gifts.Total
        FROM @Requirements requirement
        INNER JOIN
        (
            SELECT ProductoRegaloId, SUM(CONVERT(BIGINT, UnidadesRegalo)) AS Total
            FROM @Applications
            WHERE TipoBeneficio = N'Regalia'
            GROUP BY ProductoRegaloId
        ) gifts ON gifts.ProductoRegaloId = requirement.ProductoId;

        IF EXISTS
        (
            SELECT 1
            FROM @Requirements requirement
            INNER JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
            WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > product.Stock
               OR requirement.CantidadCarrito + requirement.CantidadRegalo > 2147483647
        )
            THROW 54615, N'No hay stock suficiente para completar el pedido.', 1;

        INSERT INTO dbo.Pedidos
        (
            UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total,
            Observaciones, IdentificacionCliente, MetodoPago, EstadoPago,
            ReferenciaPago, FechaPago, InventarioDescontado, FechaActualizacion
        )
        VALUES
        (
            @UsuarioId, SYSDATETIME(), N'Pendiente', @TipoEntrega, LEFT(@DireccionEntrega, 255), 0,
            LEFT(@Observaciones, 255), @IdentificacionCliente, @MetodoPago, N'Confirmado simulado',
            @ReferenciaPago, SYSDATETIME(), 0, SYSDATETIME()
        );
        SET @PedidoId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.PedidoDetalle
            (PedidoId, ProductoId, Cantidad, PrecioUnitario, ProductoNombreSnapshot, EsRegalo)
        SELECT @PedidoId, ProductoId, Cantidad, Precio, Nombre, 0
        FROM @CartProducts;

        DECLARE @CreatedCombos TABLE (PedidoComboId INT NOT NULL, ComboId INT NOT NULL PRIMARY KEY);
        INSERT INTO dbo.PedidoCombos
            (PedidoId, ComboId, ComboNombreSnapshot, ComboDescripcionSnapshot, Cantidad, PrecioUnitario)
        OUTPUT inserted.PedidoComboId, inserted.ComboId INTO @CreatedCombos (PedidoComboId, ComboId)
        SELECT @PedidoId, ComboId, Nombre, Descripcion, Cantidad, Precio
        FROM @CartCombos;
        INSERT INTO dbo.PedidoComboDetalle
            (PedidoComboId, ProductoId, ProductoNombreSnapshot, CantidadPorCombo, CantidadTotal)
        SELECT created.PedidoComboId,
               detail.ProductoId,
               product.Nombre,
               detail.Cantidad,
               detail.Cantidad * cart.Cantidad
        FROM @CreatedCombos created
        INNER JOIN @CartCombos cart ON cart.ComboId = created.ComboId
        INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = created.ComboId
        INNER JOIN @LockedProducts product ON product.ProductoId = detail.ProductoId;

        INSERT INTO dbo.PedidoDetalle
            (PedidoId, ProductoId, Cantidad, PrecioUnitario, ProductoNombreSnapshot, EsRegalo)
        SELECT @PedidoId,
               application.ProductoRegaloId,
               SUM(application.UnidadesRegalo),
               0,
               product.Nombre,
               1
        FROM @Applications application
        INNER JOIN @LockedProducts product ON product.ProductoId = application.ProductoRegaloId
        WHERE application.TipoBeneficio = N'Regalia'
        GROUP BY application.ProductoRegaloId, product.Nombre;

        UPDATE detail
        SET detail.PrecioUnitario = CONVERT
            (
                DECIMAL(18,2),
                CASE WHEN detail.Cantidad > 0
                     THEN (detail.PrecioUnitario * detail.Cantidad - discount.Total) / detail.Cantidad
                     ELSE detail.PrecioUnitario END
            )
        FROM dbo.PedidoDetalle detail
        INNER JOIN
        (
            SELECT ProductoId, SUM(MontoDescontado) AS Total
            FROM @Applications
            WHERE TipoBeneficio = N'Descuento'
            GROUP BY ProductoId
        ) discount ON discount.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.EsRegalo = 0
          AND detail.PedidoComboId IS NULL;

        UPDATE product
        SET product.Stock = product.Stock - CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo)
        FROM dbo.Productos product
        INNER JOIN @Requirements requirement ON requirement.ProductoId = product.ProductoId
        WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > 0
          AND product.Stock >= requirement.CantidadCarrito + requirement.CantidadRegalo;
        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Requirements WHERE CantidadCarrito + CantidadRegalo > 0)
            THROW 54616, N'El inventario cambió durante el checkout. Intente nuevamente.', 1;

        INSERT INTO dbo.MovimientosInventario
            (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
             Motivo, UsuarioId, UsuarioNombre, FechaMovimiento)
        SELECT requirement.ProductoId,
               product.Nombre,
               N'Salida',
               CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo),
               product.Stock,
               product.Stock - CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo),
               CONCAT(N'Pedido #', @PedidoId, N' (productos, combos y regalías)'),
               @UsuarioId,
               @NombreUsuario,
               SYSDATETIME()
        FROM @Requirements requirement
        INNER JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
        WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > 0;

        INSERT INTO dbo.PromocionAplicaciones
            (PromocionId, PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo)
        SELECT PromocionId, @PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo
        FROM @Applications;

        UPDATE dbo.Pedidos
        SET Total =
            ISNULL((SELECT SUM(detail.Cantidad * detail.PrecioUnitario)
                    FROM dbo.PedidoDetalle detail
                    WHERE detail.PedidoId = @PedidoId
                      AND detail.PedidoComboId IS NULL), 0)
            + ISNULL((SELECT SUM(combo.Cantidad * combo.PrecioUnitario)
                      FROM dbo.PedidoCombos combo WHERE combo.PedidoId = @PedidoId), 0),
            InventarioDescontado = 1,
            FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;

        INSERT INTO dbo.CheckoutOperaciones (UsuarioId, TokenOperacion, SolicitudHash, PedidoId)
        VALUES (@UsuarioId, @TokenOperacion, @SolicitudHash, @PedidoId);
        INSERT INTO dbo.InventarioOperacionAuditoria
            (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
        VALUES
            (N'Checkout', @PedidoId, N'Crear pedido', @UsuarioId, @NombreUsuario,
             CONCAT(N'Pedido creado con token idempotente ', CONVERT(NVARCHAR(36), @TokenOperacion), N'.'));

        COMMIT TRANSACTION;
        EXEC dbo.sp_Store_GetCheckoutResult @PedidoId = @PedidoId, @UsuarioId = @UsuarioId;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N'local', N'inventory_cursor') >= 0 CLOSE inventory_cursor;
        IF CURSOR_STATUS(N'local', N'inventory_cursor') > -3 DEALLOCATE inventory_cursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrders
    @Estado NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT orders.PedidoId,
           userAccount.NombreCompleto,
           userAccount.Correo,
           orders.FechaPedido,
           orders.Estado,
           orders.TipoEntrega,
           orders.DireccionEntrega,
           orders.Total,
           (SELECT COUNT(*) FROM dbo.PedidoDetalle detail
            WHERE detail.PedidoId = orders.PedidoId
              AND detail.PedidoComboId IS NULL)
           + (SELECT COUNT(*) FROM dbo.PedidoCombos combo WHERE combo.PedidoId = orders.PedidoId) AS TotalLineas
    FROM dbo.Pedidos orders
    INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = orders.UsuarioId
    WHERE @Estado IS NULL OR orders.Estado = @Estado
    ORDER BY orders.FechaPedido DESC, orders.PedidoId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderDetailLines
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT result.PedidoDetalleId,
           result.Nombre,
           result.ProductoId,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal,
           result.StockActual,
           result.EsCombo
    FROM
    (
        SELECT detail.PedidoDetalleId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre) AS Nombre,
               detail.ProductoId,
               detail.Cantidad,
               detail.PrecioUnitario,
               CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario) AS Subtotal,
               product.Stock AS StockActual,
               CONVERT(BIT, 0) AS EsCombo,
               1 AS SortOrder,
               detail.PedidoDetalleId AS SortId
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.PedidoComboId IS NULL

        UNION ALL

        SELECT -combo.PedidoComboId,
               CONCAT(N'Combo: ', combo.ComboNombreSnapshot),
               combo.ComboId,
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               ISNULL(availability.StockDisponible, 0),
               CONVERT(BIT, 1),
               2,
               combo.PedidoComboId
        FROM dbo.PedidoCombos combo
        OUTER APPLY
        (
            SELECT CONVERT(INT, MIN(product.Stock / NULLIF(component.CantidadPorCombo, 0))) AS StockDisponible
            FROM dbo.PedidoComboDetalle component
            INNER JOIN dbo.Productos product ON product.ProductoId = component.ProductoId
            WHERE component.PedidoComboId = combo.PedidoComboId
        ) availability
        WHERE combo.PedidoId = @PedidoId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Inventory_RestoreOrderStock
    @PedidoId INT,
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL,
    @Motivo NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MovementUserId INT;
    DECLARE @MovementUserName NVARCHAR(150);
    SELECT @MovementUserId = userAccount.UsuarioId,
           @MovementUserName = userAccount.NombreCompleto
    FROM dbo.Usuarios userAccount
    WHERE userAccount.UsuarioId = @UsuarioId;
    IF @MovementUserId IS NULL
    BEGIN
        SELECT @MovementUserId = orders.UsuarioId,
               @MovementUserName = userAccount.NombreCompleto
        FROM dbo.Pedidos orders
        INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = orders.UsuarioId
        WHERE orders.PedidoId = @PedidoId;
    END;
    SET @MovementUserName = COALESCE(NULLIF(LTRIM(RTRIM(@UsuarioNombre)), N''), @MovementUserName, N'Sistema');
    SET @Motivo = COALESCE(NULLIF(LTRIM(RTRIM(@Motivo)), N''), CONCAT(N'Restauración de pedido #', @PedidoId));

    DECLARE @Restore TABLE
    (
        ProductoId INT NOT NULL PRIMARY KEY,
        Cantidad BIGINT NOT NULL,
        ProductoNombre NVARCHAR(150) NULL,
        StockAnterior INT NULL,
        StockNuevo INT NULL
    );
    INSERT INTO @Restore (ProductoId, Cantidad)
    SELECT source.ProductoId, SUM(CONVERT(BIGINT, source.Cantidad))
    FROM
    (
        SELECT detail.ProductoId, detail.Cantidad
        FROM dbo.PedidoDetalle detail
        WHERE detail.PedidoId = @PedidoId
          AND detail.PedidoComboId IS NULL
        UNION ALL
        SELECT component.ProductoId, component.CantidadTotal
        FROM dbo.PedidoCombos combo
        INNER JOIN dbo.PedidoComboDetalle component ON component.PedidoComboId = combo.PedidoComboId
        WHERE combo.PedidoId = @PedidoId
    ) source
    GROUP BY source.ProductoId;
    IF EXISTS (SELECT 1 FROM @Restore WHERE Cantidad > 2147483647)
        THROW 54630, N'La cantidad a restaurar excede el límite permitido.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @RestoreProductId INT;
        DECLARE @RestoreName NVARCHAR(150);
        DECLARE @RestoreStock INT;
        DECLARE restore_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ProductoId FROM @Restore ORDER BY ProductoId;
        OPEN restore_cursor;
        FETCH NEXT FROM restore_cursor INTO @RestoreProductId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @RestoreName = NULL, @RestoreStock = NULL;
            SELECT @RestoreName = product.Nombre, @RestoreStock = product.Stock
            FROM dbo.Productos product WITH (UPDLOCK, HOLDLOCK)
            WHERE product.ProductoId = @RestoreProductId;
            IF @RestoreName IS NULL
                THROW 54631, N'No fue posible localizar un producto del pedido.', 1;
            IF CONVERT(BIGINT, @RestoreStock)
               + (SELECT Cantidad FROM @Restore WHERE ProductoId = @RestoreProductId) > 2147483647
                THROW 54632, N'La restauración excede el límite de stock permitido.', 1;
            UPDATE @Restore
            SET ProductoNombre = @RestoreName,
                StockAnterior = @RestoreStock,
                StockNuevo = @RestoreStock + CONVERT(INT, Cantidad)
            WHERE ProductoId = @RestoreProductId;
            FETCH NEXT FROM restore_cursor INTO @RestoreProductId;
        END;
        CLOSE restore_cursor;
        DEALLOCATE restore_cursor;

        UPDATE product
        SET product.Stock = restored.StockNuevo
        FROM dbo.Productos product
        INNER JOIN @Restore restored ON restored.ProductoId = product.ProductoId;
        INSERT INTO dbo.MovimientosInventario
            (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
             Motivo, UsuarioId, UsuarioNombre, FechaMovimiento)
        SELECT ProductoId, ProductoNombre, N'Entrada', CONVERT(INT, Cantidad), StockAnterior, StockNuevo,
               LEFT(@Motivo, 250), @MovementUserId, @MovementUserName, SYSDATETIME()
        FROM @Restore;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N'local', N'restore_cursor') >= 0 CLOSE restore_cursor;
        IF CURSOR_STATUS(N'local', N'restore_cursor') > -3 DEALLOCATE restore_cursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_CancelPendingOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PedidoId <= 0 OR @UsuarioId <= 0
    BEGIN
        SELECT CONVERT(BIT, 0) AS Cancelado;
        RETURN;
    END;

    DECLARE @Estado NVARCHAR(30);
    DECLARE @InventarioDescontado BIT;
    DECLARE @UsuarioNombre NVARCHAR(150);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @Estado = orders.Estado,
               @InventarioDescontado = orders.InventarioDescontado,
               @UsuarioNombre = userAccount.NombreCompleto
        FROM dbo.Pedidos orders WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = orders.UsuarioId
        WHERE orders.PedidoId = @PedidoId AND orders.UsuarioId = @UsuarioId;

        IF @Estado IS NULL OR @Estado <> N'Pendiente'
           OR EXISTS (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CONVERT(BIT, 0) AS Cancelado;
            RETURN;
        END;

        IF @InventarioDescontado = 1
            EXEC dbo.sp_Inventory_RestoreOrderStock
                @PedidoId = @PedidoId,
                @UsuarioId = @UsuarioId,
                @UsuarioNombre = @UsuarioNombre,
                @Motivo = N'Cancelación solicitada por el cliente.';

        UPDATE dbo.Pedidos
        SET Estado = N'Cancelado', InventarioDescontado = 0, FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId AND Estado = N'Pendiente';
        IF @@ROWCOUNT <> 1
            THROW 54633, N'El pedido cambió durante la cancelación.', 1;
        COMMIT TRANSACTION;
        SELECT CONVERT(BIT, 1) AS Cancelado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId INT,
    @NuevoEstado NVARCHAR(50),
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @NuevoEstado = NULLIF(LTRIM(RTRIM(@NuevoEstado)), N'');

    IF @PedidoId <= 0 THROW 51001, N'El pedido indicado no es válido.', 1;
    IF @NuevoEstado IS NULL OR @NuevoEstado NOT IN
       (N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado', N'Cancelado', N'Retenido', N'Liberado', N'Rechazado')
        THROW 51002, N'El estado indicado no es válido.', 1;

    DECLARE @EstadoActual NVARCHAR(30);
    DECLARE @TieneFactura BIT;
    DECLARE @InventarioDescontado BIT;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @EstadoActual = Estado, @InventarioDescontado = InventarioDescontado
        FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
        WHERE PedidoId = @PedidoId;
        IF @EstadoActual IS NULL THROW 51003, N'No se encontró el pedido solicitado.', 1;

        SET @TieneFactura = IIF(EXISTS
            (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId), 1, 0);
        IF @TieneFactura = 1 AND @NuevoEstado <> N'Entregado'
            THROW 51004, N'El pedido facturado debe permanecer como Entregado.', 1;
        IF @EstadoActual IN (N'Cancelado', N'Rechazado') AND @EstadoActual <> @NuevoEstado
            THROW 51005, N'No se puede cambiar el estado de un pedido cancelado o rechazado.', 1;
        IF @TieneFactura = 0 AND @EstadoActual <> @NuevoEstado
           AND NOT
           (
               (@EstadoActual = N'Pendiente' AND @NuevoEstado IN (N'Aprobado', N'Cancelado'))
            OR (@EstadoActual = N'Aprobado' AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
            OR (@EstadoActual = N'EnProceso' AND @NuevoEstado IN (N'Entregado', N'Cancelado'))
            OR (@EstadoActual = N'Entregado' AND @NuevoEstado = N'Cancelado')
            OR (@EstadoActual = N'Retenido' AND @NuevoEstado IN (N'Liberado', N'Rechazado', N'Cancelado'))
            OR (@EstadoActual = N'Liberado' AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
           )
            THROW 51006, N'La transición de estado solicitada no es válida.', 1;

        IF @NuevoEstado IN (N'Cancelado', N'Rechazado')
           AND @InventarioDescontado = 1 AND @TieneFactura = 0
            EXEC dbo.sp_Inventory_RestoreOrderStock
                @PedidoId = @PedidoId,
                @UsuarioId = @UsuarioId,
                @UsuarioNombre = @UsuarioNombre,
                @Motivo = N'Cancelación o rechazo administrativo del pedido.';

        UPDATE dbo.Pedidos
        SET Estado = @NuevoEstado,
            FechaActualizacion = SYSDATETIME(),
            InventarioDescontado = CASE
                WHEN @NuevoEstado IN (N'Cancelado', N'Rechazado') AND @TieneFactura = 0 THEN 0
                ELSE InventarioDescontado END
        WHERE PedidoId = @PedidoId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GenerateInvoiceFromOrder
    @PedidoId INT,
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @PedidoId <= 0 THROW 50901, N'El pedido indicado no es válido.', 1;

    DECLARE @PedidoUsuarioId INT;
    DECLARE @Estado NVARCHAR(30);
    DECLARE @ClienteNombre NVARCHAR(150);
    DECLARE @ClienteCorreo NVARCHAR(150);
    DECLARE @Subtotal DECIMAL(18,2);
    DECLARE @Impuesto DECIMAL(18,2);
    DECLARE @Total DECIMAL(18,2);
    DECLARE @FacturaId INT;
    DECLARE @NumeroFactura NVARCHAR(30);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @PedidoUsuarioId = orders.UsuarioId,
               @Estado = orders.Estado,
               @ClienteNombre = userAccount.NombreCompleto,
               @ClienteCorreo = userAccount.Correo
        FROM dbo.Pedidos orders WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = orders.UsuarioId
        WHERE orders.PedidoId = @PedidoId;
        IF @PedidoUsuarioId IS NULL THROW 50902, N'No se encontró el pedido solicitado.', 1;
        IF @Estado NOT IN (N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado', N'Liberado')
            THROW 50903, N'El estado del pedido no permite facturación.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK) WHERE PedidoId = @PedidoId)
            THROW 50904, N'El pedido ya tiene una factura asociada.', 1;
        IF NOT EXISTS
           (
               SELECT 1
               FROM dbo.PedidoDetalle
               WHERE PedidoId = @PedidoId
                 AND PedidoComboId IS NULL
           )
           AND NOT EXISTS (SELECT 1 FROM dbo.PedidoCombos WHERE PedidoId = @PedidoId)
            THROW 50905, N'El pedido no tiene líneas para facturar.', 1;

        SELECT @Subtotal =
            ISNULL((SELECT SUM(detail.Cantidad * detail.PrecioUnitario)
                    FROM dbo.PedidoDetalle detail
                    WHERE detail.PedidoId = @PedidoId
                      AND detail.PedidoComboId IS NULL), 0)
            + ISNULL((SELECT SUM(combo.Cantidad * combo.PrecioUnitario)
                      FROM dbo.PedidoCombos combo WHERE combo.PedidoId = @PedidoId), 0);
        SET @Impuesto = ROUND(@Subtotal * 0.13, 2);
        SET @Total = @Subtotal + @Impuesto;
        SET @NumeroFactura = CONCAT
        (
            N'FAC-', FORMAT(SYSDATETIME(), N'yyyyMMddHHmmss'), N'-',
            RIGHT(CONCAT(N'0000', CONVERT(NVARCHAR(10), @PedidoId)), 4)
        );

        INSERT INTO dbo.Facturas
            (PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo,
             Subtotal, Impuesto, Total, Estado)
        VALUES
            (@PedidoId, @NumeroFactura, @PedidoUsuarioId, @ClienteNombre, @ClienteCorreo,
             @Subtotal, @Impuesto, @Total, N'Generada');
        SET @FacturaId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.FacturaDetalle
            (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
        SELECT @FacturaId,
               detail.ProductoId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre),
               detail.Cantidad,
               detail.PrecioUnitario
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.PedidoComboId IS NULL;
        INSERT INTO dbo.FacturaCombos
            (FacturaId, PedidoComboId, ComboNombreSnapshot, Cantidad, PrecioUnitario)
        SELECT @FacturaId, combo.PedidoComboId, combo.ComboNombreSnapshot, combo.Cantidad, combo.PrecioUnitario
        FROM dbo.PedidoCombos combo
        WHERE combo.PedidoId = @PedidoId;

        UPDATE dbo.Pedidos SET Estado = N'Entregado', FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;
        COMMIT TRANSACTION;

        SELECT @FacturaId AS FacturaId,
               @PedidoId AS PedidoId,
               @NumeroFactura AS NumeroFactura,
               N'Entregado' AS EstadoPedido;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetInvoiceLines
    @FacturaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT result.ProductoNombre,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal
    FROM
    (
        SELECT detail.ProductoNombre,
               detail.Cantidad,
               detail.PrecioUnitario,
               CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario) AS Subtotal,
               1 AS SortOrder,
               detail.FacturaDetalleId AS SortId
        FROM dbo.FacturaDetalle detail
        WHERE detail.FacturaId = @FacturaId
        UNION ALL
        SELECT CONCAT(N'Combo: ', combo.ComboNombreSnapshot),
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               2,
               combo.FacturaComboId
        FROM dbo.FacturaCombos combo
        WHERE combo.FacturaId = @FacturaId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_GetInvoiceLinesByOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT result.ProductoNombre,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal
    FROM
    (
        SELECT detail.ProductoNombre,
               detail.Cantidad,
               detail.PrecioUnitario,
               CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario) AS Subtotal,
               1 AS SortOrder,
               detail.FacturaDetalleId AS SortId
        FROM dbo.FacturaDetalle detail
        INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = detail.FacturaId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = invoice.PedidoId
        WHERE invoice.PedidoId = @PedidoId
          AND invoice.UsuarioId = @UsuarioId
          AND orders.UsuarioId = @UsuarioId
        UNION ALL
        SELECT CONCAT(N'Combo: ', combo.ComboNombreSnapshot),
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               2,
               combo.FacturaComboId
        FROM dbo.FacturaCombos combo
        INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = combo.FacturaId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = invoice.PedidoId
        WHERE invoice.PedidoId = @PedidoId
          AND invoice.UsuarioId = @UsuarioId
          AND orders.UsuarioId = @UsuarioId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;
GO

/* Fin de contratos de checkout, pedidos, restauración e invoice snapshots. */

IF XACT_STATE() <> 1
    THROW 54590, N'La transacción de la migración 0012 no está disponible para confirmar.', 1;

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
DECLARE @LegacyManifestSha256 CHAR(64) = CONVERT
(
    CHAR(64),
    HASHBYTES('SHA2_256', N'0012_inventory_combos_transformations_intelligence_v1'),
    2
);

IF LEN(@MigrationSha256) <> 64
   OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 54593, N'El SHA-256 de 0012 debe llegar expandido por sqlcmd como 64 caracteres hexadecimales.', 1;

SET @MigrationSha256 = UPPER(@MigrationSha256);
IF @MigrationSha256 = @LegacyManifestSha256
    THROW 54594, N'El SHA-256 de 0012 no puede ser el manifiesto de versión heredado.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0012_inventory_combos_transformations_intelligence')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0012_inventory_combos_transformations_intelligence',
         N'0012_inventory_combos_transformations_intelligence.sql',
         @MigrationSha256,
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Combos vendibles, transformación atómica e inteligencia de inventario con snapshots e idempotencia.');
END;

COMMIT TRANSACTION;
GO

-- Validaciones posteriores de contrato. No modifican datos.
IF OBJECT_ID(N'dbo.sp_Admin_GetCombos', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetComboDetail', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_CreateCombo', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_AddComboDetail', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_ToggleComboStatus', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Inventory_TransformStockAtomic', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetPurchaseSuggestions', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetSlowMovingProducts', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetSeasonalSalesTrend', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Store_GetActiveCombos', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Store_GetComboById', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Store_GetCheckoutResult', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Store_CreateOrderWithPromotions', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Inventory_RestoreOrderStock', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetOrderDetailLines', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GenerateInvoiceFromOrder', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetInvoiceLines', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Client_GetInvoiceLinesByOrder', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Client_CancelPendingOrder', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_UpdateOrderStatus', N'P') IS NULL
    THROW 54591, N'La verificación posterior detectó procedimientos faltantes.', 1;

IF (SELECT COUNT(*) FROM dbo.Permisos
    WHERE Codigo IN (N'COMBOS_VER', N'COMBOS_GESTIONAR', N'INVENTARIO_TRANSFORMAR', N'INVENTARIO_INTELIGENCIA_VER')
      AND Activo = 1) <> 4
    THROW 54592, N'La verificación posterior detectó permisos faltantes.', 1;
GO
