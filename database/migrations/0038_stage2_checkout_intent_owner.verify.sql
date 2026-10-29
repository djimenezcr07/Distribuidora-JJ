SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0038_stage2_checkout_intent_owner' AND Status=N'Applied')
 THROW 57120,N'Falta ledger 0038.',1;
IF OBJECT_ID(N'dbo.Stage2CheckoutIntentOwners',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_Stage2_ClaimCheckoutIntent',N'P') IS NULL
 OR OBJECT_ID(N'dbo.tr_Stage2CheckoutIntentOwners_Immutable',N'TR') IS NULL THROW 57121,N'Contrato de propietario incompleto.',1;
IF (SELECT COUNT(*) FROM sys.parameters WHERE object_id=OBJECT_ID(N'dbo.sp_Stage2_ClaimCheckoutIntent'))<>9
 THROW 57122,N'Parametros de contexto incompletos.',1;
SELECT N'PASS: checkout con propietario original y contenido inmutables' AS Result;
