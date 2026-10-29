SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55250, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0025_session_revocation' AND Status = N'Applied')
    THROW 55251, N'0025 ya figura aplicada.', 1;
IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL OR OBJECT_ID(N'dbo.Perfiles', N'U') IS NULL
    THROW 55252, N'Faltan Usuarios o Perfiles.', 1;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.Usuarios', N'SecurityStamp') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios ADD SecurityStamp UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_Usuarios_SecurityStamp DEFAULT NEWID() WITH VALUES;
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER TRIGGER dbo.tr_Usuarios_RevokeSessions
ON dbo.Usuarios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE usuario
    SET SecurityStamp = NEWID()
    FROM dbo.Usuarios usuario
    INNER JOIN inserted nuevo ON nuevo.UsuarioId = usuario.UsuarioId
    INNER JOIN deleted anterior ON anterior.UsuarioId = nuevo.UsuarioId
    WHERE nuevo.Activo <> anterior.Activo
       OR nuevo.PerfilId <> anterior.PerfilId
       OR ISNULL(nuevo.ContrasenaHash, N'') <> ISNULL(anterior.ContrasenaHash, N'')
       OR ISNULL(nuevo.Contrasena, N'') <> ISNULL(anterior.Contrasena, N'')
       OR ISNULL(nuevo.PasswordVersion, 0) <> ISNULL(anterior.PasswordVersion, 0);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetSessionState
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT usuario.Activo,
           perfil.Nombre AS PerfilNombre,
           usuario.SecurityStamp
    FROM dbo.Usuarios usuario
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId
    WHERE usuario.UsuarioId = @UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_SetPasswordHash
    @UsuarioId INT,
    @ContrasenaHash NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;
    IF @UsuarioId <= 0 OR NULLIF(LTRIM(RTRIM(@ContrasenaHash)), N'') IS NULL
        THROW 55010, N'Credencial hash inválida.', 1;

    UPDATE dbo.Usuarios
    SET ContrasenaHash = @ContrasenaHash,
        Contrasena = N'',
        PasswordVersion = CASE WHEN PasswordVersion < 1 THEN 1 ELSE PasswordVersion + 1 END,
        DebeCambiarContrasena = 0,
        PasswordActualizadaUtc = SYSUTCDATETIME()
    WHERE UsuarioId = @UsuarioId;

    IF @@ROWCOUNT <> 1 THROW 55011, N'Usuario inexistente.', 1;

    SELECT SecurityStamp FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetLoginCredential
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        usuario.UsuarioId,
        usuario.NombreCompleto,
        usuario.Correo,
        perfil.Nombre AS PerfilNombre,
        usuario.Activo,
        usuario.ContrasenaHash,
        CAST(CASE
            WHEN NULLIF(usuario.ContrasenaHash, N'') IS NULL AND usuario.Contrasena = @Contrasena THEN 1
            ELSE 0
        END AS BIT) AS LegacyPasswordMatches,
        usuario.SecurityStamp
    FROM dbo.Usuarios usuario
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId
    WHERE usuario.Correo = @Correo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetUserByEmail
    @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        usuario.UsuarioId,
        usuario.NombreCompleto,
        usuario.Correo,
        perfil.Nombre AS PerfilNombre,
        usuario.Activo,
        usuario.SecurityStamp
    FROM dbo.Usuarios usuario
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId
    WHERE usuario.Correo = LTRIM(RTRIM(@Correo));
END;
GO

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55253, N'SHA-256 inválido para 0025.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0025_session_revocation', N'0025_session_revocation.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Revocación central de sesión por inactivación, cambio de perfil o credencial.');
GO
