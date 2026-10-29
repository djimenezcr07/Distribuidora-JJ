-- ============================================================
-- CU-191 / CU-192 — SERVICIO AL CLIENTE (RECLAMOS)
--
--   CU-191  Registrar un reclamo de un cliente para darle
--           seguimiento oportuno a su inconformidad.
--   CU-192  Cambiar el estado de un reclamo a "Cerrado"
--           documentando la resolución para mantener el orden.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE.
--   • Reutiliza dbo.Usuarios (cliente), dbo.Facturas y dbo.Pedidos
--     existentes mediante FK; NO altera ninguna de esas tablas.
--   • Sigue el ciclo de vida del módulo de Consultas ya existente.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLA de reclamos
-- ============================================================
IF OBJECT_ID('dbo.Reclamos','U') IS NULL
CREATE TABLE dbo.Reclamos (
    ReclamoId              INT IDENTITY(1,1) NOT NULL,
    UsuarioId              INT               NOT NULL,   -- cliente afectado (CU-191)
    FacturaId              INT               NULL,       -- enlace opcional a factura existente
    PedidoId               INT               NULL,       -- enlace opcional a pedido existente
    Asunto                 NVARCHAR(150)     NOT NULL,
    Descripcion            NVARCHAR(1000)    NOT NULL,
    Categoria              NVARCHAR(40)      NOT NULL CONSTRAINT DF_Reclamo_Categoria DEFAULT N'Otro',
    Prioridad              NVARCHAR(20)      NOT NULL CONSTRAINT DF_Reclamo_Prioridad DEFAULT N'Media',
    Estado                 NVARCHAR(20)      NOT NULL CONSTRAINT DF_Reclamo_Estado    DEFAULT N'Abierto',
    ResolucionDescripcion  NVARCHAR(1000)    NULL,       -- obligatoria al cerrar (CU-192)
    FechaCierre            DATETIME2         NULL,
    CerradoPorUsuarioId    INT               NULL,
    CerradoPorNombre       NVARCHAR(150)     NULL,
    RegistradoPorUsuarioId INT               NULL,       -- agente que registra
    RegistradoPorNombre    NVARCHAR(150)     NULL,
    FechaRegistro          DATETIME2         NOT NULL CONSTRAINT DF_Reclamo_FReg DEFAULT SYSDATETIME(),
    FechaActualizacion     DATETIME2         NULL,
    CONSTRAINT PK_Reclamos PRIMARY KEY (ReclamoId),
    CONSTRAINT CK_Reclamo_Categoria CHECK (Categoria IN (N'Producto', N'Entrega', N'Facturación', N'Servicio', N'Otro')),
    CONSTRAINT CK_Reclamo_Prioridad CHECK (Prioridad IN (N'Baja', N'Media', N'Alta')),
    CONSTRAINT CK_Reclamo_Estado    CHECK (Estado IN (N'Abierto', N'EnProceso', N'Cerrado')),
    CONSTRAINT FK_Reclamo_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId),
    CONSTRAINT FK_Reclamo_Factura FOREIGN KEY (FacturaId) REFERENCES dbo.Facturas (FacturaId),
    CONSTRAINT FK_Reclamo_Pedido  FOREIGN KEY (PedidoId)  REFERENCES dbo.Pedidos  (PedidoId)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reclamos_Estado' AND object_id = OBJECT_ID('dbo.Reclamos'))
    CREATE INDEX IX_Reclamos_Estado ON dbo.Reclamos (Estado, FechaRegistro DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reclamos_Usuario' AND object_id = OBJECT_ID('dbo.Reclamos'))
    CREATE INDEX IX_Reclamos_Usuario ON dbo.Reclamos (UsuarioId);
GO

-- ============================================================
-- 2. PERMISO + asignación por rol (idempotente)
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'RECLAMOS_GESTIONAR', N'Servicio al cliente', N'Gestionar reclamos', N'Registrar reclamos de clientes y cambiar su estado documentando la resolución.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'RECLAMOS_GESTIONAR'),
    (N'Gerente',       N'RECLAMOS_GESTIONAR');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-191/192'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

-- 3.1 CU-191 — Registrar reclamo
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_Create
    @UsuarioId    INT,
    @FacturaId    INT            = NULL,
    @PedidoId     INT            = NULL,
    @Asunto       NVARCHAR(150),
    @Descripcion  NVARCHAR(1000),
    @Categoria    NVARCHAR(40)   = N'Otro',
    @Prioridad    NVARCHAR(20)   = N'Media',
    @AgenteId     INT            = NULL,
    @AgenteNombre NVARCHAR(150)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Asunto      = NULLIF(LTRIM(RTRIM(@Asunto)), N'');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    SET @FacturaId   = NULLIF(@FacturaId, 0);
    SET @PedidoId    = NULLIF(@PedidoId, 0);

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId) THROW 53110, 'El cliente indicado no existe.', 1;
    IF @Asunto IS NULL       THROW 53111, 'El asunto del reclamo es obligatorio.', 1;
    IF @Descripcion IS NULL  THROW 53112, 'La descripción del reclamo es obligatoria.', 1;
    IF ISNULL(@Categoria, N'Otro')  NOT IN (N'Producto', N'Entrega', N'Facturación', N'Servicio', N'Otro') THROW 53113, 'Categoría de reclamo inválida.', 1;
    IF ISNULL(@Prioridad, N'Media') NOT IN (N'Baja', N'Media', N'Alta') THROW 53114, 'Prioridad de reclamo inválida.', 1;
    IF @FacturaId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Facturas WHERE FacturaId = @FacturaId AND UsuarioId = @UsuarioId)
        THROW 53115, 'La factura indicada no existe o no pertenece a ese cliente.', 1;
    IF @PedidoId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE PedidoId = @PedidoId AND UsuarioId = @UsuarioId)
        THROW 53116, 'El pedido indicado no existe o no pertenece a ese cliente.', 1;

    INSERT INTO dbo.Reclamos
        (UsuarioId, FacturaId, PedidoId, Asunto, Descripcion, Categoria, Prioridad, Estado,
         RegistradoPorUsuarioId, RegistradoPorNombre)
    VALUES
        (@UsuarioId, @FacturaId, @PedidoId, @Asunto, @Descripcion, ISNULL(@Categoria, N'Otro'),
         ISNULL(@Prioridad, N'Media'), N'Abierto', @AgenteId, @AgenteNombre);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ReclamoId;
END;
GO

-- 3.2 CU-191/192 — Listado con filtros
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_List
    @Estado NVARCHAR(20)  = NULL,
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SELECT
        r.ReclamoId, r.Asunto, r.Categoria, r.Prioridad, r.Estado,
        r.FechaRegistro, r.FechaCierre,
        u.UsuarioId, u.NombreCompleto AS ClienteNombre, u.Correo AS ClienteCorreo,
        f.NumeroFactura
    FROM dbo.Reclamos r
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = r.UsuarioId
    LEFT JOIN dbo.Facturas f  ON f.FacturaId = r.FacturaId
    WHERE (@Estado IS NULL OR r.Estado = @Estado)
      AND (@Buscar IS NULL
           OR u.NombreCompleto LIKE N'%' + @Buscar + N'%'
           OR u.Correo         LIKE N'%' + @Buscar + N'%'
           OR r.Asunto         LIKE N'%' + @Buscar + N'%'
           OR r.Descripcion    LIKE N'%' + @Buscar + N'%')
    ORDER BY
        CASE r.Estado WHEN N'Abierto' THEN 0 WHEN N'EnProceso' THEN 1 ELSE 2 END,
        CASE r.Prioridad WHEN N'Alta' THEN 0 WHEN N'Media' THEN 1 ELSE 2 END,
        r.FechaRegistro DESC;
END;
GO

-- 3.3 Detalle por id
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_GetById
    @ReclamoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.ReclamoId, r.UsuarioId, r.FacturaId, r.PedidoId, r.Asunto, r.Descripcion,
        r.Categoria, r.Prioridad, r.Estado,
        ISNULL(r.ResolucionDescripcion, N'') AS ResolucionDescripcion,
        r.FechaCierre, r.CerradoPorNombre,
        r.RegistradoPorNombre, r.FechaRegistro, r.FechaActualizacion,
        u.NombreCompleto AS ClienteNombre, u.Correo AS ClienteCorreo, u.Telefono AS ClienteTelefono,
        f.NumeroFactura, f.Total AS FacturaTotal, f.FechaFactura
    FROM dbo.Reclamos r
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = r.UsuarioId
    LEFT JOIN dbo.Facturas f  ON f.FacturaId = r.FacturaId
    WHERE r.ReclamoId = @ReclamoId;
END;
GO

-- 3.4 CU-192 — Cambiar estado (transiciones válidas + documentar resolución al cerrar)
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_CambiarEstado
    @ReclamoId  INT,
    @Estado     NVARCHAR(20),
    @Resolucion NVARCHAR(1000) = NULL,
    @UsuarioId  INT            = NULL,
    @Nombre     NVARCHAR(150)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Actual NVARCHAR(20) = (SELECT Estado FROM dbo.Reclamos WHERE ReclamoId = @ReclamoId);
    IF @Actual IS NULL THROW 53117, 'No se encontró el reclamo.', 1;
    IF @Estado NOT IN (N'Abierto', N'EnProceso', N'Cerrado') THROW 53118, 'Estado de reclamo inválido.', 1;
    IF @Actual = N'Cerrado' THROW 53119, 'El reclamo ya está cerrado; no admite más cambios.', 1;

    SET @Resolucion = NULLIF(LTRIM(RTRIM(@Resolucion)), N'');
    IF @Estado = N'Cerrado' AND @Resolucion IS NULL
        THROW 53120, 'Para cerrar el reclamo debe documentar la resolución.', 1;

    UPDATE dbo.Reclamos
    SET Estado = @Estado,
        ResolucionDescripcion = CASE WHEN @Estado = N'Cerrado' THEN @Resolucion ELSE ResolucionDescripcion END,
        FechaCierre           = CASE WHEN @Estado = N'Cerrado' THEN SYSDATETIME() ELSE NULL END,
        CerradoPorUsuarioId   = CASE WHEN @Estado = N'Cerrado' THEN @UsuarioId ELSE NULL END,
        CerradoPorNombre      = CASE WHEN @Estado = N'Cerrado' THEN @Nombre ELSE NULL END,
        FechaActualizacion    = SYSDATETIME()
    WHERE ReclamoId = @ReclamoId;
END;
GO

-- 3.5 Combo de clientes (para el formulario de registro)
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_Clientes_Buscar
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SELECT TOP (50) u.UsuarioId, u.NombreCompleto, u.Correo
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
    WHERE u.Activo = 1 AND pf.Nombre = N'Cliente'
      AND (@Buscar IS NULL OR u.NombreCompleto LIKE N'%' + @Buscar + N'%' OR u.Correo LIKE N'%' + @Buscar + N'%')
    ORDER BY u.NombreCompleto;
END;
GO

-- 3.6 Facturas de un cliente (para enlazar el reclamo)
CREATE OR ALTER PROCEDURE dbo.sp_Reclamos_FacturasPorCliente
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FacturaId, NumeroFactura, FechaFactura, Total
    FROM dbo.Facturas
    WHERE UsuarioId = @UsuarioId
    ORDER BY FechaFactura DESC;
END;
GO

PRINT 'CU-191/192 aplicado: módulo de reclamos (servicio al cliente).';
GO
