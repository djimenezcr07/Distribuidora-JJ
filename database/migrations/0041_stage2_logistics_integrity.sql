SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57510,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57511,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0041_stage2_logistics_integrity')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0041_stage2_logistics_integrity' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57512,N'Conflicto de ledger 0041.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0039_stage2_aggregate_amounts_v2' AND Status=N'Applied') THROW 57513,N'Falta contrato de importes V2.',1;
IF OBJECT_ID(N'dbo.Stage2EvidenceIntegrity') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_RouteOperation') IS NOT NULL THROW 57514,N'Objetos anteriores no acreditados.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0041:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57515,N'Instalacion concurrente.',1;
 -- Add nullable fields only; legacy references and records are never reinterpreted or backfilled.
 IF COL_LENGTH(N'dbo.EntregaEvidencias',N'StorageKey') IS NULL ALTER TABLE dbo.EntregaEvidencias ADD StorageKey nvarchar(160) NULL;
 IF COL_LENGTH(N'dbo.EntregaEvidencias',N'MimeType') IS NULL ALTER TABLE dbo.EntregaEvidencias ADD MimeType nvarchar(100) NULL;
 IF COL_LENGTH(N'dbo.EntregaEvidencias',N'StorageStatus') IS NULL ALTER TABLE dbo.EntregaEvidencias ADD StorageStatus nvarchar(20) NULL;
 CREATE TABLE dbo.Stage2EvidenceIntegrity(EvidenciaId int NOT NULL PRIMARY KEY REFERENCES dbo.EntregaEvidencias(EvidenciaId),Sha256 char(64) NOT NULL,LengthBytes bigint NOT NULL CHECK(LengthBytes>0 AND LengthBytes<=5242880),CONSTRAINT CK_Stage2EvidenceIntegrity_Hash CHECK(LEN(Sha256)=64 AND Sha256 NOT LIKE '%[^0-9A-F]%'));
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetAssignableOrders
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'''');

    SELECT
        p.PedidoId,
        u.NombreCompleto                         AS Cliente,
        u.Correo,
        p.FechaPedido,
        p.Estado,
        ISNULL(p.TipoEntrega, N'''')               AS TipoEntrega,
        ISNULL(NULLIF(p.DireccionEntrega, N''''), u.Direccion) AS DireccionEntrega,
        p.Total,
        (SELECT COUNT(*) FROM dbo.PedidoDetalle d WHERE d.PedidoId = p.PedidoId) AS TotalLineas
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.Estado=N''Facturado'' AND p.InventarioDescontado=1 AND EXISTS(SELECT 1 FROM dbo.Facturas f WHERE f.PedidoId=p.PedidoId AND f.Estado=N''Generada'') AND NOT EXISTS(SELECT 1 FROM dbo.Stage2PhysicalDeliveries pd WHERE pd.PedidoId=p.PedidoId) AND NOT EXISTS(SELECT 1 FROM dbo.RutaPedidos failed WHERE failed.PedidoId=p.PedidoId AND failed.EstadoEntrega=N''Fallido'')
      AND ISNULL(NULLIF(p.DireccionEntrega, N''''), u.Direccion) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.RutaPedidos rp
          INNER JOIN dbo.Rutas r ON r.RutaId = rp.RutaId
          WHERE rp.PedidoId = p.PedidoId
            AND r.Estado <> N''Cancelada''
      )
      AND (
          @Buscar IS NULL
          OR u.NombreCompleto LIKE N''%'' + @Buscar + N''%''
          OR u.Correo         LIKE N''%'' + @Buscar + N''%''
          OR CAST(p.PedidoId AS NVARCHAR(20)) = @Buscar
          OR ISNULL(p.DireccionEntrega, N'''')  LIKE N''%'' + @Buscar + N''%''
      )
    ORDER BY p.FechaPedido ASC, p.PedidoId ASC;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_CreateRoute
 @Zona nvarchar(120),@ChoferUsuarioId int,@VehiculoId int,@Observaciones nvarchar(300)=NULL,@PedidosJson nvarchar(max),@CreadaPorUsuarioId int,@CreadaPorNombre nvarchar(150)=NULL,@Actor int
AS BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @@TRANCOUNT=0 OR @Actor<>@CreadaPorUsuarioId THROW 57500,N''Falta contexto original.'',1;
 DECLARE @Selected TABLE(Id int NOT NULL PRIMARY KEY);
 IF ISJSON(@PedidosJson)<>1 THROW 57501,N''Pedidos no validos.'',1;
 INSERT @Selected SELECT DISTINCT pedidoId FROM OPENJSON(@PedidosJson) WITH(pedidoId int ''$.pedidoId'');
 IF EXISTS(SELECT 1 FROM @Selected selected LEFT JOIN dbo.Pedidos p WITH(UPDLOCK,HOLDLOCK) ON p.PedidoId=selected.Id
 WHERE p.PedidoId IS NULL OR p.Estado<>N''Facturado'' OR p.InventarioDescontado<>1
 OR NOT EXISTS(SELECT 1 FROM dbo.Facturas f WITH(UPDLOCK,HOLDLOCK) WHERE f.PedidoId=p.PedidoId AND f.Estado=N''Generada'')
 OR EXISTS(SELECT 1 FROM dbo.Stage2PhysicalDeliveries pd WHERE pd.PedidoId=p.PedidoId)
 OR EXISTS(SELECT 1 FROM dbo.RutaPedidos failed WITH(UPDLOCK,HOLDLOCK) WHERE failed.PedidoId=p.PedidoId AND failed.EstadoEntrega=N''Fallido''))
 THROW 57501,N''Pedido no despachable; requiere factura vigente y conciliacion de devoluciones si corresponde.'',1;
 DECLARE @Created TABLE(RutaId int,Codigo nvarchar(50));
 INSERT @Created EXEC dbo.sp_Rutas_Create @Zona=@Zona,@ChoferUsuarioId=@ChoferUsuarioId,@VehiculoId=@VehiculoId,@Observaciones=@Observaciones,@PedidosJson=@PedidosJson,@CreadaPorUsuarioId=@Actor,@CreadaPorNombre=@CreadaPorNombre;
 INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
 SELECT @Actor,u.NombreCompleto,u.Correo,p.Nombre,N''Crear ruta'',N''Rutas'',CONCAT(N''Ruta #'',c.RutaId,N'' creada con pedidos facturados.'') FROM @Created c CROSS JOIN dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@Actor;
 SELECT RutaId,Codigo FROM @Created;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_RouteOperation
 @Operation nvarchar(20),@Actor int,@RutaId int,@PedidoId int=NULL,@UsuarioId int=NULL,@UsuarioNombre nvarchar(150)=NULL,@ItemsJson nvarchar(max)=NULL,@ExcluirRutaPedidoId int=NULL,@MotivoFallo nvarchar(300)=NULL,@Motivo nvarchar(300)=NULL
AS BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @@TRANCOUNT=0 OR (@UsuarioId IS NOT NULL AND @Actor<>@UsuarioId) THROW 57500,N''Falta contexto original.'',1;
 IF @Operation NOT IN(N''AddOrder'',N''RemoveOrder'',N''Dispatch'',N''Sequence'',N''SaveSequence'',N''Recalculate'',N''Cancel'') THROW 57502,N''Operacion no acreditada.'',1;
 DECLARE @State nvarchar(30),@Driver int;
 SELECT @State=Estado,@Driver=ChoferUsuarioId FROM dbo.Rutas WITH(UPDLOCK,HOLDLOCK) WHERE RutaId=@RutaId;
 IF @State IS NULL THROW 57502,N''Ruta no disponible.'',1;
 IF @Operation IN(N''AddOrder'',N''RemoveOrder'',N''Cancel'') AND @State<>N''Planificada'' THROW 57502,N''Cambios posteriores al despacho requieren conciliacion.'',1;
 IF @Operation IN(N''AddOrder'',N''Dispatch'') BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios u WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@Driver AND u.Activo=1 AND p.Activo=1 AND p.Nombre IN(N''Chofer'',N''Administrador'')) THROW 57503,N''Asignacion logistica no vigente.'',1;
  DECLARE @Selected TABLE(Id int NOT NULL PRIMARY KEY);
  IF @Operation=N''AddOrder'' INSERT @Selected VALUES(@PedidoId);
  ELSE INSERT @Selected SELECT PedidoId FROM dbo.RutaPedidos WITH(UPDLOCK,HOLDLOCK) WHERE RutaId=@RutaId;
 IF EXISTS(SELECT 1 FROM @Selected selected LEFT JOIN dbo.Pedidos p WITH(UPDLOCK,HOLDLOCK) ON p.PedidoId=selected.Id
 WHERE p.PedidoId IS NULL OR p.Estado<>N''Facturado'' OR p.InventarioDescontado<>1
 OR NOT EXISTS(SELECT 1 FROM dbo.Facturas f WITH(UPDLOCK,HOLDLOCK) WHERE f.PedidoId=p.PedidoId AND f.Estado=N''Generada'')
 OR EXISTS(SELECT 1 FROM dbo.Stage2PhysicalDeliveries pd WHERE pd.PedidoId=p.PedidoId)
 OR EXISTS(SELECT 1 FROM dbo.RutaPedidos failed WITH(UPDLOCK,HOLDLOCK) WHERE failed.PedidoId=p.PedidoId AND failed.EstadoEntrega=N''Fallido''))
 THROW 57501,N''Pedido no despachable; requiere factura vigente y conciliacion de devoluciones si corresponde.'',1;
 END;
 SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor;
 IF @Operation=N''AddOrder'' EXEC dbo.sp_Rutas_AddOrder @RutaId=@RutaId,@PedidoId=@PedidoId;
 ELSE IF @Operation=N''RemoveOrder'' EXEC dbo.sp_Rutas_RemoveOrder @RutaId=@RutaId,@PedidoId=@PedidoId;
 ELSE IF @Operation=N''Dispatch'' EXEC dbo.sp_Rutas_Dispatch @RutaId=@RutaId,@UsuarioId=@Actor,@UsuarioNombre=@UsuarioNombre;
 ELSE IF @Operation=N''Sequence'' EXEC dbo.sp_Rutas_Secuenciar @RutaId=@RutaId;
 ELSE IF @Operation=N''SaveSequence'' EXEC dbo.sp_Rutas_GuardarSecuencia @RutaId=@RutaId,@ItemsJson=@ItemsJson;
 ELSE IF @Operation=N''Recalculate'' EXEC dbo.sp_Rutas_Recalcular @RutaId=@RutaId,@ExcluirRutaPedidoId=@ExcluirRutaPedidoId,@MotivoFallo=@MotivoFallo;
 ELSE IF @Operation=N''Cancel'' EXEC dbo.sp_Rutas_Cancel @RutaId=@RutaId,@Motivo=@Motivo,@UsuarioId=@Actor,@UsuarioNombre=@UsuarioNombre;
 INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
 SELECT @Actor,u.NombreCompleto,u.Correo,p.Nombre,@Operation,N''Rutas'',CONCAT(N''Ruta #'',@RutaId,N''; operacion logistica sin acreditar entrega por despacho.'') FROM dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@Actor;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_ConfirmDelivery
        @RutaPedidoId int,
        @NuevoEstado nvarchar(20),
        @SyncGuid uniqueidentifier,
        @MotivoFallo nvarchar(300)=NULL,
        @ChoferUsuarioId int,
        @ChoferNombre nvarchar(150)=NULL,
        @ExpectedSecurityStamp uniqueidentifier=NULL
    AS
    BEGIN
        IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
        SET NOCOUNT ON; SET XACT_ABORT ON;
        SET @NuevoEstado=NULLIF(LTRIM(RTRIM(@NuevoEstado)),N'''');
        SET @MotivoFallo=NULLIF(LTRIM(RTRIM(@MotivoFallo)),N'''');
        IF @SyncGuid IS NULL OR @SyncGuid=CONVERT(uniqueidentifier,N''00000000-0000-0000-0000-000000000000'')
            THROW 52070,N''Falta el identificador de sincronizacion.'',1;
        IF @NuevoEstado IS NULL OR @NuevoEstado NOT IN(N''EnRuta'',N''Entregado'',N''Fallido'')
            THROW 52071,N''Estado de entrega invalido.'',1;
        SET @NuevoEstado=CASE @NuevoEstado WHEN N''EnRuta'' THEN N''EnRuta'' WHEN N''Entregado'' THEN N''Entregado'' ELSE N''Fallido'' END;
        IF @NuevoEstado=N''Fallido'' AND @MotivoFallo IS NULL THROW 52072,N''Falta el motivo de entrega fallida.'',1;
        IF @ExpectedSecurityStamp IS NULL THROW 56327,N''Falta el contexto autenticado.'',1;
        DECLARE @Profile int,@RutaId int,@PedidoId int,@EstadoActual nvarchar(20),@EstadoRuta nvarchar(20),
                @Lock int,@Notificar bit=0,@RutaCompletada bit=0,@Duplicado bit=0,@SyncId int,
                @StoredRoute int,@StoredActor int,@StoredState nvarchar(20),@StoredReason nvarchar(300);
        BEGIN TRY
            BEGIN TRANSACTION;
            SELECT @Profile=PerfilId FROM dbo.Usuarios WHERE UsuarioId=@ChoferUsuarioId;
            IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WITH(UPDLOCK,HOLDLOCK) WHERE PerfilId=@Profile AND Activo=1 AND Nombre IN(N''Chofer'',N''Administrador''))
                THROW 56328,N''Contexto no vigente.'',1;
            SELECT @ChoferNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@ChoferUsuarioId;
            IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE UsuarioId=@ChoferUsuarioId
                          AND PerfilId=@Profile AND Activo=1 AND SecurityStamp=@ExpectedSecurityStamp)
                THROW 56328,N''Contexto no vigente.'',1;
            DECLARE @Resource nvarchar(255)=CONCAT(N''DeliverySync:'',CONVERT(nvarchar(36),@SyncGuid));
            EXEC @Lock=sys.sp_getapplock @Resource=@Resource,@LockMode=N''Exclusive'',@LockOwner=N''Transaction'',@LockTimeout=10000;
            IF @Lock<0 THROW 56329,N''No se pudo serializar la solicitud.'',1;
            SELECT @RutaId=rp.RutaId,@PedidoId=rp.PedidoId,@EstadoActual=rp.EstadoEntrega
            FROM dbo.RutaPedidos AS rp WITH(UPDLOCK,HOLDLOCK) WHERE rp.RutaPedidoId=@RutaPedidoId;
            SELECT @EstadoRuta=Estado FROM dbo.Rutas WITH(UPDLOCK,HOLDLOCK)
            WHERE RutaId=@RutaId AND ChoferUsuarioId=@ChoferUsuarioId;
            -- Ownership precedes every duplicate/result branch; no administrative bypass.
            IF @EstadoRuta IS NULL THROW 52074,N''La entrega no esta asignada al actor.'',1;
            SELECT @SyncId=EntregaSyncLogId,@StoredRoute=RutaPedidoId,@StoredActor=ChoferUsuarioId,
                   @StoredState=EstadoNuevo,@StoredReason=MotivoFallo
            FROM dbo.EntregaSyncLog WITH(UPDLOCK,HOLDLOCK) WHERE SyncGuid=@SyncGuid;
            IF @SyncId IS NOT NULL
            BEGIN
                IF @StoredRoute<>@RutaPedidoId OR ISNULL(@StoredActor,0)<>@ChoferUsuarioId
                    OR @StoredState<>@NuevoEstado
                    OR CONVERT(varbinary(600),ISNULL(@StoredReason,N''''))<>CONVERT(varbinary(600),ISNULL(@MotivoFallo,N''''))
                    THROW 56330,N''El UUID pertenece a otro contexto o contenido.'',1;
                SET @Duplicado=1;
            END
            ELSE
            BEGIN
                IF @EstadoRuta<>N''Despachada'' THROW 52075,N''La ruta no esta despachada.'',1;
                IF @EstadoActual IN(N''Entregado'',N''Fallido'') THROW 52076,N''La entrega ya tiene estado final.'',1;
                IF @NuevoEstado=N''Entregado'' AND NOT EXISTS(
                    SELECT 1 FROM dbo.Pedidos AS o WITH(UPDLOCK,HOLDLOCK)
                    INNER JOIN dbo.Facturas AS f WITH(UPDLOCK,HOLDLOCK) ON f.PedidoId=o.PedidoId
                    WHERE o.PedidoId=@PedidoId AND o.Estado IN(N''Facturado'',N''Entregado'') AND f.Estado=N''Generada'')
                    THROW 56331,N''Se requiere una factura vigente antes de confirmar entrega.'',1;
                UPDATE dbo.RutaPedidos SET EstadoEntrega=@NuevoEstado,
                    MotivoFallo=CASE WHEN @NuevoEstado=N''Fallido'' THEN @MotivoFallo ELSE NULL END,
                    FechaEntrega=CASE WHEN @NuevoEstado IN(N''Entregado'',N''Fallido'') THEN SYSDATETIME() ELSE FechaEntrega END,
                    FechaActualizacion=SYSDATETIME() WHERE RutaPedidoId=@RutaPedidoId;
                IF @NuevoEstado=N''Entregado''
                    UPDATE dbo.Pedidos SET Estado=N''Entregado'',FechaActualizacion=SYSDATETIME() WHERE PedidoId=@PedidoId;
                INSERT dbo.EntregaSyncLog(SyncGuid,RutaPedidoId,EstadoAnterior,EstadoNuevo,MotivoFallo,ChoferUsuarioId,ChoferNombre,FechaSync)
                VALUES(@SyncGuid,@RutaPedidoId,@EstadoActual,@NuevoEstado,@MotivoFallo,@ChoferUsuarioId,@ChoferNombre,SYSDATETIME());
                SET @SyncId=CONVERT(int,SCOPE_IDENTITY());
                IF @NuevoEstado=N''Entregado''
                    INSERT dbo.Stage2PhysicalDeliveries(PedidoId,RutaPedidoId,EntregaSyncLogId,ChoferUsuarioId,ConfirmadoUtc)
                    VALUES(@PedidoId,@RutaPedidoId,@SyncId,@ChoferUsuarioId,SYSUTCDATETIME());
                IF NOT EXISTS(SELECT 1 FROM dbo.RutaPedidos WITH(UPDLOCK,HOLDLOCK) WHERE RutaId=@RutaId AND EstadoEntrega IN(N''Pendiente'',N''EnRuta''))
                    UPDATE dbo.Rutas SET Estado=N''Completada'',FechaCierre=SYSDATETIME(),FechaActualizacion=SYSDATETIME() WHERE RutaId=@RutaId;
                SET @Notificar=CASE WHEN @NuevoEstado IN(N''EnRuta'',N''Entregado'') THEN 1 ELSE 0 END;
            END;
            SELECT @RutaCompletada=CONVERT(bit,CASE WHEN Estado=N''Completada'' THEN 1 ELSE 0 END) FROM dbo.Rutas WHERE RutaId=@RutaId;
            IF @Duplicado=0
             INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
             SELECT @ChoferUsuarioId,u.NombreCompleto,u.Correo,p.Nombre,N''Actualizar entrega'',N''Entregas'',CONCAT(N''Pedido #'',@PedidoId,N''; estado '',@NuevoEstado,N''; confirmacion logistica.'') FROM dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@ChoferUsuarioId;
            COMMIT TRANSACTION;
            SELECT rp.RutaPedidoId,rp.EstadoEntrega,rp.PedidoId,u.Correo AS ClienteCorreo,u.NombreCompleto AS ClienteNombre,
                   @Notificar AS Notificar,@RutaCompletada AS RutaCompletada,@Duplicado AS Duplicado
            FROM dbo.RutaPedidos AS rp INNER JOIN dbo.Pedidos AS o ON o.PedidoId=rp.PedidoId
            INNER JOIN dbo.Usuarios AS u ON u.UsuarioId=o.UsuarioId WHERE rp.RutaPedidoId=@RutaPedidoId;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_RegisterEvidence
    @PedidoId INT,
    @RutaId INT,
    @TipoEvidencia NVARCHAR(20),
    @StorageKey NVARCHAR(160),
    @MimeType NVARCHAR(100),
    @Observaciones NVARCHAR(300) = NULL,
    @RegistradoPorUsuarioId INT,
    @RegistradoPorNombre NVARCHAR(150) = NULL
AS
BEGIN
    IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TipoEvidencia = NULLIF(LTRIM(RTRIM(@TipoEvidencia)), N'''');
    SET @StorageKey = NULLIF(LTRIM(RTRIM(@StorageKey)), N'''');
    SET @MimeType = LOWER(NULLIF(LTRIM(RTRIM(@MimeType)), N''''));

    IF @TipoEvidencia NOT IN (N''Foto'', N''Firma'')
        THROW 52080, N''El tipo de evidencia no es válido.'', 1;
    IF @MimeType NOT IN (N''image/jpeg'', N''image/png'', N''image/webp'')
        THROW 52081, N''El tipo de contenido no es válido.'', 1;
    IF @StorageKey IS NULL OR @StorageKey LIKE N''%/%'' OR @StorageKey LIKE N''%\%'' OR @StorageKey LIKE N''%:%''
        THROW 52082, N''La referencia de almacenamiento no es válida.'', 1;
    IF (@MimeType = N''image/jpeg'' AND RIGHT(@StorageKey, 4) <> N''.jpg'')
       OR (@MimeType = N''image/png'' AND RIGHT(@StorageKey, 4) <> N''.png'')
       OR (@MimeType = N''image/webp'' AND RIGHT(@StorageKey, 5) <> N''.webp'')
        THROW 52083, N''La referencia no coincide con el tipo de contenido.'', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.RutaPedidos rp
        INNER JOIN dbo.Rutas r ON r.RutaId = rp.RutaId
        INNER JOIN dbo.Usuarios actor ON actor.UsuarioId = @RegistradoPorUsuarioId AND actor.Activo = 1
        INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = actor.PerfilId
        WHERE rp.RutaId = @RutaId
          AND rp.PedidoId = @PedidoId
          AND r.ChoferUsuarioId = @RegistradoPorUsuarioId
    )
        THROW 52084, N''El usuario no está autorizado para registrar evidencia en esta entrega.'', 1;

    INSERT INTO dbo.EntregaEvidencias
        (PedidoId, RutaId, TipoEvidencia, ArchivoUrl, StorageKey, MimeType, StorageStatus,
         Observaciones, RegistradoPorUsuarioId, RegistradoPorNombre, FechaRegistro)
    VALUES
        (@PedidoId, @RutaId, @TipoEvidencia, N''[private]'', @StorageKey, @MimeType, N''Pending'',
         NULLIF(LTRIM(RTRIM(@Observaciones)), N''''), @RegistradoPorUsuarioId,
         NULLIF(LTRIM(RTRIM(@RegistradoPorNombre)), N''''), SYSUTCDATETIME());

    SELECT CONVERT(INT, SCOPE_IDENTITY());
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_MarkEvidenceReady @EvidenciaId int,@RegistradoPorUsuarioId int,@Sha256 char(64),@Length bigint AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
 IF @Sha256 IS NULL OR LEN(@Sha256)<>64 OR @Sha256 LIKE ''%[^0-9a-fA-F]%'' OR @Length<=0 OR @Length>5242880 THROW 57504,N''Integridad de evidencia no acreditada.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.EntregaEvidencias e WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Rutas r WITH(UPDLOCK,HOLDLOCK) ON r.RutaId=e.RutaId JOIN dbo.RutaPedidos rp ON rp.RutaId=r.RutaId AND rp.PedidoId=e.PedidoId WHERE e.EvidenciaId=@EvidenciaId AND e.RegistradoPorUsuarioId=@RegistradoPorUsuarioId AND r.ChoferUsuarioId=@RegistradoPorUsuarioId AND e.StorageStatus=N''Pending'') THROW 57503,N''Asignacion de evidencia no vigente.'',1;
 INSERT dbo.Stage2EvidenceIntegrity(EvidenciaId,Sha256,LengthBytes)VALUES(@EvidenciaId,UPPER(@Sha256),@Length);
 UPDATE dbo.EntregaEvidencias SET StorageStatus=N''Ready'' WHERE EvidenciaId=@EvidenciaId;
 INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
 SELECT u.UsuarioId,u.NombreCompleto,u.Correo,p.Nombre,N''Registrar evidencia'',N''Entregas'',CONCAT(N''Evidencia #'',@EvidenciaId,N''; integridad SHA256 acreditada; no confirma entrega.'') FROM dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@RegistradoPorUsuarioId;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetAuthorizedEvidence
    @EvidenciaId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        e.EvidenciaId,
        e.PedidoId,
        e.StorageKey,
        e.MimeType,
        e.TipoEvidencia, integrity.Sha256, integrity.LengthBytes
    FROM dbo.EntregaEvidencias e
    LEFT JOIN dbo.Stage2EvidenceIntegrity integrity ON integrity.EvidenciaId=e.EvidenciaId
    INNER JOIN dbo.Pedidos pedido ON pedido.PedidoId = e.PedidoId
    INNER JOIN dbo.Usuarios usuario ON usuario.UsuarioId = @UsuarioId AND usuario.Activo = 1
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId AND perfil.Activo = 1
    LEFT JOIN dbo.Rutas ruta ON ruta.RutaId = e.RutaId
    WHERE e.EvidenciaId = @EvidenciaId
      AND e.StorageStatus = N''Ready''
      AND e.StorageKey IS NOT NULL
      AND e.MimeType IN (N''image/jpeg'', N''image/png'', N''image/webp'')
      AND
      (
          pedido.UsuarioId = @UsuarioId
          OR ruta.ChoferUsuarioId = @UsuarioId
          OR EXISTS
          (
              SELECT 1
              FROM dbo.PerfilPermisos pp
              INNER JOIN dbo.Permisos permiso ON permiso.PermisoId = pp.PermisoId
              WHERE pp.PerfilId = perfil.PerfilId
                AND permiso.Codigo = N''ENTREGAS_EVIDENCIA_VER''
                AND permiso.Activo = 1
          )
      );
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_UpdateOrderStatusV2
 @PedidoId int,@NuevoEstado nvarchar(50),@UsuarioId int,@UsuarioNombre nvarchar(150)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @@TRANCOUNT=0 THROW 57000,N''Falta transaccion de login original.'',1;
 IF @NuevoEstado NOT IN(N''Aprobado'',N''EnProceso'',N''Cancelado'') OR @NuevoEstado IS NULL
  THROW 57005,N''Estado reservado a su flujo autorizado.'',1;
 DECLARE @Actual nvarchar(50),@Stock bit,@Neto decimal(18,2),@Nombre nvarchar(150),@Correo nvarchar(256),@Rol nvarchar(100);
 SELECT @Actual=Estado,@Stock=InventarioDescontado FROM dbo.Pedidos WITH(UPDLOCK,HOLDLOCK) WHERE PedidoId=@PedidoId;
 IF @Actual IS NULL THROW 51003,N''Pedido no disponible.'',1;
 IF @Actual=N''Retenido'' THROW 57004,N''Relacion supervisora no acreditada.'',1;
 IF EXISTS(SELECT 1 FROM dbo.Facturas WITH(UPDLOCK,HOLDLOCK) WHERE PedidoId=@PedidoId)
  THROW 57006,N''Un pedido facturado no se cambia mediante estado manual.'',1;
 IF @Actual=@NuevoEstado RETURN;
 IF NOT((@Actual=N''Pendiente'' AND @NuevoEstado IN(N''Aprobado'',N''Cancelado''))
  OR (@Actual=N''Aprobado'' AND @NuevoEstado IN(N''EnProceso'',N''Cancelado''))
  OR (@Actual IN(N''EnProceso'',N''Liberado'') AND @NuevoEstado=N''Cancelado''))
  THROW 51006,N''Transicion no permitida.'',1;
 SELECT @Neto=ISNULL((SELECT SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)) FROM dbo.PedidoDetalle WITH(HOLDLOCK)
  WHERE PedidoId=@PedidoId AND PedidoComboId IS NULL),0)
  +ISNULL((SELECT SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)) FROM dbo.PedidoCombos WITH(HOLDLOCK) WHERE PedidoId=@PedidoId),0);
 SELECT @Neto=Neto FROM dbo.Stage2OrderAmounts WITH(HOLDLOCK) WHERE PedidoId=@PedidoId;
 IF @NuevoEstado<>N''Cancelado'' AND @Neto+ROUND(@Neto*0.13,2)>2000000
  THROW 57004,N''Aprobacion supervisora no acreditada para este importe.'',1;
 SELECT @Nombre=u.NombreCompleto,@Correo=u.Correo,@Rol=p.Nombre FROM dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@UsuarioId AND u.Activo=1 AND p.Activo=1;
 IF @Nombre IS NULL THROW 57001,N''Actor no acreditado.'',1;
 IF @NuevoEstado=N''Cancelado'' AND @Stock=1
  EXEC dbo.sp_Inventory_RestoreOrderStock @PedidoId=@PedidoId,@UsuarioId=@UsuarioId,@UsuarioNombre=@Nombre,@Motivo=N''Cancelacion administrativa del pedido no facturado.'';
 UPDATE dbo.Pedidos SET Estado=@NuevoEstado,InventarioDescontado=CASE WHEN @NuevoEstado=N''Cancelado'' THEN 0 ELSE InventarioDescontado END,FechaActualizacion=SYSDATETIME() WHERE PedidoId=@PedidoId;
 INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
 VALUES(@UsuarioId,@Nombre,@Correo,@Rol,N''Cambio de estado'',N''Pedidos'',CONCAT(N''Pedido #'',@PedidoId,N'': '',@Actual,N'' -> '',@NuevoEstado,N''.''));
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetEvidencesByOrder
    @PedidoId INT,@Actor int
AS
BEGIN
    IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
    IF NOT(EXISTS(SELECT 1 FROM dbo.Pedidos p WITH(HOLDLOCK) WHERE p.PedidoId=@PedidoId AND p.UsuarioId=@Actor) OR EXISTS(SELECT 1 FROM dbo.RutaPedidos rp JOIN dbo.Rutas r WITH(HOLDLOCK) ON r.RutaId=rp.RutaId WHERE rp.PedidoId=@PedidoId AND r.ChoferUsuarioId=@Actor) OR EXISTS(SELECT 1 FROM dbo.Usuarios u JOIN dbo.PerfilPermisos pp ON pp.PerfilId=u.PerfilId JOIN dbo.Permisos p ON p.PermisoId=pp.PermisoId WHERE u.UsuarioId=@Actor AND u.Activo=1 AND p.Activo=1 AND p.Codigo=N''ENTREGAS_EVIDENCIA_VER'')) THROW 57503,N''Evidencia no disponible.'',1;
    SET NOCOUNT ON;
    SELECT e.EvidenciaId, e.PedidoId, e.RutaId, e.TipoEvidencia,
           e.StorageKey, e.MimeType,
           ISNULL(e.Observaciones, N'''') AS Observaciones,
           ISNULL(e.RegistradoPorNombre, N'''') AS RegistradoPorNombre,
           e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    WHERE e.PedidoId = @PedidoId AND (e.StorageStatus = N''Ready'' OR e.StorageStatus IS NULL)
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetEvidencesByRoute
    @RutaId INT,@Actor int
AS
BEGIN
    IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
    IF NOT(EXISTS(SELECT 1 FROM dbo.Rutas WITH(HOLDLOCK) WHERE RutaId=@RutaId AND ChoferUsuarioId=@Actor) OR EXISTS(SELECT 1 FROM dbo.Usuarios u JOIN dbo.PerfilPermisos pp ON pp.PerfilId=u.PerfilId JOIN dbo.Permisos p ON p.PermisoId=pp.PermisoId WHERE u.UsuarioId=@Actor AND u.Activo=1 AND p.Activo=1 AND p.Codigo=N''ENTREGAS_EVIDENCIA_VER'')) THROW 57503,N''Evidencia no disponible.'',1;
    SET NOCOUNT ON;
    SELECT rp.PedidoId, rp.EstadoEntrega, u.NombreCompleto AS Cliente,
           (SELECT COUNT(*) FROM dbo.EntregaEvidencias e
            WHERE e.PedidoId = rp.PedidoId AND (e.StorageStatus = N''Ready'' OR e.StorageStatus IS NULL)) AS TotalEvidencias,
           CONVERT(BIT, IIF(EXISTS
           (
               SELECT 1 FROM dbo.EntregaEvidencias e
               WHERE e.PedidoId = rp.PedidoId AND (e.StorageStatus = N''Ready'' OR e.StorageStatus IS NULL)
           ), 0, 1)) AS SinEvidencia
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos p ON p.PedidoId = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia, rp.PedidoId;

    SELECT e.EvidenciaId, e.PedidoId, e.TipoEvidencia, e.StorageKey, e.MimeType,
           ISNULL(e.Observaciones, N'''') AS Observaciones,
           ISNULL(e.RegistradoPorNombre, N'''') AS RegistradoPorNombre,
           e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    INNER JOIN dbo.RutaPedidos rp ON rp.PedidoId = e.PedidoId AND rp.RutaId = @RutaId
    WHERE (e.StorageStatus = N''Ready'' OR e.StorageStatus IS NULL)
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DeletePendingEvidence @EvidenciaId int,@RegistradoPorUsuarioId int AS BEGIN SET NOCOUNT ON;
 IF @@TRANCOUNT=0 THROW 57500,N''Falta contexto original.'',1;
 DELETE dbo.EntregaEvidencias WHERE EvidenciaId=@EvidenciaId AND RegistradoPorUsuarioId=@RegistradoPorUsuarioId AND StorageStatus=N''Pending''; END;');
 EXEC(N'CREATE TRIGGER dbo.tr_Stage2EvidenceIntegrity_Immutable ON dbo.Stage2EvidenceIntegrity INSTEAD OF UPDATE,DELETE AS BEGIN THROW 57516,N''Integridad historica inmutable.'',1; END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0041_stage2_logistics_integrity',N'0041_stage2_logistics_integrity.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Factura positiva para despacho, evidencia con hash, auditoria transaccional; sin liquidaciones ni reentregas inferidas.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
