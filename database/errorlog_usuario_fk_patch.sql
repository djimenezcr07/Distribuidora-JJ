IF OBJECT_ID('dbo.ErrorLog', 'U') IS NULL
BEGIN
    PRINT 'La tabla ErrorLog no existe.';
    RETURN;
END;

IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
BEGIN
    PRINT 'La tabla Usuarios no existe.';
    RETURN;
END;

IF COL_LENGTH('dbo.ErrorLog', 'UsuarioId') IS NULL
BEGIN
    ALTER TABLE dbo.ErrorLog
    ADD UsuarioId INT NULL;

    PRINT 'Columna UsuarioId agregada a ErrorLog.';
END
ELSE
BEGIN
    PRINT 'La columna UsuarioId ya existe en ErrorLog.';
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = 'FK_ErrorLog_Usuarios'
)
BEGIN
    ALTER TABLE dbo.ErrorLog
    ADD CONSTRAINT FK_ErrorLog_Usuarios
    FOREIGN KEY (UsuarioId)
    REFERENCES dbo.Usuarios(UsuarioId);

    PRINT 'Llave foránea FK_ErrorLog_Usuarios creada correctamente.';
END
ELSE
BEGIN
    PRINT 'La llave foránea FK_ErrorLog_Usuarios ya existe.';
END;