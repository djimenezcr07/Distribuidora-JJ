SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0037_stage2_invoice_states' AND Status=N'Applied')
 THROW 57020,N'Falta ledger 0037.',1;
IF (SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN(OBJECT_ID(N'dbo.sp_Stage2_GenerateInvoiceFromOrder'),OBJECT_ID(N'dbo.sp_Stage2_UpdateOrderStatus'))
 AND uses_quoted_identifier=1 AND uses_ansi_nulls=1)<>2 THROW 57021,N'Contrato versionado incompleto.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Admin_GenerateInvoiceFromOrder')
 AND CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),definition)),2)=N'E47B9E7AC1E3FBDD6896ABEECCFB0BC02BCAE6E2B513F284713EDC72C62D5D10')
 THROW 57022,N'El modulo historico cambio.',1;
SELECT N'PASS: facturacion versionada y estado manual; modulo historico conservado' AS Result;
