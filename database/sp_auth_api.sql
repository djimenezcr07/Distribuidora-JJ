USE DistribuidoraJJ_DB;
GO

/* =========================================================
   AUTENTICACION / API
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Auth_ValidateUser
    @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Contrasena,
        p.Nombre AS PerfilNombre,
        u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p
        ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo
      AND u.Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_EmailExists
    @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(1)
    FROM dbo.Usuarios
    WHERE Correo = @Correo;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_RegisterClient
    @NombreCompleto NVARCHAR(200),
    @Correo NVARCHAR(200),
    @Contrasena NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Usuarios
    (
        PerfilId,
        NombreCompleto,
        Correo,
        Contrasena,
        Activo
    )
    VALUES
    (
        (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente'),
        @NombreCompleto,
        @Correo,
        @Contrasena,
        1
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetUserByEmail
    @Correo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Contrasena,
        p.Nombre AS PerfilNombre,
        u.Activo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p
        ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_CreatePasswordResetToken
    @UsuarioId INT,
    @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.PasswordResetTokens
    (
        UsuarioId,
        Token,
        FechaExpiracion,
        Usado
    )
    VALUES
    (
        @UsuarioId,
        @Token,
        DATEADD(MINUTE, 30, SYSDATETIME()),
        0
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetValidResetToken
    @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        t.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        t.Token,
        t.FechaExpiracion,
        t.Usado
    FROM dbo.PasswordResetTokens t
    INNER JOIN dbo.Usuarios u
        ON u.UsuarioId = t.UsuarioId
    WHERE t.Token = @Token;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UpdatePassword
    @UsuarioId INT,
    @Contrasena NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Usuarios
    SET Contrasena = @Contrasena
    WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UseResetToken
    @Token NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.PasswordResetTokens
    SET Usado = 1
    WHERE Token = @Token;
END
GO