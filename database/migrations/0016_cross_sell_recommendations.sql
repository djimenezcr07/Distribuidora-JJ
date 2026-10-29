SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-262: recomendaciones explicables basadas en co-compra, sin IA externa. */
IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL THROW 54900, N'Falta el ledger 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0016_cross_sell_recommendations' AND Status=N'Applied')
    THROW 54901, N'0016 ya figura aplicada.', 1;
IF OBJECT_ID(N'dbo.Pedidos', N'U') IS NULL OR OBJECT_ID(N'dbo.PedidoDetalle', N'U') IS NULL OR OBJECT_ID(N'dbo.Productos', N'U') IS NULL
    THROW 54902, N'Faltan Pedidos, PedidoDetalle o Productos.', 1;
IF COL_LENGTH(N'dbo.Pedidos', N'UsuarioId') IS NULL OR COL_LENGTH(N'dbo.Pedidos', N'Estado') IS NULL
   OR COL_LENGTH(N'dbo.PedidoDetalle', N'ProductoId') IS NULL OR COL_LENGTH(N'dbo.Productos', N'Stock') IS NULL
    THROW 54903, N'El esquema no contiene las columnas requeridas para CU-262.', 1;

BEGIN TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Ventas_CrossSellSuggestions
    @UsuarioId INT = NULL,
    @CartProductIds NVARCHAR(MAX),
    @CandidateLimit INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    IF @UsuarioId IS NOT NULL AND @UsuarioId <= 0 THROW 54910, N'Usuario inválido.', 1;
    IF @CandidateLimit NOT BETWEEN 1 AND 50 THROW 54911, N'Límite de candidatos inválido.', 1;
    IF LEN(COALESCE(@CartProductIds,N'')) > 4000 THROW 54912, N'Lista de productos demasiado extensa.', 1;

    CREATE TABLE #Cart(ProductoId INT NOT NULL PRIMARY KEY);
    INSERT #Cart(ProductoId)
    SELECT DISTINCT parsed.ProductoId
    FROM STRING_SPLIT(COALESCE(@CartProductIds,N''),N',') raw
    CROSS APPLY (SELECT TRY_CONVERT(INT,LTRIM(RTRIM(raw.value))) ProductoId) parsed
    WHERE parsed.ProductoId > 0;
    IF NOT EXISTS(SELECT 1 FROM #Cart) RETURN;

    CREATE TABLE #ValidOrder(PedidoId INT NOT NULL PRIMARY KEY,UsuarioId INT NULL);
    INSERT #ValidOrder
    SELECT DISTINCT orders.PedidoId,orders.UsuarioId
    FROM dbo.Pedidos orders INNER JOIN dbo.PedidoDetalle line ON line.PedidoId=orders.PedidoId
    INNER JOIN #Cart cart ON cart.ProductoId=line.ProductoId
    WHERE orders.Estado NOT IN(N'Cancelado',N'Cancelada',N'Rechazado',N'Rechazada');

    CREATE TABLE #Support(ProductoId INT NOT NULL PRIMARY KEY,Support INT NOT NULL,ClientSupport INT NOT NULL);
    INSERT #Support
    SELECT line.ProductoId,COUNT(DISTINCT orders.PedidoId),
           COUNT(DISTINCT CASE WHEN @UsuarioId IS NOT NULL AND orders.UsuarioId=@UsuarioId THEN orders.PedidoId END)
    FROM #ValidOrder orders INNER JOIN dbo.PedidoDetalle line ON line.PedidoId=orders.PedidoId
    LEFT JOIN #Cart cart ON cart.ProductoId=line.ProductoId
    WHERE cart.ProductoId IS NULL
    GROUP BY line.ProductoId;

    CREATE TABLE #Popularity(ProductoId INT NOT NULL PRIMARY KEY,Popularity INT NOT NULL);
    INSERT #Popularity
    SELECT line.ProductoId,COUNT(DISTINCT orders.PedidoId)
    FROM dbo.Pedidos orders INNER JOIN dbo.PedidoDetalle line ON line.PedidoId=orders.PedidoId
    WHERE orders.Estado NOT IN(N'Cancelado',N'Cancelada',N'Rechazado',N'Rechazada')
    GROUP BY line.ProductoId;

    ;WITH cartCategories AS
    (SELECT DISTINCT product.Categoria FROM #Cart cart INNER JOIN dbo.Productos product ON product.ProductoId=cart.ProductoId)
    SELECT TOP (@CandidateLimit)
           product.ProductoId,product.Nombre,product.Categoria,product.Precio,product.Stock,
           COALESCE(NULLIF(LTRIM(RTRIM(product.ImagenUrl)),N''),N'~/img/whisky-premium.webp') ImagenUrl,
           CONVERT(BIT,product.Activo) Activo,COALESCE(support.Support,0) Support,
           COALESCE(support.ClientSupport,0) ClientSupport,
           CONVERT(BIT,CASE WHEN category.Categoria IS NULL THEN 0 ELSE 1 END) CategoryMatch,
           COALESCE(popularity.Popularity,0) Popularity
    FROM dbo.Productos product
    LEFT JOIN #Cart cart ON cart.ProductoId=product.ProductoId
    LEFT JOIN #Support support ON support.ProductoId=product.ProductoId
    LEFT JOIN #Popularity popularity ON popularity.ProductoId=product.ProductoId
    LEFT JOIN cartCategories category ON category.Categoria=product.Categoria
    WHERE product.Activo=1 AND product.Stock>0 AND cart.ProductoId IS NULL
      AND (COALESCE(support.Support,0)>=2 OR category.Categoria IS NOT NULL OR COALESCE(popularity.Popularity,0)>0)
    ORDER BY CASE WHEN COALESCE(support.Support,0)>=2 THEN 0 ELSE 1 END,
             support.ClientSupport DESC,support.Support DESC,
             CASE WHEN category.Categoria IS NULL THEN 0 ELSE 1 END DESC,
             popularity.Popularity DESC,product.ProductoId;
END;
GO

IF XACT_STATE() <> 1 THROW 54904, N'La transacción 0016 no está disponible.', 1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 54905,N'SHA-256 inválido para 0016.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0016_cross_sell_recommendations',N'0016_cross_sell_recommendations.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-262: co-compra con soporte mínimo y fallback explicable.');
COMMIT TRANSACTION;
GO
