SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57210,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57211,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0039_stage2_aggregate_amounts_v2')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0039_stage2_aggregate_amounts_v2' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57212,N'Conflicto de ledger 0039.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0038_stage2_checkout_intent_owner' AND Status=N'Applied' AND FileSha256=N'B3FF29FF1DA8D05FA29DA944E1FDA688670B48D49A389CC462F7BF24DCF6C8BD') THROW 57213,N'Falta prerequisito 0038 acreditado.',1;
IF OBJECT_ID(N'dbo.Stage2OrderAmounts') IS NOT NULL OR OBJECT_ID(N'dbo.Stage2OrderAmountLines') IS NOT NULL OR OBJECT_ID(N'dbo.sp_Stage2_CreateOrderAmountsV2') IS NOT NULL THROW 57214,N'Objetos previos sin ledger.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0039:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57215,N'Instalacion concurrente.',1;
 CREATE TABLE dbo.Stage2OrderAmounts(
  PedidoId int NOT NULL PRIMARY KEY REFERENCES dbo.Pedidos(PedidoId),ContractVersion int NOT NULL CHECK(ContractVersion=2),
  Bruto decimal(18,2) NOT NULL,Descuento decimal(18,2) NOT NULL,Neto decimal(18,2) NOT NULL,Impuesto decimal(18,2) NOT NULL,TotalFinal decimal(18,2) NOT NULL,
  CONSTRAINT CK_Stage2OrderAmounts CHECK(Bruto>=0 AND Descuento>=0 AND Descuento<=Bruto AND Neto=Bruto-Descuento AND Impuesto=ROUND(Neto*CONVERT(decimal(4,2),0.13),2) AND TotalFinal=Neto+Impuesto));
 CREATE TABLE dbo.Stage2OrderAmountLines(
  PedidoId int NOT NULL REFERENCES dbo.Pedidos(PedidoId),LineKind nvarchar(10) NOT NULL,LineId int NOT NULL,ProductoId int NULL REFERENCES dbo.Productos(ProductoId),
  Cantidad int NOT NULL,PrecioBruto decimal(18,2) NOT NULL,Bruto decimal(18,2) NOT NULL,Descuento decimal(18,2) NOT NULL,Neto decimal(18,2) NOT NULL,
  PRIMARY KEY(PedidoId,LineKind,LineId),
  CONSTRAINT CK_Stage2OrderAmountLines CHECK(Cantidad>0 AND PrecioBruto>=0 AND Bruto=CONVERT(decimal(18,2),Cantidad*PrecioBruto) AND Descuento>=0 AND Descuento<=Bruto AND Neto=Bruto-Descuento AND ((LineKind=N'Producto' AND ProductoId IS NOT NULL) OR (LineKind=N'Combo' AND ProductoId IS NULL))));
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_CreateOrderAmountsV2
    @UsuarioId INT,
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX),
    @MetodoPago NVARCHAR(40) = N''Efectivo contra entrega'',
    @ReferenciaPago NVARCHAR(80) = NULL,
    @TokenOperacion UNIQUEIDENTIFIER,
    @OriginalLoginId uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT=0 THROW 57200,N''Falta transaccion de login original.'',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Stage2CheckoutIntentOwners i WITH(UPDLOCK,HOLDLOCK)
      JOIN dbo.Stage2OriginalLogins l WITH(UPDLOCK,HOLDLOCK) ON l.LoginId=i.LoginId
      JOIN dbo.Usuarios u ON u.UsuarioId=l.UsuarioId AND u.SecurityStamp=l.SecurityStamp AND u.PerfilId=l.PerfilId AND u.Activo=1
      JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId AND p.Activo=1
      WHERE i.OperationId=@TokenOperacion AND i.LoginId=@OriginalLoginId AND i.UsuarioId=@UsuarioId
        AND l.RevokedUtc IS NULL AND l.ExpiresUtc>SYSUTCDATETIME())
      THROW 57201,N''Propietario original no acreditado.'',1;
    SET @TipoEntrega = NULLIF(LTRIM(RTRIM(@TipoEntrega)), N'''');
    SET @DireccionEntrega = NULLIF(LTRIM(RTRIM(@DireccionEntrega)), N'''');
    SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), N'''');
    SET @IdentificacionCliente = NULLIF(LTRIM(RTRIM(@IdentificacionCliente)), N'''');
    SET @MetodoPago = COALESCE(NULLIF(LTRIM(RTRIM(@MetodoPago)), N''''), N''Efectivo contra entrega'');
    SET @ReferenciaPago = NULLIF(LTRIM(RTRIM(@ReferenciaPago)), N'''');

    IF @UsuarioId <= 0 OR @TokenOperacion IS NULL
        THROW 54601, N''El usuario o el identificador de checkout no es válido.'', 1;
    IF @TipoEntrega IS NULL
        THROW 54602, N''El tipo de entrega es obligatorio.'', 1;
    IF @MetodoPago NOT IN
       (N''Efectivo contra entrega'', N''SINPE Móvil simulado'', N''Tarjeta demo'', N''Transferencia simulada'')
        THROW 54603, N''El método de pago no es válido.'', 1;
    IF ISJSON(@ItemsJson) <> 1
        THROW 54604, N''El carrito no tiene un formato válido.'', 1;

    DECLARE @Items TABLE
    (
        Tipo NVARCHAR(20) NOT NULL,
        ItemId INT NOT NULL,
        ProductoId INT NULL,
        ComboId INT NULL,
        Cantidad INT NOT NULL,
        PRIMARY KEY (Tipo, ItemId)
    );

    IF EXISTS
    (
        SELECT 1
        FROM OPENJSON(@ItemsJson)
        WITH
        (
            Tipo NVARCHAR(20) N''$.tipo'',
            ProductoId INT N''$.productoId'',
            ComboId INT N''$.comboId'',
            Cantidad INT N''$.cantidad''
        ) source
        WHERE source.Tipo IS NULL OR source.Tipo NOT IN (N''Producto'', N''Combo'')
           OR source.Cantidad IS NULL OR source.Cantidad NOT BETWEEN 1 AND 999
           OR (source.Tipo = N''Producto'' AND (source.ProductoId IS NULL OR source.ProductoId <= 0 OR source.ComboId IS NOT NULL))
           OR (source.Tipo = N''Combo'' AND (source.ComboId IS NULL OR source.ComboId <= 0 OR source.ProductoId IS NOT NULL))
    )
        THROW 54605, N''El carrito contiene una línea no válida.'', 1;

    INSERT INTO @Items (Tipo, ItemId, ProductoId, ComboId, Cantidad)
    SELECT source.Tipo,
           IIF(source.Tipo = N''Producto'', source.ProductoId, source.ComboId),
           source.ProductoId,
           source.ComboId,
           SUM(source.Cantidad)
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        Tipo NVARCHAR(20) N''$.tipo'',
        ProductoId INT N''$.productoId'',
        ComboId INT N''$.comboId'',
        Cantidad INT N''$.cantidad''
    ) source
    GROUP BY source.Tipo, source.ProductoId, source.ComboId;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 54606, N''El carrito está vacío.'', 1;
    IF EXISTS (SELECT 1 FROM @Items WHERE Cantidad NOT BETWEEN 1 AND 999)
        THROW 54607, N''La cantidad acumulada de una línea no es válida.'', 1;

    DECLARE @CanonicalItems NVARCHAR(MAX);
    DECLARE @SolicitudHash BINARY(32);
    SELECT @CanonicalItems =
    (
        SELECT Tipo AS tipo,
               ProductoId AS productoId,
               ComboId AS comboId,
               Cantidad AS cantidad
        FROM @Items
        ORDER BY Tipo, ProductoId, ComboId
        FOR JSON PATH
    );
    SET @SolicitudHash = HASHBYTES
    (
        N''SHA2_256'',
        CONCAT(@UsuarioId, N''|'', @TipoEntrega, N''|'', COALESCE(@DireccionEntrega, N''''), N''|'',
               COALESCE(@Observaciones, N''''), N''|'', COALESCE(@IdentificacionCliente, N''''), N''|'',
               @MetodoPago, N''|'', COALESCE(@ReferenciaPago, N''''), N''|'', @CanonicalItems)
    );

    DECLARE @PedidoId INT;
    DECLARE @ExistingPedidoId INT;
    DECLARE @ExistingHash BINARY(32);
    DECLARE @NombreUsuario NVARCHAR(150);
    DECLARE @Segmento NVARCHAR(20);
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(255) = CONCAT(N''checkout:'', @UsuarioId, N'':'', CONVERT(NVARCHAR(36), @TokenOperacion));

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 54608, N''No fue posible reservar el intento de checkout. Intente nuevamente.'', 1;

        SELECT @ExistingPedidoId = operation.PedidoId,
               @ExistingHash = operation.SolicitudHash
        FROM dbo.CheckoutOperaciones operation WITH (UPDLOCK, HOLDLOCK)
        WHERE operation.UsuarioId = @UsuarioId
          AND operation.TokenOperacion = @TokenOperacion;

        IF @ExistingPedidoId IS NOT NULL
        BEGIN
            IF @ExistingHash <> @SolicitudHash
                THROW 54609, N''El identificador de checkout ya fue utilizado con otra solicitud.'', 1;

            COMMIT TRANSACTION;
            EXEC dbo.sp_Stage2_GetCheckoutAmountsV2 @PedidoId = @ExistingPedidoId, @UsuarioId = @UsuarioId;
            RETURN;
        END;

        SELECT @NombreUsuario = userAccount.NombreCompleto,
               @Segmento = ISNULL(NULLIF(userAccount.SegmentoCliente, N''''), N''Minorista'')
        FROM dbo.Usuarios userAccount WITH (UPDLOCK, HOLDLOCK)
        WHERE userAccount.UsuarioId = @UsuarioId AND userAccount.Activo = 1;
        IF @NombreUsuario IS NULL
            THROW 54610, N''El usuario del pedido no está disponible.'', 1;

        DECLARE @CartCombos TABLE
        (
            ComboId INT NOT NULL PRIMARY KEY,
            Cantidad INT NOT NULL,
            Nombre NVARCHAR(150) NOT NULL,
            Descripcion NVARCHAR(500) NULL,
            Precio DECIMAL(18,2) NOT NULL
        );
        INSERT INTO @CartCombos (ComboId, Cantidad, Nombre, Descripcion, Precio)
        SELECT combo.ComboId, item.Cantidad, combo.Nombre, combo.Descripcion, combo.Precio
        FROM @Items item
        INNER JOIN dbo.Combos combo WITH (UPDLOCK, HOLDLOCK)
            ON combo.ComboId = item.ComboId AND combo.Activo = 1
        WHERE item.Tipo = N''Combo'';
        IF (SELECT COUNT(*) FROM @CartCombos) <> (SELECT COUNT(*) FROM @Items WHERE Tipo = N''Combo'')
            THROW 54611, N''Uno o más combos no están disponibles.'', 1;
        IF EXISTS
        (
            SELECT 1
            FROM @CartCombos cart
            WHERE NOT EXISTS (SELECT 1 FROM dbo.ComboDetalle detail WHERE detail.ComboId = cart.ComboId)
        )
            THROW 54612, N''Uno o más combos no tienen componentes.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @CartCombos cart
            CROSS APPLY
            (
                SELECT COUNT(detail.ComboDetalleId) AS CantidadComponentes,
                       SUM(CASE WHEN product.ProductoId IS NOT NULL
                                     AND product.Activo = 1
                                     AND detail.Cantidad > 0 THEN 1 ELSE 0 END) AS CantidadComponentesValidos
                FROM dbo.ComboDetalle detail
                LEFT JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
                WHERE detail.ComboId = cart.ComboId
            ) availability
            WHERE availability.CantidadComponentes = 0
               OR availability.CantidadComponentesValidos <> availability.CantidadComponentes
        )
            THROW 54612, N''Uno o más combos tienen componentes inactivos o inválidos.'', 1;

        DECLARE @Candidates TABLE
        (
            PromocionId INT NOT NULL,
            ProductoId INT NOT NULL,
            Tipo NVARCHAR(25) NOT NULL,
            PorcentajeDescuento DECIMAL(5,2) NULL,
            ProductoRegaloId INT NULL,
            CantidadRegalo INT NULL,
            CantidadMinima INT NOT NULL,
            Prioridad INT NOT NULL,
            CantidadComprada INT NOT NULL,
            PRIMARY KEY (PromocionId, ProductoId)
        );
        ;WITH Ranked AS
        (
            SELECT promotion.PromocionId,
                   promotion.ProductoId,
                   promotion.Tipo,
                   promotion.PorcentajeDescuento,
                   promotion.ProductoRegaloId,
                   promotion.CantidadRegalo,
                   promotion.CantidadMinima,
                   promotion.Prioridad,
                   item.Cantidad AS CantidadComprada,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY promotion.ProductoId
                       ORDER BY promotion.Prioridad DESC, promotion.PromocionId
                   ) AS Position
            FROM @Items item
            INNER JOIN dbo.Promociones promotion WITH (UPDLOCK, HOLDLOCK)
                ON promotion.ProductoId = item.ProductoId
            WHERE item.Tipo = N''Producto''
              AND item.Cantidad >= promotion.CantidadMinima
              AND promotion.Estado = N''Activa''
              AND CONVERT(DATE, SYSDATETIME()) BETWEEN promotion.FechaInicio AND promotion.FechaFin
              AND promotion.SegmentoCliente IN (N''Todos'', @Segmento)
        )
        INSERT INTO @Candidates
            (PromocionId, ProductoId, Tipo, PorcentajeDescuento, ProductoRegaloId,
             CantidadRegalo, CantidadMinima, Prioridad, CantidadComprada)
        SELECT PromocionId, ProductoId, Tipo, PorcentajeDescuento, ProductoRegaloId,
               CantidadRegalo, CantidadMinima, Prioridad, CantidadComprada
        FROM Ranked
        WHERE Position = 1;

        DECLARE @Requirements TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            CantidadCarrito BIGINT NOT NULL,
            CantidadRegalo BIGINT NOT NULL DEFAULT (0)
        );
        INSERT INTO @Requirements (ProductoId, CantidadCarrito)
        SELECT source.ProductoId, SUM(CONVERT(BIGINT, source.Cantidad))
        FROM
        (
            SELECT item.ProductoId, item.Cantidad
            FROM @Items item
            WHERE item.Tipo = N''Producto''
            UNION ALL
            SELECT detail.ProductoId,
                   CONVERT(BIGINT, detail.Cantidad) * cart.Cantidad
            FROM @CartCombos cart
            INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = cart.ComboId
        ) source
        GROUP BY source.ProductoId;

        INSERT INTO @Requirements (ProductoId, CantidadCarrito)
        SELECT DISTINCT candidate.ProductoRegaloId, 0
        FROM @Candidates candidate
        WHERE candidate.Tipo = N''RegaliaPorVolumen''
          AND candidate.ProductoRegaloId IS NOT NULL
          AND NOT EXISTS
              (SELECT 1 FROM @Requirements requirement WHERE requirement.ProductoId = candidate.ProductoRegaloId);

        DECLARE @LockedProducts TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            Nombre NVARCHAR(150) NOT NULL,
            Categoria NVARCHAR(100) NOT NULL,
            Descripcion NVARCHAR(255) NULL,
            Precio DECIMAL(18,2) NOT NULL,
            Stock INT NOT NULL,
            ImagenUrl NVARCHAR(300) NULL,
            Activo BIT NOT NULL
        );
        DECLARE @LockProductId INT;
        DECLARE @LockName NVARCHAR(150);
        DECLARE @LockCategory NVARCHAR(100);
        DECLARE @LockDescription NVARCHAR(255);
        DECLARE @LockPrice DECIMAL(18,2);
        DECLARE @LockStock INT;
        DECLARE @LockImage NVARCHAR(300);
        DECLARE @LockActive BIT;
        DECLARE inventory_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ProductoId FROM @Requirements ORDER BY ProductoId;
        OPEN inventory_cursor;
        FETCH NEXT FROM inventory_cursor INTO @LockProductId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @LockName = NULL, @LockCategory = NULL, @LockDescription = NULL,
                   @LockPrice = NULL, @LockStock = NULL, @LockImage = NULL, @LockActive = NULL;
            SELECT @LockName = product.Nombre,
                   @LockCategory = product.Categoria,
                   @LockDescription = product.Descripcion,
                   @LockPrice = product.Precio,
                   @LockStock = product.Stock,
                   @LockImage = product.ImagenUrl,
                   @LockActive = product.Activo
            FROM dbo.Productos product WITH (UPDLOCK, HOLDLOCK)
            WHERE product.ProductoId = @LockProductId;
            IF @LockName IS NOT NULL
            BEGIN
                INSERT INTO @LockedProducts
                    (ProductoId, Nombre, Categoria, Descripcion, Precio, Stock, ImagenUrl, Activo)
                VALUES
                    (@LockProductId, @LockName, @LockCategory, @LockDescription,
                     @LockPrice, @LockStock, @LockImage, @LockActive);
            END;
            FETCH NEXT FROM inventory_cursor INTO @LockProductId;
        END;
        CLOSE inventory_cursor;
        DEALLOCATE inventory_cursor;

        IF EXISTS
        (
            SELECT 1
            FROM @Requirements requirement
            LEFT JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
            WHERE requirement.CantidadCarrito > 0
              AND (product.ProductoId IS NULL OR product.Activo = 0)
        )
            THROW 54613, N''Uno o más productos o componentes no están disponibles.'', 1;

        DECLARE @CartProducts TABLE
        (
            ProductoId INT NOT NULL PRIMARY KEY,
            Cantidad INT NOT NULL,
            Nombre NVARCHAR(150) NOT NULL,
            Categoria NVARCHAR(100) NOT NULL,
            Descripcion NVARCHAR(255) NULL,
            Precio DECIMAL(18,2) NOT NULL,
            ImagenUrl NVARCHAR(300) NULL
        );
        INSERT INTO @CartProducts
            (ProductoId, Cantidad, Nombre, Categoria, Descripcion, Precio, ImagenUrl)
        SELECT item.ProductoId, item.Cantidad, product.Nombre, product.Categoria,
               product.Descripcion, product.Precio, product.ImagenUrl
        FROM @Items item
        INNER JOIN @LockedProducts product ON product.ProductoId = item.ProductoId AND product.Activo = 1
        WHERE item.Tipo = N''Producto'';
        IF (SELECT COUNT(*) FROM @CartProducts) <> (SELECT COUNT(*) FROM @Items WHERE Tipo = N''Producto'')
            THROW 54614, N''Uno o más productos no están disponibles.'', 1;

        DECLARE @Applications TABLE
        (
            PromocionId INT NOT NULL,
            ProductoId INT NOT NULL,
            TipoBeneficio NVARCHAR(20) NOT NULL,
            MontoDescontado DECIMAL(18,2) NULL,
            UnidadesRegalo INT NULL,
            ProductoRegaloId INT NULL,
            Prioridad INT NOT NULL,
            PRIMARY KEY (PromocionId, ProductoId)
        );
        INSERT INTO @Applications
            (PromocionId, ProductoId, TipoBeneficio, MontoDescontado,
             UnidadesRegalo, ProductoRegaloId, Prioridad)
        SELECT candidate.PromocionId,
               candidate.ProductoId,
               IIF(candidate.Tipo = N''DescuentoPorcentual'', N''Descuento'', N''Regalia''),
               CASE WHEN candidate.Tipo = N''DescuentoPorcentual''
                    THEN ROUND(product.Cantidad * product.Precio * candidate.PorcentajeDescuento / 100.0, 2)
               END,
               CASE WHEN candidate.Tipo = N''RegaliaPorVolumen''
                    THEN (candidate.CantidadComprada / candidate.CantidadMinima) * candidate.CantidadRegalo
               END,
               candidate.ProductoRegaloId,
               candidate.Prioridad
        FROM @Candidates candidate
        INNER JOIN @CartProducts product ON product.ProductoId = candidate.ProductoId
        LEFT JOIN @LockedProducts gift
            ON gift.ProductoId = candidate.ProductoRegaloId AND gift.Activo = 1
        WHERE (candidate.Tipo = N''DescuentoPorcentual'' AND candidate.PorcentajeDescuento > 0)
           OR (candidate.Tipo = N''RegaliaPorVolumen'' AND gift.ProductoId IS NOT NULL
               AND candidate.CantidadRegalo > 0);

        ;WITH Allocation AS
        (
            SELECT application.PromocionId,
                   application.ProductoId,
                   CASE
                       WHEN locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ) <= 0 THEN 0
                       WHEN application.UnidadesRegalo <= locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ) THEN application.UnidadesRegalo
                       ELSE CONVERT(INT, locked.Stock - requirement.CantidadCarrito
                            - ISNULL
                              (
                                  SUM(application.UnidadesRegalo) OVER
                                  (
                                      PARTITION BY application.ProductoRegaloId
                                      ORDER BY application.Prioridad DESC, application.PromocionId, application.ProductoId
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                                  ), 0
                              ))
                   END AS Permitidas
            FROM @Applications application
            INNER JOIN @Requirements requirement ON requirement.ProductoId = application.ProductoRegaloId
            INNER JOIN @LockedProducts locked ON locked.ProductoId = application.ProductoRegaloId
            WHERE application.TipoBeneficio = N''Regalia''
        )
        UPDATE application
        SET UnidadesRegalo = allocation.Permitidas
        FROM @Applications application
        INNER JOIN Allocation allocation
            ON allocation.PromocionId = application.PromocionId
           AND allocation.ProductoId = application.ProductoId;
        DELETE FROM @Applications WHERE TipoBeneficio = N''Regalia'' AND ISNULL(UnidadesRegalo, 0) <= 0;

        UPDATE requirement
        SET CantidadRegalo = gifts.Total
        FROM @Requirements requirement
        INNER JOIN
        (
            SELECT ProductoRegaloId, SUM(CONVERT(BIGINT, UnidadesRegalo)) AS Total
            FROM @Applications
            WHERE TipoBeneficio = N''Regalia''
            GROUP BY ProductoRegaloId
        ) gifts ON gifts.ProductoRegaloId = requirement.ProductoId;

        IF EXISTS
        (
            SELECT 1
            FROM @Requirements requirement
            INNER JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
            WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > product.Stock
               OR requirement.CantidadCarrito + requirement.CantidadRegalo > 2147483647
        )
            THROW 54615, N''No hay stock suficiente para completar el pedido.'', 1;

        INSERT INTO dbo.Pedidos
        (
            UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total,
            Observaciones, IdentificacionCliente, MetodoPago, EstadoPago,
            ReferenciaPago, FechaPago, InventarioDescontado, FechaActualizacion
        )
        VALUES
        (
            @UsuarioId, SYSDATETIME(), N''Pendiente'', @TipoEntrega, LEFT(@DireccionEntrega, 255), 0,
            LEFT(@Observaciones, 255), @IdentificacionCliente, @MetodoPago, N''Confirmado simulado'',
            @ReferenciaPago, SYSDATETIME(), 0, SYSDATETIME()
        );
        SET @PedidoId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.PedidoDetalle
            (PedidoId, ProductoId, Cantidad, PrecioUnitario, ProductoNombreSnapshot, EsRegalo)
        SELECT @PedidoId, ProductoId, Cantidad, Precio, Nombre, 0
        FROM @CartProducts;

        DECLARE @CreatedCombos TABLE (PedidoComboId INT NOT NULL, ComboId INT NOT NULL PRIMARY KEY);
        INSERT INTO dbo.PedidoCombos
            (PedidoId, ComboId, ComboNombreSnapshot, ComboDescripcionSnapshot, Cantidad, PrecioUnitario)
        OUTPUT inserted.PedidoComboId, inserted.ComboId INTO @CreatedCombos (PedidoComboId, ComboId)
        SELECT @PedidoId, ComboId, Nombre, Descripcion, Cantidad, Precio
        FROM @CartCombos;
        INSERT INTO dbo.PedidoComboDetalle
            (PedidoComboId, ProductoId, ProductoNombreSnapshot, CantidadPorCombo, CantidadTotal)
        SELECT created.PedidoComboId,
               detail.ProductoId,
               product.Nombre,
               detail.Cantidad,
               detail.Cantidad * cart.Cantidad
        FROM @CreatedCombos created
        INNER JOIN @CartCombos cart ON cart.ComboId = created.ComboId
        INNER JOIN dbo.ComboDetalle detail ON detail.ComboId = created.ComboId
        INNER JOIN @LockedProducts product ON product.ProductoId = detail.ProductoId;

        INSERT INTO dbo.PedidoDetalle
            (PedidoId, ProductoId, Cantidad, PrecioUnitario, ProductoNombreSnapshot, EsRegalo)
        SELECT @PedidoId,
               application.ProductoRegaloId,
               SUM(application.UnidadesRegalo),
               0,
               product.Nombre,
               1
        FROM @Applications application
        INNER JOIN @LockedProducts product ON product.ProductoId = application.ProductoRegaloId
        WHERE application.TipoBeneficio = N''Regalia''
        GROUP BY application.ProductoRegaloId, product.Nombre;

        -- V2 preserves the gross unit price; discounts are aggregate line amounts.

        UPDATE product
        SET product.Stock = product.Stock - CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo)
        FROM dbo.Productos product
        INNER JOIN @Requirements requirement ON requirement.ProductoId = product.ProductoId
        WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > 0
          AND product.Stock >= requirement.CantidadCarrito + requirement.CantidadRegalo;
        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Requirements WHERE CantidadCarrito + CantidadRegalo > 0)
            THROW 54616, N''El inventario cambió durante el checkout. Intente nuevamente.'', 1;

        INSERT INTO dbo.MovimientosInventario
            (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
             Motivo, UsuarioId, UsuarioNombre, FechaMovimiento)
        SELECT requirement.ProductoId,
               product.Nombre,
               N''Salida'',
               CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo),
               product.Stock,
               product.Stock - CONVERT(INT, requirement.CantidadCarrito + requirement.CantidadRegalo),
               CONCAT(N''Pedido #'', @PedidoId, N'' (productos, combos y regalías)''),
               @UsuarioId,
               @NombreUsuario,
               SYSDATETIME()
        FROM @Requirements requirement
        INNER JOIN @LockedProducts product ON product.ProductoId = requirement.ProductoId
        WHERE requirement.CantidadCarrito + requirement.CantidadRegalo > 0;

        INSERT INTO dbo.PromocionAplicaciones
            (PromocionId, PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo)
        SELECT PromocionId, @PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo
        FROM @Applications;

        INSERT dbo.Stage2OrderAmountLines(PedidoId,LineKind,LineId,ProductoId,Cantidad,PrecioBruto,Bruto,Descuento,Neto)
        SELECT @PedidoId,N''Producto'',d.PedidoDetalleId,d.ProductoId,d.Cantidad,d.PrecioUnitario,
          CONVERT(decimal(18,2),d.Cantidad*d.PrecioUnitario),ISNULL(a.Discount,0),
          CONVERT(decimal(18,2),d.Cantidad*d.PrecioUnitario)-ISNULL(a.Discount,0)
        FROM dbo.PedidoDetalle d OUTER APPLY(SELECT SUM(MontoDescontado) AS Discount FROM @Applications
          WHERE TipoBeneficio=N''Descuento'' AND ProductoId=d.ProductoId) a
        WHERE d.PedidoId=@PedidoId AND d.PedidoComboId IS NULL AND d.EsRegalo=0
        UNION ALL
        SELECT @PedidoId,N''Combo'',PedidoComboId,NULL,Cantidad,PrecioUnitario,
          CONVERT(decimal(18,2),Cantidad*PrecioUnitario),0,CONVERT(decimal(18,2),Cantidad*PrecioUnitario)
        FROM dbo.PedidoCombos WHERE PedidoId=@PedidoId;
        DECLARE @Gross decimal(18,2),@Discount decimal(18,2),@Net decimal(18,2),@Tax decimal(18,2);
        SELECT @Gross=SUM(Bruto),@Discount=SUM(Descuento),@Net=SUM(Neto) FROM dbo.Stage2OrderAmountLines WHERE PedidoId=@PedidoId;
        SET @Tax=ROUND(@Net*CONVERT(decimal(4,2),0.13),2);
        INSERT dbo.Stage2OrderAmounts(PedidoId,ContractVersion,Bruto,Descuento,Neto,Impuesto,TotalFinal)
          VALUES(@PedidoId,2,@Gross,@Discount,@Net,@Tax,@Net+@Tax);
        -- Unbilled legacy header semantics remain net. Final amount is explicit in the V2 snapshot.
        UPDATE dbo.Pedidos SET Total=@Net,InventarioDescontado=1,FechaActualizacion=SYSDATETIME() WHERE PedidoId=@PedidoId;

        INSERT INTO dbo.CheckoutOperaciones (UsuarioId, TokenOperacion, SolicitudHash, PedidoId)
        VALUES (@UsuarioId, @TokenOperacion, @SolicitudHash, @PedidoId);
        INSERT INTO dbo.InventarioOperacionAuditoria
            (Modulo, EntidadId, Accion, UsuarioId, UsuarioNombre, Detalle)
        VALUES
            (N''Checkout'', @PedidoId, N''Crear pedido'', @UsuarioId, @NombreUsuario,
             CONCAT(N''Pedido creado con token idempotente '', CONVERT(NVARCHAR(36), @TokenOperacion), N''.''));

        COMMIT TRANSACTION;
        EXEC dbo.sp_Stage2_GetCheckoutAmountsV2 @PedidoId = @PedidoId, @UsuarioId = @UsuarioId;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N''local'', N''inventory_cursor'') >= 0 CLOSE inventory_cursor;
        IF CURSOR_STATUS(N''local'', N''inventory_cursor'') > -3 DEALLOCATE inventory_cursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetCheckoutAmountsV2
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pedidos
        WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId
    )
        THROW 54600, N''El pedido no pertenece al usuario indicado.'', 1;

    SELECT PedidoId, COALESCE((SELECT Neto FROM dbo.Stage2OrderAmounts a WHERE a.PedidoId=Pedidos.PedidoId),Total) AS Total,CASE WHEN EXISTS(SELECT 1 FROM dbo.Stage2OrderAmounts a WHERE a.PedidoId=Pedidos.PedidoId) THEN 2 ELSE 1 END AS ContractVersion
    FROM dbo.Pedidos
    WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId;

    SELECT result.TipoItem,
           result.ProductoId,
           result.ComboId,
           result.Nombre,
           result.Categoria,
           result.Descripcion,
           result.PrecioUnitario,
           result.Cantidad,
           result.ImagenUrl,
           result.MontoDescuento
    FROM
    (
        SELECT N''Producto'' AS TipoItem,
               detail.ProductoId,
               CONVERT(INT, NULL) AS ComboId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre) AS Nombre,
               product.Categoria,
               product.Descripcion,
               detail.PrecioUnitario,
               detail.Cantidad,
               product.ImagenUrl,
               CONVERT(DECIMAL(18,2), ISNULL
               (
                   (
                       SELECT SUM(application.MontoDescontado)
                       FROM dbo.PromocionAplicaciones application
                       WHERE application.PedidoId = detail.PedidoId
                         AND application.ProductoId = detail.ProductoId
                         AND application.TipoBeneficio = N''Descuento''
                   ), 0
               )) AS MontoDescuento,
               1 AS SortOrder,
               detail.PedidoDetalleId AS SortId
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.EsRegalo = 0
          AND detail.PedidoComboId IS NULL

        UNION ALL

        SELECT N''Combo'',
               CONVERT(INT, NULL),
               combo.ComboId,
               combo.ComboNombreSnapshot,
               N''Combo'',
               combo.ComboDescripcionSnapshot,
               combo.PrecioUnitario,
               combo.Cantidad,
               CONVERT(NVARCHAR(300), NULL),
               CONVERT(DECIMAL(18,2), 0),
               2,
               combo.PedidoComboId
        FROM dbo.PedidoCombos combo
        WHERE combo.PedidoId = @PedidoId
    ) result
    ORDER BY result.SortOrder, result.SortId;

    SELECT gift.ProductoId,
           product.Nombre,
           SUM(gift.Cantidad) AS Cantidad,
           MAX(appliedPromotion.Nombre) AS PromocionNombre
    FROM dbo.PedidoDetalle gift
    INNER JOIN dbo.Productos product ON product.ProductoId = gift.ProductoId
    OUTER APPLY
    (
        SELECT TOP (1) promotion.Nombre
        FROM dbo.PromocionAplicaciones application
        INNER JOIN dbo.Promociones promotion ON promotion.PromocionId = application.PromocionId
        WHERE application.PedidoId = gift.PedidoId
          AND application.TipoBeneficio = N''Regalia''
          AND promotion.ProductoRegaloId = gift.ProductoId
        ORDER BY promotion.Prioridad DESC, promotion.PromocionId
    ) appliedPromotion
    WHERE gift.PedidoId = @PedidoId
      AND gift.EsRegalo = 1
      AND gift.PedidoComboId IS NULL
    GROUP BY gift.ProductoId, product.Nombre
    ORDER BY product.Nombre, gift.ProductoId;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetOrderDetailLinesV2
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT result.PedidoDetalleId,
           result.Nombre,
           result.ProductoId,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal,
           result.StockActual,
           result.EsCombo
    FROM
    (
        SELECT detail.PedidoDetalleId,
               COALESCE(detail.ProductoNombreSnapshot, product.Nombre) AS Nombre,
               detail.ProductoId,
               detail.Cantidad,
               detail.PrecioUnitario,
               COALESCE((SELECT a.Neto FROM dbo.Stage2OrderAmountLines a WHERE a.PedidoId=@PedidoId AND a.LineKind=N''Producto'' AND a.LineId=detail.PedidoDetalleId),CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario)) AS Subtotal,
               product.Stock AS StockActual,
               CONVERT(BIT, 0) AS EsCombo,
               1 AS SortOrder,
               detail.PedidoDetalleId AS SortId
        FROM dbo.PedidoDetalle detail
        INNER JOIN dbo.Productos product ON product.ProductoId = detail.ProductoId
        WHERE detail.PedidoId = @PedidoId
          AND detail.PedidoComboId IS NULL

        UNION ALL

        SELECT -combo.PedidoComboId,
               CONCAT(N''Combo: '', combo.ComboNombreSnapshot),
               combo.ComboId,
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               ISNULL(availability.StockDisponible, 0),
               CONVERT(BIT, 1),
               2,
               combo.PedidoComboId
        FROM dbo.PedidoCombos combo
        OUTER APPLY
        (
            SELECT CONVERT(INT, MIN(product.Stock / NULLIF(component.CantidadPorCombo, 0))) AS StockDisponible
            FROM dbo.PedidoComboDetalle component
            INNER JOIN dbo.Productos product ON product.ProductoId = component.ProductoId
            WHERE component.PedidoComboId = combo.PedidoComboId
        ) availability
        WHERE combo.PedidoId = @PedidoId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetInvoiceLinesV2
    @FacturaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT result.ProductoNombre,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal
    FROM
    (
        SELECT detail.ProductoNombre,
               detail.Cantidad,
               detail.PrecioUnitario,
               COALESCE((SELECT a.Neto FROM dbo.Stage2OrderAmountLines a JOIN dbo.Facturas f ON f.PedidoId=a.PedidoId WHERE f.FacturaId=detail.FacturaId AND a.LineKind=N''Producto'' AND a.ProductoId=detail.ProductoId AND a.Cantidad=detail.Cantidad AND detail.PrecioUnitario>0),CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario)) AS Subtotal,
               1 AS SortOrder,
               detail.FacturaDetalleId AS SortId
        FROM dbo.FacturaDetalle detail
        WHERE detail.FacturaId = @FacturaId
        UNION ALL
        SELECT CONCAT(N''Combo: '', combo.ComboNombreSnapshot),
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               2,
               combo.FacturaComboId
        FROM dbo.FacturaCombos combo
        WHERE combo.FacturaId = @FacturaId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE dbo.sp_Stage2_GetClientInvoiceLinesV2
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT result.ProductoNombre,
           result.Cantidad,
           result.PrecioUnitario,
           result.Subtotal
    FROM
    (
        SELECT detail.ProductoNombre,
               detail.Cantidad,
               detail.PrecioUnitario,
               COALESCE((SELECT a.Neto FROM dbo.Stage2OrderAmountLines a JOIN dbo.Facturas f ON f.PedidoId=a.PedidoId WHERE f.FacturaId=detail.FacturaId AND a.LineKind=N''Producto'' AND a.ProductoId=detail.ProductoId AND a.Cantidad=detail.Cantidad AND detail.PrecioUnitario>0),CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario)) AS Subtotal,
               1 AS SortOrder,
               detail.FacturaDetalleId AS SortId
        FROM dbo.FacturaDetalle detail
        INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = detail.FacturaId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = invoice.PedidoId
        WHERE invoice.PedidoId = @PedidoId
          AND invoice.UsuarioId = @UsuarioId
          AND orders.UsuarioId = @UsuarioId
        UNION ALL
        SELECT CONCAT(N''Combo: '', combo.ComboNombreSnapshot),
               combo.Cantidad,
               combo.PrecioUnitario,
               CONVERT(DECIMAL(18,2), combo.Cantidad * combo.PrecioUnitario),
               2,
               combo.FacturaComboId
        FROM dbo.FacturaCombos combo
        INNER JOIN dbo.Facturas invoice ON invoice.FacturaId = combo.FacturaId
        INNER JOIN dbo.Pedidos orders ON orders.PedidoId = invoice.PedidoId
        WHERE invoice.PedidoId = @PedidoId
          AND invoice.UsuarioId = @UsuarioId
          AND orders.UsuarioId = @UsuarioId
    ) result
    ORDER BY result.SortOrder, result.SortId;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_GenerateInvoiceAmountsV2
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
        SELECT @Subtotal=Neto FROM dbo.Stage2OrderAmounts WITH(HOLDLOCK) WHERE PedidoId=@PedidoId;
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
 EXEC(N'CREATE TRIGGER dbo.tr_Stage2OrderAmounts_Immutable ON dbo.Stage2OrderAmounts INSTEAD OF UPDATE,DELETE AS BEGIN THROW 57216,N''Importes V2 inmutables.'',1; END;');
 EXEC(N'CREATE TRIGGER dbo.tr_Stage2OrderAmountLines_Immutable ON dbo.Stage2OrderAmountLines INSTEAD OF UPDATE,DELETE AS BEGIN THROW 57216,N''Importes V2 inmutables.'',1; END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0039_stage2_aggregate_amounts_v2',N'0039_stage2_aggregate_amounts_v2.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Importes agregados V2 sin reparto unitario; contratos historicos preservados. No habilita autoridad de cotizaciones ni aprobacion supervisora.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
