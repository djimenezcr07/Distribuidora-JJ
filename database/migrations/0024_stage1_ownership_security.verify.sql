SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.sp_Kilometraje_Cerrar', N'P') IS NULL
    THROW 55244, N'No existe sp_Kilometraje_Cerrar.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.sp_Kilometraje_Cerrar') AND name = N'@ActorUsuarioId')
    THROW 55245, N'Falta el actor en sp_Kilometraje_Cerrar.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.sp_Kilometraje_Cerrar') AND name = N'@PuedeAdministrar')
    THROW 55246, N'Falta la capacidad administrativa en sp_Kilometraje_Cerrar.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'FLOTA_KILOMETRAJE_ADMIN' AND Activo = 1)
    THROW 55247, N'Falta el permiso administrativo de kilometraje.', 1;

DECLARE @Definition NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_Kilometraje_Cerrar'));
IF CHARINDEX(N'BEGIN TRANSACTION', @Definition) = 0
   OR CHARINDEX(N'BEGIN TRANSACTION', @Definition) > CHARINDEX(N'WITH (UPDLOCK, HOLDLOCK)', @Definition)
    THROW 55248, N'La lectura protegida no está dentro de la transacción de cierre.', 1;
IF @Definition NOT LIKE N'%AND KmFinal IS NULL%'
    THROW 55249, N'El cierre no condiciona la actualización a una jornada abierta.', 1;
IF @Definition NOT LIKE N'%@@ROWCOUNT <> 1%'
    THROW 55250, N'El cierre no verifica una única actualización.', 1;
IF @Definition NOT LIKE N'%ChoferUsuarioId = @ActorUsuarioId%'
    THROW 55251, N'El cierre no conserva ownership en la actualización efectiva.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0024_stage1_ownership_security';
