SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0043_stage2_sales_report_amounts' AND Status=N'Applied' AND FileSha256=N'$(MigrationSha256)') THROW 57720,N'Ledger 0043 no acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_ReportSalesAmountsV2',N'P') IS NULL THROW 57721,N'Reporte incompleto.',1;
SELECT N'0043_VERIFY_PASS' AS Result;
