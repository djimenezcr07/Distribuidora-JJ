/* LocalDB-only fixture for the parallel checkout test. Do not run in shared environments. */
SET NOCOUNT ON;

DECLARE @ComboId INT;
DECLARE @UsuarioId INT =
    (SELECT TOP (1) UsuarioId FROM dbo.Usuarios WHERE Activo = 1 ORDER BY UsuarioId);
DECLARE @ProductoId INT =
    (SELECT TOP (1) ProductoId FROM dbo.Productos WHERE Activo = 1 ORDER BY ProductoId);
DECLARE @ComponentesJson NVARCHAR(MAX);

IF @UsuarioId IS NULL OR @ProductoId IS NULL
    THROW 54729, N'La fixture requiere un usuario y un producto activos.', 1;

UPDATE dbo.Productos SET Stock = 1 WHERE ProductoId = @ProductoId;
SET @ComponentesJson =
    CONCAT(N'[{"productoId":', @ProductoId, N',"cantidad":1}]');

EXEC dbo.sp_Admin_CreateCombo
    @Nombre = N'QA concurrency 0012',
    @Descripcion = N'Prueba de dos sesiones',
    @Precio = 1000.00,
    @ComponentesJson = @ComponentesJson,
    @UsuarioId = @UsuarioId,
    @UsuarioNombre = N'QA Local',
    @NuevoComboId = @ComboId OUTPUT;

SELECT @ComboId AS ComboId, @UsuarioId AS UsuarioId, @ProductoId AS ProductoId;
