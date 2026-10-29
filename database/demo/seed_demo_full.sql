/*
 DEMO-2026-08.  Additive QA dataset for DistribuidoraJJ_DB_DEV only.
 It deliberately does not create users, passwords, files, catalogues or modify
 existing business rows.  Every inserted row is either named/numbered with the
 batch code or recorded in dbo.DemoSeedRows for a precise compensating rollback.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BatchCode nvarchar(30) = N'DEMO-2026-08';
DECLARE @Marker nvarchar(80) = N'DEMO-2026-08:';
DECLARE @CostaRicaToday date = DATEFROMPARTS(2026, 8, 12);

IF DB_NAME() <> N'DistribuidoraJJ_DB_DEV'
    THROW 56000, N'Este seed solo puede ejecutarse en DistribuidoraJJ_DB_DEV.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.DemoSeedBatches', N'U') IS NULL
        CREATE TABLE dbo.DemoSeedBatches
        (
            DemoSeedBatchId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DemoSeedBatches PRIMARY KEY,
            BatchCode nvarchar(30) NOT NULL CONSTRAINT UQ_DemoSeedBatches_BatchCode UNIQUE,
            AppliedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_DemoSeedBatches_AppliedAtUtc DEFAULT SYSUTCDATETIME(),
            Notes nvarchar(500) NOT NULL
        );
    IF OBJECT_ID(N'dbo.DemoSeedRows', N'U') IS NULL
        CREATE TABLE dbo.DemoSeedRows
        (
            DemoSeedRowId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DemoSeedRows PRIMARY KEY,
            BatchCode nvarchar(30) NOT NULL,
            EntityName sysname NOT NULL,
            EntityId bigint NOT NULL,
            CONSTRAINT UQ_DemoSeedRows UNIQUE(BatchCode, EntityName, EntityId),
            CONSTRAINT FK_DemoSeedRows_Batch FOREIGN KEY(BatchCode) REFERENCES dbo.DemoSeedBatches(BatchCode)
        );

    IF EXISTS (SELECT 1 FROM dbo.DemoSeedBatches WHERE BatchCode = @BatchCode)
    BEGIN
        COMMIT;
        PRINT N'DEMO-2026-08 ya fue aplicado; no se insertaron duplicados.';
        RETURN;
    END;

    /* The seed may only attach activity to expressly fictitious QA identities. */
    DECLARE @QaActorId int =
    (
        SELECT TOP (1) UsuarioId FROM dbo.Usuarios
        WHERE Activo = 1 AND (Correo LIKE N'%qa%' OR Correo LIKE N'%demo%')
        ORDER BY UsuarioId
    );
    DECLARE @QaBuyerId int =
    (
        SELECT TOP (1) u.UsuarioId FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
        WHERE u.Activo = 1 AND u.UsuarioId <> @QaActorId AND p.Nombre = N'Cliente'
          AND (u.Correo LIKE N'%qa%' OR u.Correo LIKE N'%demo%')
        ORDER BY u.UsuarioId
    );
    IF @QaActorId IS NULL OR @QaBuyerId IS NULL
        THROW 56001, N'El seed requiere un actor QA/DEMO y un cliente QA/DEMO activo con perfil Cliente; no crea ni reutiliza usuarios reales.', 1;

    DECLARE @QaActorName nvarchar(150) = (SELECT NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @QaActorId);
    DECLARE @QaBuyerName nvarchar(150) = (SELECT NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @QaBuyerId);
    DECLARE @QaBuyerEmail nvarchar(150) = (SELECT Correo FROM dbo.Usuarios WHERE UsuarioId = @QaBuyerId);

    INSERT dbo.DemoSeedBatches(BatchCode, Notes)
    VALUES(@BatchCode, N'Carga QA ficticia, aditiva y reversible. No contiene usuarios, contraseñas ni archivos físicos.');

    /* Productos, categorías lógicas e inventario.  Categoria is the actual legacy contract. */
    IF OBJECT_ID(N'dbo.Productos', N'U') IS NOT NULL
    BEGIN
        INSERT dbo.Productos(Nombre, Categoria, Descripcion, Precio, Stock, Activo)
        SELECT s.Nombre, s.Categoria, CONCAT(@Marker, N' producto ficticio QA.'), s.Precio, s.Stock, 1
        FROM (VALUES
          (N'DEMO-2026-08 Café QA 500g',N'DEMO QA Abarrotes',4250.00,80),
          (N'DEMO-2026-08 Arroz QA 2kg',N'DEMO QA Abarrotes',2100.00,95),
          (N'DEMO-2026-08 Leche QA 1L',N'DEMO QA Lácteos',1150.00,90),
          (N'DEMO-2026-08 Detergente QA',N'DEMO QA Limpieza',3350.00,75),
          (N'DEMO-2026-08 Galletas QA',N'DEMO QA Snacks',1450.00,110),
          (N'DEMO-2026-08 Jugo QA 1L',N'DEMO QA Bebidas',1800.00,100),
          (N'DEMO-2026-08 Atún QA',N'DEMO QA Abarrotes',1650.00,85),
          (N'DEMO-2026-08 Papel QA',N'DEMO QA Limpieza',2850.00,70),
          (N'DEMO-2026-08 Cereal QA',N'DEMO QA Abarrotes',2950.00,80),
          (N'DEMO-2026-08 Aceite QA 1L',N'DEMO QA Abarrotes',3600.00,65),
          (N'DEMO-2026-08 Agua QA 600ml',N'DEMO QA Bebidas',850.00,140),
          (N'DEMO-2026-08 Chocolate QA',N'DEMO QA Snacks',1250.00,120)) s(Nombre,Categoria,Precio,Stock)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.Nombre=s.Nombre);

        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId)
        SELECT @BatchCode,N'Productos',p.ProductoId FROM dbo.Productos p
        WHERE p.Nombre LIKE N'DEMO-2026-08 %' ;

        INSERT dbo.MovimientosInventario(ProductoId,ProductoNombre,TipoMovimiento,Cantidad,StockAnterior,StockNuevo,Motivo,UsuarioId,UsuarioNombre,FechaMovimiento)
        SELECT p.ProductoId,p.Nombre,N'Entrada',p.Stock,p.Stock-p.Stock,p.Stock,@Marker + N' inventario inicial QA.',@QaActorId,@QaActorName,DATEADD(HOUR,8,CAST(@CostaRicaToday AS datetime2))
        FROM dbo.Productos p
        WHERE p.Nombre LIKE N'DEMO-2026-08 %'
          AND NOT EXISTS(SELECT 1 FROM dbo.MovimientosInventario m WHERE m.ProductoId=p.ProductoId AND m.Motivo=@Marker + N' inventario inicial QA.');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId)
        SELECT @BatchCode,N'MovimientosInventario',m.MovimientoId FROM dbo.MovimientosInventario m WHERE m.Motivo=@Marker + N' inventario inicial QA.';
    END;

    DECLARE @ProductOne int=(SELECT TOP(1) ProductoId FROM dbo.Productos WHERE Nombre=N'DEMO-2026-08 Café QA 500g');
    DECLARE @ProductTwo int=(SELECT TOP(1) ProductoId FROM dbo.Productos WHERE Nombre=N'DEMO-2026-08 Arroz QA 2kg');
    DECLARE @ProductThree int=(SELECT TOP(1) ProductoId FROM dbo.Productos WHERE Nombre=N'DEMO-2026-08 Leche QA 1L');
    IF @ProductOne IS NULL OR @ProductTwo IS NULL OR @ProductThree IS NULL
        THROW 56002, N'No fue posible crear o localizar los productos QA requeridos.', 1;

    /* Crédito QA: only the designated QA buyer is touched. */
    IF OBJECT_ID(N'dbo.ClienteCreditos',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.ClienteCreditoMovimientos',N'U') IS NOT NULL
    BEGIN
        DECLARE @NewCredits table(ClienteCreditoId int NOT NULL);
        INSERT dbo.ClienteCreditos(UsuarioId,LimiteCredito,CreditoActivo,CreditoBloqueado,MotivoBloqueo)
        OUTPUT inserted.ClienteCreditoId INTO @NewCredits
        SELECT @QaBuyerId,250000.00,1,0,NULL
        WHERE NOT EXISTS(SELECT 1 FROM dbo.ClienteCreditos WHERE UsuarioId=@QaBuyerId);
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ClienteCreditos',ClienteCreditoId FROM @NewCredits;
        INSERT dbo.ClienteCreditoMovimientos(UsuarioId,TipoMovimiento,Monto,Descripcion,Referencia,RegistradoPorUsuarioId,RegistradoPorNombre,FechaMovimiento)
        SELECT @QaBuyerId,N'AjustePositivo',250000.00,@Marker + N' límite ficticio QA.',@Marker + N'CRED-001',@QaActorId,@QaActorName,DATEADD(HOUR,9,CAST(@CostaRicaToday AS datetime2))
        WHERE NOT EXISTS(SELECT 1 FROM dbo.ClienteCreditoMovimientos WHERE Referencia=@Marker + N'CRED-001');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId)
        SELECT @BatchCode,N'ClienteCreditoMovimientos',CreditoMovimientoId FROM dbo.ClienteCreditoMovimientos WHERE Referencia=@Marker + N'CRED-001';
    END;

    /* Suppliers, purchase orders, detail, reception operation and QA inventory movement. */
    IF OBJECT_ID(N'dbo.Proveedores',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.OrdenesCompra',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.DetalleOrdenCompra',N'U') IS NOT NULL
    BEGIN
        INSERT dbo.Proveedores(Nombre,Contacto,Telefono,Email,Activo)
        SELECT N'DEMO-2026-08 Proveedor QA',N'Contacto QA',N'0000-0000',N'proveedor.demo.qa@example.invalid',1
        WHERE NOT EXISTS(SELECT 1 FROM dbo.Proveedores WHERE Nombre=N'DEMO-2026-08 Proveedor QA');
        DECLARE @SupplierId int=(SELECT ProveedorId FROM dbo.Proveedores WHERE Nombre=N'DEMO-2026-08 Proveedor QA');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Proveedores',@SupplierId;
        INSERT dbo.OrdenesCompra(ProveedorId,Estado,Notas,UsuarioCreacionId,UsuarioCreacionNombre,FechaCreacionUtc,TokenOperacion,SolicitudHash)
        SELECT @SupplierId,N'Recibida',@Marker + N' compra QA.',@QaActorId,@QaActorName,DATEADD(DAY,-10,CAST(@CostaRicaToday AS datetime2)),CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000801'),HASHBYTES('SHA2_256',@Marker + N'COMPRA-001')
        WHERE NOT EXISTS(SELECT 1 FROM dbo.OrdenesCompra WHERE TokenOperacion=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000801'));
        DECLARE @PurchaseId int=(SELECT OrdenCompraId FROM dbo.OrdenesCompra WHERE TokenOperacion=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000801'));
        INSERT dbo.DetalleOrdenCompra(OrdenCompraId,ProductoId,CantidadOrdenada,CantidadRecibida,PrecioUnitario)
        SELECT @PurchaseId,v.ProductoId,20,20,v.Precio FROM (VALUES(@ProductOne,3000.00),(@ProductTwo,1500.00)) v(ProductoId,Precio)
        WHERE NOT EXISTS(SELECT 1 FROM dbo.DetalleOrdenCompra d WHERE d.OrdenCompraId=@PurchaseId AND d.ProductoId=v.ProductoId);
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'OrdenesCompra',@PurchaseId;
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'DetalleOrdenCompra',DetalleOrdenCompraId FROM dbo.DetalleOrdenCompra WHERE OrdenCompraId=@PurchaseId;
        IF OBJECT_ID(N'dbo.ComprasRecepcionOperaciones',N'U') IS NOT NULL
        BEGIN
          INSERT dbo.ComprasRecepcionOperaciones(TokenOperacion,OrdenCompraId,DetalleOrdenCompraId,CantidadRecibida,UsuarioId,UsuarioNombre)
          SELECT CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000802'),@PurchaseId,d.DetalleOrdenCompraId,20,@QaActorId,@QaActorName
          FROM dbo.DetalleOrdenCompra d WHERE d.OrdenCompraId=@PurchaseId AND d.ProductoId=@ProductOne
            AND NOT EXISTS(SELECT 1 FROM dbo.ComprasRecepcionOperaciones WHERE TokenOperacion=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000802'));
          INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ComprasRecepcionOperaciones',RecepcionOperacionId FROM dbo.ComprasRecepcionOperaciones WHERE TokenOperacion=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000802');
        END;
    END;

    /* Promotions and combo are backed by the current 0012 contracts. */
    IF OBJECT_ID(N'dbo.Promociones',N'U') IS NOT NULL
    BEGIN
        INSERT dbo.Promociones(Nombre,Descripcion,Tipo,ProductoId,CantidadMinima,PorcentajeDescuento,SegmentoCliente,FechaInicio,FechaFin,Estado,Prioridad,RegistradoPorUsuarioId,RegistradoPorNombre)
        SELECT N'DEMO-2026-08 Descuento QA',@Marker + N' promoción ficticia.',N'DescuentoPorcentual',@ProductOne,2,10.00,N'Todos',DATEADD(MONTH,-1,@CostaRicaToday),DATEADD(MONTH,1,@CostaRicaToday),N'Activa',50,@QaActorId,@QaActorName
        WHERE NOT EXISTS(SELECT 1 FROM dbo.Promociones WHERE Nombre=N'DEMO-2026-08 Descuento QA');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Promociones',PromocionId FROM dbo.Promociones WHERE Nombre=N'DEMO-2026-08 Descuento QA';
    END;
    IF OBJECT_ID(N'dbo.Combos',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.ComboDetalle',N'U') IS NOT NULL
    BEGIN
        INSERT dbo.Combos(Nombre,Descripcion,Precio,Activo,RegistradoPorUsuarioId,RegistradoPorNombre,ActualizadoPorUsuarioId,ActualizadoPorNombre)
        SELECT N'DEMO-2026-08 Combo QA',@Marker + N' combo ficticio.',4800.00,1,@QaActorId,@QaActorName,@QaActorId,@QaActorName
        WHERE NOT EXISTS(SELECT 1 FROM dbo.Combos WHERE Nombre=N'DEMO-2026-08 Combo QA');
        DECLARE @ComboId int=(SELECT ComboId FROM dbo.Combos WHERE Nombre=N'DEMO-2026-08 Combo QA');
        INSERT dbo.ComboDetalle(ComboId,ProductoId,Cantidad) SELECT @ComboId,v.ProductoId,1 FROM (VALUES(@ProductOne),(@ProductThree))v(ProductoId)
        WHERE NOT EXISTS(SELECT 1 FROM dbo.ComboDetalle d WHERE d.ComboId=@ComboId AND d.ProductoId=v.ProductoId);
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Combos',@ComboId;
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ComboDetalle',ComboDetalleId FROM dbo.ComboDetalle WHERE ComboId=@ComboId;
    END;

    /* 48 historical sales from Aug-2025 plus four Costa Rica sales on 12-Aug-2026. */
    DECLARE @Sales table(Numero int PRIMARY KEY, Fecha datetime2(0), Hora tinyint);
    INSERT @Sales(Numero,Fecha,Hora)
    SELECT n.Numero,DATEADD(DAY,n.Numero*7,CAST(DATEFROMPARTS(2025,8,12) AS datetime2)),CONVERT(tinyint,9+(n.Numero%9))
    FROM (SELECT TOP(48) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1 Numero FROM sys.all_objects) n;
    INSERT @Sales VALUES(101,DATEADD(HOUR,8,CAST(@CostaRicaToday AS datetime2)),8),(102,DATEADD(HOUR,11,CAST(@CostaRicaToday AS datetime2)),11),(103,DATEADD(HOUR,14,CAST(@CostaRicaToday AS datetime2)),14),(104,DATEADD(HOUR,18,CAST(@CostaRicaToday AS datetime2)),18);
    INSERT dbo.Pedidos(UsuarioId,FechaPedido,Estado,TipoEntrega,DireccionEntrega,Total,Observaciones)
    SELECT @QaBuyerId,DATEADD(HOUR,s.Hora,CAST(CAST(s.Fecha AS date) AS datetime2)),N'Entregado',N'Retiro',N'DEMO QA - Costa Rica',0,@Marker + RIGHT(N'000'+CONVERT(nvarchar(10),s.Numero),3)
    FROM @Sales s WHERE NOT EXISTS(SELECT 1 FROM dbo.Pedidos p WHERE p.Observaciones=@Marker + RIGHT(N'000'+CONVERT(nvarchar(10),s.Numero),3));
    INSERT dbo.PedidoDetalle(PedidoId,ProductoId,Cantidad,PrecioUnitario)
    SELECT p.PedidoId,CASE WHEN p.PedidoId%3=0 THEN @ProductThree WHEN p.PedidoId%2=0 THEN @ProductTwo ELSE @ProductOne END,1+(p.PedidoId%4),x.Precio
    FROM dbo.Pedidos p CROSS APPLY(SELECT CASE WHEN p.PedidoId%3=0 THEN 1150.00 WHEN p.PedidoId%2=0 THEN 2100.00 ELSE 4250.00 END Precio)x
    WHERE p.Observaciones LIKE @Marker + N'%' AND NOT EXISTS(SELECT 1 FROM dbo.PedidoDetalle d WHERE d.PedidoId=p.PedidoId);
    UPDATE p SET Total=(SELECT SUM(d.Cantidad*d.PrecioUnitario) FROM dbo.PedidoDetalle d WHERE d.PedidoId=p.PedidoId)
    FROM dbo.Pedidos p
    WHERE p.Observaciones LIKE @Marker + N'%';
    INSERT dbo.Facturas(PedidoId,NumeroFactura,UsuarioId,ClienteNombre,ClienteCorreo,FechaFactura,Subtotal,Impuesto,Total,Estado)
    SELECT p.PedidoId,N'DEMO-2026-08-F'+RIGHT(N'000'+CONVERT(nvarchar(10),p.PedidoId),3),@QaBuyerId,@QaBuyerName,@QaBuyerEmail,p.FechaPedido,p.Total,0,p.Total,N'Generada'
    FROM dbo.Pedidos p WHERE p.Observaciones LIKE @Marker + N'%' AND NOT EXISTS(SELECT 1 FROM dbo.Facturas f WHERE f.PedidoId=p.PedidoId);
    INSERT dbo.FacturaDetalle(FacturaId,ProductoId,ProductoNombre,Cantidad,PrecioUnitario)
    SELECT f.FacturaId,d.ProductoId,pr.Nombre,d.Cantidad,d.PrecioUnitario FROM dbo.Facturas f JOIN dbo.PedidoDetalle d ON d.PedidoId=f.PedidoId JOIN dbo.Productos pr ON pr.ProductoId=d.ProductoId
    WHERE f.NumeroFactura LIKE N'DEMO-2026-08-F%' AND NOT EXISTS(SELECT 1 FROM dbo.FacturaDetalle fd WHERE fd.FacturaId=f.FacturaId);
    INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Pedidos',PedidoId FROM dbo.Pedidos WHERE Observaciones LIKE @Marker + N'%';
    INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'PedidoDetalle',PedidoDetalleId FROM dbo.PedidoDetalle d JOIN dbo.Pedidos p ON p.PedidoId=d.PedidoId WHERE p.Observaciones LIKE @Marker + N'%';
    INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Facturas',FacturaId FROM dbo.Facturas WHERE NumeroFactura LIKE N'DEMO-2026-08-F%';
    INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'FacturaDetalle',fd.FacturaDetalleId FROM dbo.FacturaDetalle fd JOIN dbo.Facturas f ON f.FacturaId=fd.FacturaId WHERE f.NumeroFactura LIKE N'DEMO-2026-08-F%';

    /* Departmental and private chat: plaintext fictional messages, two QA participants. */
    IF OBJECT_ID(N'dbo.ChatDepartamentos',N'U') IS NOT NULL
    BEGIN
        INSERT dbo.ChatDepartamentos(Nombre,Descripcion,Activo,CreadoPorUsuarioId) SELECT N'DEMO-2026-08 Operaciones QA',@Marker + N' chat departamental ficticio.',1,@QaActorId WHERE NOT EXISTS(SELECT 1 FROM dbo.ChatDepartamentos WHERE Nombre=N'DEMO-2026-08 Operaciones QA');
        DECLARE @ChatDepartmentId int=(SELECT DepartamentoId FROM dbo.ChatDepartamentos WHERE Nombre=N'DEMO-2026-08 Operaciones QA');
        INSERT dbo.ChatDepartamentoMiembros(DepartamentoId,UsuarioId,PuedePublicar,AgregadoPorUsuarioId) SELECT @ChatDepartmentId,v.UsuarioId,1,@QaActorId FROM(VALUES(@QaActorId),(@QaBuyerId))v(UsuarioId) WHERE NOT EXISTS(SELECT 1 FROM dbo.ChatDepartamentoMiembros m WHERE m.DepartamentoId=@ChatDepartmentId AND m.UsuarioId=v.UsuarioId);
        INSERT dbo.ChatDepartamentoMensajes(DepartamentoId,RemitenteId,Contenido) SELECT @ChatDepartmentId,@QaActorId,@Marker + N' mensaje departamental QA.' WHERE NOT EXISTS(SELECT 1 FROM dbo.ChatDepartamentoMensajes WHERE DepartamentoId=@ChatDepartmentId AND Contenido=@Marker + N' mensaje departamental QA.');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ChatDepartamentos',@ChatDepartmentId;
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ChatDepartamentoMensajes',MensajeId FROM dbo.ChatDepartamentoMensajes WHERE DepartamentoId=@ChatDepartmentId AND Contenido LIKE @Marker+N'%';
    END;
    IF OBJECT_ID(N'dbo.ChatConversaciones',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.ChatMensajes',N'U') IS NOT NULL
    BEGIN
      DECLARE @ChatLower int=IIF(@QaActorId<@QaBuyerId,@QaActorId,@QaBuyerId);
      DECLARE @ChatUpper int=IIF(@QaActorId<@QaBuyerId,@QaBuyerId,@QaActorId);
      DECLARE @NewPrivateConversations table(ConversacionId int NOT NULL);
      /* The live contract stores the pair in UsuarioUnoId/UsuarioDosId; the
         normalized UsuarioMenorId/UsuarioMayorId columns are computed. */
      INSERT dbo.ChatConversaciones(UsuarioUnoId,UsuarioDosId,Activo) OUTPUT inserted.ConversacionId INTO @NewPrivateConversations SELECT @ChatLower,@ChatUpper,1
      WHERE NOT EXISTS(SELECT 1 FROM dbo.ChatConversaciones WHERE UsuarioMenorId=@ChatLower AND UsuarioMayorId=@ChatUpper);
      DECLARE @PrivateConversationId int=(SELECT ConversacionId FROM dbo.ChatConversaciones WHERE UsuarioMenorId=@ChatLower AND UsuarioMayorId=@ChatUpper);
      INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ChatConversaciones',ConversacionId FROM @NewPrivateConversations;
      INSERT dbo.ChatMensajes(ConversacionId,RemitenteId,Contenido,FechaEnvio) SELECT @PrivateConversationId,@QaActorId,@Marker+N' mensaje privado QA.',DATEADD(HOUR,10,CAST(@CostaRicaToday AS datetime2))
      WHERE NOT EXISTS(SELECT 1 FROM dbo.ChatMensajes WHERE ConversacionId=@PrivateConversationId AND Contenido=@Marker+N' mensaje privado QA.');
      INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'ChatMensajes',MensajeId FROM dbo.ChatMensajes WHERE ConversacionId=@PrivateConversationId AND Contenido LIKE @Marker+N'%';
    END;

    /* QA employee records, pending task/request and attendance. No user credentials are created or changed. */
    DECLARE @QaEmployeeId int = NULL;
    IF OBJECT_ID(N'dbo.Empleados',N'U') IS NOT NULL
    BEGIN
      DECLARE @NewEmployees table(EmpleadoId int NOT NULL);
      INSERT dbo.Empleados(UsuarioId,Puesto,Salario,FechaContratacion,Activo)
      OUTPUT inserted.EmpleadoId INTO @NewEmployees
      SELECT @QaActorId,N'Colaborador QA DEMO',200000.00,DATEFROMPARTS(2025,8,1),1 WHERE NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE UsuarioId=@QaActorId);
      SET @QaEmployeeId=(SELECT EmpleadoId FROM dbo.Empleados WHERE UsuarioId=@QaActorId);
      INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'Empleados',EmpleadoId FROM @NewEmployees;
      IF OBJECT_ID(N'dbo.EmpleadoTareas',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.EmpleadoTareas(EmpleadoId,Titulo,Descripcion,Prioridad,Estado,FechaLimite,UsuarioAsignacionId,UsuarioAsignacionNombre)
        SELECT @QaEmployeeId,N'DEMO-2026-08 Tarea QA',@Marker+N' tarea pendiente ficticia.',N'Media',N'Pendiente',DATEADD(DAY,7,@CostaRicaToday),@QaActorId,@QaActorName
        WHERE NOT EXISTS(SELECT 1 FROM dbo.EmpleadoTareas WHERE Titulo=N'DEMO-2026-08 Tarea QA');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'EmpleadoTareas',TareaId FROM dbo.EmpleadoTareas WHERE Titulo=N'DEMO-2026-08 Tarea QA';
      END;
      IF OBJECT_ID(N'dbo.EmpleadoSolicitudesTiempoLibre',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.EmpleadoSolicitudesTiempoLibre(EmpleadoId,FechaInicio,FechaFin,CantidadDias,TipoSolicitud,Motivo,Estado)
        SELECT @QaEmployeeId,DATEADD(DAY,14,@CostaRicaToday),DATEADD(DAY,14,@CostaRicaToday),1,N'Con goce salarial',@Marker+N' solicitud pendiente ficticia.',N'Pendiente'
        WHERE NOT EXISTS(SELECT 1 FROM dbo.EmpleadoSolicitudesTiempoLibre WHERE Motivo=@Marker+N' solicitud pendiente ficticia.');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'EmpleadoSolicitudesTiempoLibre',SolicitudId FROM dbo.EmpleadoSolicitudesTiempoLibre WHERE Motivo=@Marker+N' solicitud pendiente ficticia.';
      END;
      IF OBJECT_ID(N'dbo.EmpleadoJornadas',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.EmpleadoJornadas(EmpleadoId,Fecha,HorasOrdinarias,HorasExtra,HorasAusencia,Observaciones,Estado,IdempotencyKey,FechaEnvioUtc)
        SELECT @QaEmployeeId,DATEADD(DAY,-1,@CostaRicaToday),8,1,0,@Marker+N' jornada enviada QA.',N'Enviada',CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001001'),SYSUTCDATETIME()
        WHERE NOT EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001001'));
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'EmpleadoJornadas',JornadaId FROM dbo.EmpleadoJornadas WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001001');
      END;
    END;

    /* Budgets, expenses, payroll rules/period and calculation are QA-only and use no legal rates. */
    IF OBJECT_ID(N'dbo.CategoriasGasto',N'U') IS NOT NULL
    BEGIN
      INSERT dbo.CategoriasGasto(Codigo,Nombre,Activo) SELECT N'DEMO-2026-08-OPER',N'DEMO-2026-08 Operaciones QA',1 WHERE NOT EXISTS(SELECT 1 FROM dbo.CategoriasGasto WHERE Codigo=N'DEMO-2026-08-OPER');
      DECLARE @DepartmentId int=(SELECT TOP(1) DepartamentoId FROM dbo.DepartamentosOperativos WHERE Activo=1 ORDER BY DepartamentoId);
      DECLARE @ExpenseCategoryId int=(SELECT CategoriaId FROM dbo.CategoriasGasto WHERE Codigo=N'DEMO-2026-08-OPER');
      IF @DepartmentId IS NOT NULL AND OBJECT_ID(N'dbo.PresupuestosAnuales',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.PresupuestosAnuales(Anio,DepartamentoId,MontoAnual,Notas,CreadoPorUsuarioId,CreadoPorNombre)
        SELECT 2026,@DepartmentId,1200000.00,@Marker + N' presupuesto QA.',@QaActorId,@QaActorName WHERE NOT EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales WHERE Notas=@Marker+N' presupuesto QA.');
        DECLARE @BudgetId int=(SELECT PresupuestoId FROM dbo.PresupuestosAnuales WHERE Notas=@Marker+N' presupuesto QA.');
        ;WITH m AS(SELECT 1 n UNION ALL SELECT n+1 FROM m WHERE n<12) INSERT dbo.PresupuestoDetalles(PresupuestoId,CategoriaId,Mes,MontoAsignado,Notas) SELECT @BudgetId,@ExpenseCategoryId,n,100000.00,@Marker+N' línea QA.' FROM m WHERE NOT EXISTS(SELECT 1 FROM dbo.PresupuestoDetalles d WHERE d.PresupuestoId=@BudgetId AND d.CategoriaId=@ExpenseCategoryId AND d.Mes=m.n);
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'PresupuestosAnuales',@BudgetId;
      END;
      IF @DepartmentId IS NOT NULL AND OBJECT_ID(N'dbo.GastosOperativos',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.GastosOperativos(FechaGasto,DepartamentoId,CategoriaId,Proveedor,NumeroDocumento,TipoDocumento,Descripcion,Subtotal,Impuesto,Total,MetodoPago,Moneda,Estado,TokenOperacion,CreadoPorUsuarioId,CreadoPorNombre,ActualizadoPorUsuarioId,ActualizadoPorNombre)
        SELECT @CostaRicaToday,@DepartmentId,@ExpenseCategoryId,N'DEMO-2026-08 Proveedor QA',N'DEMO-2026-08-GASTO-001',N'QA',@Marker+N' gasto ficticio.',5000.00,0,5000.00,N'QA',N'CRC',N'Registrado',CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000000901'),@QaActorId,@QaActorName,@QaActorId,@QaActorName WHERE NOT EXISTS(SELECT 1 FROM dbo.GastosOperativos WHERE NumeroDocumento=N'DEMO-2026-08-GASTO-001');
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'GastosOperativos',GastoId FROM dbo.GastosOperativos WHERE NumeroDocumento=N'DEMO-2026-08-GASTO-001';
      END;
    END;
    IF OBJECT_ID(N'dbo.PlanillaReglas',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.PlanillaPeriodos',N'U') IS NOT NULL
    BEGIN
      INSERT dbo.PlanillaReglas(Codigo,Nombre,Tipo,TipoCalculo,Valor,Tope,VigenteDesde,VigenteHasta,Fuente,ActorUsuarioId,ActorNombre)
      SELECT N'DEMO_2026_08_BONO',N'Bono QA ficticio',N'Ingreso',N'MontoFijo',1000.00,NULL,@CostaRicaToday,NULL,@Marker+N' valor QA, no tasa legal.',@QaActorId,@QaActorName WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaReglas WHERE Codigo=N'DEMO_2026_08_BONO' AND VigenteDesde=@CostaRicaToday);
      INSERT dbo.PlanillaPeriodos(Tipo,Desde,Hasta,FactorSalario,FuenteConfiguracion,Estado,ActorUsuarioId,ActorNombre)
      SELECT N'Quincenal',DATEFROMPARTS(2026,8,1),@CostaRicaToday,0.500000,@Marker+N' periodo QA ficticio.',N'Abierto',@QaActorId,@QaActorName WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaPeriodos WHERE Desde=DATEFROMPARTS(2026,8,1) AND Hasta=@CostaRicaToday);
      INSERT dbo.PlanillaPeriodos(Tipo,Desde,Hasta,FactorSalario,FuenteConfiguracion,Estado,ActorUsuarioId,ActorNombre)
      SELECT source.Tipo,source.Desde,source.Hasta,source.Factor,@Marker+N' periodo QA ficticio.',N'Cerrado',@QaActorId,@QaActorName
      FROM (VALUES (N'Quincenal',DATEFROMPARTS(2026,6,1),DATEFROMPARTS(2026,6,15),CONVERT(decimal(9,6),0.500000)),(N'Quincenal',DATEFROMPARTS(2026,7,1),DATEFROMPARTS(2026,7,15),CONVERT(decimal(9,6),0.500000))) source(Tipo,Desde,Hasta,Factor)
      WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaPeriodos p WHERE p.Desde=source.Desde AND p.Hasta=source.Hasta);
      INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'PlanillaReglas',ReglaId FROM dbo.PlanillaReglas WHERE Codigo=N'DEMO_2026_08_BONO' AND VigenteDesde=@CostaRicaToday;
      INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId)
      SELECT @BatchCode,N'PlanillaPeriodos',PeriodoId FROM dbo.PlanillaPeriodos
      WHERE (Desde=DATEFROMPARTS(2026,8,1) AND Hasta=@CostaRicaToday)
         OR (Desde=DATEFROMPARTS(2026,6,1) AND Hasta=DATEFROMPARTS(2026,6,15))
         OR (Desde=DATEFROMPARTS(2026,7,1) AND Hasta=DATEFROMPARTS(2026,7,15));
      DECLARE @QaPeriodId int=(SELECT PeriodoId FROM dbo.PlanillaPeriodos WHERE Desde=DATEFROMPARTS(2026,8,1) AND Hasta=@CostaRicaToday);
      IF @QaEmployeeId IS NOT NULL AND OBJECT_ID(N'dbo.PlanillaCalculos',N'U') IS NOT NULL
      BEGIN
        INSERT dbo.PlanillaCalculos(PeriodoId,EmpleadoId,SalarioBase,HorasOrdinarias,HorasExtra,Comisiones,TotalIngresos,TotalDeducciones,TotalBruto,TotalNeto,ReglasSnapshotJson,Fingerprint,IdempotencyKey,Estado,CalculadoPorUsuarioId,CalculadoPorNombre)
        SELECT @QaPeriodId,@QaEmployeeId,100000.00,80,0,0,101000.00,0,101000.00,101000.00,N'{"source":"DEMO-2026-08","legalRates":false}',HASHBYTES('SHA2_256',@Marker+N'PLANILLA-001'),CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001101'),N'Borrador',@QaActorId,@QaActorName
        WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001101'));
        DECLARE @QaCalculationId bigint=(SELECT CalculoId FROM dbo.PlanillaCalculos WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001101'));
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'PlanillaCalculos',@QaCalculationId;
        DECLARE @QaApprovedPeriodId int=(SELECT PeriodoId FROM dbo.PlanillaPeriodos WHERE Desde=DATEFROMPARTS(2026,6,1) AND Hasta=DATEFROMPARTS(2026,6,15));
        DECLARE @QaPaidPeriodId int=(SELECT PeriodoId FROM dbo.PlanillaPeriodos WHERE Desde=DATEFROMPARTS(2026,7,1) AND Hasta=DATEFROMPARTS(2026,7,15));
        INSERT dbo.PlanillaCalculos(PeriodoId,EmpleadoId,SalarioBase,HorasOrdinarias,HorasExtra,Comisiones,TotalIngresos,TotalDeducciones,TotalBruto,TotalNeto,ReglasSnapshotJson,Fingerprint,IdempotencyKey,Estado,CalculadoPorUsuarioId,CalculadoPorNombre,AprobadoPorUsuarioId,AprobadoPorNombre,FechaAprobacionUtc)
        SELECT @QaApprovedPeriodId,@QaEmployeeId,100000.00,80,0,0,101000.00,0,101000.00,101000.00,N'{"source":"DEMO-2026-08","legalRates":false}',HASHBYTES('SHA2_256',@Marker+N'PLANILLA-002'),CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001102'),N'Aprobada',@QaActorId,@QaActorName,@QaBuyerId,@QaBuyerName,DATEADD(DAY,-50,CAST(@CostaRicaToday AS datetime2))
        WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001102'));
        INSERT dbo.PlanillaCalculos(PeriodoId,EmpleadoId,SalarioBase,HorasOrdinarias,HorasExtra,Comisiones,TotalIngresos,TotalDeducciones,TotalBruto,TotalNeto,ReglasSnapshotJson,Fingerprint,IdempotencyKey,Estado,CalculadoPorUsuarioId,CalculadoPorNombre,AprobadoPorUsuarioId,AprobadoPorNombre,PagadoPorUsuarioId,PagadoPorNombre,FechaAprobacionUtc,FechaPagoUtc)
        SELECT @QaPaidPeriodId,@QaEmployeeId,100000.00,80,0,0,101000.00,0,101000.00,101000.00,N'{"source":"DEMO-2026-08","legalRates":false}',HASHBYTES('SHA2_256',@Marker+N'PLANILLA-003'),CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001103'),N'Pagada',@QaActorId,@QaActorName,@QaBuyerId,@QaBuyerName,@QaBuyerId,@QaBuyerName,DATEADD(DAY,-35,CAST(@CostaRicaToday AS datetime2)),DATEADD(DAY,-34,CAST(@CostaRicaToday AS datetime2))
        WHERE NOT EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WHERE IdempotencyKey=CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001103'));
        INSERT dbo.DemoSeedRows(BatchCode,EntityName,EntityId) SELECT @BatchCode,N'PlanillaCalculos',CalculoId FROM dbo.PlanillaCalculos WHERE IdempotencyKey IN(CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001102'),CONVERT(uniqueidentifier,'4AB3E2D1-9AC4-4DD4-A451-000000001103'));
      END;
    END;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;

SELECT EntityName,COUNT(*) AS RegistrosInsertados FROM dbo.DemoSeedRows WHERE BatchCode=@BatchCode GROUP BY EntityName ORDER BY EntityName;
