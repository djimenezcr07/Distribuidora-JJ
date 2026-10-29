SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Departamentos de chat independientes de perfiles, membresía explícita, búsqueda autorizada
  y auditoría administrativa. Requiere 0002_chat_private_security.sql.
  Rollback: desactivar departamentos y retirar procedimientos; conservar tablas para no perder historial.
*/
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.ChatDepartamentos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatDepartamentos
    (
        DepartamentoId INT IDENTITY(1,1) NOT NULL,
        Nombre NVARCHAR(120) NOT NULL,
        Descripcion NVARCHAR(300) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_ChatDepartamentos_Activo DEFAULT 1,
        CreadoPorUsuarioId INT NOT NULL,
        FechaCreacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_ChatDepartamentos_FechaCreacion DEFAULT SYSUTCDATETIME(),
        FechaActualizacion DATETIME2(0) NULL,
        CONSTRAINT PK_ChatDepartamentos PRIMARY KEY (DepartamentoId),
        CONSTRAINT FK_ChatDepartamentos_CreadoPor FOREIGN KEY (CreadoPorUsuarioId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT UQ_ChatDepartamentos_Nombre UNIQUE (Nombre)
    );
END;

IF OBJECT_ID(N'dbo.ChatDepartamentoMiembros', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatDepartamentoMiembros
    (
        DepartamentoId INT NOT NULL,
        UsuarioId INT NOT NULL,
        PuedePublicar BIT NOT NULL CONSTRAINT DF_ChatDepartamentoMiembros_PuedePublicar DEFAULT 1,
        AgregadoPorUsuarioId INT NOT NULL,
        FechaAsignacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_ChatDepartamentoMiembros_FechaAsignacion DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ChatDepartamentoMiembros PRIMARY KEY (DepartamentoId, UsuarioId),
        CONSTRAINT FK_ChatDepartamentoMiembros_Departamento FOREIGN KEY (DepartamentoId)
            REFERENCES dbo.ChatDepartamentos(DepartamentoId),
        CONSTRAINT FK_ChatDepartamentoMiembros_Usuario FOREIGN KEY (UsuarioId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_ChatDepartamentoMiembros_AgregadoPor FOREIGN KEY (AgregadoPorUsuarioId)
            REFERENCES dbo.Usuarios(UsuarioId)
    );
END;

IF OBJECT_ID(N'dbo.ChatDepartamentoMensajes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatDepartamentoMensajes
    (
        MensajeId BIGINT IDENTITY(1,1) NOT NULL,
        DepartamentoId INT NOT NULL,
        RemitenteId INT NOT NULL,
        Contenido NVARCHAR(1000) NOT NULL,
        FechaEnvio DATETIME2(0) NOT NULL
            CONSTRAINT DF_ChatDepartamentoMensajes_FechaEnvio DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ChatDepartamentoMensajes PRIMARY KEY (MensajeId),
        CONSTRAINT FK_ChatDepartamentoMensajes_Departamento FOREIGN KEY (DepartamentoId)
            REFERENCES dbo.ChatDepartamentos(DepartamentoId),
        CONSTRAINT FK_ChatDepartamentoMensajes_Remitente FOREIGN KEY (RemitenteId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_ChatDepartamentoMensajes_Contenido CHECK (LEN(LTRIM(RTRIM(Contenido))) BETWEEN 1 AND 1000)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ChatDepartamentoMensajes')
      AND name = N'IX_ChatDepartamentoMensajes_Departamento_Fecha'
)
BEGIN
    CREATE INDEX IX_ChatDepartamentoMensajes_Departamento_Fecha
        ON dbo.ChatDepartamentoMensajes (DepartamentoId, FechaEnvio DESC, MensajeId DESC)
        INCLUDE (RemitenteId);
END;

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
        (N'CHAT_DEPARTAMENTOS_GESTIONAR', N'Chat', N'Gestionar departamentos de chat',
         N'Permite crear y editar departamentos y administrar sus miembros.')
    ) AS source (Codigo, Modulo, Nombre, Descripcion)
    ON target.Codigo = source.Codigo
    WHEN MATCHED THEN UPDATE SET
        target.Modulo = source.Modulo,
        target.Nombre = source.Nombre,
        target.Descripcion = source.Descripcion,
        target.Activo = 1
    WHEN NOT MATCHED THEN
        INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);

    IF OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
        SELECT p.PerfilId, pe.PermisoId, NULL, N'Migración 0003'
        FROM dbo.Perfiles p
        INNER JOIN dbo.Permisos pe ON pe.Codigo = N'CHAT_DEPARTAMENTOS_GESTIONAR'
        WHERE p.Nombre = N'Administrador'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerfilPermisos pp
              WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId
          );
    END;
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_WriteAudit
    @ActorUsuarioId INT,
    @Accion NVARCHAR(80),
    @Descripcion NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID(N'dbo.AuditoriaSistema', N'U') IS NULL RETURN;

    INSERT INTO dbo.AuditoriaSistema
        (UsuarioId, UsuarioNombre, UsuarioCorreo, Rol, Accion, Modulo, Descripcion)
    SELECT u.UsuarioId, u.NombreCompleto, u.Correo, p.Nombre,
           @Accion, N'Chat', @Descripcion
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.UsuarioId = @ActorUsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_GetDepartments
    @UsuarioId INT,
    @PuedeAdministrarTodo BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DepartamentoId, d.Nombre, d.Descripcion,
           CONVERT(INT, COUNT(m.UsuarioId)) AS TotalUsuarios,
           CONVERT(BIT, IIF(@PuedeAdministrarTodo = 1, 1, MAX(CONVERT(INT, me.PuedePublicar)))) AS PuedePublicar
    FROM dbo.ChatDepartamentos d
    LEFT JOIN dbo.ChatDepartamentoMiembros m ON m.DepartamentoId = d.DepartamentoId
    LEFT JOIN dbo.ChatDepartamentoMiembros me
        ON me.DepartamentoId = d.DepartamentoId AND me.UsuarioId = @UsuarioId
    WHERE d.Activo = 1
      AND (@PuedeAdministrarTodo = 1 OR me.UsuarioId IS NOT NULL)
    GROUP BY d.DepartamentoId, d.Nombre, d.Descripcion
    ORDER BY d.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_IsDepartmentMember
    @DepartamentoId INT,
    @UsuarioId INT,
    @PuedeAdministrarTodo BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(BIT, IIF(EXISTS
    (
        SELECT 1
        FROM dbo.ChatDepartamentos d
        LEFT JOIN dbo.ChatDepartamentoMiembros m
            ON m.DepartamentoId = d.DepartamentoId AND m.UsuarioId = @UsuarioId
        WHERE d.DepartamentoId = @DepartamentoId
          AND d.Activo = 1
          AND (@PuedeAdministrarTodo = 1 OR m.UsuarioId IS NOT NULL)
    ), 1, 0));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_CanPostToDepartment
    @DepartamentoId INT,
    @UsuarioId INT,
    @PuedeAdministrarTodo BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(BIT, IIF(EXISTS
    (
        SELECT 1
        FROM dbo.ChatDepartamentos d
        LEFT JOIN dbo.ChatDepartamentoMiembros m
            ON m.DepartamentoId = d.DepartamentoId AND m.UsuarioId = @UsuarioId
        WHERE d.DepartamentoId = @DepartamentoId
          AND d.Activo = 1
          AND (@PuedeAdministrarTodo = 1 OR m.PuedePublicar = 1)
    ), 1, 0));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_SendDepartmentMessage
    @DepartamentoId INT,
    @RemitenteId INT,
    @Contenido NVARCHAR(1000),
    @PuedeAdministrarTodo BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Contenido = LTRIM(RTRIM(@Contenido));
    IF LEN(@Contenido) NOT BETWEEN 1 AND 1000
        THROW 51100, N'El contenido del mensaje no es válido.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ChatDepartamentos d
        LEFT JOIN dbo.ChatDepartamentoMiembros m
            ON m.DepartamentoId = d.DepartamentoId AND m.UsuarioId = @RemitenteId
        WHERE d.DepartamentoId = @DepartamentoId
          AND d.Activo = 1
          AND (@PuedeAdministrarTodo = 1 OR m.PuedePublicar = 1)
    )
        THROW 51101, N'El usuario no puede publicar en el departamento.', 1;

    INSERT INTO dbo.ChatDepartamentoMensajes (DepartamentoId, RemitenteId, Contenido)
    VALUES (@DepartamentoId, @RemitenteId, @Contenido);

    DECLARE @MensajeId BIGINT = SCOPE_IDENTITY();
    SELECT CONVERT(INT, m.MensajeId) AS MensajeId, m.DepartamentoId, m.RemitenteId,
           m.Contenido, m.FechaEnvio, u.NombreCompleto AS RemitenteNombre
    FROM dbo.ChatDepartamentoMensajes m
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = m.RemitenteId
    WHERE m.MensajeId = @MensajeId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_GetDepartmentMessages
    @DepartamentoId INT,
    @UsuarioId INT,
    @PuedeAdministrarTodo BIT = 0,
    @Pagina INT = 1,
    @TamanoPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ChatDepartamentos d
        LEFT JOIN dbo.ChatDepartamentoMiembros m
            ON m.DepartamentoId = d.DepartamentoId AND m.UsuarioId = @UsuarioId
        WHERE d.DepartamentoId = @DepartamentoId
          AND d.Activo = 1
          AND (@PuedeAdministrarTodo = 1 OR m.UsuarioId IS NOT NULL)
    )
        THROW 51102, N'El usuario no pertenece al departamento.', 1;

    SET @Pagina = IIF(@Pagina < 1, 1, @Pagina);
    SET @TamanoPagina = IIF(@TamanoPagina BETWEEN 1 AND 100, @TamanoPagina, 50);

    ;WITH Ordenados AS
    (
        SELECT CONVERT(INT, m.MensajeId) AS MensajeId, m.DepartamentoId, m.RemitenteId,
               m.Contenido, m.FechaEnvio, u.NombreCompleto AS RemitenteNombre,
               ROW_NUMBER() OVER (ORDER BY m.FechaEnvio DESC, m.MensajeId DESC) AS Numero
        FROM dbo.ChatDepartamentoMensajes m
        INNER JOIN dbo.Usuarios u ON u.UsuarioId = m.RemitenteId
        WHERE m.DepartamentoId = @DepartamentoId
    )
    SELECT MensajeId, DepartamentoId, RemitenteId, Contenido, FechaEnvio, RemitenteNombre
    FROM Ordenados
    WHERE Numero BETWEEN ((@Pagina - 1) * @TamanoPagina) + 1 AND @Pagina * @TamanoPagina
    ORDER BY FechaEnvio, MensajeId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_SearchMessages
    @UsuarioId INT,
    @Texto NVARCHAR(100),
    @Tipo NVARCHAR(20) = N'todos',
    @ConversacionId INT = NULL,
    @DepartamentoId INT = NULL,
    @PuedeAdministrarTodo BIT = 0,
    @Pagina INT = 1,
    @TamanoPagina INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    SET @Texto = LTRIM(RTRIM(@Texto));
    IF LEN(@Texto) < 2 THROW 51103, N'El texto de búsqueda es demasiado corto.', 1;
    SET @Pagina = IIF(@Pagina < 1, 1, @Pagina);
    SET @TamanoPagina = IIF(@TamanoPagina BETWEEN 1 AND 100, @TamanoPagina, 25);

    ;WITH Autorizados AS
    (
        SELECT CONVERT(INT, m.MensajeId) AS MensajeId,
               N'privado' AS TipoOrigen,
               c.ConversacionId,
               CONVERT(INT, NULL) AS DepartamentoId,
               otro.NombreCompleto AS Origen,
               m.RemitenteId,
               remitente.NombreCompleto AS RemitenteNombre,
               m.Contenido,
               m.FechaEnvio
        FROM dbo.ChatMensajes m
        INNER JOIN dbo.ChatConversaciones c ON c.ConversacionId = m.ConversacionId
        INNER JOIN dbo.Usuarios remitente ON remitente.UsuarioId = m.RemitenteId
        INNER JOIN dbo.Usuarios otro
            ON otro.UsuarioId = IIF(c.UsuarioMenorId = @UsuarioId, c.UsuarioMayorId, c.UsuarioMenorId)
        WHERE @UsuarioId IN (c.UsuarioMenorId, c.UsuarioMayorId)
          AND (@Tipo IN (N'todos', N'privado'))
          AND (@ConversacionId IS NULL OR c.ConversacionId = @ConversacionId)

        UNION ALL

        SELECT CONVERT(INT, m.MensajeId), N'departamento', NULL, d.DepartamentoId,
               d.Nombre, m.RemitenteId, remitente.NombreCompleto, m.Contenido, m.FechaEnvio
        FROM dbo.ChatDepartamentoMensajes m
        INNER JOIN dbo.ChatDepartamentos d ON d.DepartamentoId = m.DepartamentoId AND d.Activo = 1
        INNER JOIN dbo.Usuarios remitente ON remitente.UsuarioId = m.RemitenteId
        LEFT JOIN dbo.ChatDepartamentoMiembros miembro
            ON miembro.DepartamentoId = d.DepartamentoId AND miembro.UsuarioId = @UsuarioId
        WHERE (@PuedeAdministrarTodo = 1 OR miembro.UsuarioId IS NOT NULL)
          AND (@Tipo IN (N'todos', N'departamento'))
          AND (@DepartamentoId IS NULL OR d.DepartamentoId = @DepartamentoId)
    ),
    Filtrados AS
    (
        SELECT *, COUNT(*) OVER () AS TotalResultados,
               ROW_NUMBER() OVER (ORDER BY FechaEnvio DESC, MensajeId DESC) AS Numero
        FROM Autorizados
        WHERE Contenido LIKE N'%' + @Texto + N'%'
    )
    SELECT MensajeId, TipoOrigen, ConversacionId, DepartamentoId, Origen,
           RemitenteId, RemitenteNombre, Contenido, FechaEnvio, CONVERT(INT, TotalResultados) AS TotalResultados
    FROM Filtrados
    WHERE Numero BETWEEN ((@Pagina - 1) * @TamanoPagina) + 1 AND @Pagina * @TamanoPagina
    ORDER BY FechaEnvio DESC, MensajeId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_Admin_GetDepartments
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DepartamentoId, d.Nombre, d.Descripcion, d.Activo,
           CONVERT(INT, COUNT(m.UsuarioId)) AS TotalMiembros
    FROM dbo.ChatDepartamentos d
    LEFT JOIN dbo.ChatDepartamentoMiembros m ON m.DepartamentoId = d.DepartamentoId
    GROUP BY d.DepartamentoId, d.Nombre, d.Descripcion, d.Activo
    ORDER BY d.Nombre;

    SELECT m.DepartamentoId, m.UsuarioId, u.NombreCompleto, u.Correo, m.PuedePublicar
    FROM dbo.ChatDepartamentoMiembros m
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = m.UsuarioId
    ORDER BY m.DepartamentoId, u.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_Admin_CreateDepartment
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(300) = NULL,
    @Activo BIT = 1,
    @ActorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF LEN(@Nombre) NOT BETWEEN 2 AND 120 THROW 51104, N'El nombre no es válido.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ChatDepartamentos WHERE Nombre = @Nombre)
        THROW 51105, N'Ya existe un departamento con ese nombre.', 1;

    BEGIN TRANSACTION;
    INSERT INTO dbo.ChatDepartamentos (Nombre, Descripcion, Activo, CreadoPorUsuarioId)
    VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @Activo, @ActorUsuarioId);
    DECLARE @DepartamentoId INT = CONVERT(INT, SCOPE_IDENTITY());
    DECLARE @DetalleAuditoria NVARCHAR(500) = CONCAT(N'Departamento de chat creado. ID: ', @DepartamentoId, N'.');
    EXEC dbo.sp_Chat_WriteAudit @ActorUsuarioId, N'CREAR_DEPARTAMENTO', @DetalleAuditoria;
    COMMIT TRANSACTION;
    SELECT @DepartamentoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_Admin_UpdateDepartment
    @DepartamentoId INT,
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(300) = NULL,
    @Activo BIT,
    @ActorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF LEN(@Nombre) NOT BETWEEN 2 AND 120 THROW 51106, N'El nombre no es válido.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ChatDepartamentos WHERE Nombre = @Nombre AND DepartamentoId <> @DepartamentoId)
        THROW 51107, N'Ya existe un departamento con ese nombre.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.ChatDepartamentos
    SET Nombre = @Nombre,
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N''),
        Activo = @Activo,
        FechaActualizacion = SYSUTCDATETIME()
    WHERE DepartamentoId = @DepartamentoId;
    IF @@ROWCOUNT = 0 THROW 51108, N'El departamento no existe.', 1;
    DECLARE @DetalleAuditoria NVARCHAR(500) = CONCAT(N'Departamento de chat actualizado. ID: ', @DepartamentoId, N'.');
    EXEC dbo.sp_Chat_WriteAudit @ActorUsuarioId, N'ACTUALIZAR_DEPARTAMENTO', @DetalleAuditoria;
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_Admin_AddMember
    @DepartamentoId INT,
    @UsuarioId INT,
    @PuedePublicar BIT = 1,
    @ActorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.ChatDepartamentos WHERE DepartamentoId = @DepartamentoId)
        THROW 51109, N'El departamento no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND Activo = 1)
        THROW 51110, N'El usuario no está disponible.', 1;

    BEGIN TRANSACTION;
    MERGE dbo.ChatDepartamentoMiembros AS target
    USING (SELECT @DepartamentoId AS DepartamentoId, @UsuarioId AS UsuarioId) AS source
    ON target.DepartamentoId = source.DepartamentoId AND target.UsuarioId = source.UsuarioId
    WHEN MATCHED THEN UPDATE SET
        PuedePublicar = @PuedePublicar,
        AgregadoPorUsuarioId = @ActorUsuarioId,
        FechaAsignacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (DepartamentoId, UsuarioId, PuedePublicar, AgregadoPorUsuarioId)
        VALUES (@DepartamentoId, @UsuarioId, @PuedePublicar, @ActorUsuarioId);
    DECLARE @DetalleAuditoria NVARCHAR(500) = CONCAT(N'Miembro ', @UsuarioId, N' asignado al departamento de chat ', @DepartamentoId, N'.');
    EXEC dbo.sp_Chat_WriteAudit @ActorUsuarioId, N'ASIGNAR_MIEMBRO', @DetalleAuditoria;
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chat_Admin_RemoveMember
    @DepartamentoId INT,
    @UsuarioId INT,
    @ActorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DELETE FROM dbo.ChatDepartamentoMiembros
    WHERE DepartamentoId = @DepartamentoId AND UsuarioId = @UsuarioId;
    DECLARE @DetalleAuditoria NVARCHAR(500) = CONCAT(N'Miembro ', @UsuarioId, N' retirado del departamento de chat ', @DepartamentoId, N'.');
    EXEC dbo.sp_Chat_WriteAudit @ActorUsuarioId, N'RETIRAR_MIEMBRO', @DetalleAuditoria;
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0003_chat_departments_and_search')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0003_chat_departments_and_search', N'0003_chat_departments_and_search.sql',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', N'0003_chat_departments_and_search_v1'), 2),
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Hash de manifiesto v1; el ejecutor debe sustituirlo por el SHA-256 del archivo en la evidencia del despliegue.');
END;
GO
