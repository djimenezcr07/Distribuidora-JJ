SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory
               WHERE MigrationId=N'0030_stage2_authorization_invalidation' AND Status=N'Applied')
    THROW 56310, N'0030 no figura aplicada.', 1;
IF (SELECT COUNT(*) FROM sys.triggers
    WHERE name IN(N'tr_Stage2_ProfileGrants_RevokeSessions',N'tr_Stage2_Permissions_RevokeSessions',N'tr_Stage2_Profiles_RevokeSessions')
      AND is_disabled=0 AND is_instead_of_trigger=0)<>3
    THROW 56311, N'No se acreditaron los tres triggers habilitados.', 1;
SELECT name, is_disabled,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(object_id)),2) AS DefinitionSha256
FROM sys.triggers
WHERE name IN(N'tr_Stage2_ProfileGrants_RevokeSessions',N'tr_Stage2_Permissions_RevokeSessions',N'tr_Stage2_Profiles_RevokeSessions')
ORDER BY name;
