-- ============================================================
-- CU-100: Corregir sp_Admin_HasPermissionByCode
-- El C# lo llama con (@NombreRol, @Codigo) para verificar
-- si un ROL tiene un permiso por código.
-- La versión de Fase3_3-3 esperaba (@UsuarioId, @Codigo),
-- lo que causa "parameter '@UsuarioId' was not supplied".
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_HasPermissionByCode
    @NombreRol NVARCHAR(100),
    @Codigo    NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASE
        WHEN EXISTS (
            SELECT 1
            FROM   dbo.PerfilPermisos pp
            INNER JOIN dbo.Permisos   per ON per.PermisoId = pp.PermisoId
            INNER JOIN dbo.Perfiles   p   ON p.PerfilId    = pp.PerfilId
            WHERE  p.Nombre   = @NombreRol
              AND  per.Codigo = @Codigo
              AND  per.Activo = 1
        ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT)
    END AS TienePermiso;
END;
GO

PRINT 'CU-100 aplicado: sp_Admin_HasPermissionByCode actualizado para verificar por rol.';
GO
