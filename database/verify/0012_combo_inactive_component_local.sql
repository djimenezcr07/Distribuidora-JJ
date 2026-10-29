/*
  Prueba LocalDB de componentes inactivos en combos.
  No ejecutar en Azure DEV, producción ni una base compartida. Cada bloque revierte sus datos.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AdministradorId INT =
    (SELECT TOP (1) UsuarioId FROM dbo.Usuarios WHERE Activo = 1 ORDER BY UsuarioId);
DECLARE @ClienteId INT =
    (SELECT TOP (1) UsuarioId FROM dbo.Usuarios
     WHERE Activo = 1 AND UsuarioId <> @AdministradorId ORDER BY UsuarioId);
DECLARE @Producto1Id INT =
    (SELECT TOP (1) ProductoId FROM dbo.Productos WHERE Activo = 1 ORDER BY ProductoId);
DECLARE @Producto2Id INT =
    (SELECT TOP (1) ProductoId FROM dbo.Productos
     WHERE Activo = 1 AND ProductoId <> @Producto1Id ORDER BY ProductoId);
DECLARE @StockOriginalProducto1 INT =
    (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id);
DECLARE @StockOriginalProducto2 INT =
    (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id);
DECLARE @ComponentesJson NVARCHAR(MAX) = CONCAT
(
    N'[{"productoId":', @Producto1Id, N',"cantidad":2},',
    N'{"productoId":', @Producto2Id, N',"cantidad":1}]'
);

IF @StockOriginalProducto1 IS NULL OR @StockOriginalProducto2 IS NULL
   OR @AdministradorId IS NULL OR @ClienteId IS NULL
    THROW 54740, N'La fixture requiere dos usuarios y dos productos activos.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ComboId INT;
    DECLARE @DetallePublicoAntes TABLE
    (
        ComboId INT,
        Nombre NVARCHAR(150),
        Descripcion NVARCHAR(500),
        Precio DECIMAL(18,2),
        CantidadProductos INT,
        StockDisponibleCombo INT,
        ComponentesValidos BIT,
        ComponentesResumen NVARCHAR(MAX)
    );
    DECLARE @DetallePublicoInactivo TABLE
    (
        ComboId INT,
        Nombre NVARCHAR(150),
        Descripcion NVARCHAR(500),
        Precio DECIMAL(18,2),
        CantidadProductos INT,
        StockDisponibleCombo INT,
        ComponentesValidos BIT,
        ComponentesResumen NVARCHAR(MAX)
    );
    DECLARE @CatalogoInactivo TABLE
    (
        ComboId INT,
        Nombre NVARCHAR(150),
        Descripcion NVARCHAR(500),
        Precio DECIMAL(18,2),
        CantidadProductos INT,
        StockDisponibleCombo INT,
        ComponentesValidos BIT,
        ComponentesResumen NVARCHAR(MAX)
    );
    DECLARE @AdminInactivo TABLE
    (
        ComboId INT,
        Nombre NVARCHAR(150),
        Descripcion NVARCHAR(500),
        Precio DECIMAL(18,2),
        Activo BIT,
        FechaCreacionUtc DATETIME2(0),
        RegistradoPorNombre NVARCHAR(150),
        CantidadProductos INT,
        StockDisponibleCombo INT,
        EstadoDisponibilidad NVARCHAR(100)
    );

    UPDATE dbo.Productos
    SET Activo = 1, Stock = 20
    WHERE ProductoId IN (@Producto1Id, @Producto2Id);
    EXEC dbo.sp_Admin_CreateCombo
        @Nombre = N'QA componente inactivo 0012',
        @Descripcion = N'No debe venderse si un componente queda inactivo.',
        @Precio = 1200.00,
        @ComponentesJson = @ComponentesJson,
        @UsuarioId = @AdministradorId,
        @UsuarioNombre = N'QA Local',
        @NuevoComboId = @ComboId OUTPUT;

    INSERT INTO @DetallePublicoAntes EXEC dbo.sp_Store_GetComboById @ComboId = @ComboId;
    IF NOT EXISTS (SELECT 1 FROM @DetallePublicoAntes WHERE StockDisponibleCombo = 10 AND ComponentesValidos = 1)
        THROW 54741, N'El combo activo no quedó disponible antes de inactivar un componente.', 1;

    UPDATE dbo.Productos SET Activo = 0 WHERE ProductoId = @Producto2Id;
    INSERT INTO @DetallePublicoInactivo EXEC dbo.sp_Store_GetComboById @ComboId = @ComboId;
    INSERT INTO @CatalogoInactivo EXEC dbo.sp_Store_GetActiveCombos;
    INSERT INTO @AdminInactivo EXEC dbo.sp_Admin_GetCombos;

    IF EXISTS (SELECT 1 FROM @DetallePublicoInactivo)
       OR EXISTS (SELECT 1 FROM @CatalogoInactivo WHERE ComboId = @ComboId)
       OR NOT EXISTS
          (
              SELECT 1
              FROM @AdminInactivo
              WHERE ComboId = @ComboId
                AND StockDisponibleCombo = 0
                AND EstadoDisponibilidad = N'Componente inactivo o faltante'
          )
        THROW 54742, N'Un componente inactivo dejó el combo visible o disponible.', 1;

    UPDATE dbo.Productos SET Activo = 1 WHERE ProductoId = @Producto2Id;
    DECLARE @CatalogoReactivado TABLE
    (
        ComboId INT,
        Nombre NVARCHAR(150),
        Descripcion NVARCHAR(500),
        Precio DECIMAL(18,2),
        CantidadProductos INT,
        StockDisponibleCombo INT,
        ComponentesValidos BIT,
        ComponentesResumen NVARCHAR(MAX)
    );
    INSERT INTO @CatalogoReactivado EXEC dbo.sp_Store_GetComboById @ComboId = @ComboId;
    IF NOT EXISTS (SELECT 1 FROM @CatalogoReactivado WHERE StockDisponibleCombo = 10 AND ComponentesValidos = 1)
        THROW 54745, N'El combo no volvió a estar disponible al reactivar el componente.', 1;

    UPDATE dbo.Productos SET Stock = 0 WHERE ProductoId = @Producto2Id;
    DELETE FROM @CatalogoReactivado;
    INSERT INTO @CatalogoReactivado EXEC dbo.sp_Store_GetComboById @ComboId = @ComboId;
    IF EXISTS (SELECT 1 FROM @CatalogoReactivado)
        THROW 54746, N'El detalle público devolvió un combo con componente sin stock.', 1;

    ROLLBACK TRANSACTION;

    BEGIN TRANSACTION;
    DECLARE @ComboCheckoutId INT;
    DECLARE @StockAntesCheckout1 INT;
    DECLARE @StockAntesCheckout2 INT;
    DECLARE @ItemsManipulados NVARCHAR(MAX);
    DECLARE @TokenManipulado UNIQUEIDENTIFIER = NEWID();
    UPDATE dbo.Productos
    SET Activo = 1, Stock = 20
    WHERE ProductoId IN (@Producto1Id, @Producto2Id);
    EXEC dbo.sp_Admin_CreateCombo
        @Nombre = N'QA checkout componente inactivo 0012',
        @Descripcion = N'La petición manipulada debe fallar sin descontar inventario.',
        @Precio = 1200.00,
        @ComponentesJson = @ComponentesJson,
        @UsuarioId = @AdministradorId,
        @UsuarioNombre = N'QA Local',
        @NuevoComboId = @ComboCheckoutId OUTPUT;
    UPDATE dbo.Productos SET Activo = 0 WHERE ProductoId = @Producto2Id;
    SELECT @StockAntesCheckout1 = Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id;
    SELECT @StockAntesCheckout2 = Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id;
    SET @ItemsManipulados = CONCAT(N'[{"tipo":"Combo","productoId":null,"comboId":', @ComboCheckoutId, N',"cantidad":1}]');

    BEGIN TRY
        EXEC dbo.sp_Store_CreateOrderWithPromotions
            @UsuarioId = @ClienteId,
            @TipoEntrega = N'Retiro en tienda',
            @IdentificacionCliente = N'QA-COMBO-INACTIVO',
            @ItemsJson = @ItemsManipulados,
            @TokenOperacion = @TokenManipulado;
        THROW 54743, N'El checkout aceptó un combo con componente inactivo.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (54612, 54613)
            THROW;
    END CATCH;

    -- El procedimiento hace rollback de toda la transacción al rechazar el checkout.
    IF @@TRANCOUNT <> 0 ROLLBACK TRANSACTION;
    IF (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto1Id) <> @StockOriginalProducto1
       OR (SELECT Stock FROM dbo.Productos WHERE ProductoId = @Producto2Id) <> @StockOriginalProducto2
        THROW 54744, N'El checkout rechazado alteró el inventario.', 1;
    SELECT N'0012 inactive-component local test passed; all writes rolled back.' AS Resultado;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
