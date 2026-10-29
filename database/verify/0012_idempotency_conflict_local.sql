/*
  Prueba negativa local para el conflicto de token idempotente de 0012.
  Debe terminar con SQL error 54609. El rollback interno del procedimiento
  elimina todos los datos de prueba de la transacción abierta.
  No ejecutar en Azure DEV, producción ni una base compartida.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @ComboId INT;
DECLARE @Token UNIQUEIDENTIFIER = NEWID();
DECLARE @Items NVARCHAR(MAX);
DECLARE @DifferentItems NVARCHAR(MAX);
DECLARE @ComponentesJson NVARCHAR(MAX);
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

IF @AdministradorId IS NULL OR @ClienteId IS NULL
   OR @Producto1Id IS NULL OR @Producto2Id IS NULL
    THROW 54728, N'La fixture requiere dos usuarios y dos productos activos.', 1;

UPDATE dbo.Productos
SET Stock = 100
WHERE ProductoId IN (@Producto1Id, @Producto2Id);
SET @ComponentesJson = CONCAT
(
    N'[{"productoId":', @Producto1Id, N',"cantidad":1},',
    N'{"productoId":', @Producto2Id, N',"cantidad":1}]'
);

EXEC dbo.sp_Admin_CreateCombo
    @Nombre = N'QA token conflict 0012',
    @Descripcion = N'Prueba negativa local',
    @Precio = 1000.00,
    @ComponentesJson = @ComponentesJson,
    @UsuarioId = @AdministradorId,
    @UsuarioNombre = N'QA Local',
    @NuevoComboId = @ComboId OUTPUT;

SET @Items = CONCAT(N'[{"tipo":"Combo","productoId":null,"comboId":', @ComboId, N',"cantidad":1}]');
SET @DifferentItems = CONCAT
    (
        N'[{"tipo":"Producto","productoId":', @Producto1Id,
        N',"comboId":null,"cantidad":1}]'
    );

EXEC dbo.sp_Store_CreateOrderWithPromotions
    @UsuarioId = @ClienteId,
    @TipoEntrega = N'Retiro en tienda',
    @IdentificacionCliente = N'QA-TOKEN-0012',
    @ItemsJson = @Items,
    @TokenOperacion = @Token;

EXEC dbo.sp_Store_CreateOrderWithPromotions
    @UsuarioId = @ClienteId,
    @TipoEntrega = N'Retiro en tienda',
    @IdentificacionCliente = N'QA-TOKEN-0012',
    @ItemsJson = @DifferentItems,
    @TokenOperacion = @Token;
