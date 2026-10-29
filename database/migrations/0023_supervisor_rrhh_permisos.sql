SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 55400,N'Falta el ledger 0001.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0023_supervisor_rrhh_permisos' AND Status=N'Applied') THROW 55401,N'0023 ya figura aplicada.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WHERE Nombre=N'Supervisor') THROW 55402,N'No existe el perfil Supervisor.',1;
IF (SELECT COUNT(*) FROM dbo.Permisos WHERE Codigo IN(N'EMPLEADOS_VER',N'EMPLEADOS_CREAR',N'EMPLEADOS_EDITAR',N'PLANILLA_BOLETAS_GESTIONAR') AND Activo=1) <> 4
    THROW 55403,N'Faltan permisos base de Empleados o Boletas; aplique 0018 y 0020 primero.',1;

BEGIN TRANSACTION;

-- Da a Supervisor visibilidad y gestión del expediente de empleados.
DECLARE @PerfilId INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre=N'Supervisor');

INSERT dbo.PerfilPermisos(PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT @PerfilId, permission.PermisoId, NULL, N'Migración 0023 supervisor rrhh'
FROM dbo.Permisos permission
WHERE permission.Codigo IN(N'EMPLEADOS_VER', N'EMPLEADOS_CREAR', N'EMPLEADOS_EDITAR', N'PLANILLA_BOLETAS_GESTIONAR')
  AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=@PerfilId AND x.PermisoId=permission.PermisoId);

IF XACT_STATE()<>1 THROW 55404,N'La transacción 0023 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55405,N'SHA-256 inválido para 0023.',1;

INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0023_supervisor_rrhh_permisos',N'0023_supervisor_rrhh_permisos.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
    N'Otorga EMPLEADOS_VER/CREAR/EDITAR y PLANILLA_BOLETAS_GESTIONAR al perfil Supervisor; reemplaza el otorgamiento manual perdido.');

COMMIT TRANSACTION;