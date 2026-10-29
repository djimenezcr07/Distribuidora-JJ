SET NOCOUNT ON;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0023_supervisor_rrhh_permisos' AND Status = N'Applied'
)
    THROW 55406, N'0023 no figura aplicada en el ledger.', 1;

IF EXISTS (
    SELECT required.Codigo
    FROM (VALUES (N'EMPLEADOS_VER'), (N'EMPLEADOS_CREAR'), (N'EMPLEADOS_EDITAR'), (N'PLANILLA_BOLETAS_GESTIONAR')) required(Codigo)
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Perfiles profile
        INNER JOIN dbo.PerfilPermisos assignment ON assignment.PerfilId = profile.PerfilId
        INNER JOIN dbo.Permisos permission ON permission.PermisoId = assignment.PermisoId
        WHERE profile.Nombre = N'Supervisor' AND permission.Codigo = required.Codigo
    )
)
    THROW 55407, N'Faltan asignaciones de Supervisor requeridas por 0023.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0023_supervisor_rrhh_permisos';
