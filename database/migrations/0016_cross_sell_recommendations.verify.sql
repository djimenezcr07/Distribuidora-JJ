SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0016_cross_sell_recommendations' AND Status=N'Applied' AND LEN(FileSha256)=64)
    THROW 54920,N'0016 no figura aplicada correctamente.',1;
IF OBJECT_ID(N'dbo.sp_Ventas_CrossSellSuggestions',N'P') IS NULL
    THROW 54921,N'Falta sp_Ventas_CrossSellSuggestions.',1;
SELECT MigrationId,FileName,FileSha256,Status,AppliedAtUtc
FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0016_cross_sell_recommendations';
