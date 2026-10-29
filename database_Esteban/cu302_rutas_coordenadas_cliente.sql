-- ============================================================
-- CU-251/252 (refuerzo) — COORDENADAS DE ENTREGA EN EL CLIENTE
--
-- Problema corregido: al secuenciar una ruta, el chofer no veía el mapa
-- porque los pedidos no tenían coordenadas. Ahora la ubicación se guarda
-- en el CLIENTE (dbo.Usuarios), se siembra automáticamente en cada ruta,
-- y al capturarla en el detalle de la ruta se persiste de vuelta al
-- cliente para reutilizarla en rutas futuras (captura una vez).
--
-- 100 % ADITIVO e IDEMPOTENTE. Columnas nullables en dbo.Usuarios; el
-- resto son re-declaraciones con CREATE OR ALTER. No toca dbo.Pedidos.
--
-- Prerrequisito: cu081/cu082 (rutas), cu251 (secuenciación).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- 1) Ubicación guardada del cliente ------------------------------------
IF COL_LENGTH('dbo.Usuarios', 'Latitud') IS NULL
    ALTER TABLE dbo.Usuarios ADD Latitud DECIMAL(9,6) NULL;
GO
IF COL_LENGTH('dbo.Usuarios', 'Longitud') IS NULL
    ALTER TABLE dbo.Usuarios ADD Longitud DECIMAL(9,6) NULL;
GO

-- 2) sp_Rutas_Create — siembra coordenadas del cliente en cada parada ---
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Create
    @Zona               NVARCHAR(120),
    @ChoferUsuarioId    INT,
    @VehiculoId         INT,
    @Observaciones      NVARCHAR(300)   = NULL,
    @PedidosJson        NVARCHAR(MAX),
    @CreadaPorUsuarioId INT             = NULL,
    @CreadaPorNombre    NVARCHAR(150)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutaId INT, @Codigo NVARCHAR(30);

    SET @Zona = NULLIF(LTRIM(RTRIM(@Zona)), N'');
    IF @Zona IS NULL
        THROW 52000, 'Debe indicar la zona de la ruta.', 1;

    DECLARE @Items TABLE (PedidoId INT NOT NULL PRIMARY KEY);
    INSERT INTO @Items (PedidoId)
    SELECT DISTINCT PedidoId
    FROM OPENJSON(ISNULL(@PedidosJson, N''))
    WITH (PedidoId INT '$.pedidoId')
    WHERE PedidoId IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 52003, 'Debe seleccionar al menos un pedido para la ruta.', 1;

    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @ChoferUsuarioId AND u.Activo = 1 AND pf.Nombre = N'Chofer'
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52001, 'No hay chofer disponible o el chofer seleccionado no es válido.', 1; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos v WHERE v.VehiculoId = @VehiculoId AND v.Activo = 1)
    BEGIN ROLLBACK TRANSACTION; THROW 52002, 'No hay vehículo disponible o el vehículo seleccionado no es válido.', 1; END;

    IF EXISTS (
        SELECT 1 FROM @Items i
        LEFT JOIN dbo.Pedidos p ON p.PedidoId = i.PedidoId
        WHERE p.PedidoId IS NULL
           OR p.Estado IN (N'Cancelado', N'Rechazado', N'Entregado', N'Retenido')
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52004, 'Uno o más pedidos ya no se pueden asignar (estado no válido).', 1; END;

    IF EXISTS (
        SELECT 1 FROM @Items i
        INNER JOIN dbo.RutaPedidos rp ON rp.PedidoId = i.PedidoId
        INNER JOIN dbo.Rutas r        ON r.RutaId    = rp.RutaId AND r.Estado <> N'Cancelada'
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52005, 'Uno o más pedidos ya están asignados a otra ruta activa.', 1; END;

    SET @Codigo = CONCAT(N'RUT-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'));

    INSERT INTO dbo.Rutas (Codigo, Zona, ChoferUsuarioId, VehiculoId, Estado, Observaciones,
                           CreadaPorUsuarioId, CreadaPorNombre, FechaCreacion, FechaActualizacion)
    VALUES (@Codigo, @Zona, @ChoferUsuarioId, @VehiculoId, N'Planificada',
            NULLIF(LTRIM(RTRIM(@Observaciones)), N''),
            @CreadaPorUsuarioId, @CreadaPorNombre, SYSDATETIME(), SYSDATETIME());

    SET @RutaId = CAST(SCOPE_IDENTITY() AS INT);

    -- Siembra la coordenada guardada del cliente (si existe)
    INSERT INTO dbo.RutaPedidos (RutaId, PedidoId, Secuencia, EstadoEntrega, Latitud, Longitud, FechaActualizacion)
    SELECT @RutaId, i.PedidoId,
           ROW_NUMBER() OVER (ORDER BY i.PedidoId),
           N'Pendiente', u.Latitud, u.Longitud, SYSDATETIME()
    FROM @Items i
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = i.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId;

    COMMIT TRANSACTION;

    SELECT @RutaId AS RutaId, @Codigo AS Codigo;
END;
GO

-- 3) sp_Rutas_AddOrder — siembra coordenada del cliente al agregar ------
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_AddOrder
    @RutaId   INT,
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20), @Secuencia INT, @Lat DECIMAL(9,6), @Lng DECIMAL(9,6);

    BEGIN TRANSACTION;

    SELECT @EstadoRuta = Estado FROM dbo.Rutas WITH (UPDLOCK, HOLDLOCK) WHERE RutaId = @RutaId;

    IF @EstadoRuta IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52010, 'No se encontró la ruta indicada.', 1; END;

    IF @EstadoRuta <> N'Planificada'
    BEGIN ROLLBACK TRANSACTION; THROW 52011, 'Solo se pueden modificar rutas en estado Planificada (antes del despacho).', 1; END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Pedidos
        WHERE PedidoId = @PedidoId
          AND Estado NOT IN (N'Cancelado', N'Rechazado', N'Entregado', N'Retenido')
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52012, 'El pedido no existe o no se puede asignar por su estado.', 1; END;

    IF EXISTS (
        SELECT 1 FROM dbo.RutaPedidos rp
        INNER JOIN dbo.Rutas r ON r.RutaId = rp.RutaId AND r.Estado <> N'Cancelada'
        WHERE rp.PedidoId = @PedidoId
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52013, 'El pedido ya está asignado a una ruta activa.', 1; END;

    SELECT @Secuencia = ISNULL(MAX(Secuencia), 0) + 1 FROM dbo.RutaPedidos WHERE RutaId = @RutaId;

    SELECT @Lat = u.Latitud, @Lng = u.Longitud
    FROM dbo.Pedidos p INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.PedidoId = @PedidoId;

    INSERT INTO dbo.RutaPedidos (RutaId, PedidoId, Secuencia, EstadoEntrega, Latitud, Longitud, FechaActualizacion)
    VALUES (@RutaId, @PedidoId, @Secuencia, N'Pendiente', @Lat, @Lng, SYSDATETIME());

    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
END;
GO

-- 4) sp_Rutas_GuardarSecuencia — persiste la coordenada al cliente ------
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GuardarSecuencia
    @RutaId    INT,
    @ItemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20) = (SELECT Estado FROM dbo.Rutas WHERE RutaId = @RutaId);
    IF @EstadoRuta IS NULL       THROW 54000, 'No se encontró la ruta indicada.', 1;
    IF @EstadoRuta <> N'Planificada'
        THROW 54001, 'Solo se puede reordenar la ruta antes de despacharla (estado Planificada).', 1;

    DECLARE @Items TABLE (RutaPedidoId INT, Secuencia INT, Lat DECIMAL(9,6), Lng DECIMAL(9,6));
    INSERT INTO @Items (RutaPedidoId, Secuencia, Lat, Lng)
    SELECT RutaPedidoId, Secuencia, Lat, Lng
    FROM OPENJSON(ISNULL(@ItemsJson, N''))
    WITH (RutaPedidoId INT '$.rutaPedidoId', Secuencia INT '$.secuencia',
          Lat DECIMAL(9,6) '$.lat', Lng DECIMAL(9,6) '$.lng');

    BEGIN TRANSACTION;

    UPDATE rp
    SET rp.Secuencia = i.Secuencia,
        rp.Latitud   = i.Lat,
        rp.Longitud  = i.Lng,
        rp.FechaActualizacion = SYSDATETIME()
    FROM dbo.RutaPedidos rp
    INNER JOIN @Items i ON i.RutaPedidoId = rp.RutaPedidoId
    WHERE rp.RutaId = @RutaId;

    -- Persistir la ubicación capturada en el cliente (reuso futuro)
    UPDATE u
    SET u.Latitud = i.Lat, u.Longitud = i.Lng
    FROM dbo.Usuarios u
    INNER JOIN dbo.Pedidos     p  ON p.UsuarioId = u.UsuarioId
    INNER JOIN dbo.RutaPedidos rp ON rp.PedidoId = p.PedidoId AND rp.RutaId = @RutaId
    INNER JOIN @Items i ON i.RutaPedidoId = rp.RutaPedidoId
    WHERE i.Lat IS NOT NULL AND i.Lng IS NOT NULL;

    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
END;
GO

-- 5) sp_Rutas_Secuenciar — devuelve también los puntos sin coordenada ---
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Secuenciar
    @RutaId    INT,
    @OrigenLat DECIMAL(9,6) = 9.933300,
    @OrigenLng DECIMAL(9,6) = -84.083300
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20) = (SELECT Estado FROM dbo.Rutas WHERE RutaId = @RutaId);
    IF @EstadoRuta IS NULL       THROW 54010, 'No se encontró la ruta indicada.', 1;
    IF @EstadoRuta <> N'Planificada'
        THROW 54011, 'Solo se puede secuenciar la ruta antes de despacharla (estado Planificada).', 1;

    DECLARE @Stops TABLE (
        RutaPedidoId INT PRIMARY KEY, Lat DECIMAL(9,6), Lng DECIMAL(9,6),
        TieneCoord BIT, Visitado BIT DEFAULT 0, NuevaSecuencia INT NULL);
    INSERT INTO @Stops (RutaPedidoId, Lat, Lng, TieneCoord)
    SELECT rp.RutaPedidoId, rp.Latitud, rp.Longitud,
           CASE WHEN rp.Latitud IS NOT NULL AND rp.Longitud IS NOT NULL THEN 1 ELSE 0 END
    FROM dbo.RutaPedidos rp
    WHERE rp.RutaId = @RutaId AND rp.EstadoEntrega = N'Pendiente';

    DECLARE @Total INT = (SELECT COUNT(*) FROM @Stops);
    IF @Total = 0
    BEGIN
        SELECT 0 AS Secuenciados, 0 AS SinCoordenadas;   -- E2
        RETURN;
    END;

    DECLARE @Seq INT = 0, @CurLat DECIMAL(9,6) = @OrigenLat, @CurLng DECIMAL(9,6) = @OrigenLng, @NextId INT;

    WHILE EXISTS (SELECT 1 FROM @Stops WHERE Visitado = 0 AND TieneCoord = 1)
    BEGIN
        SELECT TOP 1 @NextId = RutaPedidoId
        FROM @Stops
        WHERE Visitado = 0 AND TieneCoord = 1
        ORDER BY (POWER(Lat - @CurLat, 2) + POWER((Lng - @CurLng) * COS(RADIANS(@CurLat)), 2)) ASC;

        SET @Seq += 1;
        UPDATE @Stops SET Visitado = 1, NuevaSecuencia = @Seq WHERE RutaPedidoId = @NextId;
        SELECT @CurLat = Lat, @CurLng = Lng FROM @Stops WHERE RutaPedidoId = @NextId;
    END;

    UPDATE s
    SET NuevaSecuencia = @Seq + orden.rn
    FROM @Stops s
    INNER JOIN (
        SELECT st.RutaPedidoId, ROW_NUMBER() OVER (ORDER BY rp.Secuencia, st.RutaPedidoId) AS rn
        FROM @Stops st INNER JOIN dbo.RutaPedidos rp ON rp.RutaPedidoId = st.RutaPedidoId
        WHERE st.TieneCoord = 0
    ) orden ON orden.RutaPedidoId = s.RutaPedidoId;

    BEGIN TRANSACTION;
    UPDATE rp
    SET rp.Secuencia = s.NuevaSecuencia, rp.FechaActualizacion = SYSDATETIME()
    FROM dbo.RutaPedidos rp
    INNER JOIN @Stops s ON s.RutaPedidoId = rp.RutaPedidoId;
    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;
    COMMIT TRANSACTION;

    SELECT @Total AS Secuenciados,
           (SELECT COUNT(*) FROM @Stops WHERE TieneCoord = 0) AS SinCoordenadas;   -- E1
END;
GO

PRINT 'cu302 aplicado: coordenadas de cliente + siembra en rutas + persistencia + conteo sin coordenadas.';
GO
