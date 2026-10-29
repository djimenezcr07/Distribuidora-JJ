SET NOCOUNT ON;
SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1
 THROW 56810,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 56811,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0036_stage2_transactional_login')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0036_stage2_transactional_login'
  AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 56812,N'Conflicto de ledger 0036.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0035_stage2_warranty_administrator_grant'
 AND Status=N'Applied' AND FileSha256=N'0A523309FCE9D4EAD683CEFC570FBC4C2FF8B121C258A9B70B13F83746663A63')
 THROW 56813,N'Falta prerequisito 0035 acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_RequireOriginalLogin') IS NOT NULL
 THROW 56814,N'Existe contrato transaccional sin ledger acreditado.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0036:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 56815,N'Instalacion concurrente.',1;
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_RequireOriginalLogin
 @LoginId uniqueidentifier,@UsuarioId int,@PerfilId int,@SecurityStamp uniqueidentifier,@BindingHash binary(32),
 @IssuedUtc datetime2(7),@ExpiresUtc datetime2(7),@PermissionCode nvarchar(100)=NULL
 AS
 BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 THROW 56800,N''Falta la transaccion de negocio.'',1;
  -- Hold the canonical authorization rows until the caller commits or rolls back.
  -- Permission rows precede Usuarios, as do the grant-revocation writers.
  IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK)
   WHERE PerfilId=@PerfilId AND Activo=1)
   THROW 56801,N''Contexto original no vigente.'',1;
  IF @PermissionCode IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM dbo.PerfilPermisos pp WITH(UPDLOCK,HOLDLOCK)
   JOIN dbo.Permisos p WITH(UPDLOCK,HOLDLOCK) ON p.PermisoId=pp.PermisoId
   WHERE pp.PerfilId=@PerfilId AND p.Codigo=@PermissionCode AND p.Activo=1)
   THROW 56802,N''Capacidad no vigente.'',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK)
   WHERE UsuarioId=@UsuarioId AND PerfilId=@PerfilId AND SecurityStamp=@SecurityStamp AND Activo=1)
   THROW 56801,N''Contexto original no vigente.'',1;
  DECLARE @Now datetime2(7)=SYSUTCDATETIME();
  IF NOT EXISTS(SELECT 1 FROM dbo.Stage2OriginalLogins WITH(UPDLOCK,HOLDLOCK)
   WHERE LoginId=@LoginId AND UsuarioId=@UsuarioId AND PerfilId=@PerfilId AND SecurityStamp=@SecurityStamp
    AND BindingHash=@BindingHash AND IssuedUtc=@IssuedUtc AND ExpiresUtc=@ExpiresUtc
    AND RevokedUtc IS NULL AND IssuedUtc<=@Now AND ExpiresUtc>@Now)
   THROW 56801,N''Contexto original no vigente.'',1;
 END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0036_stage2_transactional_login',N'0036_stage2_transactional_login.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
 N'Guard aditivo del login original y capacidades dentro de transacciones MVC; sin cambios de datos historicos ni asignaciones.');
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
