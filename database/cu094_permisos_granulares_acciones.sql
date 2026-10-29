USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-094 - Infraestructura para permisos granulares por accion
   No modifica tablas, datos demo ni permisos existentes.
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Admin_HasPermissionByCode
    @NombreRol NVARCHAR(100),
    @Codigo NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SET @NombreRol = NULLIF(LTRIM(RTRIM(ISNULL(@NombreRol, ''))), '');
    SET @Codigo = NULLIF(LTRIM(RTRIM(ISNULL(@Codigo, ''))), '');

    IF @NombreRol IS NULL OR @Codigo IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS HasPermission;
        RETURN;
    END;

    SELECT CAST(
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.Perfiles p
                INNER JOIN dbo.PerfilPermisos pp
                    ON pp.PerfilId = p.PerfilId
                INNER JOIN dbo.Permisos pe
                    ON pe.PermisoId = pp.PermisoId
                WHERE p.Nombre = @NombreRol
                  AND ISNULL(p.Activo, 1) = 1
                  AND pe.Activo = 1
                  AND pe.Codigo = @Codigo
            )
            THEN 1
            ELSE 0
        END AS BIT
    ) AS HasPermission;
END
GO
