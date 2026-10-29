USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-061 / CU-063 - Administrar clientes e inactivar perfil
   Se trabaja sobre la tabla existente dbo.Usuarios usando
   el perfil base Cliente.
   ========================================================= */

IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
BEGIN
    THROW 51000, 'La tabla dbo.Usuarios no existe.', 1;
END
GO

IF OBJECT_ID('dbo.Perfiles', 'U') IS NULL
BEGIN
    THROW 51001, 'La tabla dbo.Perfiles no existe.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Cliente')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES ('Cliente', 'Cliente registrado para realizar pedidos');
END
GO

IF COL_LENGTH('dbo.Usuarios', 'MotivoInactivacion') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios
    ADD MotivoInactivacion NVARCHAR(255) NULL;
END
GO

IF COL_LENGTH('dbo.Usuarios', 'FechaInactivacion') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios
    ADD FechaInactivacion DATETIME2 NULL;
END
GO

IF COL_LENGTH('dbo.Usuarios', 'FechaActualizacion') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios
    ADD FechaActualizacion DATETIME2 NULL;
END
GO

IF OBJECT_ID('dbo.Permisos', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CLIENTES_VER')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CLIENTES_VER', 'Clientes', 'Ver clientes', 'Permite consultar el listado y detalle de clientes.', 1);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CLIENTES_CREAR')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CLIENTES_CREAR', 'Clientes', 'Crear clientes', 'Permite registrar clientes manualmente.', 1);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CLIENTES_EDITAR')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CLIENTES_EDITAR', 'Clientes', 'Editar clientes', 'Permite modificar los datos de clientes.', 1);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'CLIENTES_INACTIVAR')
    BEGIN
        INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES ('CLIENTES_INACTIVAR', 'Clientes', 'Inactivar clientes', 'Permite suspender o reactivar la relación comercial con clientes.', 1);
    END

    IF OBJECT_ID('dbo.PerfilPermisos', 'U') IS NOT NULL
    BEGIN
        DECLARE @PerfilAdministrador INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador');

        IF @PerfilAdministrador IS NOT NULL
        BEGIN
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT @PerfilAdministrador, p.PermisoId, NULL, 'Script CU-061/CU-063'
FROM dbo.Permisos p
WHERE p.Modulo = 'Clientes'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.PerfilPermisos pp
        WHERE pp.PerfilId = @PerfilAdministrador
          AND pp.PermisoId = p.PermisoId
  );
        END
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClients
    @Buscar NVARCHAR(200) = NULL,
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    SET @Buscar = NULLIF(LTRIM(RTRIM(ISNULL(@Buscar, ''))), '');
    SET @Estado = NULLIF(LTRIM(RTRIM(ISNULL(@Estado, ''))), '');

    SELECT
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        CAST(ISNULL(u.Activo, 1) AS BIT) AS Activo,
        u.FechaRegistro,
        COUNT(p.PedidoId) AS TotalPedidos,
        ISNULL(SUM(CASE WHEN ISNULL(p.Estado, '') <> 'Cancelado' THEN ISNULL(p.Total, 0) ELSE 0 END), 0) AS TotalComprado,
        MAX(p.FechaPedido) AS UltimoPedido,
        u.MotivoInactivacion,
        u.FechaInactivacion
    FROM dbo.Usuarios u
    LEFT JOIN dbo.Pedidos p
        ON p.UsuarioId = u.UsuarioId
    WHERE u.PerfilId = @ClientePerfilId
      AND (
            @Buscar IS NULL
            OR u.NombreCompleto LIKE '%' + @Buscar + '%'
            OR u.Correo LIKE '%' + @Buscar + '%'
            OR ISNULL(u.Telefono, '') LIKE '%' + @Buscar + '%'
            OR ISNULL(u.Direccion, '') LIKE '%' + @Buscar + '%'
      )
      AND (
            @Estado IS NULL
            OR (@Estado = 'Activo' AND ISNULL(u.Activo, 1) = 1)
            OR (@Estado = 'Inactivo' AND ISNULL(u.Activo, 1) = 0)
      )
    GROUP BY
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        u.Activo,
        u.FechaRegistro,
        u.MotivoInactivacion,
        u.FechaInactivacion
    ORDER BY u.FechaRegistro DESC, u.UsuarioId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientById
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');

    SELECT TOP 1
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        CAST(ISNULL(u.Activo, 1) AS BIT) AS Activo,
        u.FechaRegistro,
        COUNT(p.PedidoId) AS TotalPedidos,
        ISNULL(SUM(CASE WHEN ISNULL(p.Estado, '') <> 'Cancelado' THEN ISNULL(p.Total, 0) ELSE 0 END), 0) AS TotalComprado,
        MAX(p.FechaPedido) AS UltimoPedido,
        u.MotivoInactivacion,
        u.FechaInactivacion
    FROM dbo.Usuarios u
    LEFT JOIN dbo.Pedidos p
        ON p.UsuarioId = u.UsuarioId
    WHERE u.UsuarioId = @UsuarioId
      AND u.PerfilId = @ClientePerfilId
    GROUP BY
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        u.Activo,
        u.FechaRegistro,
        u.MotivoInactivacion,
        u.FechaInactivacion;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientDetail
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_Admin_GetClientById @UsuarioId;

    SELECT
        p.PedidoId,
        p.FechaPedido,
        p.Estado,
        p.TipoEntrega,
        p.DireccionEntrega,
        p.Total,
        p.Observaciones
    FROM dbo.Pedidos p
    WHERE p.UsuarioId = @UsuarioId
    ORDER BY p.FechaPedido DESC, p.PedidoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateClient
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255),
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @Activo BIT = 1,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');

    SET @NombreCompleto = LTRIM(RTRIM(ISNULL(@NombreCompleto, '')));
    SET @Correo = LOWER(LTRIM(RTRIM(ISNULL(@Correo, ''))));
    SET @Contrasena = LTRIM(RTRIM(ISNULL(@Contrasena, '')));
    SET @Telefono = NULLIF(LTRIM(RTRIM(ISNULL(@Telefono, ''))), '');
    SET @Direccion = NULLIF(LTRIM(RTRIM(ISNULL(@Direccion, ''))), '');
    SET @MotivoInactivacion = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoInactivacion, ''))), '');

    IF @ClientePerfilId IS NULL
    BEGIN
        THROW 51002, 'No existe el perfil Cliente.', 1;
    END

    IF @NombreCompleto = '' OR @Correo = '' OR @Contrasena = ''
    BEGIN
        THROW 51003, 'Nombre, correo y contraseña son obligatorios.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
    BEGIN
        THROW 51004, 'Ya existe un usuario registrado con ese correo.', 1;
    END

    IF ISNULL(@Activo, 1) = 0 AND @MotivoInactivacion IS NULL
    BEGIN
        THROW 51005, 'Debe indicar un motivo para registrar el cliente como inactivo.', 1;
    END

    INSERT INTO dbo.Usuarios
    (
        PerfilId,
        NombreCompleto,
        Correo,
        Contrasena,
        Telefono,
        Direccion,
        Activo,
        MotivoInactivacion,
        FechaInactivacion,
        FechaActualizacion
    )
    VALUES
    (
        @ClientePerfilId,
        @NombreCompleto,
        @Correo,
        @Contrasena,
        @Telefono,
        @Direccion,
        ISNULL(@Activo, 1),
        CASE WHEN ISNULL(@Activo, 1) = 0 THEN @MotivoInactivacion ELSE NULL END,
        CASE WHEN ISNULL(@Activo, 1) = 0 THEN SYSDATETIME() ELSE NULL END,
        SYSDATETIME()
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateClient
    @UsuarioId INT,
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @Contrasena NVARCHAR(255) = NULL,
    @Activo BIT = 1,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    DECLARE @ActivoAnterior BIT;

    SELECT @ActivoAnterior = CAST(ISNULL(Activo, 1) AS BIT)
    FROM dbo.Usuarios
    WHERE UsuarioId = @UsuarioId
      AND PerfilId = @ClientePerfilId;

    IF @ActivoAnterior IS NULL
    BEGIN
        THROW 51006, 'El cliente seleccionado no existe.', 1;
    END

    SET @NombreCompleto = LTRIM(RTRIM(ISNULL(@NombreCompleto, '')));
    SET @Correo = LOWER(LTRIM(RTRIM(ISNULL(@Correo, ''))));
    SET @Telefono = NULLIF(LTRIM(RTRIM(ISNULL(@Telefono, ''))), '');
    SET @Direccion = NULLIF(LTRIM(RTRIM(ISNULL(@Direccion, ''))), '');
    SET @Contrasena = NULLIF(LTRIM(RTRIM(ISNULL(@Contrasena, ''))), '');
    SET @MotivoInactivacion = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoInactivacion, ''))), '');

    IF @NombreCompleto = '' OR @Correo = ''
    BEGIN
        THROW 51007, 'Nombre y correo son obligatorios.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo AND UsuarioId <> @UsuarioId)
    BEGIN
        THROW 51008, 'Ya existe otro usuario registrado con ese correo.', 1;
    END

    IF ISNULL(@Activo, 1) = 0 AND @MotivoInactivacion IS NULL
    BEGIN
        THROW 51009, 'Debe indicar un motivo para inactivar el cliente.', 1;
    END

    UPDATE dbo.Usuarios
    SET
        NombreCompleto = @NombreCompleto,
        Correo = @Correo,
        Telefono = @Telefono,
        Direccion = @Direccion,
        Contrasena = CASE WHEN @Contrasena IS NULL THEN Contrasena ELSE @Contrasena END,
        Activo = ISNULL(@Activo, 1),
        MotivoInactivacion = CASE WHEN ISNULL(@Activo, 1) = 0 THEN @MotivoInactivacion ELSE NULL END,
        FechaInactivacion = CASE
            WHEN ISNULL(@Activo, 1) = 0 AND @ActivoAnterior = 1 THEN SYSDATETIME()
            WHEN ISNULL(@Activo, 1) = 0 AND @ActivoAnterior = 0 THEN ISNULL(FechaInactivacion, SYSDATETIME())
            ELSE NULL
        END,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId
      AND PerfilId = @ClientePerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleClientStatus
    @UsuarioId INT,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    DECLARE @ActivoActual BIT;

    SELECT @ActivoActual = CAST(ISNULL(Activo, 1) AS BIT)
    FROM dbo.Usuarios
    WHERE UsuarioId = @UsuarioId
      AND PerfilId = @ClientePerfilId;

    IF @ActivoActual IS NULL
    BEGIN
        THROW 51010, 'El cliente seleccionado no existe.', 1;
    END

    SET @MotivoInactivacion = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoInactivacion, ''))), '');

    IF @ActivoActual = 1 AND @MotivoInactivacion IS NULL
    BEGIN
        SET @MotivoInactivacion = 'Inactivación administrativa del perfil de cliente.';
    END

    UPDATE dbo.Usuarios
    SET
        Activo = CASE WHEN @ActivoActual = 1 THEN 0 ELSE 1 END,
        MotivoInactivacion = CASE WHEN @ActivoActual = 1 THEN @MotivoInactivacion ELSE NULL END,
        FechaInactivacion = CASE WHEN @ActivoActual = 1 THEN SYSDATETIME() ELSE NULL END,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId
      AND PerfilId = @ClientePerfilId;

    SELECT CAST(CASE WHEN @ActivoActual = 1 THEN 0 ELSE 1 END AS BIT) AS NuevoEstado;
END
GO
