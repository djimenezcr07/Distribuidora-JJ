SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0041_stage2_logistics_integrity' AND Status=N'Applied' AND FileSha256=N'$(MigrationSha256)') THROW 57520,N'Ledger 0041 no acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2EvidenceIntegrity',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_ConfirmDelivery',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_RouteOperation',N'P') IS NULL THROW 57521,N'Contrato logistico incompleto.',1;
SELECT N'0041_VERIFY_PASS' AS Result;
