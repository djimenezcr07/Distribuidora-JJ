SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Chat privado seguro. Esta migración es aditiva y no depende de una base con nombre fijo.
  Rollback: retirar los procedimientos sp_Chat_* de este archivo y, solamente si se confirma
  que no existen datos útiles, eliminar dbo.ChatMensajes y dbo.ChatConversaciones.
*/
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.ChatConversaciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatConversaciones
    (
        ConversacionId INT IDENTITY(1,1) NOT NULL,
        UsuarioMenorId INT NOT NULL,
        UsuarioMayorId INT NOT NULL,
        FechaCreacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_ChatConversaciones_FechaCreacion DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ChatConversaciones PRIMARY KEY (ConversacionId),
        CONSTRAINT FK_ChatConversaciones_UsuarioMenor FOREIGN KEY (UsuarioMenorId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_ChatConversaciones_UsuarioMayor FOREIGN KEY (UsuarioMayorId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_ChatConversaciones_Orden CHECK (UsuarioMenorId < UsuarioMayorId),
        CONSTRAINT UQ_ChatConversaciones_Par UNIQUE (UsuarioMenorId, UsuarioMayorId)
    );
END;

IF OBJECT_ID(N'dbo.ChatMensajes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatMensajes
    (
        MensajeId BIGINT IDENTITY(1,1) NOT NULL,
        ConversacionId INT NOT NULL,
        RemitenteId INT NOT NULL,
        Contenido NVARCHAR(1000) NOT NULL,
        FechaEnvio DATETIME2(0) NOT NULL
            CONSTRAINT DF_ChatMensajes_FechaEnvio DEFAULT SYSUTCDATETIME(),
        Leido BIT NOT NULL CONSTRAINT DF_ChatMensajes_Leido DEFAULT 0,
        CONSTRAINT PK_ChatMensajes PRIMARY KEY (MensajeId),
        CONSTRAINT FK_ChatMensajes_Conversacion FOREIGN KEY (ConversacionId)
            REFERENCES dbo.ChatConversaciones(ConversacionId),
        CONSTRAINT FK_ChatMensajes_Remitente FOREIGN KEY (RemitenteId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_ChatMensajes_Contenido CHECK (LEN(LTRIM(RTRIM(Contenido))) BETWEEN 1 AND 1000)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ChatMensajes')
      AND name = N'IX_ChatMensajes_Conversacion_Fecha'
)
BEGIN
    CREATE INDEX IX_ChatMensajes_Conversacion_Fecha
        ON dbo.ChatMensajes (ConversacionId, FechaEnvio DESC, MensajeId DESC)
        INCLUDE (RemitenteId, Leido);
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_GetUsers
    @UsuarioIdActual INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.UsuarioId, u.NombreCompleto, u.Correo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.Activo = 1
      AND p.Activo = 1
      AND u.UsuarioId <> @UsuarioIdActual
      AND p.Nombre <> N'Cliente'
    ORDER BY u.NombreCompleto, u.UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_GetOrCreateConversation
    @UsuarioActualId INT,
    @OtroUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @UsuarioActualId <= 0 OR @OtroUsuarioId <= 0 OR @UsuarioActualId = @OtroUsuarioId
        THROW 51000, N'Los participantes de la conversación no son válidos.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @UsuarioActualId AND u.Activo = 1 AND p.Activo = 1 AND p.Nombre <> N'Cliente'
    ) OR NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @OtroUsuarioId AND u.Activo = 1 AND p.Activo = 1 AND p.Nombre <> N'Cliente'
    )
        THROW 51001, N'No es posible iniciar la conversación solicitada.', 1;

    DECLARE @Menor INT = IIF(@UsuarioActualId < @OtroUsuarioId, @UsuarioActualId, @OtroUsuarioId);
    DECLARE @Mayor INT = IIF(@UsuarioActualId < @OtroUsuarioId, @OtroUsuarioId, @UsuarioActualId);
    DECLARE @ConversacionId INT;

    BEGIN TRANSACTION;

    SELECT @ConversacionId = ConversacionId
    FROM dbo.ChatConversaciones WITH (UPDLOCK, HOLDLOCK)
    WHERE UsuarioMenorId = @Menor AND UsuarioMayorId = @Mayor;

    IF @ConversacionId IS NULL
    BEGIN
        INSERT INTO dbo.ChatConversaciones (UsuarioMenorId, UsuarioMayorId)
        VALUES (@Menor, @Mayor);
        SET @ConversacionId = CONVERT(INT, SCOPE_IDENTITY());
    END;

    COMMIT TRANSACTION;
    SELECT @ConversacionId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_IsConversationMember
    @ConversacionId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(BIT, IIF(EXISTS
    (
        SELECT 1 FROM dbo.ChatConversaciones
        WHERE ConversacionId = @ConversacionId
          AND @UsuarioId IN (UsuarioMenorId, UsuarioMayorId)
    ), 1, 0));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_SendMessage
    @ConversacionId INT,
    @RemitenteId INT,
    @Contenido NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Contenido = LTRIM(RTRIM(@Contenido));
    IF LEN(@Contenido) NOT BETWEEN 1 AND 1000
        THROW 51002, N'El contenido del mensaje no es válido.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ChatConversaciones
        WHERE ConversacionId = @ConversacionId
          AND @RemitenteId IN (UsuarioMenorId, UsuarioMayorId)
    )
        THROW 51003, N'El usuario no pertenece a la conversación.', 1;

    INSERT INTO dbo.ChatMensajes (ConversacionId, RemitenteId, Contenido)
    VALUES (@ConversacionId, @RemitenteId, @Contenido);

    DECLARE @MensajeId BIGINT = SCOPE_IDENTITY();
    SELECT CONVERT(INT, m.MensajeId) AS MensajeId,
           m.ConversacionId, m.RemitenteId, m.Contenido, m.FechaEnvio, m.Leido
    FROM dbo.ChatMensajes m
    WHERE m.MensajeId = @MensajeId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_GetMessages
    @ConversacionId INT,
    @UsuarioId INT,
    @Pagina INT = 1,
    @TamanoPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ChatConversaciones
        WHERE ConversacionId = @ConversacionId
          AND @UsuarioId IN (UsuarioMenorId, UsuarioMayorId)
    )
        THROW 51004, N'El usuario no pertenece a la conversación.', 1;

    SET @Pagina = IIF(@Pagina < 1, 1, @Pagina);
    SET @TamanoPagina = IIF(@TamanoPagina BETWEEN 1 AND 100, @TamanoPagina, 50);

    UPDATE dbo.ChatMensajes
    SET Leido = 1
    WHERE ConversacionId = @ConversacionId
      AND RemitenteId <> @UsuarioId
      AND Leido = 0;

    ;WITH Ordenados AS
    (
        SELECT CONVERT(INT, m.MensajeId) AS MensajeId,
               m.ConversacionId, m.RemitenteId, m.Contenido, m.FechaEnvio, m.Leido,
               ROW_NUMBER() OVER (ORDER BY m.FechaEnvio DESC, m.MensajeId DESC) AS Numero
        FROM dbo.ChatMensajes m
        WHERE m.ConversacionId = @ConversacionId
    )
    SELECT MensajeId, ConversacionId, RemitenteId, Contenido, FechaEnvio, Leido
    FROM Ordenados
    WHERE Numero BETWEEN ((@Pagina - 1) * @TamanoPagina) + 1 AND @Pagina * @TamanoPagina
    ORDER BY FechaEnvio, MensajeId;
END;
GO

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0002_chat_private_security')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0002_chat_private_security', N'0002_chat_private_security.sql',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', N'0002_chat_private_security_v1'), 2),
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Hash de manifiesto v1; el ejecutor debe sustituirlo por el SHA-256 del archivo en la evidencia del despliegue.');
END;
GO
