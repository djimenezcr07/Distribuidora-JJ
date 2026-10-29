SET NOCOUNT ON; SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1
 THROW 56410,N'Instalar con QUOTED_IDENTIFIER y ANSI_NULLS ON.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 56411,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0032_stage2_warranty_authorization')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0032_stage2_warranty_authorization' AND Status=N'Applied' AND FileSha256=UPPER(@Hash))
  THROW 56412,N'Conflicto de ledger 0032.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0031_stage2_physical_delivery' AND Status=N'Applied' AND FileSha256=N'9A1E93B5A8F58375D901E2889D58E5C8E3060C604A64736891FEAE5EF6AA8F78') THROW 56413,N'Falta prerequisito 0031 acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2PhysicalDeliveries',N'U') IS NULL OR OBJECT_ID(N'dbo.AuditoriaSistema',N'U') IS NULL
 OR OBJECT_ID(N'dbo.Garantias',N'U') IS NULL THROW 56414,N'Esquema requerido ausente.',1;
IF OBJECT_ID(N'dbo.sp_Admin_UpdateWarrantyStatus',N'P') IS NOT NULL
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Client_CreateWarrantyRequest')
 AND CONVERT(varchar(64),HASHBYTES('SHA2_256',definition),2)='B7172CBB21450393156DE671F642F2FE92EBEBCBC1BE11304898FEAA1DBFECB7')
 THROW 56415,N'Contrato instalado no acreditado.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0032:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 56416,N'Instalacion concurrente.',1;
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Client_CreateWarrantyRequest
 @PedidoDetalleId int,@UsuarioId int,@Motivo nvarchar(250),@Descripcion nvarchar(max)=NULL,
 @ExpectedSecurityStamp uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Motivo=NULLIF(LTRIM(RTRIM(@Motivo)),N'''');
 IF @Motivo IS NULL OR LEN(ISNULL(@Descripcion,N''''))>1000 THROW 56401,N''Solicitud no valida.'',1;
 IF @ExpectedSecurityStamp IS NULL THROW 56402,N''Contexto no vigente.'',1;
 DECLARE @Profile int,@PedidoId int,@Id int,@Nombre nvarchar(150),@Correo nvarchar(256),@Rol nvarchar(100);
 BEGIN TRY
  BEGIN TRANSACTION;
  SELECT @Profile=PerfilId FROM dbo.Usuarios WHERE UsuarioId=@UsuarioId;
  SELECT @Rol=Nombre FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=@Profile AND Activo=1 AND Nombre=N''Cliente'';
  SELECT @Nombre=NombreCompleto,@Correo=Correo FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK)
   WHERE UsuarioId=@UsuarioId AND PerfilId=@Profile AND Activo=1 AND SecurityStamp=@ExpectedSecurityStamp;
  IF @Rol IS NULL OR @Nombre IS NULL THROW 56402,N''Contexto no vigente.'',1;
  SELECT @PedidoId=o.PedidoId FROM dbo.PedidoDetalle d WITH(UPDLOCK,HOLDLOCK)
   INNER JOIN dbo.Pedidos o WITH(UPDLOCK,HOLDLOCK) ON o.PedidoId=d.PedidoId
   INNER JOIN dbo.Stage2PhysicalDeliveries e WITH(HOLDLOCK) ON e.PedidoId=o.PedidoId
   WHERE d.PedidoDetalleId=@PedidoDetalleId AND o.UsuarioId=@UsuarioId AND d.PedidoComboId IS NULL AND d.EsRegalo=0;
  IF @PedidoId IS NULL THROW 56403,N''Propiedad o entrega fisica no acreditadas.'',1;
  IF EXISTS(SELECT 1 FROM dbo.Garantias WITH(UPDLOCK,HOLDLOCK) WHERE PedidoDetalleId=@PedidoDetalleId AND Estado IN(N''Pendiente'',N''En revisión''))
   THROW 56404,N''Ya existe una solicitud abierta.'',1;
  INSERT dbo.Garantias(PedidoDetalleId,UsuarioId,Motivo,Descripcion,Estado)
   VALUES(@PedidoDetalleId,@UsuarioId,@Motivo,NULLIF(LTRIM(RTRIM(@Descripcion)),N''''),N''Pendiente'');
  SET @Id=CONVERT(int,SCOPE_IDENTITY());
  INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
   VALUES(@UsuarioId,@Nombre,@Correo,@Rol,N''CREAR_GARANTIA'',N''Garantias'',CONCAT(N''Garantia '',@Id,N''; pedido '',@PedidoId,N''.''));
  COMMIT TRANSACTION;
  SELECT @Id AS GarantiaId;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateWarrantyStatus
 @GarantiaId int,@Estado nvarchar(30),@Resolucion nvarchar(1000)=NULL,
 @ActorUsuarioId int,@ActorNombre nvarchar(150)=NULL,@ExpectedSecurityStamp uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Estado=NULLIF(LTRIM(RTRIM(@Estado)),N''''); SET @Resolucion=NULLIF(LTRIM(RTRIM(@Resolucion)),N'''');
 IF @Estado IS NULL OR @Estado NOT IN(N''En revisión'',N''Aprobada'',N''Rechazada'') THROW 56405,N''Estado no valido.'',1;
 IF @Estado IN(N''Aprobada'',N''Rechazada'') AND @Resolucion IS NULL THROW 56406,N''Resolucion requerida.'',1;
 IF @ExpectedSecurityStamp IS NULL THROW 56402,N''Contexto no vigente.'',1;
 DECLARE @Profile int,@Nombre nvarchar(150),@Correo nvarchar(256),@Rol nvarchar(100),@Anterior nvarchar(30);
 BEGIN TRY
  BEGIN TRANSACTION;
  SELECT @Profile=PerfilId FROM dbo.Usuarios WHERE UsuarioId=@ActorUsuarioId;
  SELECT @Rol=Nombre FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=@Profile AND Activo=1;
  IF @Rol IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos pp WITH(UPDLOCK,HOLDLOCK)
     INNER JOIN dbo.Permisos p WITH(UPDLOCK,HOLDLOCK) ON p.PermisoId=pp.PermisoId
     WHERE pp.PerfilId=@Profile AND p.Codigo=N''GARANTIAS_GESTIONAR'' AND p.Activo=1)
   THROW 56407,N''Capacidad no acreditada.'',1;
  SELECT @Nombre=NombreCompleto,@Correo=Correo FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK)
   WHERE UsuarioId=@ActorUsuarioId AND PerfilId=@Profile AND Activo=1 AND SecurityStamp=@ExpectedSecurityStamp;
  IF @Nombre IS NULL THROW 56402,N''Contexto no vigente.'',1;
  SELECT @Anterior=Estado FROM dbo.Garantias WITH(UPDLOCK,HOLDLOCK) WHERE GarantiaId=@GarantiaId;
  IF @Anterior IS NULL OR @Anterior NOT IN(N''Pendiente'',N''En revisión'') THROW 56408,N''Transicion no permitida.'',1;
  UPDATE dbo.Garantias SET Estado=@Estado,
   Resolucion=CASE WHEN @Estado IN(N''Aprobada'',N''Rechazada'') THEN @Resolucion ELSE Resolucion END,
   FechaResolucion=CASE WHEN @Estado IN(N''Aprobada'',N''Rechazada'') THEN SYSUTCDATETIME() ELSE NULL END
   WHERE GarantiaId=@GarantiaId;
  INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
   VALUES(@ActorUsuarioId,@Nombre,@Correo,@Rol,N''ACTUALIZAR_GARANTIA'',N''Garantias'',CONCAT(N''Garantia '',@GarantiaId,N'': '',@Anterior,N'' -> '',@Estado,N''.''));
  COMMIT TRANSACTION;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0032_stage2_warranty_authorization',N'0032_stage2_warranty_authorization.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
 N'Garantias nuevas con propiedad y evidencia fisica; capacidad vigente y auditoria atomica; historicos intactos.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;