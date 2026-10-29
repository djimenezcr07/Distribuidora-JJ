SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0033_stage2_complaints' AND Status=N'Applied')
 THROW 56520,N'Falta ledger 0033.',1;
IF OBJECT_ID(N'dbo.Reclamos',N'U') IS NULL THROW 56521,N'Falta tabla de reclamos.',1;
IF (SELECT COUNT(*) FROM sys.procedures WHERE name IN(N'sp_Reclamos_Create',N'sp_Reclamos_List',N'sp_Reclamos_GetById',
 N'sp_Reclamos_CambiarEstado',N'sp_Reclamos_Clientes_Buscar',N'sp_Reclamos_FacturasPorCliente'))<>6
 THROW 56522,N'Contrato incompleto.',1;
IF (SELECT COUNT(*) FROM sys.parameters p JOIN sys.procedures o ON o.object_id=p.object_id
 WHERE o.name LIKE N'sp[_]Reclamos[_]%' AND p.name=N'@ExpectedSecurityStamp'
 AND TYPE_NAME(p.user_type_id)=N'uniqueidentifier')<>6 THROW 56523,N'Falta contexto autenticado.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.procedures o ON o.object_id=m.object_id
 WHERE o.name LIKE N'sp[_]Reclamos[_]%' AND (m.uses_quoted_identifier<>1 OR m.uses_ansi_nulls<>1))
 THROW 56524,N'Opciones de modulo no acreditadas.',1;
SELECT COUNT(*) AS ReclamosCount FROM dbo.Reclamos;
SELECT o.name,CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2) ModuleSha256
 FROM sys.sql_modules m JOIN sys.procedures o ON o.object_id=m.object_id
 WHERE o.name LIKE N'sp[_]Reclamos[_]%';
