-- ============================================================
-- CU-251 / CU-252 / CU-253 — RUTAS INTELIGENTES
--
--   CU-251  Secuenciar automáticamente los puntos de entrega para
--           minimizar recorrido (vecino más cercano). Reorden manual.
--   CU-252  Chofer visualiza el mapa con la ruta y el orden de visitas.
--   CU-253  Recalcular la ruta en tiempo real ante un imprevisto.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO: agrega Latitud/Longitud (nullable) a dbo.RutaPedidos.
--     No toca dbo.Pedidos ni el CHECK de Rutas/RutaPedidos.
--   • IDEMPOTENTE: COL_LENGTH + CREATE OR ALTER.
--   • Los SPs de lectura sp_Rutas_GetOrders y sp_Chofer_GetRouteDeliveries
--     se re-declaran añadiendo Latitud/Longitud AL FINAL (no corren los
--     índices ordinales que ya consumen los servicios existentes).
--
-- Prerrequisito: cu081 (Rutas/RutaPedidos) y cu082 (SPs de rutas).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. COLUMNAS de geolocalización en RutaPedidos (aditivas)
-- ============================================================
IF COL_LENGTH('dbo.RutaPedidos', 'Latitud') IS NULL
    ALTER TABLE dbo.RutaPedidos ADD Latitud DECIMAL(9,6) NULL;
GO
IF COL_LENGTH('dbo.RutaPedidos', 'Longitud') IS NULL
    ALTER TABLE dbo.RutaPedidos ADD Longitud DECIMAL(9,6) NULL;
GO

-- ============================================================
-- 2. SP CU-251 E3 — Guardar secuencia manual + coordenadas
--    @ItemsJson: [{ "rutaPedidoId":1, "secuencia":1, "lat":9.9, "lng":-84.0 }, ...]
-- ============================================================
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

    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;
    COMMIT TRANSACTION;
END;
GO

-- ============================================================
-- 3. SP CU-251 E1/E2 — Secuenciar automáticamente (vecino más cercano)
--    Origen por defecto: bodega en San José, Costa Rica.
--    Devuelve la cantidad de puntos secuenciados (0 => E2, sin pedidos).
-- ============================================================
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

    -- Puntos a ordenar (pendientes de entrega)
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
        SELECT 0 AS Secuenciados;   -- E2: no hay pedidos pendientes para secuenciar
        RETURN;
    END;

    -- Vecino más cercano sobre los que tienen coordenadas
    DECLARE @Seq INT = 0, @CurLat DECIMAL(9,6) = @OrigenLat, @CurLng DECIMAL(9,6) = @OrigenLng;
    DECLARE @NextId INT;

    WHILE EXISTS (SELECT 1 FROM @Stops WHERE Visitado = 0 AND TieneCoord = 1)
    BEGIN
        SELECT TOP 1 @NextId = RutaPedidoId
        FROM @Stops
        WHERE Visitado = 0 AND TieneCoord = 1
        ORDER BY (POWER(Lat - @CurLat, 2) +
                  POWER((Lng - @CurLng) * COS(RADIANS(@CurLat)), 2)) ASC;

        SET @Seq += 1;
        UPDATE @Stops SET Visitado = 1, NuevaSecuencia = @Seq WHERE RutaPedidoId = @NextId;
        SELECT @CurLat = Lat, @CurLng = Lng FROM @Stops WHERE RutaPedidoId = @NextId;
    END;

    -- Los que no tienen coordenadas se agregan al final, en su orden actual
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

    SELECT @Total AS Secuenciados;   -- E1
END;
GO

-- ============================================================
-- 4. SP CU-253 — Recalcular ruta en tiempo real
--    Excluye/reordena el punto afectado y re-secuencia el resto
--    (pendientes / en ruta) por vecino más cercano.
--    @ExcluirRutaPedidoId: punto afectado (se marca Fallido). NULL = solo reordenar.
--    Devuelve la cantidad de puntos re-secuenciados (0 => E2).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Recalcular
    @RutaId              INT,
    @ExcluirRutaPedidoId INT           = NULL,
    @MotivoFallo         NVARCHAR(300)  = NULL,
    @OrigenLat           DECIMAL(9,6)   = 9.933300,
    @OrigenLng           DECIMAL(9,6)   = -84.083300
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20) = (SELECT Estado FROM dbo.Rutas WHERE RutaId = @RutaId);
    IF @EstadoRuta IS NULL       THROW 54020, 'No se encontró la ruta indicada.', 1;
    IF @EstadoRuta <> N'Despachada'
        THROW 54021, 'Solo se puede recalcular una ruta despachada (en curso).', 1;

    BEGIN TRANSACTION;

    -- Marca el punto afectado como Fallido (queda fuera del recorrido)
    IF @ExcluirRutaPedidoId IS NOT NULL
        UPDATE dbo.RutaPedidos
        SET EstadoEntrega = N'Fallido',
            MotivoFallo = ISNULL(NULLIF(LTRIM(RTRIM(@MotivoFallo)), N''), N'Imprevisto - recalculado'),
            FechaActualizacion = SYSDATETIME()
        WHERE RutaPedidoId = @ExcluirRutaPedidoId AND RutaId = @RutaId AND EstadoEntrega IN (N'Pendiente', N'EnRuta');

    -- Puntos restantes por visitar
    DECLARE @Stops TABLE (
        RutaPedidoId INT PRIMARY KEY, Lat DECIMAL(9,6), Lng DECIMAL(9,6),
        TieneCoord BIT, Visitado BIT DEFAULT 0, NuevaSecuencia INT NULL);
    INSERT INTO @Stops (RutaPedidoId, Lat, Lng, TieneCoord)
    SELECT rp.RutaPedidoId, rp.Latitud, rp.Longitud,
           CASE WHEN rp.Latitud IS NOT NULL AND rp.Longitud IS NOT NULL THEN 1 ELSE 0 END
    FROM dbo.RutaPedidos rp
    WHERE rp.RutaId = @RutaId AND rp.EstadoEntrega IN (N'Pendiente', N'EnRuta');

    DECLARE @Total INT = (SELECT COUNT(*) FROM @Stops);
    IF @Total = 0
    BEGIN
        COMMIT TRANSACTION;
        SELECT 0 AS Resecuenciados;  -- E2: no hay puntos por recalcular
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

    UPDATE rp
    SET rp.Secuencia = s.NuevaSecuencia, rp.FechaActualizacion = SYSDATETIME()
    FROM dbo.RutaPedidos rp INNER JOIN @Stops s ON s.RutaPedidoId = rp.RutaPedidoId;
    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
    SELECT @Total AS Resecuenciados;  -- E1
END;
GO

-- ============================================================
-- 5. Re-declaración de SPs de lectura con Latitud/Longitud AL FINAL
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetOrders
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        rp.RutaPedidoId, rp.PedidoId, rp.Secuencia, rp.EstadoEntrega,
        ISNULL(rp.MotivoFallo, N'') AS MotivoFallo, rp.FechaEntrega,
        u.NombreCompleto AS Cliente, u.Correo AS ClienteCorreo,
        ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) AS DireccionEntrega,
        p.Total, p.Estado AS EstadoPedido,
        (SELECT COUNT(*) FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId) AS TotalEvidencias,
        rp.Latitud, rp.Longitud
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia ASC, rp.RutaPedidoId ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Chofer_GetRouteDeliveries
    @RutaId          INT,
    @ChoferUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rutas WHERE RutaId = @RutaId AND ChoferUsuarioId = @ChoferUsuarioId)
        THROW 52060, 'La ruta no existe o no está asignada a este chofer.', 1;

    SELECT r.RutaId, r.Codigo, r.Zona, r.Estado, v.Placa AS VehiculoPlaca, r.FechaDespacho
    FROM dbo.Rutas r
    INNER JOIN dbo.Vehiculos v ON v.VehiculoId = r.VehiculoId
    WHERE r.RutaId = @RutaId;

    SELECT
        rp.RutaPedidoId, rp.PedidoId, rp.Secuencia, rp.EstadoEntrega,
        ISNULL(rp.MotivoFallo, N'') AS MotivoFallo, rp.FechaEntrega,
        u.NombreCompleto AS Cliente, ISNULL(u.Telefono, N'') AS Telefono,
        ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) AS DireccionEntrega,
        p.Total,
        (SELECT COUNT(*) FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId) AS TotalEvidencias,
        rp.Latitud, rp.Longitud
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia ASC, rp.RutaPedidoId ASC;
END;
GO

PRINT 'CU-251/252/253 aplicado: secuenciación, reorden manual, recálculo y coordenadas.';
GO
