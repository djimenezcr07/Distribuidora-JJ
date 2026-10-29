SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0031_stage2_physical_delivery' AND Status=N'Applied')
    THROW 56340,N'0031 no acreditada en ledger.',1;
IF OBJECT_ID(N'dbo.Stage2PhysicalDeliveries',N'U') IS NULL
    THROW 56341,N'Falta evidencia fisica canonica.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Chofer_UpdateDeliveryStatus')
              AND uses_quoted_identifier=1 AND uses_ansi_nulls=1)
    THROW 56342,N'Opciones de compilacion SQL incompatibles con indices filtrados.',1;
IF NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.sp_Chofer_UpdateDeliveryStatus')
              AND name=N'@ExpectedSecurityStamp' AND TYPE_NAME(user_type_id)=N'uniqueidentifier')
    THROW 56343,N'Falta contexto autenticado tipado.',1;
SELECT N'PASS' AS Result,COUNT(*) AS PhysicalConfirmations FROM dbo.Stage2PhysicalDeliveries;
