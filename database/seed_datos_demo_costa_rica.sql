USE DistribuidoraJJ_DB;
GO

/* =========================================================
   Datos demo Costa Rica - Licorera La Bodega / DistribuidoraJJ
   Ejecutar después de aplicar todos los parches CU-033, CU-041,
   CU-042, CU-043, CU-055, CU-056, CU-061, CU-062 y CU-071.

   Script incremental: no elimina datos existentes y evita duplicados.
   La credencial temporal debe proporcionarse al ejecutar y nunca guardarse en Git.
   ========================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DemoPassword NVARCHAR(256) = N'<SET_AT_EXECUTION>';
IF @DemoPassword = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 59008, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.Perfiles', 'U') IS NULL THROW 59001, 'Falta tabla dbo.Perfiles.', 1;
    IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL THROW 59002, 'Falta tabla dbo.Usuarios.', 1;
    IF OBJECT_ID('dbo.Productos', 'U') IS NULL THROW 59003, 'Falta tabla dbo.Productos.', 1;
    IF OBJECT_ID('dbo.Pedidos', 'U') IS NULL THROW 59004, 'Falta tabla dbo.Pedidos.', 1;
    IF OBJECT_ID('dbo.PedidoDetalle', 'U') IS NULL THROW 59005, 'Falta tabla dbo.PedidoDetalle.', 1;
    IF OBJECT_ID('dbo.Facturas', 'U') IS NULL THROW 59006, 'Falta tabla dbo.Facturas.', 1;
    IF OBJECT_ID('dbo.FacturaDetalle', 'U') IS NULL THROW 59007, 'Falta tabla dbo.FacturaDetalle.', 1;

    IF COL_LENGTH('dbo.Productos', 'StockMinimo') IS NULL
    BEGIN
        ALTER TABLE dbo.Productos ADD StockMinimo INT NOT NULL CONSTRAINT DF_Productos_StockMinimo DEFAULT (5);
    END;

    /* =========================================================
       1. Roles adicionales
       ========================================================= */
    DECLARE @Roles TABLE (Nombre NVARCHAR(50), Descripcion NVARCHAR(255));
    INSERT INTO @Roles (Nombre, Descripcion)
    VALUES
        (N'Supervisor', N'Supervisa operaciones, inventario y pedidos.'),
        (N'Vendedor', N'Usuario autorizado para registrar pedidos de clientes desde móvil.'),
        (N'Cajero', N'Usuario encargado de cobros y apoyo en facturación.'),
        (N'Bodeguero', N'Usuario encargado de entradas, salidas y control de inventario.'),
        (N'Facturador', N'Usuario encargado de emisión y revisión de facturas.'),
        (N'Chofer', N'Usuario encargado de entregar pedidos a clientes.'),
        (N'Crédito y Cobro', N'Usuario encargado de seguimiento de cuentas por cobrar.'),
        (N'Compras', N'Usuario encargado de abastecimiento y proveedores.'),
        (N'Soporte', N'Usuario encargado de soporte interno del sistema.'),
        (N'Auditor Interno', N'Usuario encargado de revisión de trazabilidad y auditoría.');

    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    SELECT r.Nombre, r.Descripcion, 1
    FROM @Roles r
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Perfiles p WHERE p.Nombre = r.Nombre);

    /* =========================================================
       2. Categorías
       ========================================================= */
    IF OBJECT_ID('dbo.Categorias', 'U') IS NOT NULL
    BEGIN
        DECLARE @Categorias TABLE (Nombre NVARCHAR(100));
        INSERT INTO @Categorias (Nombre)
        VALUES
            (N'Cerveza'),
            (N'Ron'),
            (N'Vodka'),
            (N'Tequila'),
            (N'Whisky'),
            (N'Vino'),
            (N'Ginebra'),
            (N'Energéticas'),
            (N'Refrescos'),
            (N'Snacks'),
            (N'Hielo'),
            (N'Mayoreo');

        INSERT INTO dbo.Categorias (Nombre, Activo)
        SELECT c.Nombre, 1
        FROM @Categorias c
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Categorias x WHERE x.Nombre = c.Nombre);
    END;

    /* =========================================================
       3. Productos demo
       ========================================================= */
    DECLARE @Productos TABLE
    (
        Nombre NVARCHAR(150), Categoria NVARCHAR(100), Descripcion NVARCHAR(255),
        Precio DECIMAL(18,2), Stock INT, StockMinimo INT, ImagenUrl NVARCHAR(300), EsDestacado BIT, Activo BIT
    );

    INSERT INTO @Productos (Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, ImagenUrl, EsDestacado, Activo)
    VALUES
        (N'Cacique Superior 1L', N'Ron', N'Guaro nacional costarricense, presentación de 1 litro.', 8200, 42, 10, N'~/img/productos/cacique-superior-1l.png', 1, 1),
        (N'Imperial Silver 6 Pack', N'Cerveza', N'Cerveza costarricense en paquete de 6 unidades.', 6900, 55, 12, N'~/img/productos/imperial-silver-6pack.png', 1, 1),
        (N'Pilsen 6 Pack', N'Cerveza', N'Cerveza tipo lager en paquete de 6 unidades.', 6500, 48, 12, N'~/img/productos/pilsen-6pack.png', 1, 1),
        (N'Bavaria Gold 6 Pack', N'Cerveza', N'Cerveza premium en paquete de 6 unidades.', 7900, 34, 8, N'~/img/productos/bavaria-gold-6pack.png', 0, 1),
        (N'Flor de Caña 7 Años 750ml', N'Ron', N'Ron añejo centroamericano de 750ml.', 15900, 18, 5, N'~/img/productos/flor-cana-7-750.png', 1, 1),
        (N'Smirnoff Vodka 750ml', N'Vodka', N'Vodka clásico para coctelería y eventos.', 11900, 22, 6, N'~/img/productos/smirnoff-750.png', 0, 1),
        (N'Jose Cuervo Especial 750ml', N'Tequila', N'Tequila reposado de 750ml.', 18900, 15, 5, N'~/img/productos/jose-cuervo-750.png', 0, 1),
        (N'Jack Daniel''s 750ml', N'Whisky', N'Whisky Tennessee de 750ml.', 26900, 12, 4, N'~/img/productos/jack-daniels-750.png', 1, 1),
        (N'Casillero del Diablo Cabernet 750ml', N'Vino', N'Vino tinto Cabernet Sauvignon de 750ml.', 9900, 20, 5, N'~/img/productos/casillero-cabernet.png', 0, 1),
        (N'Tanqueray Gin 750ml', N'Ginebra', N'Ginebra seca premium para coctelería.', 23900, 10, 3, N'~/img/productos/tanqueray-750.png', 0, 1),
        (N'Red Bull 250ml', N'Energéticas', N'Bebida energética lata de 250ml.', 1700, 80, 20, N'~/img/productos/redbull-250.png', 0, 1),
        (N'Coca-Cola 2.5L', N'Refrescos', N'Refresco familiar botella 2.5 litros.', 2100, 65, 18, N'~/img/productos/coca-cola-25.png', 0, 1),
        (N'Ginger Ale 2L', N'Refrescos', N'Refresco ginger ale botella 2 litros.', 1950, 38, 10, N'~/img/productos/ginger-ale-2l.png', 0, 1),
        (N'Bolsa de Hielo 2kg', N'Hielo', N'Hielo empacado para eventos y comercios.', 1200, 90, 25, N'~/img/productos/hielo-2kg.png', 0, 1),
        (N'Yucas Tostadas 150g', N'Snacks', N'Snack salado nacional para acompañamiento.', 1650, 40, 10, N'~/img/productos/yucas-150g.png', 0, 1);

    INSERT INTO dbo.Productos
    (
        Nombre, Categoria, CategoriaId, Descripcion, Precio, Stock, StockMinimo,
        ImagenUrl, EsDestacado, Activo
    )
    SELECT
        p.Nombre,
        p.Categoria,
        (SELECT TOP 1 c.CategoriaId FROM dbo.Categorias c WHERE c.Nombre = p.Categoria),
        p.Descripcion,
        p.Precio,
        p.Stock,
        p.StockMinimo,
        p.ImagenUrl,
        p.EsDestacado,
        p.Activo
    FROM @Productos p
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos x WHERE x.Nombre = p.Nombre);

    UPDATE pr
    SET
        pr.CategoriaId = ISNULL(pr.CategoriaId, c.CategoriaId),
        pr.StockMinimo = CASE WHEN pr.StockMinimo IS NULL OR pr.StockMinimo <= 0 THEN p.StockMinimo ELSE pr.StockMinimo END
    FROM dbo.Productos pr
    INNER JOIN @Productos p ON p.Nombre = pr.Nombre
    LEFT JOIN dbo.Categorias c ON c.Nombre = p.Categoria;

    /* =========================================================
       4. Clientes demo de Costa Rica
       ========================================================= */
    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');
    DECLARE @AdminPerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = N'Administrador');

    IF @ClientePerfilId IS NULL THROW 59008, 'No existe el perfil Cliente.', 1;

    DECLARE @Clientes TABLE
    (
        NombreCompleto NVARCHAR(150), Correo NVARCHAR(150), Telefono NVARCHAR(30), Direccion NVARCHAR(255), Activo BIT
    );

    INSERT INTO @Clientes (NombreCompleto, Correo, Telefono, Direccion, Activo)
    VALUES
        (N'Pulpería El Tucán', N'eltucan@clientes.labodega.cr', N'8881-1101', N'Barva de Heredia, 200 m norte del parque central', 1),
        (N'Minisúper La Sabana', N'lasabana@clientes.labodega.cr', N'8312-4502', N'Sabana Sur, San José, frente al estadio', 1),
        (N'Licorera Pura Vida', N'puravida@clientes.labodega.cr', N'7005-3321', N'San Pedro de Montes de Oca, calle principal', 1),
        (N'Super Don Beto', N'donbeto@clientes.labodega.cr', N'8820-7788', N'Alajuela Centro, avenida 2', 1),
        (N'Bar y Restaurante El Mirador', N'elmirador@clientes.labodega.cr', N'6054-2099', N'Escazú, San Rafael, contiguo a plaza comercial', 1),
        (N'Abastecedor Los Lagos', N'loslagos@clientes.labodega.cr', N'8719-3344', N'Heredia, Ulloa, Urbanización Los Lagos', 1),
        (N'Soda y Bar La Carreta', N'lacarreta@clientes.labodega.cr', N'7201-1188', N'Cartago Centro, 100 m este de las ruinas', 1),
        (N'Hotel Camino Verde', N'caminovverde@clientes.labodega.cr', N'8530-5522', N'La Fortuna de San Carlos, ruta hacia el volcán', 1),
        (N'Eventos Ticos CR', N'eventosticos@clientes.labodega.cr', N'8889-9001', N'Curridabat, Granadilla, bodega 4', 1),
        (N'Marisquería Puerto Azul', N'puertoazul@clientes.labodega.cr', N'7288-4433', N'Puntarenas Centro, paseo de los turistas', 1),
        (N'La Esquina del Sabor', N'esquinasabor@clientes.labodega.cr', N'6177-2020', N'Desamparados, San Rafael Abajo', 1),
        (N'Comercial Santa Lucía', N'santalucia@clientes.labodega.cr', N'8877-6161', N'San Rafael de Heredia, Santa Lucía', 0);

    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion, Activo)
    SELECT @ClientePerfilId, c.NombreCompleto, c.Correo, @DemoPassword, c.Telefono, c.Direccion, c.Activo
    FROM @Clientes c
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Usuarios u WHERE u.Correo = c.Correo);

    UPDATE u
    SET
        u.Telefono = c.Telefono,
        u.Direccion = c.Direccion,
        u.Activo = c.Activo,
        u.MotivoInactivacion = CASE WHEN c.Activo = 0 THEN N'Cuenta demo inactiva para pruebas de suspensión comercial.' ELSE NULL END,
        u.FechaInactivacion = CASE WHEN c.Activo = 0 THEN DATEADD(DAY, -5, SYSDATETIME()) ELSE NULL END,
        u.FechaActualizacion = SYSDATETIME()
    FROM dbo.Usuarios u
    INNER JOIN @Clientes c ON c.Correo = u.Correo
    WHERE COL_LENGTH('dbo.Usuarios', 'MotivoInactivacion') IS NOT NULL;

    /* =========================================================
       5. Empleados demo
       ========================================================= */
    DECLARE @EmpleadosSeed TABLE
    (
        NombreCompleto NVARCHAR(150), Correo NVARCHAR(150), Telefono NVARCHAR(30), Direccion NVARCHAR(255), PerfilNombre NVARCHAR(50), Puesto NVARCHAR(100), Salario DECIMAL(18,2), FechaContratacion DATE
    );

    INSERT INTO @EmpleadosSeed (NombreCompleto, Correo, Telefono, Direccion, PerfilNombre, Puesto, Salario, FechaContratacion)
    VALUES
        (N'Ana Lucía Mora Vargas', N'amora@labodega.cr', N'8890-1001', N'Heredia Centro', N'Supervisor', N'Supervisora de operaciones', 720000, '2025-02-03'),
        (N'José Andrés Solís Castro', N'jsolis@labodega.cr', N'8890-1002', N'Barva de Heredia', N'Vendedor', N'Vendedor ruta GAM', 510000, '2025-03-10'),
        (N'Marco Vinicio Arias Soto', N'marias@labodega.cr', N'8890-1003', N'Alajuela Centro', N'Vendedor', N'Vendedor ruta Alajuela', 500000, '2025-04-15'),
        (N'Gabriela Chaves Rojas', N'gchaves@labodega.cr', N'8890-1004', N'San José, Tibás', N'Cajero', N'Cajera principal', 465000, '2025-01-20'),
        (N'Luis Fernando Brenes Mora', N'lbrenes@labodega.cr', N'8890-1005', N'Santo Domingo de Heredia', N'Bodeguero', N'Encargado de bodega', 485000, '2025-05-01'),
        (N'Karla María Jiménez León', N'kjimenez@labodega.cr', N'8890-1006', N'Curridabat', N'Facturador', N'Asistente de facturación', 490000, '2025-02-17'),
        (N'Randall Quirós Méndez', N'rquiros@labodega.cr', N'8890-1007', N'Alajuelita', N'Chofer', N'Chofer repartidor', 455000, '2025-06-12'),
        (N'Silvia Patricia Campos Ruiz', N'scampos@labodega.cr', N'8890-1008', N'Moravia', N'Crédito y Cobro', N'Analista de crédito y cobro', 610000, '2025-03-03'),
        (N'Diego Armando Vargas Rojas', N'dvargas@labodega.cr', N'8890-1009', N'Cartago, Tres Ríos', N'Compras', N'Encargado de compras', 590000, '2025-04-08'),
        (N'Paola Andrea Núñez Salas', N'pnunez@labodega.cr', N'8890-1010', N'San Pedro de Montes de Oca', N'Auditor Interno', N'Auditora interna', 650000, '2025-01-08');

    INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion, Activo)
    SELECT p.PerfilId, e.NombreCompleto, e.Correo, @DemoPassword, e.Telefono, e.Direccion, 1
    FROM @EmpleadosSeed e
    INNER JOIN dbo.Perfiles p ON p.Nombre = e.PerfilNombre
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Usuarios u WHERE u.Correo = e.Correo);

    IF OBJECT_ID('dbo.Empleados', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.Empleados (UsuarioId, Puesto, Salario, FechaContratacion, Activo)
        SELECT u.UsuarioId, e.Puesto, e.Salario, e.FechaContratacion, 1
        FROM @EmpleadosSeed e
        INNER JOIN dbo.Usuarios u ON u.Correo = e.Correo
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Empleados x WHERE x.UsuarioId = u.UsuarioId);
    END;

    /* =========================================================
       6. Movimientos iniciales de inventario para productos demo
       ========================================================= */
    DECLARE @AdminId INT = (SELECT TOP 1 UsuarioId FROM dbo.Usuarios WHERE Correo = N'admin@distribuidorajj.com');
    DECLARE @AdminNombre NVARCHAR(150) = ISNULL((SELECT TOP 1 NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @AdminId), N'Administrador General');

    IF @AdminId IS NOT NULL AND OBJECT_ID('dbo.MovimientosInventario', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.MovimientosInventario (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre, FechaMovimiento)
        SELECT p.ProductoId, p.Nombre, N'Entrada', p.Stock, 0, p.Stock, N'Carga demo Costa Rica para ambiente de pruebas.', @AdminId, @AdminNombre, DATEADD(DAY, -30, SYSDATETIME())
        FROM dbo.Productos p
        INNER JOIN @Productos sp ON sp.Nombre = p.Nombre
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.MovimientosInventario mi
            WHERE mi.ProductoId = p.ProductoId
              AND mi.Motivo = N'Carga demo Costa Rica para ambiente de pruebas.'
        );
    END;

    /* =========================================================
       7. Pedidos demo y detalles
       ========================================================= */
    DECLARE @Ordenes TABLE
    (
        Codigo NVARCHAR(30), ClienteCorreo NVARCHAR(150), Estado NVARCHAR(30), TipoEntrega NVARCHAR(50), DireccionEntrega NVARCHAR(255), Observaciones NVARCHAR(255), FechaOffset INT
    );

    INSERT INTO @Ordenes (Codigo, ClienteCorreo, Estado, TipoEntrega, DireccionEntrega, Observaciones, FechaOffset)
    VALUES
        (N'SEED-CR-001', N'eltucan@clientes.labodega.cr', N'Entregado', N'Entrega a domicilio', N'Barva de Heredia, 200 m norte del parque central', N'Entrega antes del mediodía.', -15),
        (N'SEED-CR-002', N'lasabana@clientes.labodega.cr', N'Entregado', N'Entrega a domicilio', N'Sabana Sur, San José', N'Pedido para abastecimiento de fin de semana.', -13),
        (N'SEED-CR-003', N'puravida@clientes.labodega.cr', N'Facturado', N'Retiro en tienda', N'Sucursal principal', N'Retiro por encargado autorizado.', -11),
        (N'SEED-CR-004', N'donbeto@clientes.labodega.cr', N'Preparando', N'Entrega a domicilio', N'Alajuela Centro, avenida 2', N'Confirmar disponibilidad de hielo.', -9),
        (N'SEED-CR-005', N'elmirador@clientes.labodega.cr', N'Pendiente', N'Entrega a domicilio', N'Escazú, San Rafael', N'Cliente solicita factura electrónica.', -7),
        (N'SEED-CR-006', N'loslagos@clientes.labodega.cr', N'Entregado', N'Entrega a domicilio', N'Heredia, Ulloa', N'Entregar por entrada de proveedores.', -6),
        (N'SEED-CR-007', N'lacarreta@clientes.labodega.cr', N'Facturado', N'Entrega a domicilio', N'Cartago Centro', N'Pedido para evento privado.', -5),
        (N'SEED-CR-008', N'caminovverde@clientes.labodega.cr', N'Entregado', N'Entrega a domicilio', N'La Fortuna de San Carlos', N'Coordinar entrega con recepción.', -4),
        (N'SEED-CR-009', N'eventosticos@clientes.labodega.cr', N'Pendiente', N'Entrega a domicilio', N'Curridabat, Granadilla, bodega 4', N'Pedido para actividad corporativa.', -3),
        (N'SEED-CR-010', N'puertoazul@clientes.labodega.cr', N'Preparando', N'Entrega a domicilio', N'Puntarenas Centro', N'Ruta especial hacia Puntarenas.', -2);

    DECLARE @OrdenItems TABLE
    (
        Codigo NVARCHAR(30), ProductoNombre NVARCHAR(150), Cantidad INT
    );

    INSERT INTO @OrdenItems (Codigo, ProductoNombre, Cantidad)
    VALUES
        (N'SEED-CR-001', N'Cacique Superior 1L', 3), (N'SEED-CR-001', N'Imperial Silver 6 Pack', 2), (N'SEED-CR-001', N'Bolsa de Hielo 2kg', 4),
        (N'SEED-CR-002', N'Pilsen 6 Pack', 4), (N'SEED-CR-002', N'Coca-Cola 2.5L', 6),
        (N'SEED-CR-003', N'Jack Daniel''s 750ml', 1), (N'SEED-CR-003', N'Red Bull 250ml', 12),
        (N'SEED-CR-004', N'Bavaria Gold 6 Pack', 3), (N'SEED-CR-004', N'Bolsa de Hielo 2kg', 6),
        (N'SEED-CR-005', N'Flor de Caña 7 Años 750ml', 2), (N'SEED-CR-005', N'Ginger Ale 2L', 6),
        (N'SEED-CR-006', N'Smirnoff Vodka 750ml', 2), (N'SEED-CR-006', N'Red Bull 250ml', 24),
        (N'SEED-CR-007', N'Jose Cuervo Especial 750ml', 2), (N'SEED-CR-007', N'Yucas Tostadas 150g', 10),
        (N'SEED-CR-008', N'Casillero del Diablo Cabernet 750ml', 6), (N'SEED-CR-008', N'Coca-Cola 2.5L', 8),
        (N'SEED-CR-009', N'Tanqueray Gin 750ml', 1), (N'SEED-CR-009', N'Red Bull 250ml', 18), (N'SEED-CR-009', N'Bolsa de Hielo 2kg', 8),
        (N'SEED-CR-010', N'Imperial Silver 6 Pack', 5), (N'SEED-CR-010', N'Pilsen 6 Pack', 4), (N'SEED-CR-010', N'Yucas Tostadas 150g', 12);

    DECLARE @Codigo NVARCHAR(30), @ClienteCorreo NVARCHAR(150), @Estado NVARCHAR(30), @TipoEntrega NVARCHAR(50), @DireccionEntrega NVARCHAR(255), @Observaciones NVARCHAR(255), @FechaOffset INT;
    DECLARE @PedidoId INT, @ClienteId INT, @TotalPedido DECIMAL(18,2);

    DECLARE order_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Codigo, ClienteCorreo, Estado, TipoEntrega, DireccionEntrega, Observaciones, FechaOffset
        FROM @Ordenes;

    OPEN order_cursor;
    FETCH NEXT FROM order_cursor INTO @Codigo, @ClienteCorreo, @Estado, @TipoEntrega, @DireccionEntrega, @Observaciones, @FechaOffset;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE IdentificacionCliente = @Codigo)
        BEGIN
            SELECT @ClienteId = UsuarioId FROM dbo.Usuarios WHERE Correo = @ClienteCorreo;

            SELECT @TotalPedido = SUM(oi.Cantidad * p.Precio)
            FROM @OrdenItems oi
            INNER JOIN dbo.Productos p ON p.Nombre = oi.ProductoNombre
            WHERE oi.Codigo = @Codigo;

            INSERT INTO dbo.Pedidos
            (
                UsuarioId, FechaPedido, Estado, TipoEntrega, DireccionEntrega, Total, Observaciones,
                IdentificacionCliente, VendedorUsuarioId, VendedorNombre, CanalPedido, FechaActualizacion
            )
            VALUES
            (
                @ClienteId, DATEADD(DAY, @FechaOffset, SYSDATETIME()), @Estado, @TipoEntrega, @DireccionEntrega, @TotalPedido, @Observaciones,
                @Codigo, @AdminId, @AdminNombre, N'Venta móvil', DATEADD(DAY, @FechaOffset, SYSDATETIME())
            );

            SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);

            INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
            SELECT @PedidoId, p.ProductoId, oi.Cantidad, p.Precio
            FROM @OrdenItems oi
            INNER JOIN dbo.Productos p ON p.Nombre = oi.ProductoNombre
            WHERE oi.Codigo = @Codigo;
        END;

        FETCH NEXT FROM order_cursor INTO @Codigo, @ClienteCorreo, @Estado, @TipoEntrega, @DireccionEntrega, @Observaciones, @FechaOffset;
    END;

    CLOSE order_cursor;
    DEALLOCATE order_cursor;

    /* =========================================================
       8. Facturas demo
       ========================================================= */
    DECLARE @Facturas TABLE (Codigo NVARCHAR(30), NumeroFactura NVARCHAR(30), Estado NVARCHAR(20));
    INSERT INTO @Facturas (Codigo, NumeroFactura, Estado)
    VALUES
        (N'SEED-CR-001', N'FE-CR-2026-001', N'Generada'),
        (N'SEED-CR-002', N'FE-CR-2026-002', N'Generada'),
        (N'SEED-CR-003', N'FE-CR-2026-003', N'Generada'),
        (N'SEED-CR-004', N'FE-CR-2026-004', N'Pendiente'),
        (N'SEED-CR-005', N'FE-CR-2026-005', N'Pendiente'),
        (N'SEED-CR-006', N'FE-CR-2026-006', N'Generada'),
        (N'SEED-CR-007', N'FE-CR-2026-007', N'Generada'),
        (N'SEED-CR-008', N'FE-CR-2026-008', N'Generada'),
        (N'SEED-CR-009', N'FE-CR-2026-009', N'Pendiente'),
        (N'SEED-CR-010', N'FE-CR-2026-010', N'Pendiente');

    DECLARE @NumeroFactura NVARCHAR(30), @FacturaEstado NVARCHAR(20), @Subtotal DECIMAL(18,2), @Impuesto DECIMAL(18,2), @TotalFactura DECIMAL(18,2), @FacturaId INT;
    DECLARE factura_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo, NumeroFactura, Estado FROM @Facturas;

    OPEN factura_cursor;
    FETCH NEXT FROM factura_cursor INTO @Codigo, @NumeroFactura, @FacturaEstado;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @PedidoId = PedidoId FROM dbo.Pedidos WHERE IdentificacionCliente = @Codigo;

        IF @PedidoId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Facturas WHERE PedidoId = @PedidoId OR NumeroFactura = @NumeroFactura)
        BEGIN
            SELECT @Subtotal = SUM(Cantidad * PrecioUnitario) FROM dbo.PedidoDetalle WHERE PedidoId = @PedidoId;
            SET @Impuesto = ROUND(@Subtotal * 0.13, 2);
            SET @TotalFactura = @Subtotal + @Impuesto;

            INSERT INTO dbo.Facturas
            (
                PedidoId, NumeroFactura, UsuarioId, ClienteNombre, ClienteCorreo,
                FechaFactura, Subtotal, Impuesto, Total, Estado
            )
            SELECT
                p.PedidoId, @NumeroFactura, u.UsuarioId, u.NombreCompleto, u.Correo,
                DATEADD(HOUR, 2, p.FechaPedido), @Subtotal, @Impuesto, @TotalFactura, @FacturaEstado
            FROM dbo.Pedidos p
            INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
            WHERE p.PedidoId = @PedidoId;

            SET @FacturaId = CAST(SCOPE_IDENTITY() AS INT);

            INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
            SELECT @FacturaId, pd.ProductoId, pr.Nombre, pd.Cantidad, pd.PrecioUnitario
            FROM dbo.PedidoDetalle pd
            INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
            WHERE pd.PedidoId = @PedidoId;
        END;

        FETCH NEXT FROM factura_cursor INTO @Codigo, @NumeroFactura, @FacturaEstado;
    END;

    CLOSE factura_cursor;
    DEALLOCATE factura_cursor;

    /* =========================================================
       9. Consultas demo
       ========================================================= */
    IF OBJECT_ID('dbo.Consultas', 'U') IS NOT NULL
    BEGIN
        DECLARE @Consultas TABLE (Nombre NVARCHAR(100), Correo NVARCHAR(150), Asunto NVARCHAR(120), Mensaje NVARCHAR(1000), Estado NVARCHAR(30), RespuestaInterna NVARCHAR(1000));
        INSERT INTO @Consultas (Nombre, Correo, Asunto, Mensaje, Estado, RespuestaInterna)
        VALUES
            (N'María Fernanda Rojas', N'mfrojas.demo@correo.cr', N'Consulta sobre mayoreo', N'Buenas tardes, deseo información sobre precios especiales para compras mayores a 10 cajas de cerveza.', N'Pendiente', NULL),
            (N'Pulpería El Tucán', N'eltucan@clientes.labodega.cr', N'Horario de entrega en Heredia', N'Necesitamos confirmar si pueden entregar los sábados en Barva antes del mediodía.', N'Atendida', N'Se confirma entrega sabatina según disponibilidad de ruta.'),
            (N'Eventos Ticos CR', N'eventosticos@clientes.labodega.cr', N'Cotización para evento', N'Requerimos cotización de bebidas y hielo para evento corporativo de 80 personas.', N'Pendiente', NULL),
            (N'Hotel Camino Verde', N'caminovverde@clientes.labodega.cr', N'Factura electrónica', N'Solicitamos confirmar los datos necesarios para facturación electrónica.', N'Cerrada', N'Se indicaron requisitos y correo de facturación.'),
            (N'Bar El Mirador', N'elmirador@clientes.labodega.cr', N'Producto agotado', N'¿Cuándo vuelve a ingresar Jack Daniel''s de 750ml?', N'Atendida', N'Se informó fecha estimada de reposición.'),
            (N'Juan Carlos Umaña', N'jumana.demo@correo.cr', N'Apertura de cliente', N'Deseo abrir cuenta para mi minisúper en Guadalupe.', N'Pendiente', NULL),
            (N'Marisquería Puerto Azul', N'puertoazul@clientes.labodega.cr', N'Ruta a Puntarenas', N'Queremos saber si tienen entregas semanales en Puntarenas.', N'Atendida', N'Se confirmó ruta especial dos veces por semana.'),
            (N'Soda La Carreta', N'lacarreta@clientes.labodega.cr', N'Crédito comercial', N'Nos gustaría consultar requisitos para crédito comercial.', N'Pendiente', NULL),
            (N'Abastecedor Los Lagos', N'loslagos@clientes.labodega.cr', N'Devolución de producto', N'Tenemos una consulta sobre devolución de mercadería dañada.', N'Cerrada', N'Caso revisado y cerrado con reposición parcial.'),
            (N'Comercial Santa Lucía', N'santalucia@clientes.labodega.cr', N'Reactivación de cuenta', N'Solicitamos información para reactivar nuestra cuenta comercial.', N'Pendiente', NULL);

        INSERT INTO dbo.Consultas (Nombre, Correo, Asunto, Mensaje, Estado, RespuestaInterna, AtendidoPorUsuarioId, AtendidoPorNombre, FechaAtencion, FechaCreacion)
        SELECT c.Nombre, c.Correo, c.Asunto, c.Mensaje, c.Estado, c.RespuestaInterna,
               CASE WHEN c.Estado IN (N'Atendida', N'Cerrada') THEN @AdminId ELSE NULL END,
               CASE WHEN c.Estado IN (N'Atendida', N'Cerrada') THEN @AdminNombre ELSE NULL END,
               CASE WHEN c.Estado IN (N'Atendida', N'Cerrada') THEN DATEADD(DAY, -1, SYSDATETIME()) ELSE NULL END,
               DATEADD(DAY, -ABS(CHECKSUM(c.Correo)) % 20, SYSDATETIME())
        FROM @Consultas c
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Consultas x WHERE x.Correo = c.Correo AND x.Asunto = c.Asunto);
    END;

    /* =========================================================
       10. Créditos y movimientos financieros
       ========================================================= */
    IF OBJECT_ID('dbo.ClienteCreditos', 'U') IS NOT NULL AND OBJECT_ID('dbo.ClienteCreditoMovimientos', 'U') IS NOT NULL
    BEGIN
        DECLARE @Creditos TABLE (Correo NVARCHAR(150), Limite DECIMAL(18,2), Activo BIT, Bloqueado BIT, Motivo NVARCHAR(255));
        INSERT INTO @Creditos (Correo, Limite, Activo, Bloqueado, Motivo)
        VALUES
            (N'eltucan@clientes.labodega.cr', 300000, 1, 0, NULL),
            (N'lasabana@clientes.labodega.cr', 450000, 1, 0, NULL),
            (N'puravida@clientes.labodega.cr', 350000, 1, 0, NULL),
            (N'donbeto@clientes.labodega.cr', 250000, 1, 0, NULL),
            (N'elmirador@clientes.labodega.cr', 500000, 1, 0, NULL),
            (N'loslagos@clientes.labodega.cr', 280000, 1, 0, NULL),
            (N'lacarreta@clientes.labodega.cr', 220000, 1, 0, NULL),
            (N'caminovverde@clientes.labodega.cr', 600000, 1, 0, NULL),
            (N'eventosticos@clientes.labodega.cr', 400000, 1, 0, NULL),
            (N'puertoazul@clientes.labodega.cr', 320000, 1, 0, NULL),
            (N'santalucia@clientes.labodega.cr', 100000, 0, 1, N'Cliente inactivo para pruebas de suspensión comercial.');

        INSERT INTO dbo.ClienteCreditos (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado, MotivoBloqueo, FechaCreacion, FechaActualizacion)
        SELECT u.UsuarioId, c.Limite, c.Activo, c.Bloqueado, c.Motivo, DATEADD(DAY, -18, SYSDATETIME()), SYSDATETIME()
        FROM @Creditos c
        INNER JOIN dbo.Usuarios u ON u.Correo = c.Correo
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ClienteCreditos cc WHERE cc.UsuarioId = u.UsuarioId);

        UPDATE cc
        SET cc.LimiteCredito = c.Limite,
            cc.CreditoActivo = c.Activo,
            cc.CreditoBloqueado = c.Bloqueado,
            cc.MotivoBloqueo = c.Motivo,
            cc.FechaActualizacion = SYSDATETIME()
        FROM dbo.ClienteCreditos cc
        INNER JOIN dbo.Usuarios u ON u.UsuarioId = cc.UsuarioId
        INNER JOIN @Creditos c ON c.Correo = u.Correo;

        DECLARE @MovCreditos TABLE (Correo NVARCHAR(150), Tipo NVARCHAR(30), Monto DECIMAL(18,2), Descripcion NVARCHAR(500), Referencia NVARCHAR(100), FechaOffset INT);
        INSERT INTO @MovCreditos (Correo, Tipo, Monto, Descripcion, Referencia, FechaOffset)
        VALUES
            (N'eltucan@clientes.labodega.cr', N'Cargo', 62000, N'Crédito por pedido FE-CR-2026-001.', N'FE-CR-2026-001', -14),
            (N'eltucan@clientes.labodega.cr', N'Abono', 20000, N'Abono recibido por transferencia SINPE.', N'SINPE-ELTUCAN-001', -10),
            (N'lasabana@clientes.labodega.cr', N'Cargo', 48000, N'Crédito por pedido FE-CR-2026-002.', N'FE-CR-2026-002', -12),
            (N'puravida@clientes.labodega.cr', N'Cargo', 62000, N'Cargo inicial por mercadería facturada.', N'FE-CR-2026-003', -11),
            (N'puravida@clientes.labodega.cr', N'Abono', 25000, N'Abono parcial en efectivo.', N'ABO-PURAVIDA-001', -7),
            (N'elmirador@clientes.labodega.cr', N'Cargo', 45000, N'Cargo manual por reposición para evento.', N'CARGO-MIRADOR-001', -6),
            (N'loslagos@clientes.labodega.cr', N'AjustePositivo', 7500, N'Ajuste por diferencia de precio en factura.', N'AJU-LOSLAGOS-001', -5),
            (N'lacarreta@clientes.labodega.cr', N'Cargo', 39500, N'Cargo por pedido de evento privado.', N'FE-CR-2026-007', -5),
            (N'lacarreta@clientes.labodega.cr', N'AjusteNegativo', 5000, N'Descuento comercial aplicado por pronto pago.', N'DESC-LACARRETA-001', -3),
            (N'caminovverde@clientes.labodega.cr', N'Cargo', 98000, N'Cargo por abastecimiento hotelero semanal.', N'FE-CR-2026-008', -4),
            (N'eventosticos@clientes.labodega.cr', N'Cargo', 72000, N'Cargo por reservación de mercadería para evento.', N'FE-CR-2026-009', -2),
            (N'puertoazul@clientes.labodega.cr', N'Cargo', 58000, N'Cargo por ruta especial Puntarenas.', N'FE-CR-2026-010', -2);

        INSERT INTO dbo.ClienteCreditoMovimientos (UsuarioId, TipoMovimiento, Monto, Descripcion, Referencia, RegistradoPorUsuarioId, RegistradoPorNombre, FechaMovimiento)
        SELECT u.UsuarioId, m.Tipo, m.Monto, m.Descripcion, m.Referencia, @AdminId, @AdminNombre, DATEADD(DAY, m.FechaOffset, SYSDATETIME())
        FROM @MovCreditos m
        INNER JOIN dbo.Usuarios u ON u.Correo = m.Correo
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.ClienteCreditoMovimientos x
            WHERE x.UsuarioId = u.UsuarioId
              AND x.Referencia = m.Referencia
              AND x.TipoMovimiento = m.Tipo
        );
    END;

    /* =========================================================
       11. Auditoría demo
       ========================================================= */
    IF OBJECT_ID('dbo.AuditoriaSistema', 'U') IS NOT NULL
    BEGIN
        DECLARE @Auditoria TABLE (Modulo NVARCHAR(80), Accion NVARCHAR(80), Descripcion NVARCHAR(500), FechaOffset INT);
        INSERT INTO @Auditoria (Modulo, Accion, Descripcion, FechaOffset)
        VALUES
            (N'Productos', N'Crear', N'Se cargaron productos demo ambientados en Costa Rica.', -30),
            (N'Inventario', N'Entrada', N'Se registraron entradas iniciales de inventario demo.', -30),
            (N'Clientes', N'Crear', N'Se cargaron clientes comerciales demo de Costa Rica.', -25),
            (N'Pedidos', N'Crear', N'Se cargaron pedidos demo para pruebas de venta móvil.', -15),
            (N'Facturación', N'Crear', N'Se generaron facturas demo para pedidos de prueba.', -14),
            (N'Créditos', N'Configurar', N'Se asignaron límites de crédito demo por cliente.', -12),
            (N'Créditos', N'Registrar movimiento', N'Se registraron cargos y abonos demo para cuentas por cobrar.', -10),
            (N'Consultas', N'Crear', N'Se cargaron consultas demo para pruebas de atención.', -8),
            (N'Seguridad', N'Crear', N'Se agregaron roles operativos demo.', -6),
            (N'Auditoría', N'Consulta', N'Se revisó trazabilidad del sistema con datos demo.', -2);

        INSERT INTO dbo.AuditoriaSistema (UsuarioId, UsuarioNombre, UsuarioCorreo, Rol, Accion, Modulo, Descripcion, DireccionIp, UserAgent, FechaRegistro)
        SELECT @AdminId, @AdminNombre, N'admin@distribuidorajj.com', N'Administrador', a.Accion, a.Modulo, a.Descripcion, N'::1', N'Datos demo Costa Rica', DATEADD(DAY, a.FechaOffset, SYSDATETIME())
        FROM @Auditoria a
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.AuditoriaSistema x WHERE x.Descripcion = a.Descripcion
        );
    END;

    /* =========================================================
       12. ErrorLog demo con UsuarioId si existe la columna
       ========================================================= */
    IF OBJECT_ID('dbo.ErrorLog', 'U') IS NOT NULL
    BEGIN
        IF COL_LENGTH('dbo.ErrorLog', 'UsuarioId') IS NOT NULL
        BEGIN
            INSERT INTO dbo.ErrorLog (Mensaje, Origen, StackTrace, Fecha, UsuarioId)
            SELECT v.Mensaje, v.Origen, v.StackTrace, DATEADD(DAY, v.FechaOffset, SYSDATETIME()), @AdminId
            FROM (VALUES
                (N'Validación demo: intento de cargo superior al crédito disponible.', N'CreditsController', N'Dato demo controlado para pruebas.', -9),
                (N'Validación demo: producto sin stock suficiente.', N'SellerOrdersController', N'Dato demo controlado para pruebas.', -8),
                (N'Validación demo: cliente inactivo no puede iniciar sesión.', N'AccountController', N'Dato demo controlado para pruebas.', -7),
                (N'Validación demo: pedido sin productos seleccionados.', N'SellerOrdersController', N'Dato demo controlado para pruebas.', -6),
                (N'Validación demo: factura ya generada para el pedido.', N'BillingController', N'Dato demo controlado para pruebas.', -5),
                (N'Validación demo: consulta no encontrada.', N'ConsultationsController', N'Dato demo controlado para pruebas.', -4),
                (N'Validación demo: rol protegido no editable.', N'RolesController', N'Dato demo controlado para pruebas.', -3),
                (N'Validación demo: permiso de administrador protegido.', N'PermissionsController', N'Dato demo controlado para pruebas.', -2),
                (N'Validación demo: producto con historial no puede eliminarse.', N'InventoryController', N'Dato demo controlado para pruebas.', -1),
                (N'Validación demo: movimiento financiero inválido.', N'CreditsController', N'Dato demo controlado para pruebas.', 0)
            ) v(Mensaje, Origen, StackTrace, FechaOffset)
            WHERE NOT EXISTS (SELECT 1 FROM dbo.ErrorLog e WHERE e.Mensaje = v.Mensaje);
        END
        ELSE
        BEGIN
            INSERT INTO dbo.ErrorLog (Mensaje, Origen, StackTrace, Fecha)
            SELECT v.Mensaje, v.Origen, v.StackTrace, DATEADD(DAY, v.FechaOffset, SYSDATETIME())
            FROM (VALUES
                (N'Validación demo: intento de cargo superior al crédito disponible.', N'CreditsController', N'Dato demo controlado para pruebas.', -9),
                (N'Validación demo: producto sin stock suficiente.', N'SellerOrdersController', N'Dato demo controlado para pruebas.', -8),
                (N'Validación demo: cliente inactivo no puede iniciar sesión.', N'AccountController', N'Dato demo controlado para pruebas.', -7),
                (N'Validación demo: pedido sin productos seleccionados.', N'SellerOrdersController', N'Dato demo controlado para pruebas.', -6),
                (N'Validación demo: factura ya generada para el pedido.', N'BillingController', N'Dato demo controlado para pruebas.', -5),
                (N'Validación demo: consulta no encontrada.', N'ConsultationsController', N'Dato demo controlado para pruebas.', -4),
                (N'Validación demo: rol protegido no editable.', N'RolesController', N'Dato demo controlado para pruebas.', -3),
                (N'Validación demo: permiso de administrador protegido.', N'PermissionsController', N'Dato demo controlado para pruebas.', -2),
                (N'Validación demo: producto con historial no puede eliminarse.', N'InventoryController', N'Dato demo controlado para pruebas.', -1),
                (N'Validación demo: movimiento financiero inválido.', N'CreditsController', N'Dato demo controlado para pruebas.', 0)
            ) v(Mensaje, Origen, StackTrace, FechaOffset)
            WHERE NOT EXISTS (SELECT 1 FROM dbo.ErrorLog e WHERE e.Mensaje = v.Mensaje);
        END;
    END;

    COMMIT TRANSACTION;

    PRINT 'Datos demo Costa Rica cargados correctamente.';
    PRINT 'Usuarios demo creados con una credencial temporal proporcionada fuera del repositorio.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorNumber INT = ERROR_NUMBER();
    DECLARE @ErrorLine INT = ERROR_LINE();

    PRINT 'Error al cargar datos demo.';
    PRINT CONCAT('Número: ', @ErrorNumber, ' Línea: ', @ErrorLine, ' Mensaje: ', @ErrorMessage);
    THROW;
END CATCH;
GO

/* Resumen rápido */
SELECT 'Clientes demo' AS Seccion, COUNT(1) AS Total
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Cliente' AND u.Correo LIKE '%@clientes.labodega.cr'
UNION ALL
SELECT 'Empleados demo', COUNT(1)
FROM dbo.Usuarios u
WHERE u.Correo LIKE '%@labodega.cr' AND u.Correo <> 'admin@distribuidorajj.com'
UNION ALL
SELECT 'Productos demo', COUNT(1)
FROM dbo.Productos
WHERE ImagenUrl LIKE '~/img/productos/%'
UNION ALL
SELECT 'Pedidos demo', COUNT(1)
FROM dbo.Pedidos
WHERE IdentificacionCliente LIKE 'SEED-CR-%'
UNION ALL
SELECT 'Facturas demo', COUNT(1)
FROM dbo.Facturas
WHERE NumeroFactura LIKE 'FE-CR-2026-%';
GO
