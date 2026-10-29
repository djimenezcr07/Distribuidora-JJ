/*
  Verificación de sólo lectura para 0012.
  Ejecute después de aplicar 0012, contra la base seleccionada explícitamente.
  No inserta, actualiza ni elimina datos.
*/
SET NOCOUNT ON;

IF (SELECT COUNT(*)
    FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0012_inventory_combos_transformations_intelligence'
      AND Status = N'Applied') <> 1
    THROW 54600, N'El ledger no confirma una única aplicación exitosa de 0012.', 1;

DECLARE @MigrationSha256 NVARCHAR(128);
SELECT @MigrationSha256 = FileSha256
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0012_inventory_combos_transformations_intelligence'
  AND Status = N'Applied';

IF @MigrationSha256 IS NULL
   OR LEN(@MigrationSha256) <> 64
   OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
   OR @MigrationSha256 = N'$' + N'(MigrationSha256)'
   OR UPPER(@MigrationSha256) = CONVERT
      (CHAR(64), HASHBYTES('SHA2_256', N'0012_inventory_combos_transformations_intelligence_v1'), 2)
    THROW 54601, N'El ledger de 0012 no contiene un SHA-256 real válido del archivo.', 1;

DECLARE @ObjetosEsperados TABLE
(
    ObjectName SYSNAME NOT NULL,
    ObjectType CHAR(2) NOT NULL
);

INSERT INTO @ObjetosEsperados (ObjectName, ObjectType)
VALUES
    (N'dbo.Combos', N'U'),
    (N'dbo.ComboDetalle', N'U'),
    (N'dbo.PedidoCombos', N'U'),
    (N'dbo.PedidoComboDetalle', N'U'),
    (N'dbo.FacturaCombos', N'U'),
    (N'dbo.CheckoutOperaciones', N'U'),
    (N'dbo.InventarioTransformaciones', N'U'),
    (N'dbo.InventarioOperacionAuditoria', N'U'),
    (N'dbo.sp_Admin_GetCombos', N'P'),
    (N'dbo.sp_Admin_GetComboDetail', N'P'),
    (N'dbo.sp_Admin_CreateCombo', N'P'),
    (N'dbo.sp_Admin_AddComboDetail', N'P'),
    (N'dbo.sp_Admin_ToggleComboStatus', N'P'),
    (N'dbo.sp_Store_GetActiveCombos', N'P'),
    (N'dbo.sp_Store_GetComboById', N'P'),
    (N'dbo.sp_Store_GetCheckoutResult', N'P'),
    (N'dbo.sp_Store_CreateOrderWithPromotions', N'P'),
    (N'dbo.sp_Inventory_TransformStockAtomic', N'P'),
    (N'dbo.sp_Inventory_RestoreOrderStock', N'P'),
    (N'dbo.sp_Admin_GetPurchaseSuggestions', N'P'),
    (N'dbo.sp_Admin_GetSlowMovingProducts', N'P'),
    (N'dbo.sp_Admin_GetSeasonalSalesTrend', N'P'),
    (N'dbo.sp_Admin_GetOrders', N'P'),
    (N'dbo.sp_Admin_GetOrderDetailLines', N'P'),
    (N'dbo.sp_Client_CancelPendingOrder', N'P'),
    (N'dbo.sp_Admin_UpdateOrderStatus', N'P'),
    (N'dbo.sp_Admin_GenerateInvoiceFromOrder', N'P'),
    (N'dbo.sp_Admin_GetInvoiceLines', N'P'),
    (N'dbo.sp_Client_GetInvoiceLinesByOrder', N'P');

IF EXISTS
(
    SELECT 1
    FROM @ObjetosEsperados expected
    WHERE OBJECT_ID(expected.ObjectName, expected.ObjectType) IS NULL
)
    THROW 54602, N'Faltan objetos esperados de 0012.', 1;

DECLARE @ColumnasEsperadas TABLE
(
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL,
    TypeName SYSNAME NOT NULL,
    MaxLength SMALLINT NULL,
    PrecisionValue TINYINT NULL,
    ScaleValue TINYINT NULL,
    IsNullable BIT NOT NULL,
    IsComputed BIT NOT NULL,
    IsPersisted BIT NULL
);

INSERT INTO @ColumnasEsperadas
    (TableName, ColumnName, TypeName, MaxLength, PrecisionValue, ScaleValue,
     IsNullable, IsComputed, IsPersisted)
VALUES
    (N'Combos', N'ComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'Combos', N'Nombre', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'Combos', N'Descripcion', N'nvarchar', 1000, NULL, NULL, 1, 0, NULL),
    (N'Combos', N'Precio', N'decimal', 9, 18, 2, 0, 0, NULL),
    (N'Combos', N'Activo', N'bit', 1, 1, 0, 0, 0, NULL),
    (N'Combos', N'RegistradoPorUsuarioId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'Combos', N'RegistradoPorNombre', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'Combos', N'FechaCreacionUtc', N'datetime2', 8, NULL, 7, 0, 0, NULL),
    (N'Combos', N'ActualizadoPorUsuarioId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'Combos', N'ActualizadoPorNombre', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'Combos', N'FechaActualizacionUtc', N'datetime2', 8, NULL, 7, 0, 0, NULL),
    (N'ComboDetalle', N'ComboDetalleId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'ComboDetalle', N'ComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'ComboDetalle', N'ProductoId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'ComboDetalle', N'Cantidad', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoCombos', N'PedidoComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoCombos', N'PedidoId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoCombos', N'ComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoCombos', N'ComboNombreSnapshot', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'PedidoCombos', N'ComboDescripcionSnapshot', N'nvarchar', 1000, NULL, NULL, 1, 0, NULL),
    (N'PedidoCombos', N'Cantidad', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoCombos', N'PrecioUnitario', N'decimal', 9, 18, 2, 0, 0, NULL),
    (N'PedidoCombos', N'Subtotal', N'decimal', 9, 18, 2, 1, 1, 1),
    (N'PedidoCombos', N'FechaCreacionUtc', N'datetime2', 8, NULL, 7, 0, 0, NULL),
    (N'PedidoComboDetalle', N'PedidoComboDetalleId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoComboDetalle', N'PedidoComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoComboDetalle', N'ProductoId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoComboDetalle', N'ProductoNombreSnapshot', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'PedidoComboDetalle', N'CantidadPorCombo', N'int', 4, 10, 0, 0, 0, NULL),
    (N'PedidoComboDetalle', N'CantidadTotal', N'int', 4, 10, 0, 0, 0, NULL),
    (N'FacturaCombos', N'FacturaComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'FacturaCombos', N'FacturaId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'FacturaCombos', N'PedidoComboId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'FacturaCombos', N'ComboNombreSnapshot', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'FacturaCombos', N'Cantidad', N'int', 4, 10, 0, 0, 0, NULL),
    (N'FacturaCombos', N'PrecioUnitario', N'decimal', 9, 18, 2, 0, 0, NULL),
    (N'FacturaCombos', N'Subtotal', N'decimal', 9, 18, 2, 1, 1, 1),
    (N'CheckoutOperaciones', N'CheckoutOperacionId', N'bigint', 8, 19, 0, 0, 0, NULL),
    (N'CheckoutOperaciones', N'UsuarioId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'CheckoutOperaciones', N'TokenOperacion', N'uniqueidentifier', 16, NULL, NULL, 0, 0, NULL),
    (N'CheckoutOperaciones', N'SolicitudHash', N'binary', 32, NULL, NULL, 0, 0, NULL),
    (N'CheckoutOperaciones', N'PedidoId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'CheckoutOperaciones', N'FechaCreacionUtc', N'datetime2', 6, 19, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'InventarioTransformacionId', N'bigint', 8, 19, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'ReferenciaTransformacion', N'uniqueidentifier', 16, NULL, NULL, 0, 0, NULL),
    (N'InventarioTransformaciones', N'ProductoOrigenId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'CantidadOrigen', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'ProductoDestinoId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'CantidadDestino', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'UsuarioId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioTransformaciones', N'UsuarioNombre', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'InventarioTransformaciones', N'Motivo', N'nvarchar', 600, NULL, NULL, 1, 0, NULL),
    (N'InventarioTransformaciones', N'FechaCreacionUtc', N'datetime2', 6, 19, 0, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'AuditoriaId', N'bigint', 8, 19, 0, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'Modulo', N'nvarchar', 100, NULL, NULL, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'EntidadId', N'int', 4, 10, 0, 1, 0, NULL),
    (N'InventarioOperacionAuditoria', N'Accion', N'nvarchar', 100, NULL, NULL, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'UsuarioId', N'int', 4, 10, 0, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'UsuarioNombre', N'nvarchar', 300, NULL, NULL, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'Detalle', N'nvarchar', 1000, NULL, NULL, 0, 0, NULL),
    (N'InventarioOperacionAuditoria', N'FechaCreacionUtc', N'datetime2', 6, 19, 0, 0, 0, NULL),
    (N'PedidoDetalle', N'PedidoComboId', N'int', 4, 10, 0, 1, 0, NULL),
    (N'PedidoDetalle', N'ProductoNombreSnapshot', N'nvarchar', 300, NULL, NULL, 1, 0, NULL),
    (N'PedidoDetalle', N'EsRegalo', N'bit', 1, 1, 0, 0, 0, NULL);

IF EXISTS
(
    SELECT 1
    FROM @ColumnasEsperadas expected
    LEFT JOIN sys.tables tableObject ON tableObject.name = expected.TableName
                                  AND SCHEMA_NAME(tableObject.schema_id) = N'dbo'
    LEFT JOIN sys.columns columnObject ON columnObject.object_id = tableObject.object_id
                                      AND columnObject.name = expected.ColumnName
    LEFT JOIN sys.types typeObject ON typeObject.user_type_id = columnObject.user_type_id
    LEFT JOIN sys.computed_columns computedColumn
        ON computedColumn.object_id = columnObject.object_id
       AND computedColumn.column_id = columnObject.column_id
    WHERE columnObject.column_id IS NULL
       OR typeObject.name <> expected.TypeName
       OR (expected.MaxLength IS NOT NULL AND columnObject.max_length <> expected.MaxLength)
       OR (expected.PrecisionValue IS NOT NULL AND columnObject.precision <> expected.PrecisionValue)
       OR (expected.ScaleValue IS NOT NULL AND columnObject.scale <> expected.ScaleValue)
       OR columnObject.is_nullable <> expected.IsNullable
       OR columnObject.is_computed <> expected.IsComputed
       OR (expected.IsPersisted IS NOT NULL AND computedColumn.is_persisted <> expected.IsPersisted)
)
    THROW 54603, N'El contrato de columnas, nulabilidad o cómputo de 0012 es incompatible.', 1;

DECLARE @PrimaryKeysEsperadas TABLE
(
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL
);

INSERT INTO @PrimaryKeysEsperadas (TableName, ColumnName)
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
    FROM @PrimaryKeysEsperadas expected
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
        WHERE primaryIndex.object_id = OBJECT_ID(N'dbo.' + expected.TableName)
          AND primaryIndex.is_primary_key = 1
          AND indexColumn.key_ordinal = 1
          AND columnObject.name = expected.ColumnName
    )
)
    THROW 54604, N'Falta una clave primaria canónica de 0012.', 1;

IF COL_LENGTH(N'dbo.Combos', N'FechaCreacion') IS NOT NULL
   OR EXISTS
      (
          SELECT 1
          FROM sys.columns
          WHERE object_id = OBJECT_ID(N'dbo.PedidoCombos')
            AND name = N'ComboNombre'
            AND is_nullable = 0
      )
    THROW 54605, N'Permanece una columna legada que impide usar únicamente el contrato canónico.', 1;

DECLARE @RestriccionesEsperadas TABLE
(
    ObjectName SYSNAME NOT NULL,
    ObjectType CHAR(2) NOT NULL
);

INSERT INTO @RestriccionesEsperadas (ObjectName, ObjectType)
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
    FROM @RestriccionesEsperadas expected
    WHERE OBJECT_ID(expected.ObjectName, expected.ObjectType) IS NULL
)
    THROW 54606, N'Faltan defaults, checks o restricciones únicas de 0012.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints checkConstraint
    WHERE checkConstraint.parent_object_id IN
          (
              OBJECT_ID(N'dbo.Combos'),
              OBJECT_ID(N'dbo.ComboDetalle'),
              OBJECT_ID(N'dbo.PedidoCombos'),
              OBJECT_ID(N'dbo.PedidoComboDetalle'),
              OBJECT_ID(N'dbo.FacturaCombos'),
              OBJECT_ID(N'dbo.InventarioTransformaciones')
          )
      AND (checkConstraint.is_disabled = 1 OR checkConstraint.is_not_trusted = 1)
)
    THROW 54607, N'Existe un check de 0012 deshabilitado o no confiable.', 1;

DECLARE @ForeignKeysEsperadas TABLE
(
    ParentTable SYSNAME NOT NULL,
    ParentColumn SYSNAME NOT NULL,
    ReferencedTable SYSNAME NOT NULL,
    ReferencedColumn SYSNAME NOT NULL
);

INSERT INTO @ForeignKeysEsperadas
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
    FROM @ForeignKeysEsperadas expected
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys foreignKey
        INNER JOIN sys.foreign_key_columns foreignKeyColumn
            ON foreignKeyColumn.constraint_object_id = foreignKey.object_id
        WHERE foreignKey.parent_object_id = OBJECT_ID(N'dbo.' + expected.ParentTable)
          AND foreignKey.referenced_object_id = OBJECT_ID(N'dbo.' + expected.ReferencedTable)
          AND foreignKeyColumn.parent_column_id = COLUMNPROPERTY
              (OBJECT_ID(N'dbo.' + expected.ParentTable), expected.ParentColumn, N'ColumnId')
          AND foreignKeyColumn.referenced_column_id = COLUMNPROPERTY
              (OBJECT_ID(N'dbo.' + expected.ReferencedTable), expected.ReferencedColumn, N'ColumnId')
          AND foreignKey.is_disabled = 0
          AND foreignKey.is_not_trusted = 0
    )
)
    THROW 54608, N'Falta una clave foránea segura y confiable de 0012.', 1;

DECLARE @IndicesEsperados TABLE
(
    TableName SYSNAME NOT NULL,
    IndexName SYSNAME NOT NULL
);

INSERT INTO @IndicesEsperados (TableName, IndexName)
VALUES
    (N'Combos', N'IX_Combos_Activo_Nombre'),
    (N'ComboDetalle', N'IX_ComboDetalle_ProductoId'),
    (N'PedidoCombos', N'IX_PedidoCombos_PedidoId'),
    (N'PedidoComboDetalle', N'IX_PedidoComboDetalle_ProductoId'),
    (N'InventarioTransformaciones', N'IX_InventarioTransformaciones_Productos_Fecha'),
    (N'InventarioOperacionAuditoria', N'IX_InventarioOperacionAuditoria_Modulo_Fecha');

IF EXISTS
(
    SELECT 1
    FROM @IndicesEsperados expected
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes indexObject
        WHERE indexObject.object_id = OBJECT_ID(N'dbo.' + expected.TableName)
          AND indexObject.name = expected.IndexName
          AND indexObject.is_disabled = 0
          AND indexObject.is_hypothetical = 0
    )
)
    THROW 54609, N'Faltan índices requeridos de 0012.', 1;

IF EXISTS
(
    SELECT detail.ComboId, detail.ProductoId
    FROM dbo.ComboDetalle detail
    GROUP BY detail.ComboId, detail.ProductoId
    HAVING COUNT(*) > 1
)
   OR EXISTS (SELECT 1 FROM dbo.ComboDetalle WHERE Cantidad <= 0)
    THROW 54610, N'ComboDetalle no cumple unicidad o cantidad positiva.', 1;

IF EXISTS
(
    SELECT component.PedidoComboId, component.ProductoId
    FROM dbo.PedidoComboDetalle component
    GROUP BY component.PedidoComboId, component.ProductoId
    HAVING COUNT(*) > 1
)
   OR EXISTS
      (
          SELECT 1
          FROM dbo.PedidoComboDetalle component
          INNER JOIN dbo.PedidoCombos comboOrder
              ON comboOrder.PedidoComboId = component.PedidoComboId
          WHERE component.CantidadPorCombo <= 0
             OR component.CantidadTotal <= 0
             OR CONVERT(BIGINT, component.CantidadPorCombo) * comboOrder.Cantidad
                <> component.CantidadTotal
      )
    THROW 54611, N'PedidoComboDetalle contiene cantidades inválidas o duplicadas.', 1;

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
)
    THROW 54612, N'Existe un PedidoCombo sin componentes canónicos.', 1;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT detail.PedidoComboId,
               detail.ProductoId,
               SUM(CONVERT(BIGINT, detail.Cantidad)) AS CantidadTotal
        FROM dbo.PedidoDetalle detail
        WHERE detail.PedidoComboId IS NOT NULL
        GROUP BY detail.PedidoComboId, detail.ProductoId
    ) historical
    FULL OUTER JOIN dbo.PedidoComboDetalle component
        ON component.PedidoComboId = historical.PedidoComboId
       AND component.ProductoId = historical.ProductoId
    WHERE historical.PedidoComboId IS NOT NULL
      AND
      (
          component.PedidoComboId IS NULL
          OR component.CantidadTotal <> historical.CantidadTotal
      )
)
    THROW 54613, N'La reconstrucción canónica no coincide con PedidoDetalle legado.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.FacturaCombos invoiceCombo
    INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = invoiceCombo.FacturaId
    INNER JOIN dbo.PedidoCombos comboOrder ON comboOrder.PedidoComboId = invoiceCombo.PedidoComboId
    WHERE invoice.PedidoId <> comboOrder.PedidoId
       OR invoiceCombo.Cantidad <= 0
       OR invoiceCombo.PrecioUnitario <= 0
)
    THROW 54614, N'FacturaCombos contiene una relación o importe inválido.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.parameters parameter
    WHERE parameter.object_id = OBJECT_ID(N'dbo.sp_Store_CreateOrderWithPromotions', N'P')
      AND parameter.name = N'@TokenOperacion'
      AND TYPE_NAME(parameter.user_type_id) = N'uniqueidentifier'
)
   OR NOT EXISTS
      (
          SELECT 1
          FROM sys.parameters parameter
          WHERE parameter.object_id = OBJECT_ID(N'dbo.sp_Store_GetComboById', N'P')
            AND parameter.name = N'@ComboId'
            AND TYPE_NAME(parameter.user_type_id) = N'int'
      )
    THROW 54618, N'Falta un parámetro requerido del contrato de checkout o combos.', 1;

DECLARE @ProcedimientosConFiltro TABLE (ProcedureName SYSNAME NOT NULL);
INSERT INTO @ProcedimientosConFiltro (ProcedureName)
VALUES
    (N'sp_Admin_GetPurchaseSuggestions'),
    (N'sp_Admin_GetSlowMovingProducts'),
    (N'sp_Admin_GetSeasonalSalesTrend'),
    (N'sp_Store_GetCheckoutResult'),
    (N'sp_Admin_GetOrders'),
    (N'sp_Admin_GetOrderDetailLines'),
    (N'sp_Inventory_RestoreOrderStock'),
    (N'sp_Admin_GenerateInvoiceFromOrder');

IF EXISTS
(
    SELECT 1
    FROM @ProcedimientosConFiltro expected
    WHERE OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + expected.ProcedureName, N'P'))
          NOT LIKE N'%PedidoComboId IS NULL%'
)
    THROW 54619, N'Un procedimiento aún puede contar componentes legados como productos sueltos.', 1;

IF (SELECT COUNT(*) FROM dbo.Permisos
    WHERE Codigo IN (N'COMBOS_VER', N'COMBOS_GESTIONAR', N'INVENTARIO_TRANSFORMAR', N'INVENTARIO_INTELIGENCIA_VER')
      AND Activo = 1) <> 4
    THROW 54620, N'Faltan permisos activos de 0012.', 1;

IF (SELECT COUNT(DISTINCT permission.Codigo)
    FROM dbo.Perfiles profile
    INNER JOIN dbo.PerfilPermisos profilePermission ON profilePermission.PerfilId = profile.PerfilId
    INNER JOIN dbo.Permisos permission ON permission.PermisoId = profilePermission.PermisoId
    WHERE profile.Nombre = N'Administrador'
      AND permission.Codigo IN
          (N'COMBOS_VER', N'COMBOS_GESTIONAR', N'INVENTARIO_TRANSFORMAR', N'INVENTARIO_INTELIGENCIA_VER')) <> 4
    THROW 54621, N'El perfil Administrador no tiene todos los permisos de 0012.', 1;

SELECT N'0012 verificada' AS Resultado,
       DB_NAME() AS BaseDeDatos,
       SYSUTCDATETIME() AS VerificadoEnUtc;
