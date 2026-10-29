USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-071: pedidos registrados por vendedor desde móvil
   Mejora: el pedido conserva cliente, vendedor y canal.
   ========================================================= */

IF COL_LENGTH('dbo.Pedidos', 'VendedorUsuarioId') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos ADD VendedorUsuarioId INT NULL;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'VendedorNombre') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos ADD VendedorNombre NVARCHAR(150) NULL;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'CanalPedido') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos ADD CanalPedido NVARCHAR(50) NULL;
END;
GO

IF COL_LENGTH('dbo.Pedidos', 'FechaActualizacion') IS NULL
BEGIN
    ALTER TABLE dbo.Pedidos ADD FechaActualizacion DATETIME2 NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Pedidos_VendedorUsuarios')
BEGIN
    ALTER TABLE dbo.Pedidos
    ADD CONSTRAINT FK_Pedidos_VendedorUsuarios
    FOREIGN KEY (VendedorUsuarioId)
    REFERENCES dbo.Usuarios(UsuarioId);
END;
GO

/* Rol vendedor: se crea sin afectar los roles existentes. */
IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Vendedor')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES ('Vendedor', 'Usuario autorizado para registrar pedidos de clientes desde un dispositivo móvil.', 1);
END;
GO

/* Permiso específico del módulo móvil. */
MERGE dbo.Permisos AS target
USING (VALUES
    ('VENTA_MOVIL_CREAR_PEDIDO', 'Venta móvil', 'Registrar pedidos móviles', 'Permite registrar pedidos de clientes desde un dispositivo móvil.')
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET Modulo = source.Modulo,
               Nombre = source.Nombre,
               Descripcion = source.Descripcion,
               Activo = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

/* Asignar permiso a Administrador, Empleado y Vendedor si existen. */
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, 'Script CU-071'
FROM dbo.Perfiles p
INNER JOIN dbo.Permisos pe
    ON pe.Codigo = 'VENTA_MOVIL_CREAR_PEDIDO'
WHERE p.Nombre IN ('Administrador', 'Empleado', 'Vendedor')
  AND pe.Activo = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.PerfilPermisos pp
      WHERE pp.PerfilId = p.PerfilId
        AND pp.PermisoId = pe.PermisoId
  );
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetClientsForOrder
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        ISNULL(u.Telefono, '') AS Telefono,
        ISNULL(u.Direccion, '') AS Direccion
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p
        ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = 'Cliente'
      AND u.Activo = 1
      AND (
            @Buscar IS NULL
            OR u.NombreCompleto LIKE '%' + @Buscar + '%'
            OR u.Correo LIKE '%' + @Buscar + '%'
            OR ISNULL(u.Telefono, '') LIKE '%' + @Buscar + '%'
          )
    ORDER BY u.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetProductsForOrder
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.ProductoId,
        p.Nombre,
        p.Categoria,
        ISNULL(p.Descripcion, '') AS Descripcion,
        p.Precio,
        p.Stock,
        ISNULL(p.ImagenUrl, '') AS ImagenUrl
    FROM dbo.Productos p
    WHERE p.Activo = 1
      AND p.Stock > 0
      AND (
            @Buscar IS NULL
            OR p.Nombre LIKE '%' + @Buscar + '%'
            OR p.Categoria LIKE '%' + @Buscar + '%'
          )
    ORDER BY p.Categoria, p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_CreateOrder
    @ClienteUsuarioId INT,
    @VendedorUsuarioId INT,
    @VendedorNombre NVARCHAR(150),
    @TipoEntrega NVARCHAR(100),
    @DireccionEntrega NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(500) = NULL,
    @IdentificacionCliente NVARCHAR(100) = NULL,
    @ItemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PedidoId INT;
    DECLARE @Total DECIMAL(18,2);

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @ClienteUsuarioId
          AND u.Activo = 1
          AND p.Nombre = 'Cliente'
    )
    BEGIN
        THROW 50710, 'El cliente seleccionado no existe o se encuentra inactivo.', 1;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios
        WHERE UsuarioId = @VendedorUsuarioId
          AND Activo = 1
    )
    BEGIN
        THROW 50711, 'El vendedor que registra el pedido no es válido.', 1;
    END;

    IF ISNULL(@ItemsJson, '') = ''
    BEGIN
        THROW 50712, 'Debe seleccionar al menos un producto para crear el pedido.', 1;
    END;

    DECLARE @Items TABLE
    (
        ProductoId INT NOT NULL,
        Cantidad INT NOT NULL,
        Precio DECIMAL(18,2) NULL,
        StockActual INT NULL
    );

    INSERT INTO @Items (ProductoId, Cantidad)
    SELECT ProductoId, Cantidad
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        ProductoId INT '$.productoId',
        Cantidad INT '$.cantidad'
    )
    WHERE ISNULL(Cantidad, 0) > 0;

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN
        THROW 50713, 'Debe indicar cantidades mayores a cero.', 1;
    END;

    UPDATE i
    SET Precio = p.Precio,
        StockActual = p.Stock
    FROM @Items i
    INNER JOIN dbo.Productos p
        ON p.ProductoId = i.ProductoId
    WHERE p.Activo = 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE Precio IS NULL OR StockActual IS NULL)
    BEGIN
        THROW 50714, 'Uno o más productos no están disponibles.', 1;
    END;

    IF EXISTS (SELECT 1 FROM @Items WHERE Cantidad > StockActual)
    BEGIN
        THROW 50715, 'No hay stock suficiente para uno o más productos.', 1;
    END;

    SELECT @Total = SUM(Precio * Cantidad)
    FROM @Items;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Pedidos
    (
        UsuarioId,
        FechaPedido,
        Estado,
        TipoEntrega,
        DireccionEntrega,
        Total,
        Observaciones,
        IdentificacionCliente,
        VendedorUsuarioId,
        VendedorNombre,
        CanalPedido,
        FechaActualizacion
    )
    VALUES
    (
        @ClienteUsuarioId,
        SYSDATETIME(),
        'Pendiente',
        @TipoEntrega,
        LEFT(@DireccionEntrega, 255),
        @Total,
        LEFT(@Observaciones, 255),
        @IdentificacionCliente,
        @VendedorUsuarioId,
        @VendedorNombre,
        'Venta móvil',
        SYSDATETIME()
    );

    SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, ProductoId, Cantidad, Precio
    FROM @Items;

    COMMIT TRANSACTION;

    SELECT @PedidoId;
END;
GO

PRINT 'CU-071 aplicado correctamente: venta móvil, permiso y pedido por vendedor.';
GO

USE DistribuidoraJJ_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetOrderHeader
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PedidoId,
        p.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        p.FechaPedido,
        p.Estado,
        p.TipoEntrega,
        p.DireccionEntrega,
        p.Observaciones,
        p.Total
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u
        ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;
END;
GO

PRINT 'sp_Admin_GetOrderHeader corregido correctamente.';
GO
