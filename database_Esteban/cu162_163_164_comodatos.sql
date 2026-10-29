-- ============================================================
-- CU-162 / CU-163 / CU-164 — CONTROL DE ACTIVOS (COMODATOS)
--
--   CU-162  Registrar la asignación (comodato) de un equipo a un cliente
--           para trazabilidad de quién tiene el activo y desde cuándo.
--   CU-163  Registrar la devolución o retiro de un equipo prestado para
--           reingresarlo al inventario o enviarlo a mantenimiento.
--   CU-164  Consultar el inventario de equipos prestados y cruzarlo con el
--           historial de compras para verificar rentabilidad.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE.
--   • Gobierna el Estado de dbo.Activos (CU-161) sin alterar su esquema.
--   • Reutiliza dbo.Activos, dbo.Usuarios, dbo.Pedidos.
--
-- Prerrequisito: cu152_153_154_161 (dbo.Activos) aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLA
-- ============================================================
IF OBJECT_ID('dbo.Comodatos','U') IS NULL
CREATE TABLE dbo.Comodatos (
    ComodatoId             INT IDENTITY(1,1) NOT NULL,
    ActivoId               INT               NOT NULL,   -- FK -> Activos
    ClienteUsuarioId       INT               NULL,       -- FK -> Usuarios (si el cliente es usuario)
    ClienteNombre          NVARCHAR(150)     NOT NULL,   -- snapshot (puede no ser usuario)
    ClienteIdentificacion  NVARCHAR(50)      NULL,
    Ubicacion              NVARCHAR(200)     NULL,
    FechaAsignacion        DATE              NOT NULL CONSTRAINT DF_Comodato_FAsig DEFAULT CAST(SYSDATETIME() AS DATE),
    FechaDevolucion        DATE              NULL,
    Estado                 NVARCHAR(20)      NOT NULL CONSTRAINT DF_Comodato_Estado DEFAULT N'Activo',
    CondicionEntrega       NVARCHAR(300)     NULL,
    CondicionDevolucion    NVARCHAR(300)     NULL,
    DestinoDevolucion      NVARCHAR(20)      NULL,       -- Inventario | Mantenimiento
    Observaciones          NVARCHAR(300)     NULL,
    RegistradoPorUsuarioId INT               NULL,
    RegistradoPorNombre    NVARCHAR(150)     NULL,
    FechaRegistro          DATETIME2         NOT NULL CONSTRAINT DF_Comodato_FReg DEFAULT SYSDATETIME(),
    FechaActualizacion     DATETIME2         NULL,
    CONSTRAINT PK_Comodatos PRIMARY KEY (ComodatoId),
    CONSTRAINT CK_Comodato_Estado  CHECK (Estado IN (N'Activo', N'Devuelto', N'Retirado')),
    CONSTRAINT CK_Comodato_Destino CHECK (DestinoDevolucion IS NULL OR DestinoDevolucion IN (N'Inventario', N'Mantenimiento'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Comodato_Activo' AND parent_object_id = OBJECT_ID('dbo.Comodatos'))
    ALTER TABLE dbo.Comodatos ADD CONSTRAINT FK_Comodato_Activo FOREIGN KEY (ActivoId) REFERENCES dbo.Activos (ActivoId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Comodato_Cliente' AND parent_object_id = OBJECT_ID('dbo.Comodatos'))
    ALTER TABLE dbo.Comodatos ADD CONSTRAINT FK_Comodato_Cliente FOREIGN KEY (ClienteUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO
-- Integridad de estado: un solo comodato Activo por activo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Comodato_ActivoUnico' AND object_id = OBJECT_ID('dbo.Comodatos'))
    CREATE UNIQUE INDEX UX_Comodato_ActivoUnico ON dbo.Comodatos (ActivoId) WHERE Estado = N'Activo';
GO

-- ============================================================
-- 2. PERMISOS
--    Gestión (CU-162/163) reutiliza ACTIVOS_GESTIONAR (existente).
--    Consulta/rentabilidad (CU-164) = permiso nuevo COMODATOS_CONSULTAR.
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'COMODATOS_CONSULTAR', N'Activos', N'Consultar comodatos', N'Consultar inventario de equipos prestados y su rentabilidad.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'COMODATOS_CONSULTAR'),
    (N'Gerente',       N'COMODATOS_CONSULTAR'),
    (N'Auditor',       N'COMODATOS_CONSULTAR');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-164'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

-- 3.1 CU-162 — Asignar comodato
CREATE OR ALTER PROCEDURE dbo.sp_Comodato_Asignar
    @ActivoId              INT,
    @ClienteUsuarioId      INT           = NULL,
    @ClienteNombre         NVARCHAR(150),
    @ClienteIdentificacion NVARCHAR(50)  = NULL,
    @Ubicacion             NVARCHAR(200) = NULL,
    @FechaAsignacion       DATE          = NULL,
    @CondicionEntrega      NVARCHAR(300) = NULL,
    @Observaciones         NVARCHAR(300) = NULL,
    @UsuarioId             INT           = NULL,
    @Nombre                NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @ClienteNombre = NULLIF(LTRIM(RTRIM(@ClienteNombre)), N'');
    IF @ClienteNombre IS NULL THROW 53080, 'Debe indicar el cliente que recibe el equipo.', 1;

    DECLARE @Estado NVARCHAR(20) = (SELECT Estado FROM dbo.Activos WHERE ActivoId = @ActivoId AND Activo = 1);
    IF @Estado IS NULL           THROW 53081, 'El activo no existe o está inactivo.', 1;
    IF @Estado <> N'Disponible'  THROW 53082, 'El activo no está disponible para comodato.', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO dbo.Comodatos
            (ActivoId, ClienteUsuarioId, ClienteNombre, ClienteIdentificacion, Ubicacion, FechaAsignacion,
             CondicionEntrega, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombre)
        VALUES
            (@ActivoId, @ClienteUsuarioId, @ClienteNombre, NULLIF(LTRIM(RTRIM(@ClienteIdentificacion)), N''),
             NULLIF(LTRIM(RTRIM(@Ubicacion)), N''), ISNULL(@FechaAsignacion, CAST(SYSDATETIME() AS DATE)),
             NULLIF(LTRIM(RTRIM(@CondicionEntrega)), N''), NULLIF(LTRIM(RTRIM(@Observaciones)), N''), @UsuarioId, @Nombre);

        DECLARE @Id INT = SCOPE_IDENTITY();

        UPDATE dbo.Activos
        SET Estado = N'Prestado', ClientePrestamo = @ClienteNombre, FechaActualizacion = SYSDATETIME()
        WHERE ActivoId = @ActivoId;

        COMMIT;
        SELECT @Id AS ComodatoId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END;
GO

-- 3.2 CU-163 — Devolver / Retirar comodato
CREATE OR ALTER PROCEDURE dbo.sp_Comodato_Devolver
    @ComodatoId          INT,
    @Destino             NVARCHAR(20),        -- Inventario | Mantenimiento
    @CondicionDevolucion NVARCHAR(300) = NULL,
    @FechaDevolucion     DATE          = NULL,
    @UsuarioId           INT           = NULL,
    @Nombre              NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Destino NOT IN (N'Inventario', N'Mantenimiento') THROW 53083, 'Destino inválido (Inventario o Mantenimiento).', 1;

    DECLARE @ActivoId INT, @EstadoCom NVARCHAR(20);
    SELECT @ActivoId = ActivoId, @EstadoCom = Estado FROM dbo.Comodatos WHERE ComodatoId = @ComodatoId;
    IF @ActivoId IS NULL          THROW 53084, 'No se encontró el comodato.', 1;
    IF @EstadoCom <> N'Activo'     THROW 53085, 'El comodato ya fue cerrado.', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE dbo.Comodatos
        SET Estado = CASE WHEN @Destino = N'Mantenimiento' THEN N'Retirado' ELSE N'Devuelto' END,
            DestinoDevolucion = @Destino,
            CondicionDevolucion = NULLIF(LTRIM(RTRIM(@CondicionDevolucion)), N''),
            FechaDevolucion = ISNULL(@FechaDevolucion, CAST(SYSDATETIME() AS DATE)),
            FechaActualizacion = SYSDATETIME()
        WHERE ComodatoId = @ComodatoId;

        UPDATE dbo.Activos
        SET Estado = CASE WHEN @Destino = N'Mantenimiento' THEN N'Mantenimiento' ELSE N'Disponible' END,
            ClientePrestamo = NULL, FechaActualizacion = SYSDATETIME()
        WHERE ActivoId = @ActivoId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END;
GO

-- 3.3 Listado de comodatos
CREATE OR ALTER PROCEDURE dbo.sp_Comodato_List
    @Estado NVARCHAR(20)  = NULL,
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SELECT
        c.ComodatoId, c.ActivoId, a.CodigoActivo, a.Nombre AS ActivoNombre, a.Tipo AS ActivoTipo,
        c.ClienteNombre, ISNULL(c.ClienteIdentificacion, N'') AS ClienteIdentificacion,
        ISNULL(c.Ubicacion, N'') AS Ubicacion, c.FechaAsignacion, c.FechaDevolucion, c.Estado,
        ISNULL(c.DestinoDevolucion, N'') AS DestinoDevolucion,
        DATEDIFF(DAY, c.FechaAsignacion, ISNULL(c.FechaDevolucion, CAST(SYSDATETIME() AS DATE))) AS DiasEnComodato
    FROM dbo.Comodatos c
    INNER JOIN dbo.Activos a ON a.ActivoId = c.ActivoId
    WHERE (@Estado IS NULL OR c.Estado = @Estado)
      AND (@Buscar IS NULL
           OR a.CodigoActivo  LIKE N'%' + @Buscar + N'%'
           OR a.Nombre        LIKE N'%' + @Buscar + N'%'
           OR c.ClienteNombre LIKE N'%' + @Buscar + N'%')
    ORDER BY CASE WHEN c.Estado = N'Activo' THEN 0 ELSE 1 END, c.FechaAsignacion DESC;
END;
GO

-- 3.4 Historial por activo
CREATE OR ALTER PROCEDURE dbo.sp_Comodato_HistorialPorActivo
    @ActivoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ComodatoId, ClienteNombre, FechaAsignacion, FechaDevolucion, Estado,
           ISNULL(DestinoDevolucion, N'') AS DestinoDevolucion, ISNULL(Observaciones, N'') AS Observaciones
    FROM dbo.Comodatos WHERE ActivoId = @ActivoId ORDER BY FechaAsignacion DESC;
END;
GO

-- 3.5 CU-164 — Inventario prestado cruzado con compras del cliente (rentabilidad)
CREATE OR ALTER PROCEDURE dbo.sp_Comodato_Rentabilidad
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ComodatoId, a.CodigoActivo, a.Nombre AS ActivoNombre, a.Tipo AS ActivoTipo,
        c.ClienteNombre, c.ClienteUsuarioId, c.FechaAsignacion,
        DATEDIFF(DAY, c.FechaAsignacion, CAST(SYSDATETIME() AS DATE)) AS DiasEnComodato,
        ISNULL(compras.NumPedidos, 0)   AS NumPedidos,
        ISNULL(compras.TotalComprado, 0) AS TotalComprado,
        compras.UltimaCompra
    FROM dbo.Comodatos c
    INNER JOIN dbo.Activos a ON a.ActivoId = c.ActivoId
    OUTER APPLY (
        SELECT COUNT(*) AS NumPedidos, SUM(p.Total) AS TotalComprado, MAX(p.FechaPedido) AS UltimaCompra
        FROM dbo.Pedidos p
        WHERE c.ClienteUsuarioId IS NOT NULL
          AND p.UsuarioId = c.ClienteUsuarioId
          AND p.Estado IN (N'Entregado', N'Aprobado', N'EnProceso')
          AND p.FechaPedido >= c.FechaAsignacion
    ) compras
    WHERE c.Estado = N'Activo'
    ORDER BY ISNULL(compras.TotalComprado, 0) ASC;  -- menos rentables primero
END;
GO

PRINT 'CU-162/163/164 aplicado: comodatos (asignación, devolución, rentabilidad).';
GO
