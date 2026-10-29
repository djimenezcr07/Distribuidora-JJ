/* Verificacion P1 estrictamente de solo lectura. */
SET NOCOUNT ON;

SELECT
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    dp.authentication_type_desc AS AuthenticationType
FROM sys.database_principals AS dp
WHERE dp.type IN (N'E', N'X', N'S')
  AND dp.name NOT IN (N'dbo', N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY dp.name;

SELECT
    member.name AS PrincipalName,
    role_principal.name AS DatabaseRole
FROM sys.database_role_members AS drm
INNER JOIN sys.database_principals AS role_principal
    ON role_principal.principal_id = drm.role_principal_id
INNER JOIN sys.database_principals AS member
    ON member.principal_id = drm.member_principal_id
ORDER BY member.name, role_principal.name;

SELECT
    principal.name AS PrincipalName,
    permission.state_desc AS PermissionState,
    permission.permission_name AS PermissionName
FROM sys.database_permissions AS permission
INNER JOIN sys.database_principals AS principal
    ON principal.principal_id = permission.grantee_principal_id
WHERE principal.type IN (N'E', N'X', N'S')
ORDER BY principal.name, permission.permission_name;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
BEGIN
    SELECT
        MigrationId,
        FileName,
        Status,
        AppliedAtUtc,
        AppliedBy,
        EnvironmentName,
        Notes
    FROM dbo.SchemaMigrationHistory
    ORDER BY AppliedAtUtc, MigrationId;
END;

SELECT
    COUNT(*) AS ActiveDemoAccounts
FROM dbo.Usuarios AS usuario
WHERE usuario.Activo = 1
  AND
  (
      LOWER(ISNULL(usuario.Correo, N'')) LIKE N'%demo%'
      OR LOWER(ISNULL(usuario.Correo, N'')) LIKE N'%test%'
      OR LOWER(ISNULL(usuario.Correo, N'')) LIKE N'%example.invalid%'
      OR LOWER(ISNULL(usuario.NombreCompleto, N'')) LIKE N'%demo%'
      OR LOWER(ISNULL(usuario.NombreCompleto, N'')) LIKE N'%test%'
  );
