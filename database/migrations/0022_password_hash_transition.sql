SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55000, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0022_password_hash_transition' AND Status = N'Applied')
    THROW 55001, N'0022 ya figura aplicada.', 1;
IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL OR OBJECT_ID(N'dbo.Perfiles', N'U') IS NULL
    THROW 55002, N'Faltan las tablas Usuarios o Perfiles.', 1;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.Usuarios', N'ContrasenaHash') IS NULL
    ALTER TABLE dbo.Usuarios ADD ContrasenaHash NVARCHAR(512) NULL;
IF COL_LENGTH(N'dbo.Usuarios', N'PasswordVersion') IS NULL
    ALTER TABLE dbo.Usuarios ADD PasswordVersion SMALLINT NOT NULL
        CONSTRAINT DF_Usuarios_PasswordVersion DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.Usuarios', N'DebeCambiarContrasena') IS NULL
    ALTER TABLE dbo.Usuarios ADD DebeCambiarContrasena BIT NOT NULL
        CONSTRAINT DF_Usuarios_DebeCambiarContrasena DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.Usuarios', N'PasswordActualizadaUtc') IS NULL
    ALTER TABLE dbo.Usuarios ADD PasswordActualizadaUtc DATETIME2(0) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetLoginCredential
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        p.Nombre AS PerfilNombre,
        u.Activo,
        u.ContrasenaHash,
        CAST(CASE
            WHEN NULLIF(u.ContrasenaHash, N'') IS NULL AND u.Contrasena = @Contrasena THEN 1
            ELSE 0
        END AS BIT) AS LegacyPasswordMatches
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo;
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
        PasswordVersion = 1,
        DebeCambiarContrasena = 0,
        PasswordActualizadaUtc = SYSUTCDATETIME()
    WHERE UsuarioId = @UsuarioId;

    IF @@ROWCOUNT <> 1 THROW 55011, N'Usuario inexistente.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_RegisterClient
    @NombreCompleto NVARCHAR(200),
    @Correo NVARCHAR(200),
    @Contrasena NVARCHAR(255) = NULL,
    @ContrasenaHash NVARCHAR(512) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), N'') IS NULL OR
       NULLIF(LTRIM(RTRIM(@Correo)), N'') IS NULL OR
       (NULLIF(@Contrasena, N'') IS NULL AND NULLIF(LTRIM(RTRIM(@ContrasenaHash)), N'') IS NULL)
        THROW 55012, N'Datos de registro inválidos.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = LTRIM(RTRIM(@Correo)))
        THROW 55013, N'El correo ya se encuentra registrado.', 1;

    DECLARE @PerfilId INT = (SELECT TOP (1) PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');
    IF @PerfilId IS NULL THROW 55014, N'No existe el perfil Cliente.', 1;

    INSERT dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, ContrasenaHash, PasswordVersion,
         DebeCambiarContrasena, PasswordActualizadaUtc, Activo)
    VALUES
        (@PerfilId, LTRIM(RTRIM(@NombreCompleto)), LTRIM(RTRIM(@Correo)), COALESCE(@Contrasena, N''),
         @ContrasenaHash, CASE WHEN NULLIF(@ContrasenaHash, N'') IS NULL THEN 0 ELSE 1 END,
         0, CASE WHEN NULLIF(@ContrasenaHash, N'') IS NULL THEN NULL ELSE SYSUTCDATETIME() END, 1);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UpdatePassword
    @UsuarioId INT,
    @Contrasena NVARCHAR(255) = NULL,
    @ContrasenaHash NVARCHAR(512) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@ContrasenaHash)), N'') IS NOT NULL
    BEGIN
        EXEC dbo.sp_Auth_SetPasswordHash @UsuarioId = @UsuarioId, @ContrasenaHash = @ContrasenaHash;
        RETURN;
    END;

    IF @Contrasena IS NULL THROW 55015, N'Credencial invÃ¡lida.', 1;
    UPDATE dbo.Usuarios
    SET Contrasena = @Contrasena,
        ContrasenaHash = NULL,
        PasswordVersion = 0,
        PasswordActualizadaUtc = SYSUTCDATETIME()
    WHERE UsuarioId = @UsuarioId;
    IF @@ROWCOUNT <> 1 THROW 55011, N'Usuario inexistente.', 1;
END;
GO

IF XACT_STATE() <> 1 THROW 55003, N'La transacción 0022 no está disponible.', 1;
DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55004, N'SHA-256 inválido para 0022.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0022_password_hash_transition', N'0022_password_hash_transition.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Transición compatible: PBKDF2 en API, actualización gradual al iniciar sesión y sin migrar texto directo a hashes inventados.');

COMMIT TRANSACTION;
GO
