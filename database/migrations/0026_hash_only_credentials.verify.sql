SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Activo = 1 AND NULLIF(LTRIM(RTRIM(ContrasenaHash)), N'') IS NULL)
    THROW 55266, N'Persisten usuarios activos sin hash.', 1;
IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NULLIF(LTRIM(RTRIM(ContrasenaHash)), N'') IS NOT NULL AND ISNULL(Contrasena, N'') <> N'')
    THROW 55267, N'Persisten credenciales plaintext junto a hashes.', 1;
IF EXISTS (
    SELECT 1 FROM sys.parameters
    WHERE object_id IN (OBJECT_ID(N'dbo.sp_Auth_GetLoginCredential'), OBJECT_ID(N'dbo.sp_Auth_UpdatePassword'),
                        OBJECT_ID(N'dbo.sp_Auth_RegisterClient'), OBJECT_ID(N'dbo.sp_Admin_CreateClient'),
                        OBJECT_ID(N'dbo.sp_Admin_UpdateClient'), OBJECT_ID(N'dbo.sp_Admin_CreateEmployee'),
                        OBJECT_ID(N'dbo.sp_RRHH_UpdateEmployee'))
      AND name = N'@Contrasena'
)
    THROW 55268, N'Una ruta activa todavía acepta @Contrasena plaintext.', 1;

SELECT MigrationId, FileName, FileSha256, Status, AppliedAtUtc
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'0026_hash_only_credentials';
