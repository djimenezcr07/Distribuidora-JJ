SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'VENTA_MOVIL_CREAR' AND Activo = 1)
    THROW 55273, N'Falta VENTA_MOVIL_CREAR.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'CHAT_USAR' AND Activo = 1)
    THROW 55275, N'Falta CHAT_USAR.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'METAS_PROPIAS_VER' AND Activo = 1)
    THROW 55276, N'Falta METAS_PROPIAS_VER.', 1;
IF NOT EXISTS (
    SELECT 1 FROM dbo.Perfiles profile
    INNER JOIN dbo.PerfilPermisos assignment ON assignment.PerfilId = profile.PerfilId
    INNER JOIN dbo.Permisos permission ON permission.PermisoId = assignment.PermisoId
    WHERE profile.Nombre = N'Administrador' AND permission.Codigo = N'VENTA_MOVIL_CREAR'
)
    THROW 55274, N'Administrador no tiene VENTA_MOVIL_CREAR.', 1;
IF NOT EXISTS (
    SELECT 1 FROM dbo.Perfiles profile
    INNER JOIN dbo.PerfilPermisos assignment ON assignment.PerfilId = profile.PerfilId
    INNER JOIN dbo.Permisos permission ON permission.PermisoId = assignment.PermisoId
    WHERE profile.Nombre = N'Vendedor' AND permission.Codigo = N'METAS_PROPIAS_VER'
)
    THROW 55277, N'Vendedor no tiene METAS_PROPIAS_VER.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0027_dynamic_authorization_capabilities';
