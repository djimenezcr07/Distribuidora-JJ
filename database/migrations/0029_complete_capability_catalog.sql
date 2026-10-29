SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL THROW 55410, N'Falta el ledger 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0029_complete_capability_catalog' AND Status = N'Applied')
    THROW 55411, N'0029 ya figura aplicada.', 1;

BEGIN TRANSACTION;

DECLARE @Capabilities TABLE (Codigo NVARCHAR(100), Modulo NVARCHAR(100), Nombre NVARCHAR(150), Descripcion NVARCHAR(500));
INSERT @Capabilities VALUES
    (N'ACTIVOS_GESTIONAR', N'Activos', N'Gestionar activos', N'Registrar y administrar activos de la empresa.'),
    (N'COMODATOS_CONSULTAR', N'Activos', N'Consultar comodatos', N'Consultar equipos prestados y su rentabilidad.'),
    (N'LIQUIDACION_FINANCIERA', N'Finanzas', N'Liquidar cobros de ruta', N'Registrar liquidaciones financieras de rutas.'),
    (N'FLOTA_MANTENIMIENTO', N'Flota', N'Gestionar mantenimiento', N'Registrar mantenimiento y consultar alertas.'),
    (N'METAS_GESTIONAR', N'Metas y KPIs', N'Gestionar metas de ventas', N'Definir metas mensuales por vendedor.'),
    (N'REPORTE_KPI', N'Metas y KPIs', N'Reporte de cumplimiento KPI', N'Consultar el cumplimiento global de KPIs.'),
    (N'REPORTES_DASHBOARD', N'Reportes', N'Ver tablero gerencial', N'Visualizar indicadores clave del negocio.'),
    (N'PROMOCIONES_GESTIONAR', N'Promociones', N'Gestionar promociones', N'Configurar, segmentar e inactivar promociones.'),
    (N'RECLAMOS_GESTIONAR', N'Servicio al cliente', N'Gestionar reclamos', N'Registrar y resolver reclamos.'),
    (N'DEVOLUCIONES_GESTIONAR', N'Inventario', N'Gestionar devoluciones', N'Registrar devoluciones de productos.'),
    (N'CUARENTENA_GESTIONAR', N'Inventario', N'Gestionar cuarentena', N'Liberar o descartar productos en cuarentena.'),
    (N'RUTAS_GESTIONAR', N'Rutas', N'Gestionar rutas de entrega', N'Crear, despachar y cancelar rutas.');

INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
SELECT source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1
FROM @Capabilities source
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permisos target WHERE target.Codigo = source.Codigo);

UPDATE target SET Modulo = source.Modulo, Nombre = source.Nombre, Descripcion = source.Descripcion, Activo = 1
FROM dbo.Permisos target INNER JOIN @Capabilities source ON source.Codigo = target.Codigo;

DECLARE @Assignments TABLE (Perfil NVARCHAR(100), Codigo NVARCHAR(100));
INSERT @Assignments VALUES
    (N'Administrador', N'ACTIVOS_GESTIONAR'), (N'Gerente', N'ACTIVOS_GESTIONAR'),
    (N'Administrador', N'COMODATOS_CONSULTAR'), (N'Gerente', N'COMODATOS_CONSULTAR'), (N'Auditor', N'COMODATOS_CONSULTAR'), (N'Auditor Interno', N'COMODATOS_CONSULTAR'),
    (N'Administrador', N'LIQUIDACION_FINANCIERA'), (N'Gerente', N'LIQUIDACION_FINANCIERA'), (N'Cajero', N'LIQUIDACION_FINANCIERA'), (N'Financiero', N'LIQUIDACION_FINANCIERA'),
    (N'Administrador', N'FLOTA_MANTENIMIENTO'), (N'Gerente', N'FLOTA_MANTENIMIENTO'),
    (N'Administrador', N'METAS_GESTIONAR'), (N'Gerente', N'METAS_GESTIONAR'),
    (N'Administrador', N'REPORTE_KPI'), (N'Gerente', N'REPORTE_KPI'),
    (N'Administrador', N'REPORTES_DASHBOARD'), (N'Gerente', N'REPORTES_DASHBOARD'),
    (N'Administrador', N'PROMOCIONES_GESTIONAR'), (N'Gerente', N'PROMOCIONES_GESTIONAR'),
    (N'Administrador', N'RECLAMOS_GESTIONAR'), (N'Gerente', N'RECLAMOS_GESTIONAR'),
    (N'Administrador', N'DEVOLUCIONES_GESTIONAR'), (N'Gerente', N'DEVOLUCIONES_GESTIONAR'),
    (N'Administrador', N'CUARENTENA_GESTIONAR'), (N'Gerente', N'CUARENTENA_GESTIONAR'),
    (N'Administrador', N'RUTAS_GESTIONAR'), (N'Gerente', N'RUTAS_GESTIONAR');

INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, permission.PermisoId, NULL, N'Migración 0029'
FROM @Assignments source
INNER JOIN dbo.Perfiles profile ON profile.Nombre = source.Perfil
INNER JOIN dbo.Permisos permission ON permission.Codigo = source.Codigo
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos existing
    WHERE existing.PerfilId = profile.PerfilId AND existing.PermisoId = permission.PermisoId
);

COMMIT TRANSACTION;

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55412, N'SHA-256 inválido para 0029.', 1;
INSERT dbo.SchemaMigrationHistory (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES (N'0029_complete_capability_catalog', N'0029_complete_capability_catalog.sql', UPPER(@MigrationSha256), N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
        N'Versiona capacidades activas que antes solo constaban en scripts históricos.');
GO
