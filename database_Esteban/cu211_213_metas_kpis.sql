-- ============================================================
-- CU-211 / CU-213 — METAS Y RENDIMIENTO (KPIs)
--
--   CU-211  Definir metas mensuales por vendedor para establecer
--           objetivos claros de ingresos.
--   CU-213  Generar un reporte de cumplimiento global de KPIs para
--           evaluar el rendimiento de toda la fuerza de ventas.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE.
--   • Ventas reales = dbo.Facturas ⋈ dbo.Pedidos.VendedorUsuarioId
--     (ingreso facturado); NO altera facturación ni pedidos.
--   • El vendedor se valida contra el perfil 'Vendedor' (cu071).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLA de metas mensuales por vendedor
-- ============================================================
IF OBJECT_ID('dbo.MetasVendedor','U') IS NULL
CREATE TABLE dbo.MetasVendedor (
    MetaId                 INT IDENTITY(1,1) NOT NULL,
    VendedorUsuarioId      INT               NOT NULL,
    Anio                   INT               NOT NULL,
    Mes                    INT               NOT NULL,
    MontoMeta              DECIMAL(18,2)     NOT NULL,
    Observaciones          NVARCHAR(300)     NULL,
    RegistradoPorUsuarioId INT               NULL,
    RegistradoPorNombre    NVARCHAR(150)     NULL,
    FechaRegistro          DATETIME2         NOT NULL CONSTRAINT DF_Meta_FReg DEFAULT SYSDATETIME(),
    FechaActualizacion     DATETIME2         NULL,
    CONSTRAINT PK_MetasVendedor PRIMARY KEY (MetaId),
    CONSTRAINT UQ_MetasVendedor UNIQUE (VendedorUsuarioId, Anio, Mes),
    CONSTRAINT CK_Meta_Mes    CHECK (Mes BETWEEN 1 AND 12),
    CONSTRAINT CK_Meta_Anio   CHECK (Anio BETWEEN 2000 AND 2100),
    CONSTRAINT CK_Meta_Monto  CHECK (MontoMeta > 0),
    CONSTRAINT FK_Meta_Vendedor FOREIGN KEY (VendedorUsuarioId) REFERENCES dbo.Usuarios (UsuarioId)
);
GO

-- ============================================================
-- 2. PERMISOS + asignación por rol (idempotente)
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'METAS_GESTIONAR', N'Metas y KPIs', N'Gestionar metas de ventas', N'Definir metas mensuales de ingresos por vendedor.'),
    (N'REPORTE_KPI',     N'Metas y KPIs', N'Reporte de cumplimiento KPI', N'Consultar el cumplimiento global de KPIs de la fuerza de ventas.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'METAS_GESTIONAR'),
    (N'Gerente',       N'METAS_GESTIONAR'),
    (N'Administrador', N'REPORTE_KPI'),
    (N'Gerente',       N'REPORTE_KPI');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-211/213'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

-- 3.1 Vendedores disponibles (perfil 'Vendedor')
CREATE OR ALTER PROCEDURE dbo.sp_Metas_Vendedores_Options
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId, u.NombreCompleto, u.Correo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
    WHERE u.Activo = 1 AND pf.Nombre = N'Vendedor'
    ORDER BY u.NombreCompleto;
END;
GO

-- 3.2 CU-211 — Crear/actualizar meta (upsert por vendedor/año/mes)
CREATE OR ALTER PROCEDURE dbo.sp_Metas_Upsert
    @VendedorUsuarioId INT,
    @Anio              INT,
    @Mes               INT,
    @MontoMeta         DECIMAL(18,2),
    @Observaciones     NVARCHAR(300) = NULL,
    @UsuarioId         INT           = NULL,
    @Nombre            NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios u
        INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
        WHERE u.UsuarioId = @VendedorUsuarioId AND pf.Nombre = N'Vendedor')
        THROW 53130, 'El usuario seleccionado no es un vendedor válido.', 1;
    IF @Mes NOT BETWEEN 1 AND 12 THROW 53131, 'El mes debe estar entre 1 y 12.', 1;
    IF @Anio NOT BETWEEN 2000 AND 2100 THROW 53132, 'El año indicado no es válido.', 1;
    IF @MontoMeta IS NULL OR @MontoMeta <= 0 THROW 53133, 'El monto de la meta debe ser mayor que cero.', 1;

    SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), N'');

    UPDATE dbo.MetasVendedor
    SET MontoMeta = @MontoMeta, Observaciones = @Observaciones, FechaActualizacion = SYSDATETIME()
    WHERE VendedorUsuarioId = @VendedorUsuarioId AND Anio = @Anio AND Mes = @Mes;

    IF @@ROWCOUNT = 0
        INSERT INTO dbo.MetasVendedor
            (VendedorUsuarioId, Anio, Mes, MontoMeta, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombre)
        VALUES
            (@VendedorUsuarioId, @Anio, @Mes, @MontoMeta, @Observaciones, @UsuarioId, @Nombre);
END;
GO

-- 3.3 CU-211 — Listar metas del período con avance de ventas reales
CREATE OR ALTER PROCEDURE dbo.sp_Metas_List
    @Anio INT,
    @Mes  INT
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Ventas AS (
        SELECT p.VendedorUsuarioId, SUM(f.Total) AS VentasReales
        FROM dbo.Facturas f
        INNER JOIN dbo.Pedidos p ON p.PedidoId = f.PedidoId
        WHERE YEAR(f.FechaFactura) = @Anio AND MONTH(f.FechaFactura) = @Mes
          AND f.Estado <> N'Anulada'
          AND p.VendedorUsuarioId IS NOT NULL
        GROUP BY p.VendedorUsuarioId
    )
    SELECT
        m.MetaId, m.VendedorUsuarioId, u.NombreCompleto AS VendedorNombre,
        m.Anio, m.Mes, m.MontoMeta,
        ISNULL(v.VentasReales, 0) AS VentasReales,
        CASE WHEN m.MontoMeta > 0 THEN CAST(ISNULL(v.VentasReales, 0) / m.MontoMeta * 100 AS DECIMAL(9,2)) ELSE 0 END AS PorcentajeCumplimiento,
        ISNULL(m.Observaciones, N'') AS Observaciones
    FROM dbo.MetasVendedor m
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = m.VendedorUsuarioId
    LEFT JOIN Ventas v ON v.VendedorUsuarioId = m.VendedorUsuarioId
    WHERE m.Anio = @Anio AND m.Mes = @Mes
    ORDER BY u.NombreCompleto;
END;
GO

-- 3.4 CU-213 — Reporte de cumplimiento global de KPIs
--     Incluye a todos los vendedores con meta o con ventas en el período.
CREATE OR ALTER PROCEDURE dbo.sp_Kpi_CumplimientoGlobal
    @Anio INT,
    @Mes  INT
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Ventas AS (
        SELECT p.VendedorUsuarioId, SUM(f.Total) AS VentasReales, COUNT(DISTINCT f.FacturaId) AS Facturas
        FROM dbo.Facturas f
        INNER JOIN dbo.Pedidos p ON p.PedidoId = f.PedidoId
        WHERE YEAR(f.FechaFactura) = @Anio AND MONTH(f.FechaFactura) = @Mes
          AND f.Estado <> N'Anulada'
          AND p.VendedorUsuarioId IS NOT NULL
        GROUP BY p.VendedorUsuarioId
    ),
    Metas AS (
        SELECT VendedorUsuarioId, MontoMeta FROM dbo.MetasVendedor WHERE Anio = @Anio AND Mes = @Mes
    ),
    Base AS (
        SELECT VendedorUsuarioId FROM Metas
        UNION
        SELECT VendedorUsuarioId FROM Ventas
    )
    SELECT
        b.VendedorUsuarioId,
        u.NombreCompleto AS VendedorNombre,
        ISNULL(m.MontoMeta, 0)      AS MontoMeta,
        ISNULL(v.VentasReales, 0)   AS VentasReales,
        ISNULL(v.Facturas, 0)       AS Facturas,
        CASE WHEN ISNULL(m.MontoMeta, 0) > 0
             THEN CAST(ISNULL(v.VentasReales, 0) / m.MontoMeta * 100 AS DECIMAL(9,2))
             ELSE NULL END          AS PorcentajeCumplimiento,
        CASE
            WHEN ISNULL(m.MontoMeta, 0) = 0 THEN N'SinMeta'
            WHEN ISNULL(v.VentasReales, 0) / m.MontoMeta >= 1.0  THEN N'Cumplida'
            WHEN ISNULL(v.VentasReales, 0) / m.MontoMeta >= 0.7  THEN N'EnRiesgo'
            ELSE N'Incumplida'
        END AS Clasificacion
    FROM Base b
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = b.VendedorUsuarioId
    LEFT JOIN Metas m  ON m.VendedorUsuarioId = b.VendedorUsuarioId
    LEFT JOIN Ventas v ON v.VendedorUsuarioId = b.VendedorUsuarioId
    ORDER BY VentasReales DESC, VendedorNombre;

    -- Resumen global (segunda tabla de resultados)
    SELECT
        (SELECT ISNULL(SUM(MontoMeta), 0) FROM dbo.MetasVendedor WHERE Anio = @Anio AND Mes = @Mes) AS MetaGlobal,
        (SELECT ISNULL(SUM(f.Total), 0)
           FROM dbo.Facturas f INNER JOIN dbo.Pedidos p ON p.PedidoId = f.PedidoId
           WHERE YEAR(f.FechaFactura) = @Anio AND MONTH(f.FechaFactura) = @Mes
             AND f.Estado <> N'Anulada' AND p.VendedorUsuarioId IS NOT NULL) AS VentaGlobal,
        (SELECT COUNT(*) FROM dbo.MetasVendedor WHERE Anio = @Anio AND Mes = @Mes) AS VendedoresConMeta;
END;
GO

PRINT 'CU-211/213 aplicado: metas mensuales por vendedor y reporte global de KPIs.';
GO
