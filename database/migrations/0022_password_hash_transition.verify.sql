SET NOCOUNT ON;

IF COL_LENGTH(N'dbo.Usuarios', N'ContrasenaHash') IS NULL OR
   COL_LENGTH(N'dbo.Usuarios', N'PasswordVersion') IS NULL OR
   COL_LENGTH(N'dbo.Usuarios', N'DebeCambiarContrasena') IS NULL OR
   COL_LENGTH(N'dbo.Usuarios', N'PasswordActualizadaUtc') IS NULL
    THROW 55020, N'Faltan columnas de transición de credenciales.', 1;

IF OBJECT_ID(N'dbo.sp_Auth_GetLoginCredential', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Auth_SetPasswordHash', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Auth_RegisterClient', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Auth_UpdatePassword', N'P') IS NULL
    THROW 55021, N'Faltan procedimientos de credenciales 0022.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0022_password_hash_transition' AND Status = N'Applied')
    THROW 55022, N'0022 no figura aplicada en el ledger.', 1;

SELECT
    CAST(COUNT_BIG(*) AS BIGINT) AS TotalUsuarios,
    CAST(SUM(CASE WHEN NULLIF(ContrasenaHash, N'') IS NOT NULL THEN 1 ELSE 0 END) AS BIGINT) AS UsuariosConHash,
    CAST(SUM(CASE WHEN NULLIF(ContrasenaHash, N'') IS NULL THEN 1 ELSE 0 END) AS BIGINT) AS UsuariosPendientesMigracion
FROM dbo.Usuarios;
GO
