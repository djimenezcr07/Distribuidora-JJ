/*
    P0 audit: read-only inventory of demo accounts.
    Do not share results outside the approved security channel.
    This script never returns password columns and performs no data changes.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
    THROW 51010, 'No existe dbo.Usuarios en la base seleccionada.', 1;

DECLARE @IdColumn sysname = CASE
    WHEN COL_LENGTH(N'dbo.Usuarios', N'UsuarioId') IS NOT NULL THEN N'UsuarioId'
    WHEN COL_LENGTH(N'dbo.Usuarios', N'IdUsuario') IS NOT NULL THEN N'IdUsuario'
    ELSE NULL
END;
DECLARE @EmailColumn sysname = CASE
    WHEN COL_LENGTH(N'dbo.Usuarios', N'Correo') IS NOT NULL THEN N'Correo'
    WHEN COL_LENGTH(N'dbo.Usuarios', N'Email') IS NOT NULL THEN N'Email'
    ELSE NULL
END;
DECLARE @RoleColumn sysname = CASE
    WHEN COL_LENGTH(N'dbo.Usuarios', N'PerfilId') IS NOT NULL THEN N'PerfilId'
    WHEN COL_LENGTH(N'dbo.Usuarios', N'RolId') IS NOT NULL THEN N'RolId'
    WHEN COL_LENGTH(N'dbo.Usuarios', N'Rol') IS NOT NULL THEN N'Rol'
    ELSE NULL
END;
DECLARE @StatusColumn sysname = CASE WHEN COL_LENGTH(N'dbo.Usuarios', N'Activo') IS NOT NULL THEN N'Activo' ELSE NULL END;
DECLARE @DateColumn sysname = CASE
    WHEN COL_LENGTH(N'dbo.Usuarios', N'FechaRegistro') IS NOT NULL THEN N'FechaRegistro'
    WHEN COL_LENGTH(N'dbo.Usuarios', N'FechaCreacion') IS NOT NULL THEN N'FechaCreacion'
    ELSE NULL
END;

IF @EmailColumn IS NULL
    THROW 51011, 'dbo.Usuarios no tiene una columna de correo reconocida.', 1;

DECLARE @EmailExpression nvarchar(max) = N'CONVERT(nvarchar(320), u.' + QUOTENAME(@EmailColumn) + N')';
DECLARE @Sql nvarchar(max) = N'
SELECT
    ' + COALESCE(N'u.' + QUOTENAME(@IdColumn), N'NULL') + N' AS UsuarioId,
    CASE
        WHEN ' + @EmailExpression + N' IS NULL THEN NULL
        WHEN CHARINDEX(N''@'', ' + @EmailExpression + N') > 2
            THEN LEFT(' + @EmailExpression + N', 2) + N''***@'' + SUBSTRING(' + @EmailExpression + N', CHARINDEX(N''@'', ' + @EmailExpression + N') + 1, 256)
        ELSE N''***''
    END AS CorreoEnmascarado,
    ' + COALESCE(N'CONVERT(nvarchar(100), u.' + QUOTENAME(@RoleColumn) + N')', N'N''No disponible''') + N' AS Rol,
    ' + COALESCE(N'CONVERT(nvarchar(20), u.' + QUOTENAME(@StatusColumn) + N')', N'N''No disponible''') + N' AS Estado,
    ' + COALESCE(N'u.' + QUOTENAME(@DateColumn), N'NULL') + N' AS Fecha
FROM dbo.Usuarios AS u
WHERE LOWER(' + @EmailExpression + N') LIKE N''%demo%''
   OR LOWER(' + @EmailExpression + N') LIKE N''%test%''
   OR LOWER(' + @EmailExpression + N') LIKE N''%example.invalid%''
ORDER BY ' + COALESCE(N'u.' + QUOTENAME(@IdColumn), @EmailExpression) + N';';

EXEC sys.sp_executesql @Sql;

-- Interpretacion: revisar solo cuentas demo activas con el responsable del entorno.
-- No modificar cuentas desde este archivo; cualquier rotacion o desactivacion requiere un bloque Azure aprobado.
