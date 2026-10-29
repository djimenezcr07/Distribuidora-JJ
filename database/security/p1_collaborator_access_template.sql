/*
    Plantilla P1 para acceso individual de solo lectura.
    Reemplace los placeholders antes de usar una copia privada aprobada.
    El modo por defecto VERIFY no modifica la base.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Mode NVARCHAR(16) = N'VERIFY'; -- VERIFY, PROVISION o REVOKE
DECLARE @IdentityType NVARCHAR(16) = N'ENTRA'; -- ENTRA o CONTAINED
DECLARE @EntraUser SYSNAME = N'<entra-user-email>';
DECLARE @ContainedUser SYSNAME = N'<contained-user-name>';
DECLARE @PrincipalName SYSNAME =
    CASE WHEN @IdentityType = N'ENTRA' THEN @EntraUser ELSE @ContainedUser END;

IF @Mode = N'PROVISION'
BEGIN
    IF @IdentityType <> N'ENTRA'
        THROW 51040, 'La cuenta contenida debe crearse con una credencial privada fuera de esta plantilla.', 1;

    BEGIN TRANSACTION;

    IF USER_ID(@PrincipalName) IS NULL
    BEGIN
        DECLARE @CreateSql NVARCHAR(MAX) =
            N'CREATE USER ' + QUOTENAME(@PrincipalName) + N' FROM EXTERNAL PROVIDER;';
        EXEC sys.sp_executesql @CreateSql;
    END;

    IF IS_ROLEMEMBER(N'db_datareader', @PrincipalName) <> 1
    BEGIN
        DECLARE @RoleSql NVARCHAR(MAX) =
            N'ALTER ROLE [db_datareader] ADD MEMBER ' + QUOTENAME(@PrincipalName) + N';';
        EXEC sys.sp_executesql @RoleSql;
    END;

    DECLARE @GrantSql NVARCHAR(MAX) =
        N'GRANT VIEW DEFINITION TO ' + QUOTENAME(@PrincipalName) + N';';
    EXEC sys.sp_executesql @GrantSql;

    COMMIT TRANSACTION;
END;

IF @Mode = N'REVOKE' AND USER_ID(@PrincipalName) IS NOT NULL
BEGIN
    BEGIN TRANSACTION;

    IF IS_ROLEMEMBER(N'db_datareader', @PrincipalName) = 1
    BEGIN
        DECLARE @DropRoleSql NVARCHAR(MAX) =
            N'ALTER ROLE [db_datareader] DROP MEMBER ' + QUOTENAME(@PrincipalName) + N';';
        EXEC sys.sp_executesql @DropRoleSql;
    END;

    DECLARE @DropUserSql NVARCHAR(MAX) = N'DROP USER ' + QUOTENAME(@PrincipalName) + N';';
    EXEC sys.sp_executesql @DropUserSql;

    COMMIT TRANSACTION;
END;

SELECT
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    IS_ROLEMEMBER(N'db_datareader', dp.name) AS IsDataReader,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM sys.database_permissions AS permission
            WHERE permission.grantee_principal_id = dp.principal_id
              AND permission.class = 0
              AND permission.permission_name = N'VIEW DEFINITION'
              AND permission.state IN (N'G', N'W')
        ) THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS HasViewDefinition
FROM sys.database_principals AS dp
WHERE dp.name = @PrincipalName;
