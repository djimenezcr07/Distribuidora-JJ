-- ============================================================
-- CU-222 — COMPRAS Y PRESUPUESTO (GASTOS OPERATIVOS)
--
--   CU-222  Registrar los gastos operativos diarios para afectar
--           las cuentas presupuestarias correspondientes.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE.
--   • Tablas nuevas independientes; NO interfiere con Cuentas por
--     Cobrar (AR de clientes) ni con facturación/finanzas.
--   • Cada gasto "afecta" el presupuesto de su cuenta vía el
--     resumen presupuestario (presupuesto vs gastado vs disponible).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLAS
-- ============================================================
IF OBJECT_ID('dbo.CuentasPresupuestarias','U') IS NULL
CREATE TABLE dbo.CuentasPresupuestarias (
    CuentaId           INT IDENTITY(1,1) NOT NULL,
    Codigo             NVARCHAR(20)      NOT NULL,
    Nombre             NVARCHAR(120)     NOT NULL,
    Descripcion        NVARCHAR(300)     NULL,
    PresupuestoMensual DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Cuenta_Presup DEFAULT 0,
    Activo             BIT               NOT NULL CONSTRAINT DF_Cuenta_Activo DEFAULT 1,
    FechaRegistro      DATETIME2         NOT NULL CONSTRAINT DF_Cuenta_FReg DEFAULT SYSDATETIME(),
    FechaActualizacion DATETIME2         NULL,
    CONSTRAINT PK_CuentasPresupuestarias PRIMARY KEY (CuentaId),
    CONSTRAINT UQ_Cuenta_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Cuenta_Presup CHECK (PresupuestoMensual >= 0)
);
GO

IF OBJECT_ID('dbo.GastosOperativos','U') IS NULL
CREATE TABLE dbo.GastosOperativos (
    GastoId                INT IDENTITY(1,1) NOT NULL,
    CuentaId               INT               NOT NULL,   -- cuenta presupuestaria afectada
    Fecha                  DATE              NOT NULL CONSTRAINT DF_Gasto_Fecha DEFAULT CAST(SYSDATETIME() AS DATE),
    Monto                  DECIMAL(18,2)     NOT NULL,
    Concepto               NVARCHAR(200)     NOT NULL,
    Proveedor              NVARCHAR(150)     NULL,
    Comprobante            NVARCHAR(60)      NULL,
    RegistradoPorUsuarioId INT               NULL,
    RegistradoPorNombre    NVARCHAR(150)     NULL,
    FechaRegistro          DATETIME2         NOT NULL CONSTRAINT DF_Gasto_FReg DEFAULT SYSDATETIME(),
    CONSTRAINT PK_GastosOperativos PRIMARY KEY (GastoId),
    CONSTRAINT CK_Gasto_Monto CHECK (Monto > 0),
    CONSTRAINT FK_Gasto_Cuenta FOREIGN KEY (CuentaId) REFERENCES dbo.CuentasPresupuestarias (CuentaId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gastos_Fecha' AND object_id = OBJECT_ID('dbo.GastosOperativos'))
    CREATE INDEX IX_Gastos_Fecha ON dbo.GastosOperativos (Fecha DESC, CuentaId);
GO

-- Seed de cuentas presupuestarias base (idempotente por Codigo)
MERGE dbo.CuentasPresupuestarias AS t
USING (VALUES
    (N'LOG', N'Logística y transporte',    N'Combustible, peajes, fletes y mantenimiento de reparto.', 500000),
    (N'SERV',N'Servicios',                 N'Electricidad, agua, internet y telefonía.',               300000),
    (N'MANT',N'Mantenimiento e instalaciones', N'Reparaciones y mantenimiento de bodega/local.',       200000),
    (N'ADM', N'Gastos administrativos',    N'Papelería, limpieza y gastos varios de oficina.',         150000)
) AS s (Codigo, Nombre, Descripcion, PresupuestoMensual)
ON t.Codigo = s.Codigo
WHEN NOT MATCHED THEN
    INSERT (Codigo, Nombre, Descripcion, PresupuestoMensual) VALUES (s.Codigo, s.Nombre, s.Descripcion, s.PresupuestoMensual);
GO

-- ============================================================
-- 2. PERMISO + asignación por rol (idempotente)
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'GASTOS_REGISTRAR', N'Compras', N'Registrar gastos operativos', N'Registrar gastos operativos diarios y gestionar cuentas presupuestarias.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'GASTOS_REGISTRAR'),
    (N'Gerente',       N'GASTOS_REGISTRAR');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-222'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

-- 3.1 Cuentas activas para el combo del formulario
CREATE OR ALTER PROCEDURE dbo.sp_CuentasPresupuestarias_Options
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CuentaId, Codigo, Nombre, PresupuestoMensual
    FROM dbo.CuentasPresupuestarias
    WHERE Activo = 1
    ORDER BY Nombre;
END;
GO

-- 3.2 Listado de cuentas (gestión)
CREATE OR ALTER PROCEDURE dbo.sp_CuentasPresupuestarias_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CuentaId, Codigo, Nombre, ISNULL(Descripcion, N'') AS Descripcion, PresupuestoMensual, Activo
    FROM dbo.CuentasPresupuestarias
    ORDER BY Activo DESC, Nombre;
END;
GO

-- 3.3 Crear/actualizar cuenta presupuestaria
CREATE OR ALTER PROCEDURE dbo.sp_CuentasPresupuestarias_Upsert
    @CuentaId           INT           = NULL,
    @Codigo             NVARCHAR(20),
    @Nombre             NVARCHAR(120),
    @Descripcion        NVARCHAR(300) = NULL,
    @PresupuestoMensual DECIMAL(18,2) = 0,
    @Activo             BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET @Codigo = NULLIF(LTRIM(RTRIM(@Codigo)), N'');
    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    SET @CuentaId = NULLIF(@CuentaId, 0);
    IF @Codigo IS NULL THROW 53150, 'El código de la cuenta es obligatorio.', 1;
    IF @Nombre IS NULL THROW 53151, 'El nombre de la cuenta es obligatorio.', 1;
    IF @PresupuestoMensual IS NULL OR @PresupuestoMensual < 0 THROW 53152, 'El presupuesto mensual no puede ser negativo.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CuentasPresupuestarias WHERE Codigo = @Codigo AND (@CuentaId IS NULL OR CuentaId <> @CuentaId))
        THROW 53153, 'Ya existe otra cuenta con ese código.', 1;

    IF @CuentaId IS NULL
        INSERT INTO dbo.CuentasPresupuestarias (Codigo, Nombre, Descripcion, PresupuestoMensual, Activo)
        VALUES (@Codigo, @Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @PresupuestoMensual, ISNULL(@Activo, 1));
    ELSE
        UPDATE dbo.CuentasPresupuestarias
        SET Codigo = @Codigo, Nombre = @Nombre, Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N''),
            PresupuestoMensual = @PresupuestoMensual, Activo = ISNULL(@Activo, 1), FechaActualizacion = SYSDATETIME()
        WHERE CuentaId = @CuentaId;
END;
GO

-- 3.4 CU-222 — Registrar gasto operativo
CREATE OR ALTER PROCEDURE dbo.sp_Gastos_Registrar
    @CuentaId    INT,
    @Fecha       DATE           = NULL,
    @Monto       DECIMAL(18,2),
    @Concepto    NVARCHAR(200),
    @Proveedor   NVARCHAR(150)  = NULL,
    @Comprobante NVARCHAR(60)   = NULL,
    @UsuarioId   INT            = NULL,
    @Nombre      NVARCHAR(150)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Concepto = NULLIF(LTRIM(RTRIM(@Concepto)), N'');
    IF NOT EXISTS (SELECT 1 FROM dbo.CuentasPresupuestarias WHERE CuentaId = @CuentaId AND Activo = 1)
        THROW 53154, 'La cuenta presupuestaria no existe o está inactiva.', 1;
    IF @Monto IS NULL OR @Monto <= 0 THROW 53155, 'El monto del gasto debe ser mayor que cero.', 1;
    IF @Concepto IS NULL THROW 53156, 'El concepto del gasto es obligatorio.', 1;
    IF @Fecha IS NOT NULL AND @Fecha > CAST(SYSDATETIME() AS DATE) THROW 53157, 'La fecha del gasto no puede ser futura.', 1;

    INSERT INTO dbo.GastosOperativos
        (CuentaId, Fecha, Monto, Concepto, Proveedor, Comprobante, RegistradoPorUsuarioId, RegistradoPorNombre)
    VALUES
        (@CuentaId, ISNULL(@Fecha, CAST(SYSDATETIME() AS DATE)), @Monto, @Concepto,
         NULLIF(LTRIM(RTRIM(@Proveedor)), N''), NULLIF(LTRIM(RTRIM(@Comprobante)), N''), @UsuarioId, @Nombre);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS GastoId;
END;
GO

-- 3.5 CU-222 — Listado de gastos del período
CREATE OR ALTER PROCEDURE dbo.sp_Gastos_List
    @Anio     INT,
    @Mes      INT,
    @CuentaId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @CuentaId = NULLIF(@CuentaId, 0);
    SELECT
        g.GastoId, g.Fecha, g.Monto, g.Concepto, ISNULL(g.Proveedor, N'') AS Proveedor,
        ISNULL(g.Comprobante, N'') AS Comprobante, ISNULL(g.RegistradoPorNombre, N'') AS RegistradoPorNombre,
        c.CuentaId, c.Codigo AS CuentaCodigo, c.Nombre AS CuentaNombre
    FROM dbo.GastosOperativos g
    INNER JOIN dbo.CuentasPresupuestarias c ON c.CuentaId = g.CuentaId
    WHERE YEAR(g.Fecha) = @Anio AND MONTH(g.Fecha) = @Mes
      AND (@CuentaId IS NULL OR g.CuentaId = @CuentaId)
    ORDER BY g.Fecha DESC, g.GastoId DESC;
END;
GO

-- 3.6 CU-222 — Resumen presupuestario (afectación de cuentas del período)
CREATE OR ALTER PROCEDURE dbo.sp_Presupuesto_Resumen
    @Anio INT,
    @Mes  INT
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Gasto AS (
        SELECT CuentaId, SUM(Monto) AS Gastado
        FROM dbo.GastosOperativos
        WHERE YEAR(Fecha) = @Anio AND MONTH(Fecha) = @Mes
        GROUP BY CuentaId
    )
    SELECT
        c.CuentaId, c.Codigo, c.Nombre, c.PresupuestoMensual,
        ISNULL(g.Gastado, 0) AS Gastado,
        c.PresupuestoMensual - ISNULL(g.Gastado, 0) AS Disponible,
        CASE WHEN c.PresupuestoMensual > 0
             THEN CAST(ISNULL(g.Gastado, 0) / c.PresupuestoMensual * 100 AS DECIMAL(9,2))
             ELSE NULL END AS PorcentajeEjecucion
    FROM dbo.CuentasPresupuestarias c
    LEFT JOIN Gasto g ON g.CuentaId = c.CuentaId
    WHERE c.Activo = 1
    ORDER BY c.Nombre;
END;
GO

PRINT 'CU-222 aplicado: gastos operativos y cuentas presupuestarias.';
GO
