/*
  Prueba local en dos fases para reconciliar el BACPAC legado real.

  1. Ejecute una vez antes de 0012: captura sólo conteos, IDs, importes
     agregados, hashes y stock; nunca nombres, correos ni credenciales.
  2. Ejecute de nuevo después de 0012: compara la evidencia, valida la
     reconstrucción de PedidoComboDetalle y ejecuta DBCC CHECKDB.

  El script se niega a operar fuera de la instancia LocalDB aislada y de una
  base desechable cuyo nombre empiece por TrilogiaReconcile.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF CONVERT(INT, SERVERPROPERTY(N'IsLocalDB')) <> 1
   OR DB_NAME() NOT LIKE N'TrilogiaReconcile%[_]%'
    THROW 54800, N'Esta prueba sólo puede ejecutarse en la copia LocalDB desechable de reconciliación.', 1;

DECLARE @MigrationApplied BIT = IIF(EXISTS
(
    SELECT 1
    FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0012_inventory_combos_transformations_intelligence'
      AND Status = N'Applied'
), 1, 0);

IF @MigrationApplied = 0
BEGIN
    IF OBJECT_ID(N'dbo._0012LegacyBaselineLocal', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo._0012LegacyComboLocal', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo._0012LegacyComboDetalleLocal', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo._0012LegacyPedidoComboLocal', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo._0012LegacyComponentLocal', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo._0012LegacyProductStockLocal', N'U') IS NOT NULL
        THROW 54801, N'La evidencia previa ya existe; no se sobrescribirá.', 1;

    CREATE TABLE dbo._0012LegacyBaselineLocal
    (
        MetricName SYSNAME NOT NULL CONSTRAINT PK__0012LegacyBaselineLocal PRIMARY KEY,
        IntegerValue BIGINT NULL,
        DecimalValue DECIMAL(38,2) NULL
    );

    CREATE TABLE dbo._0012LegacyComboLocal
    (
        ComboId INT NOT NULL CONSTRAINT PK__0012LegacyComboLocal PRIMARY KEY,
        RowHash BINARY(32) NOT NULL
    );

    CREATE TABLE dbo._0012LegacyComboDetalleLocal
    (
        ComboDetalleId INT NOT NULL CONSTRAINT PK__0012LegacyComboDetalleLocal PRIMARY KEY,
        ComboId INT NOT NULL,
        ProductoId INT NOT NULL,
        Cantidad INT NOT NULL
    );

    CREATE TABLE dbo._0012LegacyPedidoComboLocal
    (
        PedidoComboId INT NOT NULL CONSTRAINT PK__0012LegacyPedidoComboLocal PRIMARY KEY,
        PedidoId INT NOT NULL,
        ComboId INT NOT NULL,
        Cantidad INT NOT NULL,
        PrecioUnitario DECIMAL(18,2) NOT NULL
    );

    CREATE TABLE dbo._0012LegacyComponentLocal
    (
        PedidoComboId INT NOT NULL,
        PedidoId INT NOT NULL,
        ProductoId INT NOT NULL,
        CantidadTotal INT NOT NULL,
        CONSTRAINT PK__0012LegacyComponentLocal PRIMARY KEY (PedidoComboId, ProductoId)
    );

    CREATE TABLE dbo._0012LegacyProductStockLocal
    (
        ProductoId INT NOT NULL CONSTRAINT PK__0012LegacyProductStockLocal PRIMARY KEY,
        Stock INT NOT NULL
    );

    INSERT INTO dbo._0012LegacyBaselineLocal (MetricName, IntegerValue)
    SELECT N'Usuarios.Count', COUNT_BIG(*) FROM dbo.Usuarios
    UNION ALL SELECT N'Usuarios.IdSum', COALESCE(SUM(CONVERT(BIGINT, UsuarioId)), 0) FROM dbo.Usuarios
    UNION ALL SELECT N'Productos.Count', COUNT_BIG(*) FROM dbo.Productos
    UNION ALL SELECT N'Productos.IdSum', COALESCE(SUM(CONVERT(BIGINT, ProductoId)), 0) FROM dbo.Productos
    UNION ALL SELECT N'Productos.StockSum', COALESCE(SUM(CONVERT(BIGINT, Stock)), 0) FROM dbo.Productos
    UNION ALL SELECT N'Pedidos.Count', COUNT_BIG(*) FROM dbo.Pedidos
    UNION ALL SELECT N'Pedidos.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoId)), 0) FROM dbo.Pedidos
    UNION ALL SELECT N'PedidoDetalle.Count', COUNT_BIG(*) FROM dbo.PedidoDetalle
    UNION ALL SELECT N'PedidoDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoDetalleId)), 0) FROM dbo.PedidoDetalle
    UNION ALL SELECT N'PedidoDetalle.QuantitySum', COALESCE(SUM(CONVERT(BIGINT, Cantidad)), 0) FROM dbo.PedidoDetalle
    UNION ALL SELECT N'Facturas.Count', COUNT_BIG(*) FROM dbo.Facturas
    UNION ALL SELECT N'Facturas.IdSum', COALESCE(SUM(CONVERT(BIGINT, FacturaId)), 0) FROM dbo.Facturas
    UNION ALL SELECT N'FacturaDetalle.Count', COUNT_BIG(*) FROM dbo.FacturaDetalle
    UNION ALL SELECT N'FacturaDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, FacturaDetalleId)), 0) FROM dbo.FacturaDetalle
    UNION ALL SELECT N'Combos.Count', COUNT_BIG(*) FROM dbo.Combos
    UNION ALL SELECT N'Combos.IdSum', COALESCE(SUM(CONVERT(BIGINT, ComboId)), 0) FROM dbo.Combos
    UNION ALL SELECT N'ComboDetalle.Count', COUNT_BIG(*) FROM dbo.ComboDetalle
    UNION ALL SELECT N'ComboDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, ComboDetalleId)), 0) FROM dbo.ComboDetalle
    UNION ALL SELECT N'PedidoCombos.Count', COUNT_BIG(*) FROM dbo.PedidoCombos
    UNION ALL SELECT N'PedidoCombos.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoComboId)), 0) FROM dbo.PedidoCombos
    UNION ALL SELECT N'SchemaMigrationHistory.Count', COUNT_BIG(*) FROM dbo.SchemaMigrationHistory;

    INSERT INTO dbo._0012LegacyBaselineLocal (MetricName, DecimalValue)
    SELECT N'Pedidos.Total', COALESCE(SUM(CONVERT(DECIMAL(38,2), Total)), 0) FROM dbo.Pedidos
    UNION ALL SELECT N'PedidoDetalle.Total',
        COALESCE(SUM(CONVERT(DECIMAL(38,2), Cantidad * PrecioUnitario)), 0) FROM dbo.PedidoDetalle
    UNION ALL SELECT N'Facturas.Subtotal',
        COALESCE(SUM(CONVERT(DECIMAL(38,2), Subtotal)), 0) FROM dbo.Facturas
    UNION ALL SELECT N'Facturas.Impuesto',
        COALESCE(SUM(CONVERT(DECIMAL(38,2), Impuesto)), 0) FROM dbo.Facturas
    UNION ALL SELECT N'Facturas.Total',
        COALESCE(SUM(CONVERT(DECIMAL(38,2), Total)), 0) FROM dbo.Facturas
    UNION ALL SELECT N'FacturaDetalle.Total',
        COALESCE(SUM(CONVERT(DECIMAL(38,2), Cantidad * PrecioUnitario)), 0) FROM dbo.FacturaDetalle;

    EXEC sys.sp_executesql
        N'INSERT INTO dbo._0012LegacyComboLocal (ComboId, RowHash)
          SELECT ComboId,
                 HASHBYTES
                 (
                     N''SHA2_256'',
                     CONCAT
                     (
                         ComboId, N''|'', Nombre, N''|'', COALESCE(Descripcion, N''''), N''|'',
                         CONVERT(NVARCHAR(50), Precio), N''|'', Activo, N''|'',
                         CONVERT(NVARCHAR(40), FechaCreacion, 126), N''|'',
                         RegistradoPorUsuarioId, N''|'', RegistradoPorNombre
                     )
                 )
          FROM dbo.Combos;';

    INSERT INTO dbo._0012LegacyComboDetalleLocal
        (ComboDetalleId, ComboId, ProductoId, Cantidad)
    SELECT ComboDetalleId, ComboId, ProductoId, Cantidad
    FROM dbo.ComboDetalle;

    INSERT INTO dbo._0012LegacyPedidoComboLocal
        (PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario)
    SELECT PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario
    FROM dbo.PedidoCombos;

    INSERT INTO dbo._0012LegacyComponentLocal
        (PedidoComboId, PedidoId, ProductoId, CantidadTotal)
    SELECT detail.PedidoComboId,
           comboOrder.PedidoId,
           detail.ProductoId,
           CONVERT(INT, SUM(CONVERT(BIGINT, detail.Cantidad)))
    FROM dbo.PedidoDetalle detail
    INNER JOIN dbo.PedidoCombos comboOrder
        ON comboOrder.PedidoComboId = detail.PedidoComboId
       AND comboOrder.PedidoId = detail.PedidoId
    WHERE detail.PedidoComboId IS NOT NULL
    GROUP BY detail.PedidoComboId, comboOrder.PedidoId, detail.ProductoId;

    INSERT INTO dbo._0012LegacyProductStockLocal (ProductoId, Stock)
    SELECT DISTINCT product.ProductoId, product.Stock
    FROM dbo.Productos product
    INNER JOIN dbo._0012LegacyComponentLocal component
        ON component.ProductoId = product.ProductoId;

    SELECT N'Evidencia previa de 0012 capturada sin datos personales.' AS Resultado;
    RETURN;
END;

IF OBJECT_ID(N'dbo._0012LegacyBaselineLocal', N'U') IS NULL
   OR OBJECT_ID(N'dbo._0012LegacyComboLocal', N'U') IS NULL
   OR OBJECT_ID(N'dbo._0012LegacyComboDetalleLocal', N'U') IS NULL
   OR OBJECT_ID(N'dbo._0012LegacyPedidoComboLocal', N'U') IS NULL
   OR OBJECT_ID(N'dbo._0012LegacyComponentLocal', N'U') IS NULL
   OR OBJECT_ID(N'dbo._0012LegacyProductStockLocal', N'U') IS NULL
    THROW 54802, N'Falta la evidencia capturada antes de ejecutar 0012.', 1;

DECLARE @CurrentIntegerMetrics TABLE
(
    MetricName SYSNAME NOT NULL PRIMARY KEY,
    IntegerValue BIGINT NOT NULL
);

INSERT INTO @CurrentIntegerMetrics (MetricName, IntegerValue)
SELECT N'Usuarios.Count', COUNT_BIG(*) FROM dbo.Usuarios
UNION ALL SELECT N'Usuarios.IdSum', COALESCE(SUM(CONVERT(BIGINT, UsuarioId)), 0) FROM dbo.Usuarios
UNION ALL SELECT N'Productos.Count', COUNT_BIG(*) FROM dbo.Productos
UNION ALL SELECT N'Productos.IdSum', COALESCE(SUM(CONVERT(BIGINT, ProductoId)), 0) FROM dbo.Productos
UNION ALL SELECT N'Productos.StockSum', COALESCE(SUM(CONVERT(BIGINT, Stock)), 0) FROM dbo.Productos
UNION ALL SELECT N'Pedidos.Count', COUNT_BIG(*) FROM dbo.Pedidos
UNION ALL SELECT N'Pedidos.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoId)), 0) FROM dbo.Pedidos
UNION ALL SELECT N'PedidoDetalle.Count', COUNT_BIG(*) FROM dbo.PedidoDetalle
UNION ALL SELECT N'PedidoDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoDetalleId)), 0) FROM dbo.PedidoDetalle
UNION ALL SELECT N'PedidoDetalle.QuantitySum', COALESCE(SUM(CONVERT(BIGINT, Cantidad)), 0) FROM dbo.PedidoDetalle
UNION ALL SELECT N'Facturas.Count', COUNT_BIG(*) FROM dbo.Facturas
UNION ALL SELECT N'Facturas.IdSum', COALESCE(SUM(CONVERT(BIGINT, FacturaId)), 0) FROM dbo.Facturas
UNION ALL SELECT N'FacturaDetalle.Count', COUNT_BIG(*) FROM dbo.FacturaDetalle
UNION ALL SELECT N'FacturaDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, FacturaDetalleId)), 0) FROM dbo.FacturaDetalle
UNION ALL SELECT N'Combos.Count', COUNT_BIG(*) FROM dbo.Combos
UNION ALL SELECT N'Combos.IdSum', COALESCE(SUM(CONVERT(BIGINT, ComboId)), 0) FROM dbo.Combos
UNION ALL SELECT N'ComboDetalle.Count', COUNT_BIG(*) FROM dbo.ComboDetalle
UNION ALL SELECT N'ComboDetalle.IdSum', COALESCE(SUM(CONVERT(BIGINT, ComboDetalleId)), 0) FROM dbo.ComboDetalle
UNION ALL SELECT N'PedidoCombos.Count', COUNT_BIG(*) FROM dbo.PedidoCombos
UNION ALL SELECT N'PedidoCombos.IdSum', COALESCE(SUM(CONVERT(BIGINT, PedidoComboId)), 0) FROM dbo.PedidoCombos;

IF EXISTS
(
    SELECT 1
    FROM dbo._0012LegacyBaselineLocal baseline
    LEFT JOIN @CurrentIntegerMetrics currentMetric
        ON currentMetric.MetricName = baseline.MetricName
    WHERE baseline.IntegerValue IS NOT NULL
      AND baseline.MetricName <> N'SchemaMigrationHistory.Count'
      AND
      (
          currentMetric.MetricName IS NULL
          OR currentMetric.IntegerValue <> baseline.IntegerValue
      )
)
    THROW 54803, N'Un conteo, suma de IDs, cantidad o stock histórico cambió durante 0012.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.SchemaMigrationHistory)
   <> (SELECT IntegerValue + 1
       FROM dbo._0012LegacyBaselineLocal
       WHERE MetricName = N'SchemaMigrationHistory.Count')
    THROW 54804, N'El ledger no contiene exactamente la nueva entrada de 0012.', 1;

DECLARE @CurrentDecimalMetrics TABLE
(
    MetricName SYSNAME NOT NULL PRIMARY KEY,
    DecimalValue DECIMAL(38,2) NOT NULL
);

INSERT INTO @CurrentDecimalMetrics (MetricName, DecimalValue)
SELECT N'Pedidos.Total', COALESCE(SUM(CONVERT(DECIMAL(38,2), Total)), 0) FROM dbo.Pedidos
UNION ALL SELECT N'PedidoDetalle.Total',
    COALESCE(SUM(CONVERT(DECIMAL(38,2), Cantidad * PrecioUnitario)), 0) FROM dbo.PedidoDetalle
UNION ALL SELECT N'Facturas.Subtotal',
    COALESCE(SUM(CONVERT(DECIMAL(38,2), Subtotal)), 0) FROM dbo.Facturas
UNION ALL SELECT N'Facturas.Impuesto',
    COALESCE(SUM(CONVERT(DECIMAL(38,2), Impuesto)), 0) FROM dbo.Facturas
UNION ALL SELECT N'Facturas.Total',
    COALESCE(SUM(CONVERT(DECIMAL(38,2), Total)), 0) FROM dbo.Facturas
UNION ALL SELECT N'FacturaDetalle.Total',
    COALESCE(SUM(CONVERT(DECIMAL(38,2), Cantidad * PrecioUnitario)), 0) FROM dbo.FacturaDetalle;

IF EXISTS
(
    SELECT 1
    FROM dbo._0012LegacyBaselineLocal baseline
    LEFT JOIN @CurrentDecimalMetrics currentMetric
        ON currentMetric.MetricName = baseline.MetricName
    WHERE baseline.DecimalValue IS NOT NULL
      AND
      (
          currentMetric.MetricName IS NULL
          OR currentMetric.DecimalValue <> baseline.DecimalValue
      )
)
    THROW 54805, N'Los totales de pedidos, detalles o facturas cambiaron durante 0012.', 1;

IF EXISTS
(
    SELECT ComboDetalleId, ComboId, ProductoId, Cantidad
    FROM dbo._0012LegacyComboDetalleLocal
    EXCEPT
    SELECT ComboDetalleId, ComboId, ProductoId, Cantidad
    FROM dbo.ComboDetalle
)
   OR EXISTS
      (
          SELECT ComboDetalleId, ComboId, ProductoId, Cantidad
          FROM dbo.ComboDetalle
          EXCEPT
          SELECT ComboDetalleId, ComboId, ProductoId, Cantidad
          FROM dbo._0012LegacyComboDetalleLocal
      )
    THROW 54806, N'ComboDetalle no conserva exactamente las claves y cantidades históricas.', 1;

IF EXISTS
(
    SELECT PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario
    FROM dbo._0012LegacyPedidoComboLocal
    EXCEPT
    SELECT PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario
    FROM dbo.PedidoCombos
)
   OR EXISTS
      (
          SELECT PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario
          FROM dbo.PedidoCombos
          EXCEPT
          SELECT PedidoComboId, PedidoId, ComboId, Cantidad, PrecioUnitario
          FROM dbo._0012LegacyPedidoComboLocal
      )
    THROW 54807, N'PedidoCombos no conserva exactamente sus claves y valores históricos.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo._0012LegacyComboLocal baseline
    INNER JOIN dbo.Combos combo ON combo.ComboId = baseline.ComboId
    WHERE baseline.RowHash <> HASHBYTES
          (
              N'SHA2_256',
              CONCAT
              (
                  combo.ComboId, N'|', combo.Nombre, N'|', COALESCE(combo.Descripcion, N''), N'|',
                  CONVERT(NVARCHAR(50), combo.Precio), N'|', combo.Activo, N'|',
                  CONVERT(NVARCHAR(40), combo.FechaCreacionUtc, 126), N'|',
                  combo.RegistradoPorUsuarioId, N'|', combo.RegistradoPorNombre
              )
          )
)
   OR (SELECT COUNT_BIG(*) FROM dbo._0012LegacyComboLocal)
      <> (SELECT COUNT_BIG(*) FROM dbo.Combos)
    THROW 54808, N'El combo legado cambió fuera de las columnas canónicas rellenadas por 0012.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo._0012LegacyComponentLocal baseline
    LEFT JOIN dbo.PedidoComboDetalle component
        ON component.PedidoComboId = baseline.PedidoComboId
       AND component.ProductoId = baseline.ProductoId
    INNER JOIN dbo.PedidoCombos comboOrder
        ON comboOrder.PedidoComboId = baseline.PedidoComboId
    WHERE component.PedidoComboId IS NULL
       OR component.CantidadTotal <> baseline.CantidadTotal
       OR component.CantidadPorCombo <= 0
       OR component.CantidadTotal % comboOrder.Cantidad <> 0
       OR component.CantidadPorCombo * comboOrder.Cantidad <> component.CantidadTotal
)
   OR (SELECT COUNT_BIG(*) FROM dbo._0012LegacyComponentLocal)
      <> (SELECT COUNT_BIG(*)
          FROM dbo.PedidoComboDetalle component
          INNER JOIN dbo._0012LegacyPedidoComboLocal baseline
              ON baseline.PedidoComboId = component.PedidoComboId)
    THROW 54809, N'PedidoComboDetalle no fue reconstruido exactamente o contiene cantidades fraccionarias.', 1;

IF EXISTS
(
    SELECT stock.ProductoId, stock.Stock
    FROM dbo._0012LegacyProductStockLocal stock
    EXCEPT
    SELECT product.ProductoId, product.Stock
    FROM dbo.Productos product
    INNER JOIN dbo._0012LegacyProductStockLocal stock
        ON stock.ProductoId = product.ProductoId
)
    THROW 54810, N'El inventario de un componente histórico cambió durante 0012.', 1;

IF EXISTS (SELECT 1 FROM dbo.FacturaCombos)
    THROW 54811, N'0012 no debe sintetizar FacturaCombos para facturas históricas.', 1;

DBCC CHECKDB WITH NO_INFOMSGS, ALL_ERRORMSGS;

SELECT N'Reconciliación legada verificada' AS Resultado,
       (SELECT COUNT_BIG(*) FROM dbo.Combos) AS Combos,
       (SELECT COUNT_BIG(*) FROM dbo.ComboDetalle) AS ComboDetalle,
       (SELECT COUNT_BIG(*) FROM dbo.PedidoCombos) AS PedidoCombos,
       (SELECT COUNT_BIG(*) FROM dbo.PedidoComboDetalle) AS PedidoComboDetalle,
       (SELECT COUNT_BIG(*) FROM dbo.PedidoDetalle) AS PedidoDetalle;
