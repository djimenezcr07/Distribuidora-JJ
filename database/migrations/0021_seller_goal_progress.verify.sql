SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.sp_Metas_MiProgreso', N'P') IS NULL
    THROW 54920, N'Falta sp_Metas_MiProgreso.', 1;
IF NOT EXISTS (
    SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0021_seller_goal_progress' AND Status = N'Applied')
    THROW 54921, N'0021 no figura aplicada en el ledger.', 1;

SELECT MigrationId, FileName, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0021_seller_goal_progress';
GO
