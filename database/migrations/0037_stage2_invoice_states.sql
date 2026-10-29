SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57010,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57011,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0037_stage2_invoice_states')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0037_stage2_invoice_states' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57012,N'Conflicto de ledger 0037.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0036_stage2_transactional_login' AND Status=N'Applied' AND FileSha256=N'98816A77160064B6B86579A25C9A6B41962197C60E38FE32FE2BAC58A7C02FDC') THROW 57013,N'Falta prerequisito 0036 acreditado.',1;
IF OBJECT_ID(N'dbo.sp_Stage2_GenerateInvoiceFromOrder') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_UpdateOrderStatus') IS NOT NULL THROW 57014,N'Existe contrato versionado sin ledger acreditado.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Admin_GenerateInvoiceFromOrder') AND CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),definition)),2)=N'E47B9E7AC1E3FBDD6896ABEECCFB0BC02BCAE6E2B513F284713EDC72C62D5D10')
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.sp_Inventory_RestoreOrderStock') AND CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),definition)),2)=N'A704D9C44B65550EC17FF729F5BC2D5478C1739F04DEC85D4A59FF83E731808F') THROW 57015,N'Contrato instalado distinto del acreditado.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0037:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57016,N'Instalacion concurrente.',1;
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_GenerateInvoiceFromOrder
    @PedidoId INT,
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @PedidoId <= 0 THROW 50901, N''El pedido indicado no es válido.'', 1;

    IF @@TRANCOUNT=0 THROW 57000,N''Falta transaccion de login original.'',1;
    DECLARE @InventarioDescontado bit,@ActorNombre nvarchar(150),@ActorCorreo nvarchar(256),@ActorRol nvarchar(100);
    SELECT @ActorNombre=u.NombreCompleto,@ActorCorreo=u.Correo,@ActorRol=p.Nombre FROM dbo.Usuarios u JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId WHERE u.UsuarioId=@UsuarioId AND u.Activo=1 AND p.Activo=1;
    IF @ActorNombre IS NULL THROW 57001,N''Actor no acreditado.'',1;
    DECLARE @PedidoUsuarioId INT;
    DECLARE @Estado NVARCHAR(30);
    DECLARE @ClienteNombre NVARCHAR(150);
    DECLARE @ClienteCorreo NVARCHAR(150);
    DECLARE @Subtotal DECIMAL(18,2);
    DECLARE @Impuesto DECIMAL(18,2);
    DECLARE @Total DECIMAL(18,2);
    DECLARE @FacturaId INT;
    DECLARE @NumeroFactura NVARCHAR(30);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @PedidoUsuarioId = orders.UsuarioId,
               @Estado = orders.Estado, @InventarioDescontado=orders.InventarioDescontado,
               @ClienteNombre = userAccount.NombreCompleto,
               @ClienteCorreo = userAccount.Correo
        FROM dbo.Pedidos orders WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = orders.UsuarioId
        WHERE orders.PedidoId = @PedidoId;
        IF @PedidoUsuarioId IS NULL THROW 50902, N''No se encontró el pedido solicitado.'', 1;
        SELECT @FacturaId=FacturaId,@NumeroFactura=NumeroFactura FROM dbo.Facturas WITH(UPDLOCK,HOLDLOCK)
         WHERE PedidoId=@PedidoId AND UsuarioId=@PedidoUsuarioId;
        IF @FacturaId IS NOT NULL
        BEGIN
         COMMIT TRANSACTION;
         SELECT @FacturaId AS FacturaId,@PedidoId AS PedidoId,@NumeroFactura AS NumeroFactura,@Estado AS EstadoPedido;
         RETURN;
        END;
        IF @Estado NOT IN(N''Pendiente'',N''Aprobado'',N''EnProceso'',N''Liberado'')
         THROW 57002,N''Estado no habilitado para facturacion; no se acredita aprobacion ni entrega historica.'',1;
        IF ISNULL(@InventarioDescontado,0)<>1
         THROW 57003,N''Inventario del pedido no acreditado; requiere reconciliacion.'',1;
        IF NOT EXISTS
           (
               SELECT 1
               FROM dbo.PedidoDetalle
               WHERE PedidoId = @PedidoId
                 AND PedidoComboId IS NULL
           )
           AND NOT EXISTS (SELECT 1 FROM dbo.PedidoCombos WHERE PedidoId = @PedidoId)
            THROW 50905, N''El pedido no tiene líneas para facturar.'', 1;

        SELECT @Subtotal =
            ISNULL((SELECT SUM(detail.Cantidad * detail.PrecioUnitario)
                    FROM dbo.PedidoDetalle detail WITH(HOLDLOCK)
                    WHERE detail.PedidoId = @PedidoId
                      AND detail.PedidoComboId IS NULL), 0)
            + ISNULL((SELECT SUM(combo.Cantidad * combo.PrecioUnitario)
                      FROM dbo.PedidoCombos combo WITH(HOLDLOCK) WHERE combo.PedidoId = @PedidoId), 0);
        SET @Impuesto = ROUND(@Subtotal * 0.13, 2);
        SET @Total = @Subtotal + @Impuesto;
        IF @Subtotal<0 OR @Total>2000000 THROW 57004,N''Aprobacion supervisora no acreditada para este importe.'',1;
        UPDATE dbo.Pedidos SET Estado=N''Liberado'',FechaActualizacion=SYSDATETIME() WHERE PedidoId=@PedidoId;
        INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
        VALUES(@UsuarioId,@ActorNombre,@ActorCorreo,@ActorRol,N''Liberar pedido'',N''Pedidos'',CONCAT(N''Pedido #'',@PedidoId,N'': Liberado para facturacion; total final dentro del umbral.''));
        SET @NumeroFactura=CONCAT(N''FAC-S2-'',CONVERT(nvarchar(10),@PedidoId));

        INSERT INTO dbo.Facturas
            (PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo,
             Subtotal, Impuesto, Total, Estado)
        VALUES
            (@PedidoId, @NumeroFactura, @PedidoUsuarioId, @ClienteNombre, @ClienteCorreo,
             @Subtotal, @Impuesto, @Total, N''Generada'');
        SET @FacturaId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.FacturaDetalle
            (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
        SELECT @FacturaId,
               detail.ProductoId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre),
               detail.Cantidad,
               detail.PrecioUnitario
        FROM dbo.PedidoDetalle detail WITH(HOLDLOCK)
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.PedidoComboId IS NULL;
        INSERT INTO dbo.FacturaCombos
            (FacturaId, PedidoComboId, ComboNombreSnapshot, Cantidad, PrecioUnitario)
        SELECT @FacturaId, combo.PedidoComboId, combo.ComboNombreSnapshot, combo.Cantidad, combo.PrecioUnitario
        FROM dbo.PedidoCombos combo WITH(HOLDLOCK)
        WHERE combo.PedidoId = @PedidoId;

        UPDATE dbo.Pedidos SET Estado = N''Facturado'', Total=@Total, FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;
        INSERT dbo.AuditoriaSistema(UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Accion,Modulo,Descripcion)
        VALUES(@UsuarioId,@ActorNombre,@ActorCorreo,@ActorRol,N''Generar factura'',N''Facturacion'',CONCAT(N''Pedido #'',@PedidoId,N'': Facturado; factura #'',@FacturaId,N''. No acredita entrega fisica.''));
        COMMIT TRANSACTION;

        SELECT @FacturaId AS FacturaId,
               @PedidoId AS PedidoId,
               @NumeroFactura AS NumeroFactura,
               N''Facturado'' AS EstadoPedido;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_UpdateOrderStatus
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
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0037_stage2_invoice_states',N'0037_stage2_invoice_states.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Contratos versionados de facturacion y estado manual; no backfill, no entregas inferidas ni relaciones comerciales.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;