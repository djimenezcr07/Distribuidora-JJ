-- ============================================================
-- CU-152 / CU-153 / CU-154 / CU-161 — FLOTA (MANTENIMIENTO) Y ACTIVOS
--
--   CU-152  Chofer registra kilometraje inicial/final de su jornada.
--   CU-153  Registrar órdenes de mantenimiento (preventivo/correctivo).
--   CU-154  Alertas automáticas de mantenimiento y vencimientos legales.
--   CU-161  Registrar activos de la empresa (neveras, exhibidores) con
--           su código de activo para inventario/préstamo.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE (IF OBJECT_ID / CREATE OR ALTER).
--   • No altera tablas ni SPs previos. Reutiliza dbo.Vehiculos y dbo.Usuarios.
--
-- Prerrequisito: cu081 (Vehiculos) aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLAS
-- ============================================================

-- 1.1 CU-152 — Kilometraje por jornada -----------------------
IF OBJECT_ID('dbo.VehiculoKilometraje', 'U') IS NULL
CREATE TABLE dbo.VehiculoKilometraje (
    KilometrajeId   INT           IDENTITY(1,1) NOT NULL,
    VehiculoId      INT                         NOT NULL,  -- FK -> Vehiculos
    ChoferUsuarioId INT                         NULL,      -- FK -> Usuarios
    ChoferNombre    NVARCHAR(150)               NULL,
    Fecha           DATE                        NOT NULL CONSTRAINT DF_VehKm_Fecha DEFAULT CAST(SYSDATETIME() AS DATE),
    KmInicial       INT                         NOT NULL,
    KmFinal         INT                         NULL,
    Observaciones   NVARCHAR(300)               NULL,
    FechaRegistro   DATETIME2                   NOT NULL CONSTRAINT DF_VehKm_FechaReg DEFAULT SYSDATETIME(),
    FechaCierre     DATETIME2                   NULL,
    CONSTRAINT PK_VehiculoKilometraje PRIMARY KEY (KilometrajeId),
    CONSTRAINT CK_VehKm_Inicial CHECK (KmInicial >= 0),
    CONSTRAINT CK_VehKm_Final   CHECK (KmFinal IS NULL OR KmFinal >= KmInicial)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_VehKm_VehiculoId' AND parent_object_id = OBJECT_ID('dbo.VehiculoKilometraje'))
    ALTER TABLE dbo.VehiculoKilometraje ADD CONSTRAINT FK_VehKm_VehiculoId FOREIGN KEY (VehiculoId) REFERENCES dbo.Vehiculos (VehiculoId);
GO

-- 1.2 CU-153 — Órdenes de mantenimiento ----------------------
IF OBJECT_ID('dbo.OrdenesMantenimiento', 'U') IS NULL
CREATE TABLE dbo.OrdenesMantenimiento (
    OrdenMantenimientoId INT          IDENTITY(1,1) NOT NULL,
    VehiculoId           INT                        NOT NULL,  -- FK -> Vehiculos
    Tipo                 NVARCHAR(20)               NOT NULL,  -- Preventivo | Correctivo
    Descripcion          NVARCHAR(300)              NOT NULL,
    Taller               NVARCHAR(150)              NULL,
    Costo                DECIMAL(18,2)              NOT NULL CONSTRAINT DF_OrdMant_Costo DEFAULT 0,
    Estado               NVARCHAR(20)               NOT NULL CONSTRAINT DF_OrdMant_Estado DEFAULT N'Programada',
    FechaProgramada      DATE                       NULL,
    FechaRealizada       DATE                       NULL,
    KilometrajeProximo   INT                        NULL,      -- para aviso preventivo por desgaste
    RegistradoPorUsuarioId INT                      NULL,
    RegistradoPorNombre    NVARCHAR(150)            NULL,
    FechaRegistro        DATETIME2                  NOT NULL CONSTRAINT DF_OrdMant_FechaReg DEFAULT SYSDATETIME(),
    CONSTRAINT PK_OrdenesMantenimiento PRIMARY KEY (OrdenMantenimientoId),
    CONSTRAINT CK_OrdMant_Tipo   CHECK (Tipo   IN (N'Preventivo', N'Correctivo')),
    CONSTRAINT CK_OrdMant_Estado CHECK (Estado IN (N'Programada', N'EnProceso', N'Completada', N'Cancelada')),
    CONSTRAINT CK_OrdMant_Costo  CHECK (Costo >= 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OrdMant_VehiculoId' AND parent_object_id = OBJECT_ID('dbo.OrdenesMantenimiento'))
    ALTER TABLE dbo.OrdenesMantenimiento ADD CONSTRAINT FK_OrdMant_VehiculoId FOREIGN KEY (VehiculoId) REFERENCES dbo.Vehiculos (VehiculoId);
GO

-- 1.3 CU-154 — Documentos legales del vehículo (marchamo, RTV, seguro)
IF OBJECT_ID('dbo.VehiculoDocumentos', 'U') IS NULL
CREATE TABLE dbo.VehiculoDocumentos (
    DocumentoId      INT          IDENTITY(1,1) NOT NULL,
    VehiculoId       INT                        NOT NULL,  -- FK -> Vehiculos
    Tipo             NVARCHAR(40)               NOT NULL,  -- Marchamo | RTV | Seguro | Otro
    FechaVencimiento DATE                       NOT NULL,
    Observaciones    NVARCHAR(300)              NULL,
    FechaRegistro    DATETIME2                  NOT NULL CONSTRAINT DF_VehDoc_FechaReg DEFAULT SYSDATETIME(),
    CONSTRAINT PK_VehiculoDocumentos PRIMARY KEY (DocumentoId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_VehDoc_VehiculoId' AND parent_object_id = OBJECT_ID('dbo.VehiculoDocumentos'))
    ALTER TABLE dbo.VehiculoDocumentos ADD CONSTRAINT FK_VehDoc_VehiculoId FOREIGN KEY (VehiculoId) REFERENCES dbo.Vehiculos (VehiculoId);
GO

-- 1.4 CU-161 — Activos de la empresa (neveras, exhibidores) --
IF OBJECT_ID('dbo.Activos', 'U') IS NULL
CREATE TABLE dbo.Activos (
    ActivoId        INT           IDENTITY(1,1) NOT NULL,
    CodigoActivo    NVARCHAR(40)                NOT NULL,   -- placa/código de activo
    Nombre          NVARCHAR(150)               NOT NULL,
    Tipo            NVARCHAR(40)                NOT NULL,   -- Nevera | Exhibidor | Otro
    Descripcion     NVARCHAR(300)               NULL,
    Estado          NVARCHAR(20)                NOT NULL CONSTRAINT DF_Activos_Estado DEFAULT N'Disponible',
    ClientePrestamo NVARCHAR(150)               NULL,       -- a quién está prestado
    Activo          BIT                         NOT NULL CONSTRAINT DF_Activos_Activo DEFAULT 1,
    FechaRegistro   DATETIME2                   NOT NULL CONSTRAINT DF_Activos_FechaReg DEFAULT SYSDATETIME(),
    FechaActualizacion DATETIME2                NULL,
    CONSTRAINT PK_Activos PRIMARY KEY (ActivoId),
    CONSTRAINT UQ_Activos_Codigo UNIQUE (CodigoActivo),
    CONSTRAINT CK_Activos_Estado CHECK (Estado IN (N'Disponible', N'Prestado', N'Mantenimiento', N'Baja'))
);
GO

-- ============================================================
-- 2. PERMISOS
-- ============================================================
MERGE dbo.Permisos AS target
USING (VALUES
    (N'FLOTA_KILOMETRAJE',   N'Flota',   N'Registrar kilometraje',   N'Registrar kilometraje inicial/final de jornada.'),
    (N'FLOTA_MANTENIMIENTO', N'Flota',   N'Gestionar mantenimiento', N'Registrar órdenes de mantenimiento y ver alertas.'),
    (N'ACTIVOS_GESTIONAR',   N'Activos', N'Gestionar activos',       N'Registrar y administrar activos de la empresa.')
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
    (N'Administrador', N'FLOTA_KILOMETRAJE'),
    (N'Administrador', N'FLOTA_MANTENIMIENTO'),
    (N'Administrador', N'ACTIVOS_GESTIONAR'),
    (N'Gerente',       N'FLOTA_MANTENIMIENTO'),
    (N'Gerente',       N'ACTIVOS_GESTIONAR'),
    (N'Chofer',        N'FLOTA_KILOMETRAJE');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-152/153/154/161'
FROM @Asig a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES — CU-152 Kilometraje
-- ============================================================

-- Abrir jornada (km inicial). Bloquea si hay una jornada abierta del mismo vehículo.
CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_Abrir
    @VehiculoId INT,
    @ChoferUsuarioId INT           = NULL,
    @ChoferNombre    NVARCHAR(150)  = NULL,
    @KmInicial       INT,
    @Observaciones   NVARCHAR(300)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId AND Activo = 1)
        THROW 53040, 'El vehículo no existe o está inactivo.', 1;
    IF ISNULL(@KmInicial, -1) < 0 THROW 53041, 'El kilometraje inicial no es válido.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VehiculoKilometraje WHERE VehiculoId = @VehiculoId AND KmFinal IS NULL)
        THROW 53042, 'El vehículo tiene una jornada de kilometraje sin cerrar.', 1;

    INSERT INTO dbo.VehiculoKilometraje (VehiculoId, ChoferUsuarioId, ChoferNombre, KmInicial, Observaciones)
    VALUES (@VehiculoId, @ChoferUsuarioId, @ChoferNombre, @KmInicial, NULLIF(LTRIM(RTRIM(@Observaciones)), N''));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS KilometrajeId;
END;
GO

-- Cerrar jornada (km final).
CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_Cerrar
    @KilometrajeId INT,
    @KmFinal       INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @KmInicial INT, @KmFinalActual INT;
    SELECT @KmInicial = KmInicial, @KmFinalActual = KmFinal
    FROM dbo.VehiculoKilometraje WHERE KilometrajeId = @KilometrajeId;

    IF @KmInicial IS NULL      THROW 53043, 'No se encontró la jornada indicada.', 1;
    IF @KmFinalActual IS NOT NULL THROW 53044, 'La jornada ya fue cerrada.', 1;
    IF @KmFinal < @KmInicial   THROW 53045, 'El kilometraje final no puede ser menor al inicial.', 1;

    UPDATE dbo.VehiculoKilometraje
    SET KmFinal = @KmFinal, FechaCierre = SYSDATETIME()
    WHERE KilometrajeId = @KilometrajeId;
END;
GO

-- Listado de jornadas (opcionalmente por vehículo o chofer).
CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_List
    @VehiculoId INT = NULL,
    @ChoferUsuarioId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        k.KilometrajeId, k.VehiculoId, v.Placa AS VehiculoPlaca,
        ISNULL(k.ChoferNombre, N'') AS ChoferNombre, k.Fecha,
        k.KmInicial, k.KmFinal,
        CASE WHEN k.KmFinal IS NULL THEN NULL ELSE k.KmFinal - k.KmInicial END AS Recorrido,
        ISNULL(k.Observaciones, N'') AS Observaciones, k.FechaRegistro
    FROM dbo.VehiculoKilometraje k
    INNER JOIN dbo.Vehiculos v ON v.VehiculoId = k.VehiculoId
    WHERE (@VehiculoId IS NULL OR k.VehiculoId = @VehiculoId)
      AND (@ChoferUsuarioId IS NULL OR k.ChoferUsuarioId = @ChoferUsuarioId)
    ORDER BY k.Fecha DESC, k.KilometrajeId DESC;
END;
GO

-- ============================================================
-- 4. STORED PROCEDURES — CU-153 Mantenimiento y CU-154 Alertas
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Mantenimiento_Create
    @VehiculoId INT,
    @Tipo       NVARCHAR(20),
    @Descripcion NVARCHAR(300),
    @Taller     NVARCHAR(150)  = NULL,
    @Costo      DECIMAL(18,2)  = 0,
    @Estado     NVARCHAR(20)   = N'Programada',
    @FechaProgramada DATE      = NULL,
    @FechaRealizada  DATE      = NULL,
    @KilometrajeProximo INT    = NULL,
    @UsuarioId  INT            = NULL,
    @Nombre     NVARCHAR(150)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId)
        THROW 53050, 'El vehículo indicado no existe.', 1;
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    IF @Descripcion IS NULL THROW 53051, 'Debe describir el mantenimiento.', 1;
    IF @Tipo NOT IN (N'Preventivo', N'Correctivo') THROW 53052, 'Tipo de mantenimiento no válido.', 1;

    INSERT INTO dbo.OrdenesMantenimiento
        (VehiculoId, Tipo, Descripcion, Taller, Costo, Estado, FechaProgramada, FechaRealizada,
         KilometrajeProximo, RegistradoPorUsuarioId, RegistradoPorNombre)
    VALUES
        (@VehiculoId, @Tipo, @Descripcion, NULLIF(LTRIM(RTRIM(@Taller)), N''), ISNULL(@Costo, 0),
         ISNULL(@Estado, N'Programada'), @FechaProgramada, @FechaRealizada, @KilometrajeProximo, @UsuarioId, @Nombre);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS OrdenMantenimientoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mantenimiento_MarcarCompletada
    @OrdenMantenimientoId INT,
    @FechaRealizada DATE = NULL,
    @Costo DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.OrdenesMantenimiento WHERE OrdenMantenimientoId = @OrdenMantenimientoId)
        THROW 53053, 'No se encontró la orden de mantenimiento.', 1;
    UPDATE dbo.OrdenesMantenimiento
    SET Estado = N'Completada',
        FechaRealizada = ISNULL(@FechaRealizada, CAST(SYSDATETIME() AS DATE)),
        Costo = ISNULL(@Costo, Costo)
    WHERE OrdenMantenimientoId = @OrdenMantenimientoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mantenimiento_List
    @VehiculoId INT = NULL,
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SELECT
        m.OrdenMantenimientoId, m.VehiculoId, v.Placa AS VehiculoPlaca, m.Tipo, m.Descripcion,
        ISNULL(m.Taller, N'') AS Taller, m.Costo, m.Estado,
        m.FechaProgramada, m.FechaRealizada, m.KilometrajeProximo,
        ISNULL(m.RegistradoPorNombre, N'') AS RegistradoPorNombre, m.FechaRegistro
    FROM dbo.OrdenesMantenimiento m
    INNER JOIN dbo.Vehiculos v ON v.VehiculoId = m.VehiculoId
    WHERE (@VehiculoId IS NULL OR m.VehiculoId = @VehiculoId)
      AND (@Estado IS NULL OR m.Estado = @Estado)
    ORDER BY m.FechaRegistro DESC;
END;
GO

-- Documentos legales
CREATE OR ALTER PROCEDURE dbo.sp_VehiculoDocumento_Create
    @VehiculoId INT,
    @Tipo NVARCHAR(40),
    @FechaVencimiento DATE,
    @Observaciones NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId)
        THROW 53054, 'El vehículo indicado no existe.', 1;
    SET @Tipo = NULLIF(LTRIM(RTRIM(@Tipo)), N'');
    IF @Tipo IS NULL THROW 53055, 'Debe indicar el tipo de documento.', 1;
    INSERT INTO dbo.VehiculoDocumentos (VehiculoId, Tipo, FechaVencimiento, Observaciones)
    VALUES (@VehiculoId, @Tipo, @FechaVencimiento, NULLIF(LTRIM(RTRIM(@Observaciones)), N''));
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS DocumentoId;
END;
GO

-- CU-154 — Alertas: mantenimientos preventivos y vencimientos legales.
CREATE OR ALTER PROCEDURE dbo.sp_Flota_Alertas
    @DiasAviso INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);

    -- Últimos kilometrajes cerrados por vehículo (para aviso por desgaste)
    ;WITH UltimoKm AS (
        SELECT VehiculoId, MAX(KmFinal) AS KmActual
        FROM dbo.VehiculoKilometraje
        WHERE KmFinal IS NOT NULL
        GROUP BY VehiculoId
    )
    SELECT * FROM (
        -- Documentos legales por vencer o vencidos
        SELECT
            N'Documento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(d.Tipo, N' vence el ', FORMAT(d.FechaVencimiento, 'dd/MM/yyyy')) AS Detalle,
            d.FechaVencimiento AS Fecha,
            DATEDIFF(DAY, @Hoy, d.FechaVencimiento) AS DiasRestantes,
            CASE WHEN d.FechaVencimiento < @Hoy THEN N'Vencido' ELSE N'PorVencer' END AS Severidad
        FROM dbo.VehiculoDocumentos d
        INNER JOIN dbo.Vehiculos v ON v.VehiculoId = d.VehiculoId
        WHERE DATEDIFF(DAY, @Hoy, d.FechaVencimiento) <= @DiasAviso

        UNION ALL

        -- Mantenimientos preventivos programados por fecha
        SELECT
            N'Mantenimiento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(N'Preventivo programado: ', m.Descripcion) AS Detalle,
            m.FechaProgramada AS Fecha,
            DATEDIFF(DAY, @Hoy, m.FechaProgramada) AS DiasRestantes,
            CASE WHEN m.FechaProgramada < @Hoy THEN N'Vencido' ELSE N'PorVencer' END AS Severidad
        FROM dbo.OrdenesMantenimiento m
        INNER JOIN dbo.Vehiculos v ON v.VehiculoId = m.VehiculoId
        WHERE m.Tipo = N'Preventivo' AND m.Estado = N'Programada'
          AND m.FechaProgramada IS NOT NULL
          AND DATEDIFF(DAY, @Hoy, m.FechaProgramada) <= @DiasAviso

        UNION ALL

        -- Mantenimientos preventivos por desgaste (kilometraje)
        SELECT
            N'Mantenimiento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(N'Preventivo por kilometraje (', m.KilometrajeProximo, N' km): ', m.Descripcion) AS Detalle,
            NULL AS Fecha,
            NULL AS DiasRestantes,
            N'Vencido' AS Severidad
        FROM dbo.OrdenesMantenimiento m
        INNER JOIN dbo.Vehiculos v  ON v.VehiculoId = m.VehiculoId
        INNER JOIN UltimoKm uk       ON uk.VehiculoId = m.VehiculoId
        WHERE m.Tipo = N'Preventivo' AND m.Estado = N'Programada'
          AND m.KilometrajeProximo IS NOT NULL
          AND uk.KmActual >= m.KilometrajeProximo
    ) AS Alertas
    ORDER BY CASE Severidad WHEN N'Vencido' THEN 0 ELSE 1 END, DiasRestantes;
END;
GO

-- ============================================================
-- 5. STORED PROCEDURES — CU-161 Activos
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Activos_List
    @Buscar NVARCHAR(150) = NULL,
    @Estado NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SELECT
        a.ActivoId, a.CodigoActivo, a.Nombre, a.Tipo, ISNULL(a.Descripcion, N'') AS Descripcion,
        a.Estado, ISNULL(a.ClientePrestamo, N'') AS ClientePrestamo, a.Activo, a.FechaRegistro
    FROM dbo.Activos a
    WHERE (@Estado IS NULL OR a.Estado = @Estado)
      AND (@Buscar IS NULL
           OR a.CodigoActivo LIKE N'%' + @Buscar + N'%'
           OR a.Nombre       LIKE N'%' + @Buscar + N'%'
           OR a.Tipo         LIKE N'%' + @Buscar + N'%'
           OR ISNULL(a.ClientePrestamo, N'') LIKE N'%' + @Buscar + N'%')
    ORDER BY a.Activo DESC, a.CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Activos_GetById
    @ActivoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ActivoId, CodigoActivo, Nombre, Tipo, ISNULL(Descripcion, N'') AS Descripcion,
           Estado, ISNULL(ClientePrestamo, N'') AS ClientePrestamo, Activo
    FROM dbo.Activos WHERE ActivoId = @ActivoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Activos_Create
    @CodigoActivo NVARCHAR(40),
    @Nombre       NVARCHAR(150),
    @Tipo         NVARCHAR(40),
    @Descripcion  NVARCHAR(300) = NULL,
    @Estado       NVARCHAR(20)  = N'Disponible',
    @ClientePrestamo NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @CodigoActivo = NULLIF(LTRIM(RTRIM(@CodigoActivo)), N'');
    SET @Nombre       = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    IF @CodigoActivo IS NULL OR @Nombre IS NULL THROW 53060, 'El código y el nombre del activo son obligatorios.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Activos WHERE CodigoActivo = @CodigoActivo)
        THROW 53061, 'Ya existe un activo con ese código.', 1;
    INSERT INTO dbo.Activos (CodigoActivo, Nombre, Tipo, Descripcion, Estado, ClientePrestamo)
    VALUES (@CodigoActivo, @Nombre, @Tipo, NULLIF(LTRIM(RTRIM(@Descripcion)), N''),
            ISNULL(@Estado, N'Disponible'), NULLIF(LTRIM(RTRIM(@ClientePrestamo)), N''));
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ActivoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Activos_Update
    @ActivoId     INT,
    @CodigoActivo NVARCHAR(40),
    @Nombre       NVARCHAR(150),
    @Tipo         NVARCHAR(40),
    @Descripcion  NVARCHAR(300) = NULL,
    @Estado       NVARCHAR(20)  = N'Disponible',
    @ClientePrestamo NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @CodigoActivo = NULLIF(LTRIM(RTRIM(@CodigoActivo)), N'');
    SET @Nombre       = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    IF @CodigoActivo IS NULL OR @Nombre IS NULL THROW 53060, 'El código y el nombre del activo son obligatorios.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Activos WHERE ActivoId = @ActivoId) THROW 53062, 'No se encontró el activo.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Activos WHERE CodigoActivo = @CodigoActivo AND ActivoId <> @ActivoId)
        THROW 53061, 'Ya existe un activo con ese código.', 1;
    UPDATE dbo.Activos
    SET CodigoActivo = @CodigoActivo, Nombre = @Nombre, Tipo = @Tipo,
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N''), Estado = ISNULL(@Estado, N'Disponible'),
        ClientePrestamo = NULLIF(LTRIM(RTRIM(@ClientePrestamo)), N''), FechaActualizacion = SYSDATETIME()
    WHERE ActivoId = @ActivoId;
END;
GO

PRINT 'CU-152/153/154/161 aplicado: kilometraje, mantenimiento, alertas, documentos y activos.';
GO
