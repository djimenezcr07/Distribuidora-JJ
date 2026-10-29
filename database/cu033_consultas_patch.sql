/*
    CU-033 Historial de consultas
    Ejecutar en la base de datos del proyecto.
    Este script es incremental e idempotente: no elimina datos existentes.
*/

IF OBJECT_ID('dbo.Consultas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Consultas
    (
        ConsultaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Consultas PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL,
        Correo NVARCHAR(150) NOT NULL,
        Asunto NVARCHAR(120) NOT NULL,
        Mensaje NVARCHAR(1000) NOT NULL,
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_Consultas_Estado DEFAULT('Pendiente'),
        RespuestaInterna NVARCHAR(1000) NULL,
        AtendidoPorUsuarioId INT NULL,
        AtendidoPorNombre NVARCHAR(150) NULL,
        FechaAtencion DATETIME2 NULL,
        FechaCreacion DATETIME2 NOT NULL CONSTRAINT DF_Consultas_FechaCreacion DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_Consultas_Estado CHECK (Estado IN ('Pendiente', 'Atendida', 'Cerrada')),
        CONSTRAINT FK_Consultas_Usuarios FOREIGN KEY (AtendidoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END
GO

IF OBJECT_ID('dbo.sp_Admin_CreateConsultation', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_CreateConsultation;
GO
CREATE PROCEDURE dbo.sp_Admin_CreateConsultation
    @Nombre NVARCHAR(100),
    @Correo NVARCHAR(150),
    @Asunto NVARCHAR(120),
    @Mensaje NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Consultas (Nombre, Correo, Asunto, Mensaje, Estado)
    VALUES (LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Correo)), LTRIM(RTRIM(@Asunto)), LTRIM(RTRIM(@Mensaje)), 'Pendiente');

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ConsultaId;
END
GO

IF OBJECT_ID('dbo.sp_Admin_GetConsultations', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetConsultations;
GO
CREATE PROCEDURE dbo.sp_Admin_GetConsultations
    @Estado NVARCHAR(30) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ConsultaId,
        Nombre,
        Correo,
        Asunto,
        Mensaje,
        Estado,
        RespuestaInterna,
        AtendidoPorUsuarioId,
        AtendidoPorNombre,
        FechaAtencion,
        FechaCreacion
    FROM dbo.Consultas
    WHERE
        (@Estado IS NULL OR @Estado = '' OR Estado = @Estado)
        AND
        (
            @Buscar IS NULL OR @Buscar = ''
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Correo LIKE '%' + @Buscar + '%'
            OR Asunto LIKE '%' + @Buscar + '%'
            OR Mensaje LIKE '%' + @Buscar + '%'
        )
    ORDER BY FechaCreacion DESC, ConsultaId DESC;
END
GO

IF OBJECT_ID('dbo.sp_Admin_GetConsultationById', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetConsultationById;
GO
CREATE PROCEDURE dbo.sp_Admin_GetConsultationById
    @ConsultaId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ConsultaId,
        Nombre,
        Correo,
        Asunto,
        Mensaje,
        Estado,
        RespuestaInterna,
        AtendidoPorUsuarioId,
        AtendidoPorNombre,
        FechaAtencion,
        FechaCreacion
    FROM dbo.Consultas
    WHERE ConsultaId = @ConsultaId;
END
GO

IF OBJECT_ID('dbo.sp_Admin_UpdateConsultationStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UpdateConsultationStatus;
GO
CREATE PROCEDURE dbo.sp_Admin_UpdateConsultationStatus
    @ConsultaId INT,
    @Estado NVARCHAR(30),
    @RespuestaInterna NVARCHAR(1000) = NULL,
    @AtendidoPorUsuarioId INT = NULL,
    @AtendidoPorNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Consultas WHERE ConsultaId = @ConsultaId)
    BEGIN
        RAISERROR('La consulta indicada no existe.', 16, 1);
        RETURN;
    END

    IF @Estado NOT IN ('Pendiente', 'Atendida', 'Cerrada')
    BEGIN
        RAISERROR('El estado indicado no es válido.', 16, 1);
        RETURN;
    END

    UPDATE dbo.Consultas
    SET
        Estado = @Estado,
        RespuestaInterna = NULLIF(LTRIM(RTRIM(ISNULL(@RespuestaInterna, ''))), ''),
        AtendidoPorUsuarioId = @AtendidoPorUsuarioId,
        AtendidoPorNombre = NULLIF(LTRIM(RTRIM(ISNULL(@AtendidoPorNombre, ''))), ''),
        FechaAtencion = SYSDATETIME()
    WHERE ConsultaId = @ConsultaId;
END
GO

/* Asegura que el catálogo de permisos tenga permisos de Consultas si ya existe CU-042. */
IF OBJECT_ID('dbo.Permisos', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CONSULTAS_VER')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CONSULTAS_VER', 'Consultas', 'Ver consultas', 'Permite consultar el historial de mensajes recibidos.', 1);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CONSULTAS_ATENDER')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CONSULTAS_ATENDER', 'Consultas', 'Atender consultas', 'Permite cambiar el estado de consultas recibidas.', 1);
    END
END
GO
