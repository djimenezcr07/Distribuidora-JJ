USE DistribuidoraJJ_DB;
GO

IF OBJECT_ID('dbo.PasswordResetTokens', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PasswordResetTokens (
        PasswordResetTokenId INT IDENTITY(1,1) PRIMARY KEY,
        UsuarioId INT NOT NULL,
        Token NVARCHAR(120) NOT NULL UNIQUE,
        FechaExpiracion DATETIME2 NOT NULL,
        Usado BIT NOT NULL DEFAULT 0,
        FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_PasswordResetTokens_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END
GO
