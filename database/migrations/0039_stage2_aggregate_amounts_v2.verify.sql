SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0039_stage2_aggregate_amounts_v2' AND Status=N'Applied' AND FileSha256=N'$(MigrationSha256)') THROW 57220,N'Ledger 0039 no acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2OrderAmounts',N'U') IS NULL OR OBJECT_ID(N'dbo.Stage2OrderAmountLines',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_CreateOrderAmountsV2',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_GenerateInvoiceAmountsV2',N'P') IS NULL THROW 57221,N'Contrato V2 incompleto.',1;
IF EXISTS(SELECT 1 FROM dbo.Stage2OrderAmounts a WHERE a.Bruto-a.Descuento<>a.Neto OR a.Neto+a.Impuesto<>a.TotalFinal OR a.Impuesto<>ROUND(a.Neto*CONVERT(decimal(4,2),0.13),2)) THROW 57222,N'Importes inconsistentes.',1;
SELECT N'0039_VERIFY_PASS' AS Result;
