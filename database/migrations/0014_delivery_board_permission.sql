SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 54700,N'Falta el ledger 0001.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0014_delivery_board_permission' AND Status=N'Applied')
    THROW 54701,N'0014 ya figura aplicada.',1;
IF OBJECT_ID(N'dbo.Permisos',N'U') IS NULL OR OBJECT_ID(N'dbo.Perfiles',N'U') IS NULL OR OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NULL
    THROW 54702,N'Faltan tablas de permisos.',1;

BEGIN TRANSACTION;

UPDATE dbo.Permisos SET Modulo=N'Entregas',Nombre=N'Consultar tablero de entregas',Descripcion=N'Permite consultar estado agregado de rutas y entregas.',Activo=1 WHERE Codigo=N'ENTREGAS_TABLERO_VER';
IF @@ROWCOUNT=0
    INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo) VALUES(N'ENTREGAS_TABLERO_VER',N'Entregas',N'Consultar tablero de entregas',N'Permite consultar estado agregado de rutas y entregas.',1);

INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0014 tablero de entregas'
FROM dbo.Perfiles profile CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre IN(N'Administrador',N'Gerente') AND permission.Codigo=N'ENTREGAS_TABLERO_VER'
  AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos assigned WHERE assigned.PerfilId=profile.PerfilId AND assigned.PermisoId=permission.PermisoId);

DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 54703,N'SHA-256 inválido para 0014.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0014_delivery_board_permission',N'0014_delivery_board_permission.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-084: permiso exacto del tablero de entregas actualizado.');
COMMIT TRANSACTION;
