-- ============================================================
-- CU-141 / CU-142 / CU-105 — DEVOLUCIONES, CUARENTENA Y LIQUIDACIÓN DE RUTA
--
--   CU-141  Registrar devoluciones de productos (control de inventario).
--   CU-142  Colocar productos devueltos en cuarentena (evitar reventa).
--   CU-105  Liquidar la ruta al final del día para reingresar al
--           inventario la mercadería no entregada.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO: tabla nueva + columnas nullable en dbo.Rutas.
--     No altera tipos, no elimina objetos, no toca el CHECK de Rutas.
--   • IDEMPOTENTE: IF OBJECT_ID / COL_LENGTH / CREATE OR ALTER.
--   • Reutiliza dbo.MovimientosInventario (mismo formato que
--     sp_Admin_CreateInventoryMovement) y dbo.PedidoDetalle.
--   • Los productos devueltos entran en CUARENTENA y NO vuelven al
--     stock vendible hasta que un encargado los libere (CU-142).
--
-- Prerrequisito: Fase1/Fase2 (Productos, Pedidos, PedidoDetalle,
--                MovimientosInventario) y cu081 (Rutas/RutaPedidos).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLA Devoluciones (unifica devolución + ciclo de cuarentena)
--    Estado: EnCuarentena -> Reintegrada | Descartada
-- ============================================================
IF OBJECT_ID('dbo.Devoluciones', 'U') IS NULL
CREATE TABLE dbo.Devoluciones (
    DevolucionId           INT           IDENTITY(1,1) NOT NULL,
    PedidoId               INT                         NULL,      -- FK -> Pedidos (opcional)
    ProductoId             INT                         NOT NULL,  -- FK -> Productos
    ProductoNombre         NVARCHAR(150)               NOT NULL,
    Cantidad               INT                         NOT NULL,
    Motivo                 NVARCHAR(300)               NOT NULL,
    Estado                 NVARCHAR(20)                NOT NULL CONSTRAINT DF_Devoluciones_Estado DEFAULT N'EnCuarentena',
    ClienteInfo            NVARCHAR(150)               NULL,
    RegistradoPorUsuarioId INT                         NULL,      -- FK -> Usuarios
    RegistradoPorNombre    NVARCHAR(150)               NULL,
    FechaRegistro          DATETIME2                   NOT NULL CONSTRAINT DF_Devoluciones_Fecha DEFAULT SYSDATETIME(),
    ResueltoPorUsuarioId   INT                         NULL,      -- FK -> Usuarios
    ResueltoPorNombre      NVARCHAR(150)               NULL,
    ObservacionResolucion  NVARCHAR(300)               NULL,
    FechaResolucion        DATETIME2                   NULL,
    CONSTRAINT PK_Devoluciones PRIMARY KEY (DevolucionId),
    CONSTRAINT CK_Devoluciones_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Devoluciones_Estado   CHECK (Estado IN (N'EnCuarentena', N'Reintegrada', N'Descartada'))
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Devoluciones_ProductoId' AND parent_object_id = OBJECT_ID('dbo.Devoluciones'))
    ALTER TABLE dbo.Devoluciones ADD CONSTRAINT FK_Devoluciones_ProductoId
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (ProductoId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Devoluciones_PedidoId' AND parent_object_id = OBJECT_ID('dbo.Devoluciones'))
    ALTER TABLE dbo.Devoluciones ADD CONSTRAINT FK_Devoluciones_PedidoId
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos (PedidoId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Devoluciones_Estado' AND object_id = OBJECT_ID('dbo.Devoluciones'))
    CREATE INDEX IX_Devoluciones_Estado ON dbo.Devoluciones (Estado, FechaRegistro DESC);
GO

-- ============================================================
-- 2. COLUMNAS de liquidación en dbo.Rutas (aditivas, nullables)
-- ============================================================
IF COL_LENGTH('dbo.Rutas', 'Liquidada') IS NULL
    ALTER TABLE dbo.Rutas ADD Liquidada BIT NOT NULL CONSTRAINT DF_Rutas_Liquidada DEFAULT 0;
GO
IF COL_LENGTH('dbo.Rutas', 'FechaLiquidacion') IS NULL
    ALTER TABLE dbo.Rutas ADD FechaLiquidacion DATETIME2 NULL;
GO
IF COL_LENGTH('dbo.Rutas', 'LiquidadaPorUsuarioId') IS NULL
    ALTER TABLE dbo.Rutas ADD LiquidadaPorUsuarioId INT NULL;
GO
IF COL_LENGTH('dbo.Rutas', 'LiquidadaPorNombre') IS NULL
    ALTER TABLE dbo.Rutas ADD LiquidadaPorNombre NVARCHAR(150) NULL;
GO

-- ============================================================
-- 3. PERMISOS del módulo (idempotente)
-- ============================================================
MERGE dbo.Permisos AS target
USING (VALUES
    (N'DEVOLUCIONES_GESTIONAR', N'Inventario', N'Gestionar devoluciones',       N'Registrar devoluciones de productos.'),
    (N'CUARENTENA_GESTIONAR',   N'Inventario', N'Gestionar cuarentena',         N'Liberar o descartar productos en cuarentena.')
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET Modulo = source.Modulo, Nombre = source.Nombre, Descripcion = source.Descripcion, Activo = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

DECLARE @Asig TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @Asig (Rol, Codigo) VALUES
    (N'Administrador', N'DEVOLUCIONES_GESTIONAR'),
    (N'Administrador', N'CUARENTENA_GESTIONAR'),
    (N'Gerente',       N'DEVOLUCIONES_GESTIONAR'),
    (N'Gerente',       N'CUARENTENA_GESTIONAR');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-141/142'
FROM @Asig a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 4. STORED PROCEDURES
-- ============================================================

-- 4.1 CU-141 — Registrar devolución (entra en cuarentena, sin tocar stock)
CREATE OR ALTER PROCEDURE dbo.sp_Devoluciones_Create
    @PedidoId    INT           = NULL,
    @ProductoId  INT,
    @Cantidad    INT,
    @Motivo      NVARCHAR(300),
    @ClienteInfo NVARCHAR(150)  = NULL,
    @UsuarioId   INT            = NULL,
    @Nombre      NVARCHAR(150)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');
    IF @Motivo IS NULL      THROW 53010, 'Debe indicar el motivo de la devolución.', 1;
    IF ISNULL(@Cantidad, 0) <= 0 THROW 53011, 'La cantidad devuelta debe ser mayor a cero.', 1;

    DECLARE @ProductoNombre NVARCHAR(150) =
        (SELECT Nombre FROM dbo.Productos WHERE ProductoId = @ProductoId AND Activo = 1);
    IF @ProductoNombre IS NULL THROW 53012, 'El producto seleccionado no existe o está inactivo.', 1;

    IF @PedidoId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE PedidoId = @PedidoId)
        THROW 53013, 'El pedido indicado no existe.', 1;

    INSERT INTO dbo.Devoluciones
        (PedidoId, ProductoId, ProductoNombre, Cantidad, Motivo, Estado,
         ClienteInfo, RegistradoPorUsuarioId, RegistradoPorNombre)
    VALUES
        (@PedidoId, @ProductoId, @ProductoNombre, @Cantidad, @Motivo, N'EnCuarentena',
         NULLIF(LTRIM(RTRIM(@ClienteInfo)), N''), @UsuarioId, @Nombre);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS DevolucionId;
END;
GO

-- 4.2 Listado de devoluciones (todas o por estado/búsqueda)
CREATE OR ALTER PROCEDURE dbo.sp_Devoluciones_List
    @Estado NVARCHAR(20)  = NULL,
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT
        d.DevolucionId, d.PedidoId, d.ProductoId, d.ProductoNombre, d.Cantidad,
        d.Motivo, d.Estado, ISNULL(d.ClienteInfo, N'') AS ClienteInfo,
        ISNULL(d.RegistradoPorNombre, N'') AS RegistradoPorNombre, d.FechaRegistro,
        ISNULL(d.ResueltoPorNombre, N'') AS ResueltoPorNombre, d.FechaResolucion,
        ISNULL(d.ObservacionResolucion, N'') AS ObservacionResolucion
    FROM dbo.Devoluciones d
    WHERE (@Estado IS NULL OR d.Estado = @Estado)
      AND (@Buscar IS NULL
           OR d.ProductoNombre LIKE N'%' + @Buscar + N'%'
           OR d.Motivo         LIKE N'%' + @Buscar + N'%'
           OR ISNULL(d.ClienteInfo, N'') LIKE N'%' + @Buscar + N'%')
    ORDER BY d.FechaRegistro DESC;
END;
GO

-- 4.3 CU-142 — Liberar de cuarentena (reintegra al stock vendible)
CREATE OR ALTER PROCEDURE dbo.sp_Cuarentena_Liberar
    @DevolucionId INT,
    @UsuarioId    INT           = NULL,
    @Nombre       NVARCHAR(150) = NULL,
    @Observacion  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ProductoId INT, @ProductoNombre NVARCHAR(150), @Cantidad INT, @Estado NVARCHAR(20);
    SELECT @ProductoId = ProductoId, @ProductoNombre = ProductoNombre,
           @Cantidad = Cantidad, @Estado = Estado
    FROM dbo.Devoluciones WHERE DevolucionId = @DevolucionId;

    IF @ProductoId IS NULL      THROW 53020, 'No se encontró la devolución indicada.', 1;
    IF @Estado <> N'EnCuarentena' THROW 53021, 'La devolución ya fue resuelta.', 1;

    BEGIN TRANSACTION;

    DECLARE @StockAnterior INT = (SELECT Stock FROM dbo.Productos WHERE ProductoId = @ProductoId);
    DECLARE @StockNuevo INT = @StockAnterior + @Cantidad;

    UPDATE dbo.Productos SET Stock = @StockNuevo WHERE ProductoId = @ProductoId;

    INSERT INTO dbo.MovimientosInventario
        (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre)
    VALUES
        (@ProductoId, @ProductoNombre, N'Entrada', @Cantidad, @StockAnterior, @StockNuevo,
         CONCAT(N'Reintegro desde cuarentena (devolución #', @DevolucionId, N')'), @UsuarioId, @Nombre);

    UPDATE dbo.Devoluciones
    SET Estado = N'Reintegrada', ResueltoPorUsuarioId = @UsuarioId, ResueltoPorNombre = @Nombre,
        ObservacionResolucion = NULLIF(LTRIM(RTRIM(@Observacion)), N''), FechaResolucion = SYSDATETIME()
    WHERE DevolucionId = @DevolucionId;

    COMMIT TRANSACTION;
END;
GO

-- 4.4 CU-142 — Descartar de cuarentena (no reingresa stock)
CREATE OR ALTER PROCEDURE dbo.sp_Cuarentena_Descartar
    @DevolucionId INT,
    @UsuarioId    INT           = NULL,
    @Nombre       NVARCHAR(150) = NULL,
    @Observacion  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Estado NVARCHAR(20) = (SELECT Estado FROM dbo.Devoluciones WHERE DevolucionId = @DevolucionId);
    IF @Estado IS NULL          THROW 53020, 'No se encontró la devolución indicada.', 1;
    IF @Estado <> N'EnCuarentena' THROW 53021, 'La devolución ya fue resuelta.', 1;

    UPDATE dbo.Devoluciones
    SET Estado = N'Descartada', ResueltoPorUsuarioId = @UsuarioId, ResueltoPorNombre = @Nombre,
        ObservacionResolucion = NULLIF(LTRIM(RTRIM(@Observacion)), N''), FechaResolucion = SYSDATETIME()
    WHERE DevolucionId = @DevolucionId;
END;
GO

-- 4.5 CU-105 — Liquidar ruta: reingresa al inventario la mercadería
--     de los pedidos NO entregados y cierra la ruta.
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Liquidar
    @RutaId    INT,
    @UsuarioId INT           = NULL,
    @Nombre    NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Estado NVARCHAR(20), @Liquidada BIT, @Codigo NVARCHAR(30);
    SELECT @Estado = Estado, @Liquidada = Liquidada, @Codigo = Codigo
    FROM dbo.Rutas WHERE RutaId = @RutaId;

    IF @Estado IS NULL   THROW 53030, 'No se encontró la ruta indicada.', 1;
    IF @Liquidada = 1    THROW 53031, 'La ruta ya fue liquidada.', 1;
    IF @Estado NOT IN (N'Despachada', N'Planificada')
        THROW 53032, 'Solo se pueden liquidar rutas despachadas o en planificación.', 1;

    BEGIN TRANSACTION;

    -- Pedidos NO entregados de la ruta (mercadería que regresa a bodega)
    DECLARE @NoEntregados TABLE (PedidoId INT PRIMARY KEY);
    INSERT INTO @NoEntregados (PedidoId)
    SELECT rp.PedidoId
    FROM dbo.RutaPedidos rp
    WHERE rp.RutaId = @RutaId AND rp.EstadoEntrega <> N'Entregado';

    -- Reingreso de inventario por cada línea de pedido no entregado
    DECLARE @Reingresos TABLE (ProductoId INT, ProductoNombre NVARCHAR(150), Cantidad INT, PedidoId INT);
    INSERT INTO @Reingresos (ProductoId, ProductoNombre, Cantidad, PedidoId)
    SELECT pd.ProductoId, pr.Nombre, SUM(pd.Cantidad), pd.PedidoId
    FROM dbo.PedidoDetalle pd
    INNER JOIN @NoEntregados ne ON ne.PedidoId = pd.PedidoId
    INNER JOIN dbo.Productos pr ON pr.ProductoId = pd.ProductoId
    GROUP BY pd.ProductoId, pr.Nombre, pd.PedidoId;

    DECLARE @ProductoId INT, @ProductoNombre NVARCHAR(150), @Cantidad INT, @PedidoId INT,
            @StockAnterior INT, @StockNuevo INT, @Unidades INT = 0;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT ProductoId, ProductoNombre, Cantidad, PedidoId FROM @Reingresos;
    OPEN cur;
    FETCH NEXT FROM cur INTO @ProductoId, @ProductoNombre, @Cantidad, @PedidoId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @StockAnterior = (SELECT Stock FROM dbo.Productos WHERE ProductoId = @ProductoId);
        SET @StockNuevo = @StockAnterior + @Cantidad;
        UPDATE dbo.Productos SET Stock = @StockNuevo WHERE ProductoId = @ProductoId;
        INSERT INTO dbo.MovimientosInventario
            (ProductoId, ProductoNombre, TipoMovimiento, Cantidad, StockAnterior, StockNuevo, Motivo, UsuarioId, UsuarioNombre)
        VALUES
            (@ProductoId, @ProductoNombre, N'Entrada', @Cantidad, @StockAnterior, @StockNuevo,
             CONCAT(N'Reingreso por liquidación de ruta ', @Codigo, N' (pedido #', @PedidoId, N')'), @UsuarioId, @Nombre);
        SET @Unidades += @Cantidad;
        FETCH NEXT FROM cur INTO @ProductoId, @ProductoNombre, @Cantidad, @PedidoId;
    END;
    CLOSE cur; DEALLOCATE cur;

    -- Marca los pedidos no entregados como Fallidos (no se despacharon)
    UPDATE dbo.RutaPedidos
    SET EstadoEntrega = N'Fallido',
        MotivoFallo = ISNULL(MotivoFallo, N'No entregado - liquidación de ruta'),
        FechaActualizacion = SYSDATETIME()
    WHERE RutaId = @RutaId AND EstadoEntrega <> N'Entregado';

    -- Cierra y marca la ruta como liquidada
    UPDATE dbo.Rutas
    SET Estado = N'Completada', Liquidada = 1, FechaCierre = SYSDATETIME(),
        FechaLiquidacion = SYSDATETIME(), LiquidadaPorUsuarioId = @UsuarioId,
        LiquidadaPorNombre = @Nombre, FechaActualizacion = SYSDATETIME()
    WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;

    SELECT (SELECT COUNT(*) FROM @NoEntregados) AS PedidosReingresados, @Unidades AS UnidadesReingresadas;
END;
GO

PRINT 'CU-141/142/105 aplicado: Devoluciones, cuarentena y liquidación de ruta.';
GO
