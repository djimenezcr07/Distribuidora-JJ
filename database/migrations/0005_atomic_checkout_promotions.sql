SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Checkout atómico: el pedido base, inventario, descuentos, regalías, historial y total
  se confirman o revierten juntos. Las promociones se vuelven a resolver en SQL con precio,
  stock, segmento y vigencia actuales; el navegador no decide importes.
  Requiere sp_Store_CreateOrder y los objetos de CU-171/174.
  Rollback: la aplicación puede volver temporalmente a sp_Store_CreateOrder; no hay DDL destructivo.
*/
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_CreateOrderWithPromotions
    @UsuarioId INT,
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX),
    @MetodoPago NVARCHAR(40) = N'Efectivo contra entrega',
    @ReferenciaPago NVARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Pedido TABLE (PedidoId INT NOT NULL);
    DECLARE @PedidoId INT;
    DECLARE @NombreUsuario NVARCHAR(150);
    DECLARE @Segmento NVARCHAR(20);
    DECLARE @AplicacionesJson NVARCHAR(MAX);

    SELECT @NombreUsuario = u.NombreCompleto,
           @Segmento = ISNULL(NULLIF(u.SegmentoCliente, N''), N'Minorista')
    FROM dbo.Usuarios u
    WHERE u.UsuarioId = @UsuarioId AND u.Activo = 1;

    IF @NombreUsuario IS NULL THROW 53200, N'El usuario del pedido no es válido.', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO @Pedido (PedidoId)
        EXEC dbo.sp_Store_CreateOrder
            @UsuarioId = @UsuarioId,
            @TipoEntrega = @TipoEntrega,
            @DireccionEntrega = @DireccionEntrega,
            @Observaciones = @Observaciones,
            @IdentificacionCliente = @IdentificacionCliente,
            @ItemsJson = @ItemsJson,
            @MetodoPago = @MetodoPago,
            @ReferenciaPago = @ReferenciaPago;

        SELECT @PedidoId = PedidoId FROM @Pedido;
        IF @PedidoId IS NULL THROW 53201, N'No fue posible crear el pedido.', 1;

        DECLARE @Aplicaciones TABLE
        (
            PromocionId INT NOT NULL,
            ProductoId INT NOT NULL,
            TipoBeneficio NVARCHAR(20) NOT NULL,
            MontoDescontado DECIMAL(18,2) NULL,
            UnidadesRegalo INT NULL,
            ProductoRegaloId INT NULL
        );

        ;WITH Elegibles AS
        (
            SELECT pr.PromocionId, pr.ProductoId, pr.Tipo, pr.PorcentajeDescuento,
                   pr.ProductoRegaloId, pr.CantidadRegalo, pr.CantidadMinima,
                   pd.Cantidad, pd.PrecioUnitario,
                   regalo.Stock AS StockRegalo,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY pr.ProductoId
                       ORDER BY pr.Prioridad DESC, pr.PromocionId
                   ) AS PrioridadProducto
            FROM dbo.PedidoDetalle pd
            INNER JOIN dbo.Promociones pr WITH (UPDLOCK, HOLDLOCK)
                ON pr.ProductoId = pd.ProductoId
            LEFT JOIN dbo.Productos regalo WITH (UPDLOCK, HOLDLOCK)
                ON regalo.ProductoId = pr.ProductoRegaloId AND regalo.Activo = 1
            WHERE pd.PedidoId = @PedidoId
              AND pd.Cantidad >= pr.CantidadMinima
              AND pr.Estado = N'Activa'
              AND CONVERT(DATE, SYSDATETIME()) BETWEEN pr.FechaInicio AND pr.FechaFin
              AND pr.SegmentoCliente IN (N'Todos', @Segmento)
        )
        INSERT INTO @Aplicaciones
            (PromocionId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo, ProductoRegaloId)
        SELECT PromocionId,
               ProductoId,
               IIF(Tipo = N'DescuentoPorcentual', N'Descuento', N'Regalia'),
               CASE WHEN Tipo = N'DescuentoPorcentual'
                    THEN ROUND(Cantidad * PrecioUnitario * PorcentajeDescuento / 100.0, 2)
               END,
               CASE WHEN Tipo = N'RegaliaPorVolumen'
                    THEN IIF(StockRegalo < (Cantidad / CantidadMinima) * CantidadRegalo,
                             StockRegalo,
                             (Cantidad / CantidadMinima) * CantidadRegalo)
               END,
               CASE WHEN Tipo = N'RegaliaPorVolumen' THEN ProductoRegaloId END
        FROM Elegibles
        WHERE PrioridadProducto = 1
          AND
          (
              (Tipo = N'DescuentoPorcentual' AND PorcentajeDescuento > 0)
              OR
              (Tipo = N'RegaliaPorVolumen' AND ProductoRegaloId IS NOT NULL
               AND CantidadRegalo > 0 AND ISNULL(StockRegalo, 0) > 0)
          );

        SELECT @AplicacionesJson =
        (
            SELECT PromocionId, ProductoId, TipoBeneficio,
                   MontoDescontado, UnidadesRegalo, ProductoRegaloId
            FROM @Aplicaciones
            FOR JSON PATH
        );

        IF @AplicacionesJson IS NOT NULL AND @AplicacionesJson <> N'[]'
        BEGIN
            EXEC dbo.sp_Promociones_AplicarAPedido
                @PedidoId = @PedidoId,
                @AplicacionesJson = @AplicacionesJson,
                @UsuarioId = @UsuarioId,
                @Nombre = @NombreUsuario;
        END;

        COMMIT TRANSACTION;

        SELECT p.PedidoId, p.Total
        FROM dbo.Pedidos p
        WHERE p.PedidoId = @PedidoId;

        SELECT pr.ProductoRegaloId AS ProductoId,
               producto.Nombre,
               SUM(pa.UnidadesRegalo) AS Cantidad,
               MAX(pr.Nombre) AS PromocionNombre
        FROM dbo.PromocionAplicaciones pa
        INNER JOIN dbo.Promociones pr ON pr.PromocionId = pa.PromocionId
        INNER JOIN dbo.Productos producto ON producto.ProductoId = pr.ProductoRegaloId
        WHERE pa.PedidoId = @PedidoId
          AND pa.TipoBeneficio = N'Regalia'
          AND pa.UnidadesRegalo > 0
        GROUP BY pr.ProductoRegaloId, producto.Nombre;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0005_atomic_checkout_promotions')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0005_atomic_checkout_promotions', N'0005_atomic_checkout_promotions.sql',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', N'0005_atomic_checkout_promotions_v1'), 2),
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Checkout, inventario y promociones se confirman en una sola transacción externa.');
END;
GO
