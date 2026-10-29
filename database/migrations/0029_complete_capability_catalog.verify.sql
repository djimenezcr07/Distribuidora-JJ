SET NOCOUNT ON;

IF EXISTS (
    SELECT required.Codigo FROM (VALUES
        (N'ACTIVOS_GESTIONAR'), (N'COMODATOS_CONSULTAR'), (N'LIQUIDACION_FINANCIERA'), (N'FLOTA_MANTENIMIENTO'),
        (N'METAS_GESTIONAR'), (N'REPORTE_KPI'), (N'REPORTES_DASHBOARD'), (N'PROMOCIONES_GESTIONAR'),
        (N'RECLAMOS_GESTIONAR'), (N'DEVOLUCIONES_GESTIONAR'), (N'CUARENTENA_GESTIONAR'), (N'RUTAS_GESTIONAR')
    ) required(Codigo)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Permisos permission WHERE permission.Codigo = required.Codigo AND permission.Activo = 1)
) THROW 55413, N'Faltan capacidades del catálogo 0029.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0029_complete_capability_catalog' AND Status = N'Applied')
    THROW 55414, N'0029 no figura aplicada.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0029_complete_capability_catalog';
