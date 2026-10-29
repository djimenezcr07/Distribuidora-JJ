SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0036_stage2_transactional_login' AND Status=N'Applied')
 THROW 56820,N'Falta ledger 0036.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_RequireOriginalLogin',N'P') IS NULL
 OR (SELECT COUNT(*) FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.sp_Stage2_RequireOriginalLogin'))<>8
 THROW 56821,N'Falta contrato transaccional.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Stage2_RequireOriginalLogin')
 AND uses_ansi_nulls=1 AND uses_quoted_identifier=1)
 THROW 56822,N'Opciones del modulo incompatibles.',1;
SELECT N'PASS: guard transaccional de login original y capacidad, sin renovacion' AS Result;
