USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-041 - Crear y administrar roles de usuario
   Se trabaja sobre la tabla existente dbo.Perfiles.
   ========================================================= */

IF COL_LENGTH('dbo.Perfiles', 'Activo') IS NULL
BEGIN
    ALTER TABLE dbo.Perfiles
    ADD Activo BIT NOT NULL CONSTRAINT DF_Perfiles_Activo DEFAULT 1;
END
GO

IF COL_LENGTH('dbo.Perfiles', 'FechaCreacion') IS NULL
BEGIN
    ALTER TABLE dbo.Perfiles
    ADD FechaCreacion DATETIME2 NOT NULL CONSTRAINT DF_Perfiles_FechaCreacion DEFAULT SYSDATETIME();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRoles
    @Buscar NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PerfilId,
        p.Nombre,
        ISNULL(p.Descripcion, '') AS Descripcion,
        CAST(ISNULL(p.Activo, 1) AS BIT) AS Activo,
        p.FechaCreacion,
        COUNT(u.UsuarioId) AS TotalUsuarios
    FROM dbo.Perfiles p
    LEFT JOIN dbo.Usuarios u
        ON u.PerfilId = p.PerfilId
    WHERE
        @Buscar IS NULL
        OR LTRIM(RTRIM(@Buscar)) = ''
        OR p.Nombre LIKE '%' + LTRIM(RTRIM(@Buscar)) + '%'
        OR ISNULL(p.Descripcion, '') LIKE '%' + LTRIM(RTRIM(@Buscar)) + '%'
    GROUP BY
        p.PerfilId,
        p.Nombre,
        p.Descripcion,
        p.Activo,
        p.FechaCreacion
    ORDER BY
        CASE
            WHEN p.Nombre = 'Administrador' THEN 1
            WHEN p.Nombre = 'Cliente' THEN 2
            WHEN p.Nombre = 'Empleado' THEN 3
            ELSE 4
        END,
        p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRoleById
    @PerfilId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        p.PerfilId,
        p.Nombre,
        ISNULL(p.Descripcion, '') AS Descripcion,
        CAST(ISNULL(p.Activo, 1) AS BIT) AS Activo,
        p.FechaCreacion,
        COUNT(u.UsuarioId) AS TotalUsuarios
    FROM dbo.Perfiles p
    LEFT JOIN dbo.Usuarios u
        ON u.PerfilId = p.PerfilId
    WHERE p.PerfilId = @PerfilId
    GROUP BY
        p.PerfilId,
        p.Nombre,
        p.Descripcion,
        p.Activo,
        p.FechaCreacion;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateRole
    @Nombre NVARCHAR(50),
    @Descripcion NVARCHAR(255) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @Nombre = LTRIM(RTRIM(@Nombre));
    SET @Descripcion = NULLIF(LTRIM(RTRIM(ISNULL(@Descripcion, ''))), '');

    IF @Nombre IS NULL OR @Nombre = ''
    BEGIN
        THROW 50001, 'El nombre del rol es obligatorio.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = @Nombre)
    BEGIN
        THROW 50002, 'Ya existe un rol con ese nombre.', 1;
    END

    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES (@Nombre, @Descripcion, ISNULL(@Activo, 1));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS PerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateRole
    @PerfilId INT,
    @Nombre NVARCHAR(50),
    @Descripcion NVARCHAR(255) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NombreActual NVARCHAR(50);

    SELECT @NombreActual = Nombre
    FROM dbo.Perfiles
    WHERE PerfilId = @PerfilId;

    IF @NombreActual IS NULL
    BEGIN
        THROW 50003, 'El rol seleccionado no existe.', 1;
    END

    SET @Nombre = LTRIM(RTRIM(@Nombre));
    SET @Descripcion = NULLIF(LTRIM(RTRIM(ISNULL(@Descripcion, ''))), '');

    IF @Nombre IS NULL OR @Nombre = ''
    BEGIN
        THROW 50004, 'El nombre del rol es obligatorio.', 1;
    END

    IF @NombreActual IN ('Administrador', 'Cliente', 'Empleado') AND @Nombre <> @NombreActual
    BEGIN
        THROW 50005, 'Los roles base del sistema no pueden cambiar de nombre.', 1;
    END

    IF @NombreActual IN ('Administrador', 'Cliente') AND ISNULL(@Activo, 1) = 0
    BEGIN
        THROW 50006, 'El rol Administrador o Cliente no puede ser inactivado porque es requerido por el sistema.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = @Nombre AND PerfilId <> @PerfilId)
    BEGIN
        THROW 50007, 'Ya existe otro rol con ese nombre.', 1;
    END

    UPDATE dbo.Perfiles
    SET
        Nombre = @Nombre,
        Descripcion = @Descripcion,
        Activo = ISNULL(@Activo, 1)
    WHERE PerfilId = @PerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleRoleStatus
    @PerfilId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NombreActual NVARCHAR(50);
    DECLARE @ActivoActual BIT;

    SELECT
        @NombreActual = Nombre,
        @ActivoActual = CAST(ISNULL(Activo, 1) AS BIT)
    FROM dbo.Perfiles
    WHERE PerfilId = @PerfilId;

    IF @NombreActual IS NULL
    BEGIN
        THROW 50008, 'El rol seleccionado no existe.', 1;
    END

    IF @NombreActual IN ('Administrador', 'Cliente') AND @ActivoActual = 1
    BEGIN
        THROW 50009, 'El rol Administrador o Cliente no puede ser inactivado porque es requerido por el sistema.', 1;
    END

    UPDATE dbo.Perfiles
    SET Activo = CASE WHEN ISNULL(Activo, 1) = 1 THEN 0 ELSE 1 END
    WHERE PerfilId = @PerfilId;
END
GO
