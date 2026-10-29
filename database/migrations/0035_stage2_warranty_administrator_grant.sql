SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 56710,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 56711,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0035_stage2_warranty_administrator_grant')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0035_stage2_warranty_administrator_grant' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 56712,N'Conflicto de ledger 0035.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0034_stage2_original_login_8h' AND Status=N'Applied' AND FileSha256=N'7054204E907042E164CBE38F9CD8ED4315C37E1F01E46D31C7502AD7DED12C94') THROW 56713,N'Falta prerequisito 0034 acreditado.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int,@Permission int,@GrantCreated bit=0;
 EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0035:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 56714,N'Instalacion concurrente.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=1 AND Nombre COLLATE Latin1_General_100_BIN2=N'Administrador' AND Activo=1)
  THROW 56715,N'El perfil autorizado no coincide con el catalogo.',1;
 SELECT @Permission=PermisoId FROM dbo.Permisos WITH(UPDLOCK,HOLDLOCK) WHERE Codigo=N'GARANTIAS_GESTIONAR';
 IF @Permission IS NULL
 BEGIN
  INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo)
   VALUES(N'GARANTIAS_GESTIONAR',N'Garantias',N'Gestionar garantías',N'Consultar y resolver garantías mediante autorización efectiva y auditoría.',1);
  SET @Permission=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE IF NOT EXISTS(SELECT 1 FROM dbo.Permisos WHERE PermisoId=@Permission AND Activo=1 AND Modulo=N'Garantias' AND Nombre=N'Gestionar garantías')
  THROW 56716,N'Definicion de capacidad existente no acreditada.',1;
 IF EXISTS(SELECT 1 FROM dbo.PerfilPermisos WITH(UPDLOCK,HOLDLOCK) WHERE PermisoId=@Permission AND PerfilId<>1)
  THROW 56717,N'Existe una asignacion fuera del alcance autorizado.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=1 AND PermisoId=@Permission)
 BEGIN
  INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
   VALUES(1,@Permission,NULL,N'Autorización humana explícita 2026-10-14; migración 0035');
  SET @GrantCreated=1;
 END;
 -- Do not infer an application user for the Windows operator. Record the real SQL identity.
 INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
  VALUES(NULL,ORIGINAL_LOGIN(),N'',N'Operador SQL local',N'ASIGNAR_CAPACIDAD',N'Garantias',
    CONCAT(N'Autorización humana explícita: GARANTIAS_GESTIONAR únicamente para PerfilId 1 Administrador. Asignación nueva: ',@GrantCreated,N'.'));
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
  VALUES(N'0035_stage2_warranty_administrator_grant',N'0035_stage2_warranty_administrator_grant.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
   N'Autorizacion humana 2026-10-14: capacidad de garantias unicamente a Administrador PerfilId 1. Sin relaciones comerciales ni bypass.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;