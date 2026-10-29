SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0020_private_pay_slips' AND Status=N'Applied' AND LEN(FileSha256)=64) THROW 55330,N'0020 no figura aplicada.',1;
IF OBJECT_ID(N'dbo.PlanillaBoletaEnvios',N'U') IS NULL THROW 55331,N'Falta la bitácora privada de envíos.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Permisos WHERE Codigo=N'PLANILLA_BOLETAS_GESTIONAR' AND Activo=1) THROW 55332,N'Falta permiso de boletas.',1;
IF OBJECT_ID(N'dbo.sp_PaySlip_Listar',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_PaySlip_Obtener',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_PaySlip_PrepararEnvio',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_PaySlip_CompletarEnvio',N'P') IS NULL THROW 55333,N'Faltan procedimientos de boleta.',1;
IF EXISTS(SELECT 1 FROM dbo.PlanillaBoletaEnvios WHERE Estado=N'Exitoso' AND FechaResultadoUtc IS NULL) THROW 55334,N'Existe un envío exitoso sin fecha de resultado.',1;
SELECT MigrationId,FileSha256,Status,AppliedAtUtc FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0020_private_pay_slips';
