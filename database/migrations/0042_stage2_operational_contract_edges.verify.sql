SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0042_stage2_operational_contract_edges' AND Status=N'Applied' AND FileSha256=N'$(MigrationSha256)') THROW 57620,N'Ledger 0042 no acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_CreateOrderAmountsV2_1',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_AuthorizeDocumentDownload',N'P') IS NULL THROW 57621,N'Contrato incompleto.',1;
SELECT N'0042_VERIFY_PASS' AS Result;
