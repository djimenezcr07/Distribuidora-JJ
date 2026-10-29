-- Extend the existing canonical SecurityStamp; no roles, grants or epochs are fabricated.
-- Historical ledger IDs and existing business rows are preserved during installation.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 56300, N'Falta el historial de migraciones.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0025_session_revocation' AND Status=N'Applied')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0027_dynamic_authorization_capabilities' AND Status=N'Applied')
    THROW 56301, N'Faltan las dependencias exactas de revocacion y capacidades.', 1;
IF COL_LENGTH(N'dbo.Usuarios',N'SecurityStamp') IS NULL
   OR OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NULL OR OBJECT_ID(N'dbo.Permisos',N'U') IS NULL
    THROW 56302, N'El esquema de autorizacion no es compatible.', 1;

DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%'
    THROW 56303, N'Hash de archivo invalido.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0030_stage2_authorization_invalidation')
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0030_stage2_authorization_invalidation'
                   AND FileSha256=UPPER(@Hash) AND Status=N'Applied')
        THROW 56304, N'Conflicto de identidad o hash de la migracion.', 1;
    RETURN;
END;
IF OBJECT_ID(N'dbo.tr_Stage2_ProfileGrants_RevokeSessions') IS NOT NULL
   OR OBJECT_ID(N'dbo.tr_Stage2_Permissions_RevokeSessions') IS NOT NULL
   OR OBJECT_ID(N'dbo.tr_Stage2_Profiles_RevokeSessions') IS NOT NULL
    THROW 56305, N'Objetos sin ledger acreditado: revisar antes de instalar.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock int;
    EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0030:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 56306, N'No se obtuvo el bloqueo de instalacion.', 1;
    EXEC(N'CREATE TRIGGER dbo.tr_Stage2_ProfileGrants_RevokeSessions
    ON dbo.PerfilPermisos AFTER INSERT, UPDATE, DELETE AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE u SET SecurityStamp=NEWID()
        FROM dbo.Usuarios AS u
        INNER JOIN (SELECT PerfilId FROM inserted UNION SELECT PerfilId FROM deleted) AS affected
            ON affected.PerfilId=u.PerfilId;
    END;');
    EXEC(N'CREATE TRIGGER dbo.tr_Stage2_Permissions_RevokeSessions
    ON dbo.Permisos AFTER UPDATE, DELETE AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE u SET SecurityStamp=NEWID()
        FROM dbo.Usuarios AS u
        WHERE EXISTS (
            SELECT 1 FROM dbo.PerfilPermisos AS assignment
            INNER JOIN (SELECT PermisoId FROM inserted UNION SELECT PermisoId FROM deleted) AS affected
                ON affected.PermisoId=assignment.PermisoId
            WHERE assignment.PerfilId=u.PerfilId
        );
    END;');
    EXEC(N'CREATE TRIGGER dbo.tr_Stage2_Profiles_RevokeSessions
    ON dbo.Perfiles AFTER UPDATE AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE u SET SecurityStamp=NEWID()
        FROM dbo.Usuarios AS u
        INNER JOIN inserted AS changed ON changed.PerfilId=u.PerfilId
        INNER JOIN deleted AS previous ON previous.PerfilId=changed.PerfilId
        WHERE changed.Activo<>previous.Activo OR changed.Nombre<>previous.Nombre;
    END;');
    INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
    VALUES(N'0030_stage2_authorization_invalidation',N'0030_stage2_authorization_invalidation.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
           N'Revocacion transaccional por grants, permisos y estado de perfil; sin asignaciones ni reescritura historica.');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
