SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0035_stage2_warranty_administrator_grant' AND Status=N'Applied')
 THROW 56720,N'Falta ledger 0035.',1;
IF (SELECT COUNT(*) FROM dbo.PerfilPermisos pp JOIN dbo.Permisos p ON p.PermisoId=pp.PermisoId WHERE p.Codigo=N'GARANTIAS_GESTIONAR')<>1
 OR NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos pp JOIN dbo.Permisos p ON p.PermisoId=pp.PermisoId
 JOIN dbo.Perfiles pf ON pf.PerfilId=pp.PerfilId
 WHERE pp.PerfilId=1 AND pf.Nombre=N'Administrador' AND pf.Activo=1 AND p.Codigo=N'GARANTIAS_GESTIONAR' AND p.Activo=1)
 THROW 56721,N'Asignacion distinta de la autorizada.',1;
SELECT N'PASS: GARANTIAS_GESTIONAR únicamente en Administrador PerfilId 1' AS Result;
