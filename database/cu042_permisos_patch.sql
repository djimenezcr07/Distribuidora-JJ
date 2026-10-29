USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-042 - Asignar permisos específicos a cada rol
   Este script no elimina tablas ni datos existentes.
   Crea catálogo de permisos y relación Perfil-Permiso.
   ========================================================= */

IF OBJECT_ID('dbo.Permisos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Permisos (
        PermisoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Permisos PRIMARY KEY,
        Codigo NVARCHAR(100) NOT NULL CONSTRAINT UQ_Permisos_Codigo UNIQUE,
        Modulo NVARCHAR(80) NOT NULL,
        Nombre NVARCHAR(120) NOT NULL,
        Descripcion NVARCHAR(255) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Permisos_Activo DEFAULT 1,
        FechaCreacion DATETIME2 NOT NULL CONSTRAINT DF_Permisos_FechaCreacion DEFAULT SYSDATETIME()
    );
END
GO

IF OBJECT_ID('dbo.PerfilPermisos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerfilPermisos (
        PerfilId INT NOT NULL,
        PermisoId INT NOT NULL,
        FechaAsignacion DATETIME2 NOT NULL CONSTRAINT DF_PerfilPermisos_FechaAsignacion DEFAULT SYSDATETIME(),
        UsuarioAsignacionId INT NULL,
        UsuarioAsignacionNombre NVARCHAR(150) NULL,
        CONSTRAINT PK_PerfilPermisos PRIMARY KEY (PerfilId, PermisoId),
        CONSTRAINT FK_PerfilPermisos_Perfiles FOREIGN KEY (PerfilId) REFERENCES dbo.Perfiles(PerfilId),
        CONSTRAINT FK_PerfilPermisos_Permisos FOREIGN KEY (PermisoId) REFERENCES dbo.Permisos(PermisoId),
        CONSTRAINT FK_PerfilPermisos_Usuarios FOREIGN KEY (UsuarioAsignacionId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END
GO

/* Permisos base del sistema */
MERGE dbo.Permisos AS target
USING (VALUES
    ('DASHBOARD_VER', 'Dashboard', 'Ver dashboard', 'Permite visualizar el panel administrativo.'),
    ('INVENTARIO_VER', 'Inventario', 'Ver inventario', 'Permite consultar productos del inventario.'),
    ('INVENTARIO_CREAR', 'Inventario', 'Crear productos', 'Permite registrar nuevos productos.'),
    ('INVENTARIO_EDITAR', 'Inventario', 'Editar productos', 'Permite modificar productos existentes.'),
    ('INVENTARIO_MOVIMIENTOS', 'Inventario', 'Registrar movimientos', 'Permite registrar entradas, salidas y ajustes de inventario.'),
    ('PEDIDOS_VER', 'Pedidos', 'Ver pedidos', 'Permite consultar pedidos realizados.'),
    ('PEDIDOS_CAMBIAR_ESTADO', 'Pedidos', 'Cambiar estado de pedidos', 'Permite modificar el estado de un pedido.'),
    ('FACTURACION_VER', 'Facturación', 'Ver facturación', 'Permite consultar reportes y facturas.'),
    ('ROLES_VER', 'Roles', 'Ver roles', 'Permite consultar roles de usuario.'),
    ('ROLES_CREAR_EDITAR', 'Roles', 'Crear y editar roles', 'Permite crear, editar, activar o inactivar roles.'),
    ('PERMISOS_VER', 'Permisos', 'Ver permisos', 'Permite consultar permisos asignados por rol.'),
    ('PERMISOS_ASIGNAR', 'Permisos', 'Asignar permisos', 'Permite modificar permisos de roles.'),
    ('AUDITORIA_VER', 'Auditoría', 'Ver auditoría', 'Permite consultar la bitácora general del sistema.'),
    ('CONSULTAS_VER', 'Consultas', 'Ver consultas', 'Permite consultar el historial de mensajes recibidos.'),
    ('CONSULTAS_ATENDER', 'Consultas', 'Atender consultas', 'Permite cambiar el estado de consultas recibidas.')
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET
        target.Modulo = source.Modulo,
        target.Nombre = source.Nombre,
        target.Descripcion = source.Descripcion,
        target.Activo = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

/* El administrador mantiene todos los permisos por seguridad. */
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, 'Carga inicial CU-042'
FROM dbo.Perfiles p
CROSS JOIN dbo.Permisos pe
WHERE p.Nombre = 'Administrador'
  AND pe.Activo = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.PerfilPermisos pp
      WHERE pp.PerfilId = p.PerfilId
        AND pp.PermisoId = pe.PermisoId
  );
GO

/* Permisos sugeridos para Empleado. No afecta al cliente. */
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, 'Carga inicial CU-042'
FROM dbo.Perfiles p
INNER JOIN dbo.Permisos pe
    ON pe.Codigo IN (
        'DASHBOARD_VER',
        'INVENTARIO_VER',
        'INVENTARIO_MOVIMIENTOS',
        'PEDIDOS_VER',
        'PEDIDOS_CAMBIAR_ESTADO',
        'FACTURACION_VER',
        'CONSULTAS_VER',
        'CONSULTAS_ATENDER'
    )
WHERE p.Nombre = 'Empleado'
  AND pe.Activo = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.PerfilPermisos pp
      WHERE pp.PerfilId = p.PerfilId
        AND pp.PermisoId = pe.PermisoId
  );
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRolePermissions
    @PerfilId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE PerfilId = @PerfilId)
    BEGIN
        THROW 50020, 'El rol solicitado no existe.', 1;
    END;

    SELECT TOP 1
        PerfilId,
        Nombre,
        ISNULL(Descripcion, '') AS Descripcion,
        CAST(ISNULL(Activo, 1) AS BIT) AS Activo
    FROM dbo.Perfiles
    WHERE PerfilId = @PerfilId;

    SELECT
        pe.PermisoId,
        pe.Codigo,
        pe.Modulo,
        pe.Nombre,
        ISNULL(pe.Descripcion, '') AS Descripcion,
        CAST(pe.Activo AS BIT) AS Activo,
        CAST(CASE WHEN pp.PermisoId IS NULL THEN 0 ELSE 1 END AS BIT) AS Asignado
    FROM dbo.Permisos pe
    LEFT JOIN dbo.PerfilPermisos pp
        ON pp.PermisoId = pe.PermisoId
       AND pp.PerfilId = @PerfilId
    WHERE pe.Activo = 1
    ORDER BY
        CASE pe.Modulo
            WHEN 'Dashboard' THEN 1
            WHEN 'Inventario' THEN 2
            WHEN 'Pedidos' THEN 3
            WHEN 'Facturación' THEN 4
            WHEN 'Roles' THEN 5
            WHEN 'Permisos' THEN 6
            WHEN 'Auditoría' THEN 7
            WHEN 'Consultas' THEN 8
            ELSE 99
        END,
        pe.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateRolePermissions
    @PerfilId INT,
    @PermisosCsv NVARCHAR(MAX) = NULL,
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NombreRol NVARCHAR(50);

    SELECT @NombreRol = Nombre
    FROM dbo.Perfiles
    WHERE PerfilId = @PerfilId;

    IF @NombreRol IS NULL
    BEGIN
        THROW 50021, 'El rol solicitado no existe.', 1;
    END;

    IF @NombreRol = 'Administrador'
    BEGIN
        THROW 50022, 'El rol Administrador mantiene todos los permisos por seguridad y no puede modificarse desde esta pantalla.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.PerfilPermisos
        WHERE PerfilId = @PerfilId;

        ;WITH PermisosSeleccionados AS (
            SELECT DISTINCT TRY_CONVERT(INT, value) AS PermisoId
            FROM STRING_SPLIT(ISNULL(@PermisosCsv, ''), ',')
            WHERE TRY_CONVERT(INT, value) IS NOT NULL
        )
        INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
        SELECT
            @PerfilId,
            pe.PermisoId,
            @UsuarioId,
            NULLIF(LTRIM(RTRIM(@UsuarioNombre)), '')
        FROM dbo.Permisos pe
        INNER JOIN PermisosSeleccionados ps
            ON ps.PermisoId = pe.PermisoId
        WHERE pe.Activo = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
