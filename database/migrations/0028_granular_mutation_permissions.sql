SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55280, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0028_granular_mutation_permissions' AND Status = N'Applied')
    THROW 55281, N'0028 ya figura aplicada.', 1;

BEGIN TRANSACTION;

DECLARE @Required TABLE (Codigo NVARCHAR(100), Modulo NVARCHAR(100), Nombre NVARCHAR(150), Descripcion NVARCHAR(500));
INSERT @Required VALUES
    (N'CLIENTES_VER', N'Clientes', N'Ver clientes', N'Permite consultar el listado y detalle de clientes.'),
    (N'CLIENTES_CREAR', N'Clientes', N'Crear clientes', N'Permite registrar clientes manualmente.'),
    (N'CLIENTES_EDITAR', N'Clientes', N'Editar clientes', N'Permite modificar los datos de clientes.'),
    (N'CLIENTES_INACTIVAR', N'Clientes', N'Inactivar clientes', N'Permite suspender o reactivar la relación comercial con clientes.'),
    (N'CONSULTAS_VER', N'Consultas', N'Ver consultas', N'Permite consultar mensajes recibidos.'),
    (N'CONSULTAS_ATENDER', N'Consultas', N'Atender consultas', N'Permite responder y cambiar el estado de consultas.'),
    (N'INVENTARIO_VER', N'Inventario', N'Ver inventario', N'Permite consultar productos y movimientos.'),
    (N'INVENTARIO_CREAR', N'Inventario', N'Crear productos', N'Permite registrar productos.'),
    (N'INVENTARIO_EDITAR', N'Inventario', N'Editar productos', N'Permite modificar productos y su visibilidad.'),
    (N'INVENTARIO_MOVIMIENTOS', N'Inventario', N'Registrar movimientos', N'Permite registrar entradas, salidas y ajustes.'),
    (N'INVENTARIO_ELIMINAR', N'Inventario', N'Eliminar productos permanentemente', N'Permite eliminar productos sin referencias, con efecto irreversible.');

INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
SELECT required.Codigo, required.Modulo, required.Nombre, required.Descripcion, 1
FROM @Required required
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permisos permission WHERE permission.Codigo = required.Codigo);

UPDATE permission
SET Modulo = required.Modulo, Nombre = required.Nombre, Descripcion = required.Descripcion, Activo = 1
FROM dbo.Permisos permission
INNER JOIN @Required required ON required.Codigo = permission.Codigo;

-- Preserva equivalencias históricas de catálogos anteriores.
DECLARE @Aliases TABLE (CodigoAnterior NVARCHAR(100), CodigoActual NVARCHAR(100));
INSERT @Aliases VALUES
    (N'CLIENTES_ACTIVAR_DESACTIVAR', N'CLIENTES_INACTIVAR'),
    (N'CONSULTAS_GESTIONAR', N'CONSULTAS_ATENDER'),
    (N'INVENTARIO_AGREGAR', N'INVENTARIO_CREAR'),
    (N'INVENTARIO_AJUSTAR_STOCK', N'INVENTARIO_MOVIMIENTOS');

INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT DISTINCT assignment.PerfilId, currentPermission.PermisoId, NULL, N'Migración 0028'
FROM @Aliases aliases
INNER JOIN dbo.Permisos oldPermission ON oldPermission.Codigo = aliases.CodigoAnterior
INNER JOIN dbo.PerfilPermisos assignment ON assignment.PermisoId = oldPermission.PermisoId
INNER JOIN dbo.Permisos currentPermission ON currentPermission.Codigo = aliases.CodigoActual
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos existingAssignment
    WHERE existingAssignment.PerfilId = assignment.PerfilId
      AND existingAssignment.PermisoId = currentPermission.PermisoId
);

-- El administrador conserva todas las capacidades. Los perfiles con permisos del
-- módulo conservan lectura; las mutaciones permanecen separadas y explícitas.
INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, permission.PermisoId, NULL, N'Migración 0028'
FROM dbo.Perfiles profile
CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre = N'Administrador'
  AND permission.Codigo IN (SELECT Codigo FROM @Required)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.PerfilPermisos existingAssignment
      WHERE existingAssignment.PerfilId = profile.PerfilId AND existingAssignment.PermisoId = permission.PermisoId
  );

INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT DISTINCT assignment.PerfilId, readPermission.PermisoId, NULL, N'Migración 0028'
FROM dbo.PerfilPermisos assignment
INNER JOIN dbo.Permisos existingPermission ON existingPermission.PermisoId = assignment.PermisoId
INNER JOIN dbo.Permisos readPermission ON readPermission.Codigo = CASE existingPermission.Modulo
    WHEN N'Clientes' THEN N'CLIENTES_VER'
    WHEN N'Consultas' THEN N'CONSULTAS_VER'
    WHEN N'Inventario' THEN N'INVENTARIO_VER'
END
WHERE existingPermission.Modulo IN (N'Clientes', N'Consultas', N'Inventario')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.PerfilPermisos existingAssignment
      WHERE existingAssignment.PerfilId = assignment.PerfilId AND existingAssignment.PermisoId = readPermission.PermisoId
  );

COMMIT TRANSACTION;

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55282, N'SHA-256 inválido para 0028.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0028_granular_mutation_permissions', N'0028_granular_mutation_permissions.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Separa lectura, creación, edición, estado, movimientos y eliminación permanente.');
GO
