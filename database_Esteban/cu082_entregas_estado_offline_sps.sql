-- ============================================================
-- CU-081 / CU-082  —  RUTAS Y ENTREGAS
-- BLOQUE 2/4: STORED PROCEDURES  (rutas admin + portal chofer)
--
--   CU-081  E1 Generación de ruta (agrupa por zona, asigna chofer+vehículo)
--           E2 Sin recursos disponibles (valida chofer/vehículo libres)
--           E3 Modificación de ruta (agregar/quitar pedidos antes del despacho)
--   CU-082  E1 Actualización de estado con fecha y hora
--           E2 Soporte offline (idempotencia por SyncGuid)
--           E3 Datos para notificación al cliente (EnRuta / Entregado)
--
-- CREATE OR ALTER — idempotente. No modifica SPs existentes.
-- Prerrequisito: cu081_rutas_entregas_esquema.sql aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

/* =========================================================
   1. sp_Rutas_GetAssignableOrders
      Pedidos que se pueden asignar a una ruta:
      - No cancelados/rechazados/entregados/retenidos
      - Con dirección de entrega
      - No están ya en una ruta activa (no cancelada)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetAssignableOrders
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT
        p.PedidoId,
        u.NombreCompleto                         AS Cliente,
        u.Correo,
        p.FechaPedido,
        p.Estado,
        ISNULL(p.TipoEntrega, N'')               AS TipoEntrega,
        ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) AS DireccionEntrega,
        p.Total,
        (SELECT COUNT(*) FROM dbo.PedidoDetalle d WHERE d.PedidoId = p.PedidoId) AS TotalLineas
    FROM dbo.Pedidos p
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE p.Estado NOT IN (N'Cancelado', N'Rechazado', N'Entregado', N'Retenido')
      AND ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.RutaPedidos rp
          INNER JOIN dbo.Rutas r ON r.RutaId = rp.RutaId
          WHERE rp.PedidoId = p.PedidoId
            AND r.Estado <> N'Cancelada'
      )
      AND (
          @Buscar IS NULL
          OR u.NombreCompleto LIKE N'%' + @Buscar + N'%'
          OR u.Correo         LIKE N'%' + @Buscar + N'%'
          OR CAST(p.PedidoId AS NVARCHAR(20)) = @Buscar
          OR ISNULL(p.DireccionEntrega, N'')  LIKE N'%' + @Buscar + N'%'
      )
    ORDER BY p.FechaPedido ASC, p.PedidoId ASC;
END;
GO

/* =========================================================
   2. sp_Rutas_GetAvailableDrivers
      Choferes activos + cuántas rutas abiertas tienen.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetAvailableDrivers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        ISNULL(u.Telefono, N'') AS Telefono,
        (SELECT COUNT(*) FROM dbo.Rutas r
         WHERE r.ChoferUsuarioId = u.UsuarioId
           AND r.Estado IN (N'Planificada', N'Despachada')) AS RutasAbiertas
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = N'Chofer'
      AND u.Activo = 1
    ORDER BY RutasAbiertas ASC, u.NombreCompleto ASC;
END;
GO

/* =========================================================
   3. sp_Rutas_GetAvailableVehicles
      Vehículos activos + cuántas rutas abiertas tienen.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetAvailableVehicles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.VehiculoId,
        v.Placa,
        v.Descripcion,
        ISNULL(v.Capacidad, 0) AS Capacidad,
        (SELECT COUNT(*) FROM dbo.Rutas r
         WHERE r.VehiculoId = v.VehiculoId
           AND r.Estado IN (N'Planificada', N'Despachada')) AS RutasAbiertas
    FROM dbo.Vehiculos v
    WHERE v.Activo = 1
    ORDER BY RutasAbiertas ASC, v.Placa ASC;
END;
GO

/* =========================================================
   4. sp_Rutas_Create   (CU-081 E1 + E2)
      Valida recursos disponibles, agrupa pedidos por zona,
      crea la ruta (Planificada) y sus RutaPedidos (Pendiente).
      Códigos de error 520xx específicos para mensajes claros.
   ========================================================= */
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

    -- Pedidos solicitados
    DECLARE @Items TABLE (PedidoId INT NOT NULL PRIMARY KEY);
    INSERT INTO @Items (PedidoId)
    SELECT DISTINCT PedidoId
    FROM OPENJSON(ISNULL(@PedidosJson, N''))
    WITH (PedidoId INT '$.pedidoId')
    WHERE PedidoId IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 52003, 'Debe seleccionar al menos un pedido para la ruta.', 1;

    BEGIN TRANSACTION;

    -- Chofer válido, activo y con perfil Chofer (E2)
    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @ChoferUsuarioId AND u.Activo = 1 AND pf.Nombre = N'Chofer'
    )
    BEGIN ROLLBACK TRANSACTION; THROW 52001, 'No hay chofer disponible o el chofer seleccionado no es válido.', 1; END;

    -- Vehículo válido y activo (E2)
    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos v WHERE v.VehiculoId = @VehiculoId AND v.Activo = 1)
    BEGIN ROLLBACK TRANSACTION; THROW 52002, 'No hay vehículo disponible o el vehículo seleccionado no es válido.', 1; END;

    -- Todos los pedidos deben seguir siendo asignables (no en ruta activa, estado válido)
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

    -- Código único de ruta
    SET @Codigo = CONCAT(N'RUT-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'));

    INSERT INTO dbo.Rutas (Codigo, Zona, ChoferUsuarioId, VehiculoId, Estado, Observaciones,
                           CreadaPorUsuarioId, CreadaPorNombre, FechaCreacion, FechaActualizacion)
    VALUES (@Codigo, @Zona, @ChoferUsuarioId, @VehiculoId, N'Planificada',
            NULLIF(LTRIM(RTRIM(@Observaciones)), N''),
            @CreadaPorUsuarioId, @CreadaPorNombre, SYSDATETIME(), SYSDATETIME());

    SET @RutaId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.RutaPedidos (RutaId, PedidoId, Secuencia, EstadoEntrega, FechaActualizacion)
    SELECT @RutaId, i.PedidoId,
           ROW_NUMBER() OVER (ORDER BY i.PedidoId),
           N'Pendiente', SYSDATETIME()
    FROM @Items i;

    COMMIT TRANSACTION;

    SELECT @RutaId AS RutaId, @Codigo AS Codigo;
END;
GO

/* =========================================================
   5. sp_Rutas_List
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_List
    @Estado NVARCHAR(20)  = NULL,
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT
        r.RutaId,
        r.Codigo,
        r.Zona,
        r.Estado,
        ch.NombreCompleto                         AS Chofer,
        v.Placa                                   AS VehiculoPlaca,
        r.FechaCreacion,
        r.FechaDespacho,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId)                                   AS TotalPedidos,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId AND rp.EstadoEntrega = N'Entregado') AS Entregados,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId AND rp.EstadoEntrega = N'Fallido')   AS Fallidos,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId AND rp.EstadoEntrega IN (N'Pendiente', N'EnRuta')) AS Pendientes
    FROM dbo.Rutas r
    INNER JOIN dbo.Usuarios  ch ON ch.UsuarioId  = r.ChoferUsuarioId
    INNER JOIN dbo.Vehiculos v  ON v.VehiculoId  = r.VehiculoId
    WHERE (@Estado IS NULL OR r.Estado = @Estado)
      AND (
          @Buscar IS NULL
          OR r.Codigo         LIKE N'%' + @Buscar + N'%'
          OR r.Zona           LIKE N'%' + @Buscar + N'%'
          OR ch.NombreCompleto LIKE N'%' + @Buscar + N'%'
          OR v.Placa          LIKE N'%' + @Buscar + N'%'
      )
    ORDER BY
        CASE r.Estado WHEN N'Despachada' THEN 0 WHEN N'Planificada' THEN 1 WHEN N'Completada' THEN 2 ELSE 3 END,
        r.FechaCreacion DESC;
END;
GO

/* =========================================================
   6. sp_Rutas_GetHeader
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetHeader
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.RutaId,
        r.Codigo,
        r.Zona,
        r.Estado,
        r.ChoferUsuarioId,
        ch.NombreCompleto            AS Chofer,
        r.VehiculoId,
        v.Placa                      AS VehiculoPlaca,
        v.Descripcion                AS VehiculoDescripcion,
        ISNULL(r.Observaciones, N'') AS Observaciones,
        ISNULL(r.CreadaPorNombre, N'') AS CreadaPorNombre,
        r.FechaCreacion,
        r.FechaDespacho,
        r.FechaCierre
    FROM dbo.Rutas r
    INNER JOIN dbo.Usuarios  ch ON ch.UsuarioId = r.ChoferUsuarioId
    INNER JOIN dbo.Vehiculos v  ON v.VehiculoId = r.VehiculoId
    WHERE r.RutaId = @RutaId;
END;
GO

/* =========================================================
   7. sp_Rutas_GetOrders
      Pedidos de una ruta + estado de entrega + evidencias.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_GetOrders
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rp.RutaPedidoId,
        rp.PedidoId,
        rp.Secuencia,
        rp.EstadoEntrega,
        ISNULL(rp.MotivoFallo, N'')              AS MotivoFallo,
        rp.FechaEntrega,
        u.NombreCompleto                         AS Cliente,
        u.Correo                                 AS ClienteCorreo,
        ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) AS DireccionEntrega,
        p.Total,
        p.Estado                                 AS EstadoPedido,
        (SELECT COUNT(*) FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId) AS TotalEvidencias
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia ASC, rp.RutaPedidoId ASC;
END;
GO

/* =========================================================
   8. sp_Rutas_AddOrder   (CU-081 E3)  — solo si Planificada
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_AddOrder
    @RutaId   INT,
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20), @Secuencia INT;

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

    INSERT INTO dbo.RutaPedidos (RutaId, PedidoId, Secuencia, EstadoEntrega, FechaActualizacion)
    VALUES (@RutaId, @PedidoId, @Secuencia, N'Pendiente', SYSDATETIME());

    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
END;
GO

/* =========================================================
   9. sp_Rutas_RemoveOrder   (CU-081 E3)  — solo si Planificada
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_RemoveOrder
    @RutaId   INT,
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20);

    BEGIN TRANSACTION;

    SELECT @EstadoRuta = Estado FROM dbo.Rutas WITH (UPDLOCK, HOLDLOCK) WHERE RutaId = @RutaId;

    IF @EstadoRuta IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52020, 'No se encontró la ruta indicada.', 1; END;

    IF @EstadoRuta <> N'Planificada'
    BEGIN ROLLBACK TRANSACTION; THROW 52021, 'Solo se pueden modificar rutas en estado Planificada (antes del despacho).', 1; END;

    DELETE FROM dbo.RutaPedidos
    WHERE RutaId = @RutaId AND PedidoId = @PedidoId AND EstadoEntrega = N'Pendiente';

    IF @@ROWCOUNT = 0
    BEGIN ROLLBACK TRANSACTION; THROW 52022, 'El pedido no está en la ruta o ya no se puede quitar.', 1; END;

    UPDATE dbo.Rutas SET FechaActualizacion = SYSDATETIME() WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
END;
GO

/* =========================================================
   10. sp_Rutas_Dispatch
       Planificada -> Despachada; pone las entregas en EnRuta.
       Devuelve los pedidos que pasan a EnRuta para notificar (E3).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Dispatch
    @RutaId        INT,
    @UsuarioId     INT           = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20), @Total INT;

    BEGIN TRANSACTION;

    SELECT @EstadoRuta = Estado FROM dbo.Rutas WITH (UPDLOCK, HOLDLOCK) WHERE RutaId = @RutaId;

    IF @EstadoRuta IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52030, 'No se encontró la ruta indicada.', 1; END;

    IF @EstadoRuta <> N'Planificada'
    BEGIN ROLLBACK TRANSACTION; THROW 52031, 'Solo se pueden despachar rutas en estado Planificada.', 1; END;

    SELECT @Total = COUNT(*) FROM dbo.RutaPedidos WHERE RutaId = @RutaId;
    IF @Total = 0
    BEGIN ROLLBACK TRANSACTION; THROW 52032, 'La ruta no tiene pedidos para despachar.', 1; END;

    UPDATE dbo.RutaPedidos
    SET EstadoEntrega = N'EnRuta', FechaActualizacion = SYSDATETIME()
    WHERE RutaId = @RutaId AND EstadoEntrega = N'Pendiente';

    UPDATE dbo.Rutas
    SET Estado = N'Despachada', FechaDespacho = SYSDATETIME(), FechaActualizacion = SYSDATETIME()
    WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;

    -- Pedidos ahora En ruta -> para notificación al cliente (CU-082 E3)
    SELECT
        rp.PedidoId,
        u.NombreCompleto AS ClienteNombre,
        u.Correo         AS ClienteCorreo
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId AND rp.EstadoEntrega = N'EnRuta';
END;
GO

/* =========================================================
   11. sp_Rutas_Cancel
       Cancela la ruta (libera los pedidos para otras rutas).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Rutas_Cancel
    @RutaId        INT,
    @Motivo        NVARCHAR(300) = NULL,
    @UsuarioId     INT           = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRuta NVARCHAR(20);

    BEGIN TRANSACTION;

    SELECT @EstadoRuta = Estado FROM dbo.Rutas WITH (UPDLOCK, HOLDLOCK) WHERE RutaId = @RutaId;

    IF @EstadoRuta IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52040, 'No se encontró la ruta indicada.', 1; END;

    IF @EstadoRuta = N'Completada'
    BEGIN ROLLBACK TRANSACTION; THROW 52041, 'No se puede cancelar una ruta ya completada.', 1; END;

    IF @EstadoRuta = N'Cancelada'
    BEGIN ROLLBACK TRANSACTION; THROW 52042, 'La ruta ya está cancelada.', 1; END;

    UPDATE dbo.Rutas
    SET Estado             = N'Cancelada',
        Observaciones      = LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@Motivo)), N''), Observaciones), 300),
        FechaCierre        = SYSDATETIME(),
        FechaActualizacion = SYSDATETIME()
    WHERE RutaId = @RutaId;

    COMMIT TRANSACTION;
END;
GO

/* =========================================================
   12. sp_Chofer_GetMyRoutes
       Rutas asignadas al chofer (Despachadas primero).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Chofer_GetMyRoutes
    @ChoferUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.RutaId,
        r.Codigo,
        r.Zona,
        r.Estado,
        v.Placa AS VehiculoPlaca,
        r.FechaDespacho,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId) AS TotalPedidos,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId AND rp.EstadoEntrega IN (N'Pendiente', N'EnRuta')) AS Pendientes,
        (SELECT COUNT(*) FROM dbo.RutaPedidos rp WHERE rp.RutaId = r.RutaId AND rp.EstadoEntrega = N'Entregado') AS Entregados
    FROM dbo.Rutas r
    INNER JOIN dbo.Vehiculos v ON v.VehiculoId = r.VehiculoId
    WHERE r.ChoferUsuarioId = @ChoferUsuarioId
      AND r.Estado IN (N'Planificada', N'Despachada', N'Completada')
    ORDER BY
        CASE r.Estado WHEN N'Despachada' THEN 0 WHEN N'Planificada' THEN 1 ELSE 2 END,
        r.FechaCreacion DESC;
END;
GO

/* =========================================================
   13. sp_Chofer_GetRouteDeliveries
       Entregas de una ruta del chofer (valida propiedad).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Chofer_GetRouteDeliveries
    @RutaId          INT,
    @ChoferUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Rutas WHERE RutaId = @RutaId AND ChoferUsuarioId = @ChoferUsuarioId)
        THROW 52060, 'La ruta no existe o no está asignada a este chofer.', 1;

    -- Cabecera
    SELECT
        r.RutaId, r.Codigo, r.Zona, r.Estado,
        v.Placa AS VehiculoPlaca, r.FechaDespacho
    FROM dbo.Rutas r
    INNER JOIN dbo.Vehiculos v ON v.VehiculoId = r.VehiculoId
    WHERE r.RutaId = @RutaId;

    -- Detalle de entregas
    SELECT
        rp.RutaPedidoId,
        rp.PedidoId,
        rp.Secuencia,
        rp.EstadoEntrega,
        ISNULL(rp.MotivoFallo, N'')              AS MotivoFallo,
        rp.FechaEntrega,
        u.NombreCompleto                         AS Cliente,
        ISNULL(u.Telefono, N'')                  AS Telefono,
        ISNULL(NULLIF(p.DireccionEntrega, N''), u.Direccion) AS DireccionEntrega,
        p.Total,
        (SELECT COUNT(*) FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId) AS TotalEvidencias
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia ASC, rp.RutaPedidoId ASC;
END;
GO

/* =========================================================
   14. sp_Chofer_UpdateDeliveryStatus   (CU-082 E1 + E2 + E3)
       - Idempotente por @SyncGuid (soporte offline).
       - Valida propiedad de la ruta y transición.
       - Registra fecha/hora en RutaPedidos y en EntregaSyncLog.
       - Al Entregado sincroniza dbo.Pedidos.Estado='Entregado'
         (respeta guard de Cancelado/Rechazado; NO toca el CHECK).
       - Autocompleta la ruta si ya no quedan entregas pendientes.
       - Devuelve datos para notificar al cliente (EnRuta/Entregado).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Chofer_UpdateDeliveryStatus
    @RutaPedidoId    INT,
    @NuevoEstado     NVARCHAR(20),
    @SyncGuid        UNIQUEIDENTIFIER,
    @MotivoFallo     NVARCHAR(300) = NULL,
    @ChoferUsuarioId INT,
    @ChoferNombre    NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RutaId        INT,
        @EstadoRuta    NVARCHAR(20),
        @EstadoActual  NVARCHAR(20),
        @PedidoId      INT,
        @Notificar     BIT = 0,
        @RutaCompletada BIT = 0;

    SET @NuevoEstado = NULLIF(LTRIM(RTRIM(@NuevoEstado)), N'');
    SET @MotivoFallo = NULLIF(LTRIM(RTRIM(@MotivoFallo)), N'');

    IF @SyncGuid IS NULL
        THROW 52070, 'Falta el identificador de sincronización.', 1;

    IF @NuevoEstado IS NULL OR @NuevoEstado NOT IN (N'EnRuta', N'Entregado', N'Fallido')
        THROW 52071, 'El estado de entrega indicado no es válido.', 1;

    IF @NuevoEstado = N'Fallido' AND @MotivoFallo IS NULL
        THROW 52072, 'Debe indicar el motivo cuando la entrega es fallida.', 1;

    -- ── Idempotencia offline: si el SyncGuid ya se procesó, devolver estado actual ──
    IF EXISTS (SELECT 1 FROM dbo.EntregaSyncLog WHERE SyncGuid = @SyncGuid)
    BEGIN
        SELECT
            rp.RutaPedidoId,
            rp.EstadoEntrega,
            rp.PedidoId,
            u.Correo         AS ClienteCorreo,
            u.NombreCompleto AS ClienteNombre,
            CAST(0 AS BIT)   AS Notificar,       -- ya procesado, no re-notificar
            CAST(CASE WHEN r.Estado = N'Completada' THEN 1 ELSE 0 END AS BIT) AS RutaCompletada,
            CAST(1 AS BIT)   AS Duplicado
        FROM dbo.RutaPedidos rp
        INNER JOIN dbo.Rutas    r ON r.RutaId    = rp.RutaId
        INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
        INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
        WHERE rp.RutaPedidoId = @RutaPedidoId;
        RETURN;
    END;

    BEGIN TRANSACTION;

    SELECT
        @RutaId       = rp.RutaId,
        @EstadoActual = rp.EstadoEntrega,
        @PedidoId     = rp.PedidoId
    FROM dbo.RutaPedidos rp WITH (UPDLOCK, HOLDLOCK)
    WHERE rp.RutaPedidoId = @RutaPedidoId;

    IF @RutaId IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52073, 'No se encontró la entrega indicada.', 1; END;

    SELECT @EstadoRuta = Estado FROM dbo.Rutas WHERE RutaId = @RutaId AND ChoferUsuarioId = @ChoferUsuarioId;

    IF @EstadoRuta IS NULL
    BEGIN ROLLBACK TRANSACTION; THROW 52074, 'La ruta no está asignada a este chofer.', 1; END;

    IF @EstadoRuta <> N'Despachada'
    BEGIN ROLLBACK TRANSACTION; THROW 52075, 'Solo se pueden actualizar entregas de una ruta despachada.', 1; END;

    -- Transiciones válidas
    IF @EstadoActual IN (N'Entregado', N'Fallido')
    BEGIN ROLLBACK TRANSACTION; THROW 52076, 'La entrega ya tiene un estado final.', 1; END;

    -- (@EstadoActual es Pendiente o EnRuta) -> EnRuta/Entregado/Fallido: permitido.

    UPDATE dbo.RutaPedidos
    SET EstadoEntrega      = @NuevoEstado,
        MotivoFallo        = CASE WHEN @NuevoEstado = N'Fallido' THEN @MotivoFallo ELSE NULL END,
        FechaEntrega       = CASE WHEN @NuevoEstado IN (N'Entregado', N'Fallido') THEN SYSDATETIME() ELSE FechaEntrega END,
        FechaActualizacion = SYSDATETIME()
    WHERE RutaPedidoId = @RutaPedidoId;

    -- Sincronizar el pedido a Entregado (transición ya válida; no toca Cancelado/Rechazado)
    IF @NuevoEstado = N'Entregado'
        UPDATE dbo.Pedidos
        SET Estado = N'Entregado', FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId AND Estado NOT IN (N'Cancelado', N'Rechazado', N'Entregado');

    -- Registro de sincronización (idempotencia + historial con fecha/hora)
    INSERT INTO dbo.EntregaSyncLog (SyncGuid, RutaPedidoId, EstadoAnterior, EstadoNuevo, MotivoFallo, ChoferUsuarioId, ChoferNombre, FechaSync)
    VALUES (@SyncGuid, @RutaPedidoId, @EstadoActual, @NuevoEstado, @MotivoFallo, @ChoferUsuarioId, @ChoferNombre, SYSDATETIME());

    -- Autocompletar ruta si ya no quedan entregas pendientes/en ruta
    IF NOT EXISTS (SELECT 1 FROM dbo.RutaPedidos WHERE RutaId = @RutaId AND EstadoEntrega IN (N'Pendiente', N'EnRuta'))
    BEGIN
        UPDATE dbo.Rutas
        SET Estado = N'Completada', FechaCierre = SYSDATETIME(), FechaActualizacion = SYSDATETIME()
        WHERE RutaId = @RutaId;
        SET @RutaCompletada = 1;
    END;

    SET @Notificar = CASE WHEN @NuevoEstado IN (N'EnRuta', N'Entregado') THEN 1 ELSE 0 END;

    COMMIT TRANSACTION;

    SELECT
        rp.RutaPedidoId,
        rp.EstadoEntrega,
        rp.PedidoId,
        u.Correo         AS ClienteCorreo,
        u.NombreCompleto AS ClienteNombre,
        @Notificar       AS Notificar,
        @RutaCompletada  AS RutaCompletada,
        CAST(0 AS BIT)   AS Duplicado
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaPedidoId = @RutaPedidoId;
END;
GO

/* =========================================================
   15. CRUD de Vehículos  (CU-081 — gestión de flota)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_List
    @Buscar NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT
        v.VehiculoId,
        v.Placa,
        v.Descripcion,
        ISNULL(v.Capacidad, 0) AS Capacidad,
        v.Activo,
        (SELECT COUNT(*) FROM dbo.Rutas r
         WHERE r.VehiculoId = v.VehiculoId
           AND r.Estado IN (N'Planificada', N'Despachada')) AS RutasAbiertas
    FROM dbo.Vehiculos v
    WHERE (@Buscar IS NULL
           OR v.Placa       LIKE N'%' + @Buscar + N'%'
           OR v.Descripcion LIKE N'%' + @Buscar + N'%')
    ORDER BY v.Activo DESC, v.Placa ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_GetById
    @VehiculoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT VehiculoId, Placa, Descripcion, ISNULL(Capacidad, 0) AS Capacidad, Activo
    FROM dbo.Vehiculos
    WHERE VehiculoId = @VehiculoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_Create
    @Placa       NVARCHAR(20),
    @Descripcion NVARCHAR(150),
    @Capacidad   INT = NULL,
    @Activo      BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @Placa       = NULLIF(LTRIM(RTRIM(@Placa)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

    IF @Placa IS NULL OR @Descripcion IS NULL
        THROW 52090, 'La placa y la descripción son obligatorias.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE Placa = @Placa)
        THROW 52091, 'Ya existe un vehículo con esa placa.', 1;

    INSERT INTO dbo.Vehiculos (Placa, Descripcion, Capacidad, Activo)
    VALUES (@Placa, @Descripcion, @Capacidad, ISNULL(@Activo, 1));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS VehiculoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_Update
    @VehiculoId  INT,
    @Placa       NVARCHAR(20),
    @Descripcion NVARCHAR(150),
    @Capacidad   INT = NULL,
    @Activo      BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @Placa       = NULLIF(LTRIM(RTRIM(@Placa)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

    IF @Placa IS NULL OR @Descripcion IS NULL
        THROW 52090, 'La placa y la descripción son obligatorias.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId)
        THROW 52092, 'No se encontró el vehículo indicado.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE Placa = @Placa AND VehiculoId <> @VehiculoId)
        THROW 52091, 'Ya existe un vehículo con esa placa.', 1;

    UPDATE dbo.Vehiculos
    SET Placa = @Placa, Descripcion = @Descripcion, Capacidad = @Capacidad, Activo = ISNULL(@Activo, 1)
    WHERE VehiculoId = @VehiculoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_ToggleStatus
    @VehiculoId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId)
        THROW 52092, 'No se encontró el vehículo indicado.', 1;

    -- No inactivar un vehículo con rutas abiertas
    IF EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId AND Activo = 1)
       AND EXISTS (SELECT 1 FROM dbo.Rutas WHERE VehiculoId = @VehiculoId AND Estado IN (N'Planificada', N'Despachada'))
        THROW 52093, 'No se puede inactivar un vehículo con rutas abiertas.', 1;

    UPDATE dbo.Vehiculos SET Activo = CASE WHEN Activo = 1 THEN 0 ELSE 1 END
    WHERE VehiculoId = @VehiculoId;

    SELECT Activo FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId;
END;
GO

PRINT 'CU-082 (SPs de rutas y entregas) aplicado correctamente.';
GO
