-- ============================================================
-- CU-261 (ampliación) — MÉTRICAS INTEGRALES PARA EL ASISTENTE
--
-- Un único SP que devuelve una "foto" completa del negocio en una sola
-- fila. El asistente (motor de reglas en C#) responde cualquier consulta
-- a partir de esta foto y aplica el control de acceso por rol.
--
-- 100 % ADITIVO e IDEMPOTENTE (solo CREATE OR ALTER de un SP de lectura).
-- Las tablas satélite se consultan con guardas OBJECT_ID para que el SP
-- funcione aunque algún módulo no esté aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Asistente_Metricas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @IniMes DATE = DATEFROMPARTS(YEAR(@Hoy), MONTH(@Hoy), 1);
    DECLARE @IniAnio DATE = DATEFROMPARTS(YEAR(@Hoy), 1, 1);

    -- ── Financiero ──────────────────────────────────────────
    DECLARE @VentasHoy DECIMAL(18,2), @VentasMes DECIMAL(18,2), @VentasAnio DECIMAL(18,2),
            @FacturasMes INT, @TicketMes DECIMAL(18,2), @CobrosPendientes DECIMAL(18,2),
            @ClientesConCredito INT = 0, @CreditosBloqueados INT = 0, @ValorInventario DECIMAL(18,2) = 0;

    SELECT @VentasHoy = ISNULL(SUM(Total), 0)
    FROM dbo.Facturas WHERE Estado = N'Generada' AND CAST(FechaFactura AS DATE) = @Hoy;

    SELECT @VentasMes = ISNULL(SUM(Total), 0), @FacturasMes = COUNT(*)
    FROM dbo.Facturas WHERE Estado = N'Generada' AND CAST(FechaFactura AS DATE) BETWEEN @IniMes AND @Hoy;

    SELECT @VentasAnio = ISNULL(SUM(Total), 0)
    FROM dbo.Facturas WHERE Estado = N'Generada' AND CAST(FechaFactura AS DATE) BETWEEN @IniAnio AND @Hoy;

    SET @TicketMes = CASE WHEN @FacturasMes > 0 THEN ROUND(@VentasMes / @FacturasMes, 2) ELSE 0 END;

    SET @CobrosPendientes = (
        SELECT ISNULL(SUM(CASE WHEN s.Saldo > 0 THEN s.Saldo ELSE 0 END), 0)
        FROM (
            SELECT cc.UsuarioId,
                   ISNULL((SELECT SUM(CASE cm.TipoMovimiento
                                        WHEN N'Cargo' THEN cm.Monto WHEN N'Abono' THEN -cm.Monto
                                        WHEN N'AjustePositivo' THEN cm.Monto ELSE -cm.Monto END)
                           FROM dbo.ClienteCreditoMovimientos cm WHERE cm.UsuarioId = cc.UsuarioId), 0) AS Saldo
            FROM dbo.ClienteCreditos cc
        ) s);

    SELECT @ClientesConCredito = SUM(CASE WHEN CreditoActivo = 1 THEN 1 ELSE 0 END),
           @CreditosBloqueados = SUM(CASE WHEN CreditoBloqueado = 1 THEN 1 ELSE 0 END)
    FROM dbo.ClienteCreditos;

    SELECT @ValorInventario = ISNULL(SUM(CAST(Stock AS DECIMAL(18,2)) * Precio), 0)
    FROM dbo.Productos WHERE Activo = 1;

    -- ── Inventario ──────────────────────────────────────────
    DECLARE @TotalProductos INT, @StockBajo INT, @Agotados INT, @DevolucionesCuarentena INT = 0;
    SELECT @TotalProductos = COUNT(*),
           @StockBajo = SUM(CASE WHEN EstadoStock = N'Bajo' THEN 1 ELSE 0 END),
           @Agotados  = SUM(CASE WHEN EstadoStock = N'Agotado' THEN 1 ELSE 0 END)
    FROM dbo.Productos WHERE Activo = 1;

    IF OBJECT_ID('dbo.Devoluciones', 'U') IS NOT NULL
        SELECT @DevolucionesCuarentena = COUNT(*) FROM dbo.Devoluciones WHERE Estado = N'EnCuarentena';

    -- ── Pedidos ─────────────────────────────────────────────
    DECLARE @PedidosHoy INT, @PedidosPendientes INT, @PedidosRetenidos INT,
            @PedidosEntregadosHoy INT, @PedidosEnRuta INT = 0;
    SELECT @PedidosHoy = SUM(CASE WHEN CAST(FechaPedido AS DATE) = @Hoy THEN 1 ELSE 0 END),
           @PedidosPendientes = SUM(CASE WHEN Estado = N'Pendiente' THEN 1 ELSE 0 END),
           @PedidosRetenidos = SUM(CASE WHEN Estado = N'Retenido' THEN 1 ELSE 0 END),
           @PedidosEntregadosHoy = SUM(CASE WHEN Estado = N'Entregado' AND CAST(FechaPedido AS DATE) = @Hoy THEN 1 ELSE 0 END)
    FROM dbo.Pedidos;

    IF OBJECT_ID('dbo.RutaPedidos', 'U') IS NOT NULL
        SELECT @PedidosEnRuta = COUNT(*) FROM dbo.RutaPedidos WHERE EstadoEntrega = N'EnRuta';

    -- ── Clientes / consultas ────────────────────────────────
    DECLARE @TotalClientes INT, @ClientesActivos INT, @ConsultasPendientes INT = 0;
    SELECT @TotalClientes = COUNT(*),
           @ClientesActivos = SUM(CASE WHEN u.Activo = 1 THEN 1 ELSE 0 END)
    FROM dbo.Usuarios u INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = N'Cliente';

    IF OBJECT_ID('dbo.Consultas', 'U') IS NOT NULL
        SELECT @ConsultasPendientes = COUNT(*) FROM dbo.Consultas WHERE Estado = N'Pendiente';

    -- ── Personal ────────────────────────────────────────────
    DECLARE @TotalEmpleados INT = 0, @SolicitudesPendientes INT = 0, @TareasPendientes INT = 0;
    IF OBJECT_ID('dbo.Empleados', 'U') IS NOT NULL
        SELECT @TotalEmpleados = COUNT(*) FROM dbo.Empleados WHERE Activo = 1;
    IF OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre', 'U') IS NOT NULL
        SELECT @SolicitudesPendientes = COUNT(*) FROM dbo.EmpleadoSolicitudesTiempoLibre WHERE Estado = N'Pendiente';
    IF OBJECT_ID('dbo.EmpleadoTareas', 'U') IS NOT NULL
        SELECT @TareasPendientes = COUNT(*) FROM dbo.EmpleadoTareas WHERE Estado IN (N'Pendiente', N'En proceso');

    -- ── Logística / flota ───────────────────────────────────
    DECLARE @RutasPlanificadas INT = 0, @RutasDespachadas INT = 0, @EntregasPendientes INT = 0,
            @EntregasFallidas INT = 0, @TotalVehiculos INT = 0, @VehiculosActivos INT = 0,
            @MantenimientosProgramados INT = 0, @AlertasFlota INT = 0, @TotalActivos INT = 0, @ActivosPrestados INT = 0;

    IF OBJECT_ID('dbo.Rutas', 'U') IS NOT NULL
        SELECT @RutasPlanificadas = SUM(CASE WHEN Estado = N'Planificada' THEN 1 ELSE 0 END),
               @RutasDespachadas  = SUM(CASE WHEN Estado = N'Despachada'  THEN 1 ELSE 0 END)
        FROM dbo.Rutas;

    IF OBJECT_ID('dbo.RutaPedidos', 'U') IS NOT NULL
        SELECT @EntregasPendientes = SUM(CASE WHEN EstadoEntrega = N'Pendiente' THEN 1 ELSE 0 END),
               @EntregasFallidas   = SUM(CASE WHEN EstadoEntrega = N'Fallido'   THEN 1 ELSE 0 END)
        FROM dbo.RutaPedidos;

    IF OBJECT_ID('dbo.Vehiculos', 'U') IS NOT NULL
        SELECT @TotalVehiculos = COUNT(*), @VehiculosActivos = SUM(CASE WHEN Activo = 1 THEN 1 ELSE 0 END)
        FROM dbo.Vehiculos;

    IF OBJECT_ID('dbo.OrdenesMantenimiento', 'U') IS NOT NULL
        SELECT @MantenimientosProgramados = COUNT(*) FROM dbo.OrdenesMantenimiento WHERE Estado = N'Programada';

    -- Alertas de flota (documentos por vencer/vencidos + preventivos vencidos por fecha o km)
    IF OBJECT_ID('dbo.VehiculoDocumentos', 'U') IS NOT NULL
        SELECT @AlertasFlota = @AlertasFlota + COUNT(*)
        FROM dbo.VehiculoDocumentos WHERE DATEDIFF(DAY, @Hoy, FechaVencimiento) <= 15;

    IF OBJECT_ID('dbo.OrdenesMantenimiento', 'U') IS NOT NULL AND OBJECT_ID('dbo.Vehiculos', 'U') IS NOT NULL
        SELECT @AlertasFlota = @AlertasFlota + COUNT(*)
        FROM dbo.OrdenesMantenimiento m INNER JOIN dbo.Vehiculos v ON v.VehiculoId = m.VehiculoId
        WHERE m.Tipo = N'Preventivo' AND m.Estado = N'Programada'
          AND ((m.FechaProgramada IS NOT NULL AND DATEDIFF(DAY, @Hoy, m.FechaProgramada) <= 15)
               OR (m.KilometrajeProximo IS NOT NULL AND v.KilometrajeActual >= m.KilometrajeProximo));

    IF OBJECT_ID('dbo.Activos', 'U') IS NOT NULL
        SELECT @TotalActivos = COUNT(*), @ActivosPrestados = SUM(CASE WHEN Estado = N'Prestado' THEN 1 ELSE 0 END)
        FROM dbo.Activos;

    -- ── Resultado (una sola fila) ───────────────────────────
    SELECT
        @VentasHoy AS VentasHoy, @VentasMes AS VentasMes, @VentasAnio AS VentasAnio,
        @FacturasMes AS FacturasMes, @TicketMes AS TicketPromedioMes, @CobrosPendientes AS CobrosPendientes,
        @ClientesConCredito AS ClientesConCredito, @CreditosBloqueados AS CreditosBloqueados, @ValorInventario AS ValorInventario,
        @TotalProductos AS TotalProductos, ISNULL(@StockBajo,0) AS StockBajo, ISNULL(@Agotados,0) AS ProductosAgotados,
        @DevolucionesCuarentena AS DevolucionesCuarentena,
        ISNULL(@PedidosHoy,0) AS PedidosHoy, ISNULL(@PedidosPendientes,0) AS PedidosPendientes,
        ISNULL(@PedidosRetenidos,0) AS PedidosRetenidos, @PedidosEnRuta AS PedidosEnRuta,
        ISNULL(@PedidosEntregadosHoy,0) AS PedidosEntregadosHoy,
        @TotalClientes AS TotalClientes, ISNULL(@ClientesActivos,0) AS ClientesActivos, @ConsultasPendientes AS ConsultasPendientes,
        @TotalEmpleados AS TotalEmpleados, @SolicitudesPendientes AS SolicitudesPendientes, @TareasPendientes AS TareasPendientes,
        ISNULL(@RutasPlanificadas,0) AS RutasPlanificadas, ISNULL(@RutasDespachadas,0) AS RutasDespachadas,
        ISNULL(@EntregasPendientes,0) AS EntregasPendientes, ISNULL(@EntregasFallidas,0) AS EntregasFallidas,
        @TotalVehiculos AS TotalVehiculos, ISNULL(@VehiculosActivos,0) AS VehiculosActivos,
        @MantenimientosProgramados AS MantenimientosProgramados, @AlertasFlota AS AlertasFlota,
        @TotalActivos AS TotalActivos, ISNULL(@ActivosPrestados,0) AS ActivosPrestados;
END;
GO

PRINT 'cu310 aplicado: sp_Asistente_Metricas (foto integral del negocio).';
GO
