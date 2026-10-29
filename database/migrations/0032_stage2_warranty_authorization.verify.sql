SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0032_stage2_warranty_authorization' AND Status=N'Applied')
 THROW 56420,N'Falta ledger 0032.',1;
IF (SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN(OBJECT_ID(N'dbo.sp_Client_CreateWarrantyRequest'),OBJECT_ID(N'dbo.sp_Admin_UpdateWarrantyStatus'))
 AND uses_quoted_identifier=1 AND uses_ansi_nulls=1)<>2 THROW 56421,N'Modulos u opciones no acreditados.',1;
IF (SELECT COUNT(*) FROM sys.parameters WHERE object_id IN(OBJECT_ID(N'dbo.sp_Client_CreateWarrantyRequest'),OBJECT_ID(N'dbo.sp_Admin_UpdateWarrantyStatus'))
 AND name=N'@ExpectedSecurityStamp' AND TYPE_NAME(user_type_id)=N'uniqueidentifier')<>2 THROW 56422,N'Falta contexto autenticado.',1;
SELECT o.name,CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2) ModuleSha256
 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
 WHERE o.object_id IN(OBJECT_ID(N'dbo.sp_Client_CreateWarrantyRequest'),OBJECT_ID(N'dbo.sp_Admin_UpdateWarrantyStatus'));
