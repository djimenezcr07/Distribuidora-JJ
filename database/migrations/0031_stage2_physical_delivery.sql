SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0030_stage2_authorization_invalidation' AND Status=N'Applied')
    THROW 56320,N'Falta la invalidacion de autorizacion 0030.',1;
IF OBJECT_ID(N'dbo.EntregaSyncLog',N'U') IS NULL OR OBJECT_ID(N'dbo.RutaPedidos',N'U') IS NULL
    OR OBJECT_ID(N'dbo.sp_Chofer_UpdateDeliveryStatus',N'P') IS NULL
    THROW 56321,N'Falta el contrato logistico existente.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 56322,N'Hash invalido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0031_stage2_physical_delivery')
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0031_stage2_physical_delivery' AND FileSha256=UPPER(@Hash) AND Status=N'Applied')
        THROW 56323,N'Conflicto de hash de 0031.',1;
    RETURN;
END;
IF OBJECT_ID(N'dbo.Stage2PhysicalDeliveries') IS NOT NULL
    THROW 56324,N'Existe evidencia sin ledger acreditado.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock int;
    EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0031:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 56325,N'No se obtuvo bloqueo de instalacion.',1;
    CREATE TABLE dbo.Stage2PhysicalDeliveries
    (
        PedidoId int NOT NULL CONSTRAINT PK_Stage2PhysicalDeliveries PRIMARY KEY REFERENCES dbo.Pedidos(PedidoId),
        RutaPedidoId int NOT NULL CONSTRAINT UQ_Stage2PhysicalDeliveries_Route UNIQUE REFERENCES dbo.RutaPedidos(RutaPedidoId),
        EntregaSyncLogId int NOT NULL CONSTRAINT UQ_Stage2PhysicalDeliveries_Sync UNIQUE REFERENCES dbo.EntregaSyncLog(EntregaSyncLogId),
        ChoferUsuarioId int NOT NULL REFERENCES dbo.Usuarios(UsuarioId),
        ConfirmadoUtc datetime2(7) NOT NULL
    );
    -- No historical backfill: billing and pre-existing status values are not physical proof.
    EXEC(N'CREATE TRIGGER dbo.tr_Stage2PhysicalDeliveries_Immutable ON dbo.Stage2PhysicalDeliveries
        INSTEAD OF UPDATE,DELETE AS BEGIN THROW 56326,N''La evidencia fisica es inmutable.'',1; END;');
    EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Chofer_UpdateDeliveryStatus
        @RutaPedidoId int,
        @NuevoEstado nvarchar(20),
        @SyncGuid uniqueidentifier,
        @MotivoFallo nvarchar(300)=NULL,
        @ChoferUsuarioId int,
        @ChoferNombre nvarchar(150)=NULL,
        @ExpectedSecurityStamp uniqueidentifier=NULL
    AS
    BEGIN
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
    INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
    VALUES(N'0031_stage2_physical_delivery',N'0031_stage2_physical_delivery.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),
           N'Confirmacion fisica explicita, contexto vigente e idempotencia ligada a actor/recurso/contenido; sin backfill.');
    COMMIT TRANSACTION;
END TRY BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
