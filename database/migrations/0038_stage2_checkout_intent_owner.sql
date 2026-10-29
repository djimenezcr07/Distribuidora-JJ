SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57110,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57111,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0038_stage2_checkout_intent_owner')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0038_stage2_checkout_intent_owner' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57112,N'Conflicto de ledger 0038.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0037_stage2_invoice_states' AND Status=N'Applied' AND FileSha256=N'AE94532AA649B2B933B06342F6CD933F7845E9B9C67D0207739E17D749049572') THROW 57113,N'Falta prerequisito 0037 acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2CheckoutIntentOwners') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_ClaimCheckoutIntent') IS NOT NULL THROW 57114,N'Existe contrato sin ledger acreditado.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0038:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57115,N'Instalacion concurrente.',1;
 CREATE TABLE dbo.Stage2CheckoutIntentOwners(
  OperationId uniqueidentifier NOT NULL CONSTRAINT PK_Stage2CheckoutIntentOwners PRIMARY KEY,
  LoginId uniqueidentifier NOT NULL REFERENCES dbo.Stage2OriginalLogins(LoginId),
  UsuarioId int NOT NULL REFERENCES dbo.Usuarios(UsuarioId),
  PayloadHash binary(32) NOT NULL,
  CreatedUtc datetime2(7) NOT NULL CONSTRAINT DF_Stage2CheckoutIntentOwners_CreatedUtc DEFAULT SYSUTCDATETIME()
 );
 EXEC(N'CREATE TRIGGER dbo.tr_Stage2CheckoutIntentOwners_Immutable ON dbo.Stage2CheckoutIntentOwners AFTER UPDATE,DELETE
 AS BEGIN SET NOCOUNT ON;IF EXISTS(SELECT 1 FROM deleted) THROW 57102,N''El propietario y contenido del intento son inmutables.'',1;END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_ClaimCheckoutIntent
 @OperationId uniqueidentifier,@LoginId uniqueidentifier,@UsuarioId int,@PerfilId int,@SecurityStamp uniqueidentifier,@BindingHash binary(32),
 @IssuedUtc datetime2(7),@ExpiresUtc datetime2(7),@PayloadHash binary(32)
 AS BEGIN
  SET NOCOUNT ON;SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 THROW 57100,N''Falta transaccion de login original.'',1;
  IF @OperationId IS NULL OR @OperationId=CONVERT(uniqueidentifier,N''00000000-0000-0000-0000-000000000000'') OR @PayloadHash IS NULL
   THROW 57101,N''Intento no acreditado.'',1;
  EXEC dbo.sp_Stage2_RequireOriginalLogin @LoginId=@LoginId,@UsuarioId=@UsuarioId,@PerfilId=@PerfilId,@SecurityStamp=@SecurityStamp,
   @BindingHash=@BindingHash,@IssuedUtc=@IssuedUtc,@ExpiresUtc=@ExpiresUtc;
  IF NOT EXISTS(SELECT 1 FROM dbo.Stage2OriginalLogins WITH(UPDLOCK,HOLDLOCK)
   WHERE LoginId=@LoginId AND UsuarioId=@UsuarioId AND RevokedUtc IS NULL AND ExpiresUtc>SYSUTCDATETIME())
   THROW 57101,N''Intento no acreditado.'',1;
  IF EXISTS(SELECT 1 FROM dbo.Stage2CheckoutIntentOwners WITH(UPDLOCK,HOLDLOCK) WHERE OperationId=@OperationId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.Stage2CheckoutIntentOwners WHERE OperationId=@OperationId AND LoginId=@LoginId AND UsuarioId=@UsuarioId AND PayloadHash=@PayloadHash)
    THROW 57101,N''Intento no acreditado.'',1;
   RETURN;
  END;
  IF EXISTS(SELECT 1 FROM dbo.CheckoutOperaciones WITH(UPDLOCK,HOLDLOCK) WHERE TokenOperacion=@OperationId)
   THROW 57101,N''No se adopta un intento historico sin propietario original.'',1;
  INSERT dbo.Stage2CheckoutIntentOwners(OperationId,LoginId,UsuarioId,PayloadHash)VALUES(@OperationId,@LoginId,@UsuarioId,@PayloadHash);
 END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0038_stage2_checkout_intent_owner',N'0038_stage2_checkout_intent_owner.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Propietario original y huella inmutables del checkout, sin adoptar tokens historicos ni cambiar precios/SQL0012.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;