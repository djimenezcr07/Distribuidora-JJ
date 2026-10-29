SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0034_stage2_original_login_8h' AND Status=N'Applied')
 THROW 56620,N'Falta ledger 0034.',1;
IF OBJECT_ID(N'dbo.Stage2OriginalLogins',N'U') IS NULL OR OBJECT_ID(N'dbo.tr_Stage2OriginalLogins_Immutable',N'TR') IS NULL
 THROW 56621,N'Contrato de login incompleto.',1;
IF (SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN(OBJECT_ID(N'dbo.sp_Stage2_CreateOriginalLogin'),
 OBJECT_ID(N'dbo.sp_Stage2_ValidateOriginalLogin'),OBJECT_ID(N'dbo.sp_Stage2_RevokeOriginalLogin'))
 AND uses_quoted_identifier=1 AND uses_ansi_nulls=1)<>3 THROW 56622,N'Modulos u opciones incompatibles.',1;
IF EXISTS(SELECT 1 FROM sys.parameters WHERE object_id IN(OBJECT_ID(N'dbo.sp_Stage2_ValidateOriginalLogin'),OBJECT_ID(N'dbo.sp_Stage2_RevokeOriginalLogin'))
 AND name IN(N'@IssuedUtc',N'@ExpiresUtc') AND (TYPE_NAME(user_type_id)<>N'datetime2' OR scale<>7))
 THROW 56623,N'Precision temporal incompatible.',1;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.Stage2OriginalLogins') AND (is_disabled=1 OR is_not_trusted=1))
 THROW 56624,N'Restricciones no acreditadas.',1;
SELECT COUNT(*) AS OriginalLoginCount FROM dbo.Stage2OriginalLogins;
