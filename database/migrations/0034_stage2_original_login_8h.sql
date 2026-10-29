SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 56610,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 56611,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0034_stage2_original_login_8h')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0034_stage2_original_login_8h' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 56612,N'Conflicto de ledger 0034.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0033_stage2_complaints' AND Status=N'Applied' AND FileSha256=N'21B329A75AEC24D9D83204ABAAE59BD5E6EF5A865348C380064DC2DCDA0755DA') THROW 56613,N'Falta prerequisito 0033 acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2OriginalLogins') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_CreateOriginalLogin') IS NOT NULL
 OR OBJECT_ID(N'dbo.sp_Stage2_ValidateOriginalLogin') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_RevokeOriginalLogin') IS NOT NULL
 THROW 56614,N'Existe contrato de login no acreditado.',1;
IF OBJECT_ID(N'dbo.AuditoriaSistema',N'U') IS NULL OR COL_LENGTH(N'dbo.Usuarios',N'SecurityStamp') IS NULL THROW 56615,N'Falta esquema de identidad requerido.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0034:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 56616,N'Instalacion concurrente.',1;
 CREATE TABLE dbo.Stage2OriginalLogins(
  LoginId uniqueidentifier NOT NULL CONSTRAINT PK_Stage2OriginalLogins PRIMARY KEY,
  UsuarioId int NOT NULL REFERENCES dbo.Usuarios(UsuarioId),
  PerfilId int NOT NULL REFERENCES dbo.Perfiles(PerfilId),
  SecurityStamp uniqueidentifier NOT NULL,
  BindingHash binary(32) NOT NULL CONSTRAINT UQ_Stage2OriginalLogins_Binding UNIQUE,
  IssuedUtc datetime2(7) NOT NULL,
  ExpiresUtc datetime2(7) NOT NULL,
  RevokedUtc datetime2(7) NULL,
  CONSTRAINT CK_Stage2OriginalLogins_Lifetime CHECK(ExpiresUtc=DATEADD(hour,8,IssuedUtc)),
  CONSTRAINT CK_Stage2OriginalLogins_Revocation CHECK(RevokedUtc IS NULL OR RevokedUtc>=IssuedUtc)
 );
 CREATE INDEX IX_Stage2OriginalLogins_UserExpiry ON dbo.Stage2OriginalLogins(UsuarioId,ExpiresUtc);
 -- No backfill and no automatic deletion of history.
EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_CreateOriginalLogin
 @UsuarioId int,@PerfilId int,@SecurityStamp uniqueidentifier,@BindingHash binary(32)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UsuarioId<=0 OR @PerfilId<=0 OR @SecurityStamp IS NULL OR @SecurityStamp=CONVERT(uniqueidentifier,N''00000000-0000-0000-0000-000000000000'')
  OR @BindingHash IS NULL OR @BindingHash=CONVERT(binary(32),0) THROW 56601,N''Contexto de autenticacion no acreditado.'',1;
 DECLARE @Name nvarchar(150),@Email nvarchar(256),@Role nvarchar(100),@Id uniqueidentifier=NEWID(),@Issued datetime2(7),@Expires datetime2(7);
 BEGIN TRY BEGIN TRANSACTION;
  SELECT @Role=Nombre FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=@PerfilId AND Activo=1;
  SELECT @Name=NombreCompleto,@Email=Correo FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK)
   WHERE UsuarioId=@UsuarioId AND PerfilId=@PerfilId AND Activo=1 AND SecurityStamp=@SecurityStamp;
  IF @Name IS NULL OR @Role IS NULL THROW 56601,N''Contexto de autenticacion no acreditado.'',1;
  SET @Issued=SYSUTCDATETIME();SET @Expires=DATEADD(hour,8,@Issued);
  INSERT dbo.Stage2OriginalLogins(LoginId,UsuarioId,PerfilId,SecurityStamp,BindingHash,IssuedUtc,ExpiresUtc)
   VALUES(@Id,@UsuarioId,@PerfilId,@SecurityStamp,@BindingHash,@Issued,@Expires);
  INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
   VALUES(@UsuarioId,@Name,@Email,@Role,N''LOGIN'',N''Autenticación'',N''Inicio de sesión; vigencia absoluta de ocho horas.'');
  COMMIT TRANSACTION;
  SELECT @Id AS LoginId,@Issued AS IssuedUtc,@Expires AS ExpiresUtc;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
END;');

EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_ValidateOriginalLogin
 @LoginId uniqueidentifier,@UsuarioId int,@PerfilId int,@SecurityStamp uniqueidentifier,@BindingHash binary(32),
 @IssuedUtc datetime2(7),@ExpiresUtc datetime2(7)
AS
BEGIN
 SET NOCOUNT ON;
 -- A single canonical read. No UPDATE, sliding expiration or inferred session identity.
 SELECT u.Activo,p.Nombre AS PerfilNombre,u.SecurityStamp,u.PerfilId,p.Activo AS PerfilActivo
 FROM dbo.Stage2OriginalLogins l
 INNER JOIN dbo.Usuarios u ON u.UsuarioId=l.UsuarioId AND u.PerfilId=l.PerfilId AND u.SecurityStamp=l.SecurityStamp
 INNER JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId
 WHERE l.LoginId=@LoginId AND l.UsuarioId=@UsuarioId AND l.PerfilId=@PerfilId
  AND l.SecurityStamp=@SecurityStamp AND l.BindingHash=@BindingHash
  AND l.IssuedUtc=@IssuedUtc AND l.ExpiresUtc=@ExpiresUtc
  AND l.RevokedUtc IS NULL AND l.IssuedUtc<=SYSUTCDATETIME() AND l.ExpiresUtc>SYSUTCDATETIME()
  AND u.Activo=1 AND p.Activo=1;
END;');

EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_RevokeOriginalLogin
 @LoginId uniqueidentifier,@UsuarioId int,@PerfilId int,@SecurityStamp uniqueidentifier,@BindingHash binary(32),
 @IssuedUtc datetime2(7),@ExpiresUtc datetime2(7)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 DECLARE @Name nvarchar(150),@Email nvarchar(256),@Role nvarchar(100),@CurrentProfile int;
 BEGIN TRY BEGIN TRANSACTION;
  SELECT @CurrentProfile=PerfilId FROM dbo.Usuarios WHERE UsuarioId=@UsuarioId;
  SELECT @Role=Nombre FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=@CurrentProfile;
  SELECT @Name=NombreCompleto,@Email=Correo FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE UsuarioId=@UsuarioId AND PerfilId=@CurrentProfile;
  IF @Name IS NULL OR @Role IS NULL THROW 56602,N''Actor de cierre no acreditado.'',1;
  UPDATE dbo.Stage2OriginalLogins WITH(UPDLOCK,HOLDLOCK) SET RevokedUtc=SYSUTCDATETIME()
  WHERE LoginId=@LoginId AND UsuarioId=@UsuarioId AND PerfilId=@PerfilId AND SecurityStamp=@SecurityStamp
    AND BindingHash=@BindingHash AND IssuedUtc=@IssuedUtc AND ExpiresUtc=@ExpiresUtc AND RevokedUtc IS NULL;
  IF @@ROWCOUNT=1
   INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
    VALUES(@UsuarioId,@Name,@Email,@Role,N''LOGOUT'',N''Autenticación'',N''Cierre del login original.'');
  COMMIT TRANSACTION;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
END;');

EXEC(N'CREATE TRIGGER dbo.tr_Stage2OriginalLogins_Immutable ON dbo.Stage2OriginalLogins AFTER UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT LoginId,UsuarioId,PerfilId,SecurityStamp,BindingHash,IssuedUtc,ExpiresUtc FROM deleted
    EXCEPT SELECT LoginId,UsuarioId,PerfilId,SecurityStamp,BindingHash,IssuedUtc,ExpiresUtc FROM inserted)
  THROW 56603,N''El propietario y la vigencia originales son inmutables.'',1;
 IF EXISTS(SELECT 1 FROM deleted d JOIN inserted i ON i.LoginId=d.LoginId
    WHERE d.RevokedUtc IS NOT NULL AND (i.RevokedUtc IS NULL OR i.RevokedUtc<>d.RevokedUtc))
  THROW 56604,N''No se puede reactivar un login revocado.'',1;
END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0034_stage2_original_login_8h',N'0034_stage2_original_login_8h.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
 N'Login MVC original inmutable, binding de sesion, ocho horas absolutas UTC; sin backfill ni asignaciones comerciales.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;