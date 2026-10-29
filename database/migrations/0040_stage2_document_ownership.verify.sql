SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0040_stage2_document_ownership' AND Status=N'Applied' AND FileSha256=N'$(MigrationSha256)') THROW 57420,N'Ledger 0040 no acreditado.',1;
IF (SELECT COUNT(*) FROM sys.procedures WHERE name LIKE N'sp[_]Stage2[_]Document%')<>19 THROW 57421,N'Contrato Documents incompleto.',1;
SELECT N'0040_VERIFY_PASS' AS Result;
