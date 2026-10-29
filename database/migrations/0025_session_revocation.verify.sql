SET NOCOUNT ON;

IF COL_LENGTH(N'dbo.Usuarios', N'SecurityStamp') IS NULL
    THROW 55254, N'Falta Usuarios.SecurityStamp.', 1;
IF OBJECT_ID(N'dbo.tr_Usuarios_RevokeSessions', N'TR') IS NULL
    THROW 55255, N'Falta el trigger de revocación.', 1;
IF OBJECT_ID(N'dbo.sp_Auth_GetSessionState', N'P') IS NULL
    THROW 55256, N'Falta sp_Auth_GetSessionState.', 1;
IF OBJECT_ID(N'dbo.sp_Auth_SetPasswordHash', N'P') IS NULL
    THROW 55258, N'Falta sp_Auth_SetPasswordHash.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Usuarios') AND name = N'SecurityStamp' AND is_nullable = 0)
    THROW 55257, N'SecurityStamp debe ser obligatorio.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0025_session_revocation';
