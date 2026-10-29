SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55270, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0027_dynamic_authorization_capabilities' AND Status = N'Applied')
    THROW 55271, N'0027 ya figura aplicada.', 1;

BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'VENTA_MOVIL_CREAR')
BEGIN
    INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (N'VENTA_MOVIL_CREAR', N'Venta móvil', N'Crear venta móvil',
            N'Permite abrir el flujo de venta móvil y registrar pedidos propios.', 1);
END
ELSE
BEGIN
    UPDATE dbo.Permisos
    SET Modulo = N'Venta móvil', Nombre = N'Crear venta móvil',
        Descripcion = N'Permite abrir el flujo de venta móvil y registrar pedidos propios.', Activo = 1
    WHERE Codigo = N'VENTA_MOVIL_CREAR';
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'CHAT_USAR')
BEGIN
    INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (N'CHAT_USAR', N'Chat', N'Usar chat', N'Permite utilizar conversaciones privadas y departamentos autorizados.', 1);
END
ELSE
BEGIN
    UPDATE dbo.Permisos
    SET Modulo = N'Chat', Nombre = N'Usar chat',
        Descripcion = N'Permite utilizar conversaciones privadas y departamentos autorizados.', Activo = 1
    WHERE Codigo = N'CHAT_USAR';
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'METAS_PROPIAS_VER')
BEGIN
    INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (N'METAS_PROPIAS_VER', N'Metas y KPIs', N'Consultar meta propia',
            N'Permite al vendedor consultar exclusivamente el progreso de su propia meta.', 1);
END
ELSE
BEGIN
    UPDATE dbo.Permisos
    SET Modulo = N'Metas y KPIs', Nombre = N'Consultar meta propia',
        Descripcion = N'Permite al vendedor consultar exclusivamente el progreso de su propia meta.', Activo = 1
    WHERE Codigo = N'METAS_PROPIAS_VER';
END;

DECLARE @VentaMovilPermisoId INT = (SELECT PermisoId FROM dbo.Permisos WHERE Codigo = N'VENTA_MOVIL_CREAR');

INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT DISTINCT profile.PerfilId, @VentaMovilPermisoId, NULL, N'Migración 0027'
FROM dbo.Perfiles profile
WHERE (profile.Nombre = N'Administrador'
   OR EXISTS (
       SELECT 1
       FROM dbo.PerfilPermisos oldAssignment
       INNER JOIN dbo.Permisos oldPermission ON oldPermission.PermisoId = oldAssignment.PermisoId
       WHERE oldAssignment.PerfilId = profile.PerfilId
         AND oldPermission.Codigo IN (N'VENTA_MOVIL_CREAR_PEDIDO', N'VENTA_MOVIL_OFFLINE_SYNC')
   ))
AND NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos existingAssignment
    WHERE existingAssignment.PerfilId = profile.PerfilId
      AND existingAssignment.PermisoId = @VentaMovilPermisoId
);

DECLARE @MetaPropiaPermisoId INT = (SELECT PermisoId FROM dbo.Permisos WHERE Codigo = N'METAS_PROPIAS_VER');
INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, @MetaPropiaPermisoId, NULL, N'Migración 0027'
FROM dbo.Perfiles profile
WHERE profile.Nombre IN (N'Administrador', N'Vendedor')
AND NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos existingAssignment
    WHERE existingAssignment.PerfilId = profile.PerfilId
      AND existingAssignment.PermisoId = @MetaPropiaPermisoId
);

DECLARE @ChatPermisoId INT = (SELECT PermisoId FROM dbo.Permisos WHERE Codigo = N'CHAT_USAR');
INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, @ChatPermisoId, NULL, N'Migración 0027'
FROM dbo.Perfiles profile
WHERE (
    profile.Nombre IN (N'Administrador', N'Auditor Interno', N'Bodeguero', N'Bodega', N'Cajero', N'Chofer',
                       N'Compras', N'Crédito y Cobro', N'Empleado', N'Facturador', N'Gerente', N'Soporte', N'Supervisor', N'Vendedor')
    OR EXISTS (
        SELECT 1 FROM dbo.PerfilPermisos manageAssignment
        INNER JOIN dbo.Permisos managePermission ON managePermission.PermisoId = manageAssignment.PermisoId
        WHERE manageAssignment.PerfilId = profile.PerfilId
          AND managePermission.Codigo = N'CHAT_DEPARTAMENTOS_GESTIONAR'
    )
)
AND NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos existingAssignment
    WHERE existingAssignment.PerfilId = profile.PerfilId
      AND existingAssignment.PermisoId = @ChatPermisoId
);

COMMIT TRANSACTION;

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55272, N'SHA-256 inválido para 0027.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0027_dynamic_authorization_capabilities', N'0027_dynamic_authorization_capabilities.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Capacidades explícitas para venta móvil, chat y consulta de meta propia.');
GO
