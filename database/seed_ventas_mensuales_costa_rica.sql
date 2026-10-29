USE DistribuidoraJJ_DB;
GO

/* =========================================================
   Ventas mensuales demo Costa Rica - Licorera La Bodega
   Ejecutar DESPUÉS de seed_datos_demo_costa_rica.sql.

   Objetivo:
   - Cargar ventas distribuidas durante los últimos 12 meses.
   - Alimentar reportes de Ventas por mes, Facturación y Dashboard.
   - Script incremental: no borra datos y evita duplicados.
   ========================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL THROW 60001, 'Falta tabla dbo.Usuarios.', 1;
    IF OBJECT_ID('dbo.Productos', 'U') IS NULL THROW 60002, 'Falta tabla dbo.Productos.', 1;
    IF OBJECT_ID('dbo.Pedidos', 'U') IS NULL THROW 60003, 'Falta tabla dbo.Pedidos.', 1;
    IF OBJECT_ID('dbo.PedidoDetalle', 'U') IS NULL THROW 60004, 'Falta tabla dbo.PedidoDetalle.', 1;
    IF OBJECT_ID('dbo.Facturas', 'U') IS NULL THROW 60005, 'Falta tabla dbo.Facturas.', 1;
    IF OBJECT_ID('dbo.FacturaDetalle', 'U') IS NULL THROW 60006, 'Falta tabla dbo.FacturaDetalle.', 1;

    DECLARE @AdminId INT = (SELECT TOP 1 UsuarioId FROM dbo.Usuarios WHERE Correo = N'admin@distribuidorajj.com');
    DECLARE @AdminNombre NVARCHAR(150) = ISNULL((SELECT TOP 1 NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @AdminId), N'Administrador General');

    IF @AdminId IS NULL THROW 60007, 'No se encontró el usuario administrador admin@distribuidorajj.com.', 1;

    /* Validar datos base del seed principal */
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'eltucan@clientes.labodega.cr')
        THROW 60008, 'Primero ejecute seed_datos_demo_costa_rica.sql. No se encontraron clientes demo.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Cacique Superior 1L')
        THROW 60009, 'Primero ejecute seed_datos_demo_costa_rica.sql. No se encontraron productos demo.', 1;

    /* =========================================================
       1. Ventas distribuidas por mes
       ========================================================= */
    DECLARE @VentasMensuales TABLE
    (
        Codigo NVARCHAR(40),
        NumeroFactura NVARCHAR(40),
        ClienteCorreo NVARCHAR(150),
        MesOffset INT,
        Dia INT,
        Producto1 NVARCHAR(150), Cantidad1 INT,
        Producto2 NVARCHAR(150), Cantidad2 INT,
        Producto3 NVARCHAR(150), Cantidad3 INT,
        Observaciones NVARCHAR(255)
    );

    INSERT INTO @VentasMensuales
    (
        Codigo, NumeroFactura, ClienteCorreo, MesOffset, Dia,
        Producto1, Cantidad1, Producto2, Cantidad2, Producto3, Cantidad3, Observaciones
    )
    VALUES
        /* Mes actual */
        (N'SEED-MES-00-01', N'FE-CR-MES-00-01', N'eltucan@clientes.labodega.cr', 0, 4,  N'Imperial Silver 6 Pack', 8,  N'Cacique Superior 1L', 4,  N'Bolsa de Hielo 2kg', 10, N'Venta demo del mes actual para reporte mensual.'),
        (N'SEED-MES-00-02', N'FE-CR-MES-00-02', N'eventosticos@clientes.labodega.cr', 0, 16, N'Jack Daniel''s 750ml', 2, N'Red Bull 250ml', 24, N'Yucas Tostadas 150g', 15, N'Pedido corporativo demo del mes actual.'),

        /* 1 mes atrás */
        (N'SEED-MES-01-01', N'FE-CR-MES-01-01', N'lasabana@clientes.labodega.cr', 1, 7,  N'Pilsen 6 Pack', 10, N'Coca-Cola 2.5L', 12, N'Bolsa de Hielo 2kg', 12, N'Abastecimiento mensual demo.'),
        (N'SEED-MES-01-02', N'FE-CR-MES-01-02', N'elmirador@clientes.labodega.cr', 1, 20, N'Flor de Caña 7 Años 750ml', 3, N'Ginger Ale 2L', 10, N'Red Bull 250ml', 18, N'Compra demo para restaurante.'),

        /* 2 meses atrás */
        (N'SEED-MES-02-01', N'FE-CR-MES-02-01', N'puravida@clientes.labodega.cr', 2, 5,  N'Cacique Superior 1L', 6, N'Bavaria Gold 6 Pack', 5, N'Bolsa de Hielo 2kg', 8, N'Reposición demo de licorera.'),
        (N'SEED-MES-02-02', N'FE-CR-MES-02-02', N'donbeto@clientes.labodega.cr', 2, 22, N'Smirnoff Vodka 750ml', 3, N'Coca-Cola 2.5L', 16, N'Yucas Tostadas 150g', 20, N'Venta demo de minisúper.'),

        /* 3 meses atrás */
        (N'SEED-MES-03-01', N'FE-CR-MES-03-01', N'loslagos@clientes.labodega.cr', 3, 9, N'Imperial Silver 6 Pack', 7, N'Pilsen 6 Pack', 6, N'Red Bull 250ml', 20, N'Compra demo de abastecedor.'),
        (N'SEED-MES-03-02', N'FE-CR-MES-03-02', N'lacarreta@clientes.labodega.cr', 3, 19, N'Jose Cuervo Especial 750ml', 2, N'Casillero del Diablo Cabernet 750ml', 8, N'Bolsa de Hielo 2kg', 12, N'Pedido demo para evento privado.'),

        /* 4 meses atrás */
        (N'SEED-MES-04-01', N'FE-CR-MES-04-01', N'caminovverde@clientes.labodega.cr', 4, 6, N'Casillero del Diablo Cabernet 750ml', 12, N'Tanqueray Gin 750ml', 2, N'Ginger Ale 2L', 14, N'Abastecimiento demo hotelero.'),
        (N'SEED-MES-04-02', N'FE-CR-MES-04-02', N'puertoazul@clientes.labodega.cr', 4, 24, N'Imperial Silver 6 Pack', 9, N'Pilsen 6 Pack', 9, N'Coca-Cola 2.5L', 20, N'Ruta demo Puntarenas.'),

        /* 5 meses atrás */
        (N'SEED-MES-05-01', N'FE-CR-MES-05-01', N'esquinasabor@clientes.labodega.cr', 5, 10, N'Cacique Superior 1L', 5, N'Flor de Caña 7 Años 750ml', 2, N'Bolsa de Hielo 2kg', 10, N'Venta demo para restaurante local.'),
        (N'SEED-MES-05-02', N'FE-CR-MES-05-02', N'eltucan@clientes.labodega.cr', 5, 21, N'Red Bull 250ml', 30, N'Coca-Cola 2.5L', 18, N'Yucas Tostadas 150g', 18, N'Reposición demo de pulpería.'),

        /* 6 meses atrás */
        (N'SEED-MES-06-01', N'FE-CR-MES-06-01', N'eventosticos@clientes.labodega.cr', 6, 3, N'Jack Daniel''s 750ml', 3, N'Tanqueray Gin 750ml', 2, N'Red Bull 250ml', 36, N'Venta demo de temporada alta.'),
        (N'SEED-MES-06-02', N'FE-CR-MES-06-02', N'elmirador@clientes.labodega.cr', 6, 18, N'Jose Cuervo Especial 750ml', 3, N'Bavaria Gold 6 Pack', 8, N'Bolsa de Hielo 2kg', 15, N'Compra demo restaurante temporada alta.'),

        /* 7 meses atrás */
        (N'SEED-MES-07-01', N'FE-CR-MES-07-01', N'lasabana@clientes.labodega.cr', 7, 8, N'Pilsen 6 Pack', 8, N'Imperial Silver 6 Pack', 8, N'Coca-Cola 2.5L', 15, N'Abastecimiento mensual demo.'),
        (N'SEED-MES-07-02', N'FE-CR-MES-07-02', N'donbeto@clientes.labodega.cr', 7, 23, N'Cacique Superior 1L', 4, N'Bolsa de Hielo 2kg', 8, N'Ginger Ale 2L', 10, N'Venta demo Alajuela.'),

        /* 8 meses atrás */
        (N'SEED-MES-08-01', N'FE-CR-MES-08-01', N'puravida@clientes.labodega.cr', 8, 11, N'Flor de Caña 7 Años 750ml', 3, N'Smirnoff Vodka 750ml', 3, N'Red Bull 250ml', 20, N'Reposición demo de inventario.'),
        (N'SEED-MES-08-02', N'FE-CR-MES-08-02', N'loslagos@clientes.labodega.cr', 8, 25, N'Imperial Silver 6 Pack', 6, N'Pilsen 6 Pack', 6, N'Yucas Tostadas 150g', 24, N'Venta demo abastecedor.'),

        /* 9 meses atrás */
        (N'SEED-MES-09-01', N'FE-CR-MES-09-01', N'lacarreta@clientes.labodega.cr', 9, 6, N'Jose Cuervo Especial 750ml', 2, N'Casillero del Diablo Cabernet 750ml', 6, N'Coca-Cola 2.5L', 12, N'Venta demo Cartago.'),
        (N'SEED-MES-09-02', N'FE-CR-MES-09-02', N'caminovverde@clientes.labodega.cr', 9, 19, N'Tanqueray Gin 750ml', 3, N'Ginger Ale 2L', 12, N'Bolsa de Hielo 2kg', 18, N'Venta demo hotel La Fortuna.'),

        /* 10 meses atrás */
        (N'SEED-MES-10-01', N'FE-CR-MES-10-01', N'puertoazul@clientes.labodega.cr', 10, 9, N'Imperial Silver 6 Pack', 10, N'Pilsen 6 Pack', 8, N'Bolsa de Hielo 2kg', 18, N'Venta demo ruta Puntarenas.'),
        (N'SEED-MES-10-02', N'FE-CR-MES-10-02', N'esquinasabor@clientes.labodega.cr', 10, 22, N'Cacique Superior 1L', 4, N'Red Bull 250ml', 18, N'Yucas Tostadas 150g', 16, N'Venta demo restaurante.'),

        /* 11 meses atrás */
        (N'SEED-MES-11-01', N'FE-CR-MES-11-01', N'eltucan@clientes.labodega.cr', 11, 5, N'Pilsen 6 Pack', 7, N'Coca-Cola 2.5L', 10, N'Bolsa de Hielo 2kg', 10, N'Venta demo histórica.'),
        (N'SEED-MES-11-02', N'FE-CR-MES-11-02', N'eventosticos@clientes.labodega.cr', 11, 17, N'Jack Daniel''s 750ml', 2, N'Jose Cuervo Especial 750ml', 2, N'Red Bull 250ml', 24, N'Venta demo histórica para eventos.');

    DECLARE
        @Codigo NVARCHAR(40),
        @NumeroFactura NVARCHAR(40),
        @ClienteCorreo NVARCHAR(150),
        @MesOffset INT,
        @Dia INT,
        @Producto1 NVARCHAR(150), @Cantidad1 INT,
        @Producto2 NVARCHAR(150), @Cantidad2 INT,
        @Producto3 NVARCHAR(150), @Cantidad3 INT,
        @Observaciones NVARCHAR(255),
        @FechaPedido DATETIME2,
        @PedidoId INT,
        @FacturaId INT,
        @ClienteId INT,
        @ClienteNombre NVARCHAR(150),
        @Direccion NVARCHAR(255),
        @Subtotal DECIMAL(18,2),
        @Impuesto DECIMAL(18,2),
        @Total DECIMAL(18,2);

    DECLARE ventas_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Codigo, NumeroFactura, ClienteCorreo, MesOffset, Dia, Producto1, Cantidad1, Producto2, Cantidad2, Producto3, Cantidad3, Observaciones
        FROM @VentasMensuales
        ORDER BY MesOffset DESC, Dia ASC;

    OPEN ventas_cursor;
    FETCH NEXT FROM ventas_cursor INTO @Codigo, @NumeroFactura, @ClienteCorreo, @MesOffset, @Dia, @Producto1, @Cantidad1, @Producto2, @Cantidad2, @Producto3, @Cantidad3, @Observaciones;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FechaPedido = DATEADD(HOUR, 10, CAST(DATEADD(MONTH, -@MesOffset, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), @Dia)) AS DATETIME2));

        IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE IdentificacionCliente = @Codigo)
        BEGIN
            SELECT
                @ClienteId = UsuarioId,
                @ClienteNombre = NombreCompleto,
                @Direccion = Direccion
            FROM dbo.Usuarios
            WHERE Correo = @ClienteCorreo;

            IF @ClienteId IS NULL
                THROW 60010, 'No se encontró uno de los clientes demo para ventas mensuales.', 1;

            DECLARE @Items TABLE (ProductoNombre NVARCHAR(150), Cantidad INT);
            DELETE FROM @Items;

            INSERT INTO @Items (ProductoNombre, Cantidad)
            VALUES
                (@Producto1, @Cantidad1),
                (@Producto2, @Cantidad2),
                (@Producto3, @Cantidad3);

            IF EXISTS
            (
                SELECT 1
                FROM @Items i
                LEFT JOIN dbo.Productos p ON p.Nombre = i.ProductoNombre
                WHERE p.ProductoId IS NULL
            )
                THROW 60011, 'No se encontró uno de los productos demo para ventas mensuales.', 1;

            SELECT @Subtotal = SUM(i.Cantidad * p.Precio)
            FROM @Items i
            INNER JOIN dbo.Productos p ON p.Nombre = i.ProductoNombre;

            SET @Impuesto = ROUND(@Subtotal * 0.13, 2);
            SET @Total = @Subtotal + @Impuesto;

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
                @ClienteId,
                @FechaPedido,
                N'Entregado',
                N'Entrega a domicilio',
                @Direccion,
                @Subtotal,
                @Observaciones,
                @Codigo,
                @AdminId,
                @AdminNombre,
                N'Venta móvil demo',
                DATEADD(HOUR, 1, @FechaPedido)
            );

            SET @PedidoId = CAST(SCOPE_IDENTITY() AS INT);

            INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
            SELECT @PedidoId, p.ProductoId, i.Cantidad, p.Precio
            FROM @Items i
            INNER JOIN dbo.Productos p ON p.Nombre = i.ProductoNombre;

            IF NOT EXISTS (SELECT 1 FROM dbo.Facturas WHERE NumeroFactura = @NumeroFactura)
            BEGIN
                INSERT INTO dbo.Facturas
                (
                    PedidoId,
                    NumeroFactura,
                    UsuarioId,
                    ClienteNombre,
                    ClienteCorreo,
                    FechaFactura,
                    Subtotal,
                    Impuesto,
                    Total,
                    Estado
                )
                VALUES
                (
                    @PedidoId,
                    @NumeroFactura,
                    @ClienteId,
                    @ClienteNombre,
                    @ClienteCorreo,
                    DATEADD(HOUR, 2, @FechaPedido),
                    @Subtotal,
                    @Impuesto,
                    @Total,
                    N'Generada'
                );

                SET @FacturaId = CAST(SCOPE_IDENTITY() AS INT);

                INSERT INTO dbo.FacturaDetalle (FacturaId, ProductoId, ProductoNombre, Cantidad, PrecioUnitario)
                SELECT @FacturaId, p.ProductoId, p.Nombre, i.Cantidad, p.Precio
                FROM @Items i
                INNER JOIN dbo.Productos p ON p.Nombre = i.ProductoNombre;
            END;
        END;

        FETCH NEXT FROM ventas_cursor INTO @Codigo, @NumeroFactura, @ClienteCorreo, @MesOffset, @Dia, @Producto1, @Cantidad1, @Producto2, @Cantidad2, @Producto3, @Cantidad3, @Observaciones;
    END;

    CLOSE ventas_cursor;
    DEALLOCATE ventas_cursor;

    /* =========================================================
       2. Auditoría de carga mensual
       ========================================================= */
    IF OBJECT_ID('dbo.AuditoriaSistema', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.AuditoriaSistema
        (
            UsuarioId,
            UsuarioNombre,
            UsuarioCorreo,
            Rol,
            Accion,
            Modulo,
            Descripcion,
            DireccionIp,
            UserAgent,
            FechaRegistro
        )
        SELECT
            @AdminId,
            @AdminNombre,
            N'admin@distribuidorajj.com',
            N'Administrador',
            N'Carga demo',
            N'Facturación',
            N'Se cargaron ventas mensuales demo de Costa Rica para reportes por mes.',
            N'::1',
            N'Seed ventas mensuales Costa Rica',
            SYSDATETIME()
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.AuditoriaSistema
            WHERE Descripcion = N'Se cargaron ventas mensuales demo de Costa Rica para reportes por mes.'
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'Ventas mensuales demo Costa Rica cargadas correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorNumber INT = ERROR_NUMBER();
    DECLARE @ErrorLine INT = ERROR_LINE();

    PRINT 'Error al cargar ventas mensuales demo.';
    PRINT CONCAT('Número: ', @ErrorNumber, ' Línea: ', @ErrorLine, ' Mensaje: ', @ErrorMessage);
    THROW;
END CATCH;
GO

/* Resumen de ventas demo por mes */
SELECT
    FORMAT(FechaFactura, 'yyyy-MM') AS Periodo,
    COUNT(1) AS Facturas,
    SUM(Total) AS Ventas
FROM dbo.Facturas
WHERE Estado = 'Generada'
  AND NumeroFactura LIKE 'FE-CR-MES-%'
GROUP BY FORMAT(FechaFactura, 'yyyy-MM')
ORDER BY Periodo DESC;
GO
