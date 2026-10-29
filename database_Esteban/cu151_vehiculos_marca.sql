-- ============================================================
-- CU-151 — Campo Marca en la flota de vehículos
--
-- Como encargado de logística quiero registrar y administrar los
-- vehículos de la flotilla (placa, marca, capacidad de carga) para
-- controlar los activos disponibles para las rutas.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO: agrega una columna nullable; no altera ni
--     elimina tablas, columnas, datos, relaciones ni SPs previos.
--   • IDEMPOTENTE: COL_LENGTH antes de ALTER; SPs con CREATE OR ALTER.
--   • NO toca tablas núcleo (Pedidos, Usuarios, Facturas) ni FKs.
--   • sp_Vehiculos_ToggleStatus NO se modifica.
--
-- Prerrequisito: cu081 (esquema) y cu082 (SPs) ya aplicados.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

SET NOCOUNT ON;
GO

-- ============================================================
-- 1. COLUMNA (nullable, aditiva)
-- ============================================================
IF COL_LENGTH('dbo.Vehiculos', 'Marca') IS NULL
    ALTER TABLE dbo.Vehiculos ADD Marca NVARCHAR(60) NULL;
GO

-- ============================================================
-- 2. STORED PROCEDURES (incluyen Marca)
--    Marca se agrega al FINAL del SELECT en List/GetById para no
--    correr los índices ordinales que ya consume el service C#.
-- ============================================================

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
            AND r.Estado IN (N'Planificada', N'Despachada')) AS RutasAbiertas,
        v.Marca
    FROM dbo.Vehiculos v
    WHERE (@Buscar IS NULL
           OR v.Placa       LIKE N'%' + @Buscar + N'%'
           OR v.Descripcion LIKE N'%' + @Buscar + N'%'
           OR v.Marca       LIKE N'%' + @Buscar + N'%')
    ORDER BY v.Activo DESC, v.Placa ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_GetById
    @VehiculoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT VehiculoId, Placa, Descripcion, ISNULL(Capacidad, 0) AS Capacidad, Activo, Marca
    FROM dbo.Vehiculos
    WHERE VehiculoId = @VehiculoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_Create
    @Placa       NVARCHAR(20),
    @Descripcion NVARCHAR(150),
    @Capacidad   INT = NULL,
    @Activo      BIT = 1,
    @Marca       NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Placa       = NULLIF(LTRIM(RTRIM(@Placa)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    SET @Marca       = NULLIF(LTRIM(RTRIM(@Marca)), N'');

    IF @Placa IS NULL OR @Descripcion IS NULL
        THROW 52090, 'La placa y la descripción son obligatorias.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE Placa = @Placa)
        THROW 52091, 'Ya existe un vehículo con esa placa.', 1;

    INSERT INTO dbo.Vehiculos (Placa, Descripcion, Capacidad, Activo, Marca)
    VALUES (@Placa, @Descripcion, @Capacidad, ISNULL(@Activo, 1), @Marca);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS VehiculoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_Update
    @VehiculoId  INT,
    @Placa       NVARCHAR(20),
    @Descripcion NVARCHAR(150),
    @Capacidad   INT = NULL,
    @Activo      BIT = 1,
    @Marca       NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Placa       = NULLIF(LTRIM(RTRIM(@Placa)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    SET @Marca       = NULLIF(LTRIM(RTRIM(@Marca)), N'');

    IF @Placa IS NULL OR @Descripcion IS NULL
        THROW 52090, 'La placa y la descripción son obligatorias.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId)
        THROW 52092, 'No se encontró el vehículo indicado.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE Placa = @Placa AND VehiculoId <> @VehiculoId)
        THROW 52091, 'Ya existe un vehículo con esa placa.', 1;

    UPDATE dbo.Vehiculos
    SET Placa       = @Placa,
        Descripcion = @Descripcion,
        Capacidad   = @Capacidad,
        Activo      = ISNULL(@Activo, 1),
        Marca       = @Marca
    WHERE VehiculoId = @VehiculoId;
END;
GO

PRINT 'CU-151 aplicado: columna Marca + SPs de vehículos actualizados.';
GO
