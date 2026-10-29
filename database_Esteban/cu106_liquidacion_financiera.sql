-- ============================================================
-- CU-106 — LIQUIDACIÓN FINANCIERA DE COBROS DE RUTA
--   Cajero/financiero cuadra el efectivo y los comprobantes
--   recibidos por el chofer contra lo esperado de los pedidos
--   entregados de la ruta.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE (IF OBJECT_ID / CREATE OR ALTER).
--   • Complementa (NO sustituye) la liquidación logística CU-105.
--   • Reutiliza dbo.Rutas, dbo.RutaPedidos, dbo.Pedidos.
--
-- Prerrequisitos: cu081 (Rutas/RutaPedidos), cu141 (liquidación logística).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLAS
-- ============================================================

-- 1.1 Cabecera de liquidación financiera (una por ruta)
IF OBJECT_ID('dbo.RutaLiquidacionCobros','U') IS NULL
CREATE TABLE dbo.RutaLiquidacionCobros (
    LiquidacionCobrosId   INT IDENTITY(1,1) NOT NULL,
    RutaId                INT               NOT NULL,
    MontoEsperadoEfectivo DECIMAL(18,2)     NOT NULL CONSTRAINT DF_LiqCob_Esp DEFAULT 0,
    MontoEsperadoOtros    DECIMAL(18,2)     NOT NULL CONSTRAINT DF_LiqCob_EspOtros DEFAULT 0,
    MontoEfectivoRecibido DECIMAL(18,2)     NOT NULL CONSTRAINT DF_LiqCob_EfeRec DEFAULT 0,
    MontoComprobantes     DECIMAL(18,2)     NOT NULL CONSTRAINT DF_LiqCob_Comp DEFAULT 0,
    Diferencia AS (MontoEfectivoRecibido + MontoComprobantes - MontoEsperadoEfectivo - MontoEsperadoOtros) PERSISTED,
    Estado                NVARCHAR(20)      NOT NULL CONSTRAINT DF_LiqCob_Estado DEFAULT N'Cuadrada',
    Observaciones         NVARCHAR(400)     NULL,
    LiquidadoPorUsuarioId INT               NULL,
    LiquidadoPorNombre    NVARCHAR(150)     NULL,
    FechaLiquidacion      DATETIME2         NOT NULL CONSTRAINT DF_LiqCob_Fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_RutaLiquidacionCobros PRIMARY KEY (LiquidacionCobrosId),
    CONSTRAINT UQ_RutaLiquidacionCobros_Ruta UNIQUE (RutaId),
    CONSTRAINT CK_LiqCob_Estado CHECK (Estado IN (N'Cuadrada', N'Faltante', N'Sobrante'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_LiqCob_Ruta' AND parent_object_id = OBJECT_ID('dbo.RutaLiquidacionCobros'))
    ALTER TABLE dbo.RutaLiquidacionCobros ADD CONSTRAINT FK_LiqCob_Ruta FOREIGN KEY (RutaId) REFERENCES dbo.Rutas (RutaId);
GO

-- 1.2 Detalle de comprobantes recibidos (SINPE, transferencia, depósito...)
IF OBJECT_ID('dbo.RutaLiquidacionComprobantes','U') IS NULL
CREATE TABLE dbo.RutaLiquidacionComprobantes (
    ComprobanteId       INT IDENTITY(1,1) NOT NULL,
    LiquidacionCobrosId INT               NOT NULL,
    Tipo                NVARCHAR(30)      NOT NULL,   -- SINPE | Transferencia | Depósito | Cheque | Otro
    Referencia          NVARCHAR(80)      NULL,
    Monto               DECIMAL(18,2)     NOT NULL,
    CONSTRAINT PK_RutaLiquidacionComprobantes PRIMARY KEY (ComprobanteId),
    CONSTRAINT CK_LiqComp_Monto CHECK (Monto > 0),
    CONSTRAINT FK_LiqComp_Cab FOREIGN KEY (LiquidacionCobrosId) REFERENCES dbo.RutaLiquidacionCobros (LiquidacionCobrosId)
);
GO

-- ============================================================
-- 2. PERMISOS (idempotente). El JOIN filtra perfiles inexistentes.
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'LIQUIDACION_FINANCIERA', N'Finanzas', N'Liquidar cobros de ruta', N'Registrar la liquidación financiera (efectivo y comprobantes) de una ruta.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'LIQUIDACION_FINANCIERA'),
    (N'Gerente',       N'LIQUIDACION_FINANCIERA'),
    (N'Cajero',        N'LIQUIDACION_FINANCIERA'),
    (N'Financiero',    N'LIQUIDACION_FINANCIERA');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-106'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

-- 3.1 Preparar: calcula lo esperado y lista los pedidos entregados de la ruta
CREATE OR ALTER PROCEDURE dbo.sp_LiquidacionCobros_Preparar
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rutas WHERE RutaId = @RutaId) THROW 53070, 'La ruta indicada no existe.', 1;

    SELECT
        r.RutaId, r.Codigo, r.Estado, r.Liquidada,
        ISNULL(lc.LiquidacionCobrosId, 0) AS LiquidacionCobrosId,
        ISNULL(SUM(CASE WHEN rp.EstadoEntrega = N'Entregado' AND p.MetodoPago LIKE N'%Efectivo%' THEN p.Total END), 0) AS EsperadoEfectivo,
        ISNULL(SUM(CASE WHEN rp.EstadoEntrega = N'Entregado' AND p.MetodoPago NOT LIKE N'%Efectivo%' THEN p.Total END), 0) AS EsperadoOtros
    FROM dbo.Rutas r
    LEFT JOIN dbo.RutaPedidos rp ON rp.RutaId = r.RutaId
    LEFT JOIN dbo.Pedidos p ON p.PedidoId = rp.PedidoId
    LEFT JOIN dbo.RutaLiquidacionCobros lc ON lc.RutaId = r.RutaId
    WHERE r.RutaId = @RutaId
    GROUP BY r.RutaId, r.Codigo, r.Estado, r.Liquidada, lc.LiquidacionCobrosId;

    -- Detalle de pedidos entregados
    SELECT p.PedidoId, p.Total, p.MetodoPago, p.EstadoPago, ISNULL(u.NombreCompleto, N'') AS Cliente
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos p ON p.PedidoId = rp.PedidoId
    LEFT JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId AND rp.EstadoEntrega = N'Entregado'
    ORDER BY p.PedidoId;
END;
GO

-- 3.2 Registrar liquidación financiera
CREATE OR ALTER PROCEDURE dbo.sp_LiquidacionCobros_Registrar
    @RutaId                INT,
    @MontoEfectivoRecibido DECIMAL(18,2),
    @MontoComprobantes     DECIMAL(18,2) = 0,
    @Observaciones         NVARCHAR(400) = NULL,
    @ComprobantesJson      NVARCHAR(MAX) = NULL,   -- [{Tipo,Referencia,Monto}]
    @UsuarioId             INT           = NULL,
    @Nombre                NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rutas WHERE RutaId = @RutaId) THROW 53070, 'La ruta indicada no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.RutaLiquidacionCobros WHERE RutaId = @RutaId) THROW 53071, 'Esta ruta ya tiene liquidación financiera registrada.', 1;
    IF ISNULL(@MontoEfectivoRecibido, -1) < 0 THROW 53072, 'El efectivo recibido no puede ser negativo.', 1;
    IF ISNULL(@MontoComprobantes, -1) < 0 THROW 53073, 'El monto de comprobantes no puede ser negativo.', 1;

    DECLARE @Esp DECIMAL(18,2) = 0, @EspOtros DECIMAL(18,2) = 0;
    SELECT
        @Esp      = ISNULL(SUM(CASE WHEN rp.EstadoEntrega = N'Entregado' AND p.MetodoPago LIKE N'%Efectivo%' THEN p.Total END), 0),
        @EspOtros = ISNULL(SUM(CASE WHEN rp.EstadoEntrega = N'Entregado' AND p.MetodoPago NOT LIKE N'%Efectivo%' THEN p.Total END), 0)
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos p ON p.PedidoId = rp.PedidoId
    WHERE rp.RutaId = @RutaId;

    DECLARE @Dif DECIMAL(18,2) = (@MontoEfectivoRecibido + @MontoComprobantes) - (@Esp + @EspOtros);
    DECLARE @Estado NVARCHAR(20) = CASE WHEN @Dif = 0 THEN N'Cuadrada' WHEN @Dif < 0 THEN N'Faltante' ELSE N'Sobrante' END;

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO dbo.RutaLiquidacionCobros
            (RutaId, MontoEsperadoEfectivo, MontoEsperadoOtros, MontoEfectivoRecibido, MontoComprobantes, Estado, Observaciones, LiquidadoPorUsuarioId, LiquidadoPorNombre)
        VALUES
            (@RutaId, @Esp, @EspOtros, @MontoEfectivoRecibido, @MontoComprobantes, @Estado, NULLIF(LTRIM(RTRIM(@Observaciones)), N''), @UsuarioId, @Nombre);

        DECLARE @Id INT = SCOPE_IDENTITY();

        IF @ComprobantesJson IS NOT NULL AND LTRIM(RTRIM(@ComprobantesJson)) <> N''
            INSERT INTO dbo.RutaLiquidacionComprobantes (LiquidacionCobrosId, Tipo, Referencia, Monto)
            SELECT @Id, j.Tipo, NULLIF(LTRIM(RTRIM(j.Referencia)), N''), j.Monto
            FROM OPENJSON(@ComprobantesJson) WITH (
                Tipo       NVARCHAR(30)  '$.Tipo',
                Referencia NVARCHAR(80)  '$.Referencia',
                Monto      DECIMAL(18,2) '$.Monto'
            ) j
            WHERE j.Monto > 0;

        COMMIT;
        SELECT @Id AS LiquidacionCobrosId, @Estado AS Estado, @Dif AS Diferencia;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END;
GO

-- 3.3 Listado
CREATE OR ALTER PROCEDURE dbo.sp_LiquidacionCobros_List
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SELECT lc.LiquidacionCobrosId, lc.RutaId, r.Codigo AS RutaCodigo,
           lc.MontoEsperadoEfectivo, lc.MontoEsperadoOtros, lc.MontoEfectivoRecibido, lc.MontoComprobantes,
           lc.Diferencia, lc.Estado, ISNULL(lc.LiquidadoPorNombre, N'') AS LiquidadoPorNombre, lc.FechaLiquidacion
    FROM dbo.RutaLiquidacionCobros lc
    INNER JOIN dbo.Rutas r ON r.RutaId = lc.RutaId
    WHERE (@Estado IS NULL OR lc.Estado = @Estado)
    ORDER BY lc.FechaLiquidacion DESC;
END;
GO

-- 3.4 Detalle por ruta (cabecera + comprobantes)
CREATE OR ALTER PROCEDURE dbo.sp_LiquidacionCobros_GetByRuta
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT lc.LiquidacionCobrosId, lc.RutaId, r.Codigo AS RutaCodigo,
           lc.MontoEsperadoEfectivo, lc.MontoEsperadoOtros, lc.MontoEfectivoRecibido, lc.MontoComprobantes,
           lc.Diferencia, lc.Estado, ISNULL(lc.Observaciones, N'') AS Observaciones,
           ISNULL(lc.LiquidadoPorNombre, N'') AS LiquidadoPorNombre, lc.FechaLiquidacion
    FROM dbo.RutaLiquidacionCobros lc
    INNER JOIN dbo.Rutas r ON r.RutaId = lc.RutaId
    WHERE lc.RutaId = @RutaId;

    SELECT c.ComprobanteId, c.Tipo, ISNULL(c.Referencia, N'') AS Referencia, c.Monto
    FROM dbo.RutaLiquidacionComprobantes c
    INNER JOIN dbo.RutaLiquidacionCobros lc ON lc.LiquidacionCobrosId = c.LiquidacionCobrosId
    WHERE lc.RutaId = @RutaId
    ORDER BY c.ComprobanteId;
END;
GO

PRINT 'CU-106 aplicado: liquidación financiera de cobros de ruta.';
GO
