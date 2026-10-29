USE DistribuidoraJJ_DB;
GO

IF OBJECT_ID('dbo.AuditoriaSistema', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditoriaSistema
    (
        AuditoriaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditoriaSistema PRIMARY KEY,
        UsuarioId INT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        UsuarioCorreo NVARCHAR(150) NOT NULL,
        Rol NVARCHAR(50) NOT NULL,
        Accion NVARCHAR(80) NOT NULL,
        Modulo NVARCHAR(80) NOT NULL,
        Descripcion NVARCHAR(500) NOT NULL,
        DireccionIp NVARCHAR(80) NULL,
        UserAgent NVARCHAR(300) NULL,
        FechaRegistro DATETIME2 NOT NULL CONSTRAINT DF_AuditoriaSistema_FechaRegistro DEFAULT SYSDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditoriaSistema_FechaRegistro' AND object_id = OBJECT_ID('dbo.AuditoriaSistema'))
BEGIN
    CREATE INDEX IX_AuditoriaSistema_FechaRegistro ON dbo.AuditoriaSistema(FechaRegistro DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditoriaSistema_Modulo_Accion' AND object_id = OBJECT_ID('dbo.AuditoriaSistema'))
BEGIN
    CREATE INDEX IX_AuditoriaSistema_Modulo_Accion ON dbo.AuditoriaSistema(Modulo, Accion);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateAuditLog
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150),
    @UsuarioCorreo NVARCHAR(150),
    @Rol NVARCHAR(50),
    @Accion NVARCHAR(80),
    @Modulo NVARCHAR(80),
    @Descripcion NVARCHAR(500),
    @DireccionIp NVARCHAR(80) = NULL,
    @UserAgent NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditoriaSistema
    (
        UsuarioId,
        UsuarioNombre,
        UsuarioCorreo,
        Rol,
        Accion,
        Modulo,
        Descripcion,
        DireccionIp,
        UserAgent
    )
    VALUES
    (
        @UsuarioId,
        ISNULL(NULLIF(LTRIM(RTRIM(@UsuarioNombre)), ''), 'Usuario no identificado'),
        ISNULL(NULLIF(LTRIM(RTRIM(@UsuarioCorreo)), ''), 'No disponible'),
        ISNULL(NULLIF(LTRIM(RTRIM(@Rol)), ''), 'No disponible'),
        @Accion,
        @Modulo,
        @Descripcion,
        NULLIF(LTRIM(RTRIM(@DireccionIp)), ''),
        NULLIF(LTRIM(RTRIM(@UserAgent)), '')
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetAuditLogs
    @Modulo NVARCHAR(80) = NULL,
    @Accion NVARCHAR(80) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 200
        AuditoriaId,
        UsuarioId,
        UsuarioNombre,
        UsuarioCorreo,
        Rol,
        Accion,
        Modulo,
        Descripcion,
        DireccionIp,
        UserAgent,
        FechaRegistro
    FROM dbo.AuditoriaSistema
    WHERE
        (@Modulo IS NULL OR Modulo = @Modulo)
        AND (@Accion IS NULL OR Accion = @Accion)
        AND
        (
            @Buscar IS NULL
            OR UsuarioNombre LIKE '%' + @Buscar + '%'
            OR UsuarioCorreo LIKE '%' + @Buscar + '%'
            OR Rol LIKE '%' + @Buscar + '%'
            OR Accion LIKE '%' + @Buscar + '%'
            OR Modulo LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
        )
    ORDER BY FechaRegistro DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId INT,
    @NuevoEstado NVARCHAR(50),
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Pedidos
    SET Estado = @NuevoEstado
    WHERE PedidoId = @PedidoId;
END
GO
