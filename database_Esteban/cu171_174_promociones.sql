-- ============================================================
-- CU-171 / CU-172 / CU-173 / CU-174 — MOTOR DE PROMOCIONES
--
--   CU-171  Configurar promociones (descuento porcentual o regalía por
--           volumen) para incentivar productos estratégicos.
--   CU-172  Segmentar promociones por tipo de cliente (Mayorista/Minorista).
--   CU-173  Cálculo/aplicación automática en el carrito de compras.
--   CU-174  Inactivar manualmente una promoción antes de su vencimiento.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO e IDEMPOTENTE.
--   • NO modifica dbo.sp_Store_CreateOrder: la aplicación al pedido se hace
--     en un paso posterior (sp_Promociones_AplicarAPedido). Cero riesgo para
--     el checkout actual.
--   • Reutiliza dbo.Productos, dbo.Usuarios, dbo.Pedidos, dbo.PedidoDetalle.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. CU-172 — Segmento de cliente (aditivo en Usuarios)
-- ============================================================
IF COL_LENGTH('dbo.Usuarios', 'SegmentoCliente') IS NULL
    ALTER TABLE dbo.Usuarios ADD SegmentoCliente NVARCHAR(20) NOT NULL CONSTRAINT DF_Usuarios_Segmento DEFAULT N'Minorista';
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Usuarios_Segmento')
    ALTER TABLE dbo.Usuarios ADD CONSTRAINT CK_Usuarios_Segmento CHECK (SegmentoCliente IN (N'Minorista', N'Mayorista'));
GO

-- ============================================================
-- 2. TABLAS de promociones
-- ============================================================
IF OBJECT_ID('dbo.Promociones','U') IS NULL
CREATE TABLE dbo.Promociones (
    PromocionId            INT IDENTITY(1,1) NOT NULL,
    Nombre                 NVARCHAR(150)     NOT NULL,
    Descripcion            NVARCHAR(300)     NULL,
    Tipo                   NVARCHAR(25)      NOT NULL,   -- DescuentoPorcentual | RegaliaPorVolumen
    ProductoId             INT               NOT NULL,   -- producto estratégico que gatilla
    CantidadMinima         INT               NOT NULL CONSTRAINT DF_Promo_CantMin DEFAULT 1,
    PorcentajeDescuento    DECIMAL(5,2)      NULL,       -- para DescuentoPorcentual
    ProductoRegaloId       INT               NULL,       -- para RegaliaPorVolumen
    CantidadRegalo         INT               NULL,
    SegmentoCliente        NVARCHAR(20)      NOT NULL CONSTRAINT DF_Promo_Segmento DEFAULT N'Todos',
    FechaInicio            DATE              NOT NULL,
    FechaFin               DATE              NOT NULL,
    Estado                 NVARCHAR(20)      NOT NULL CONSTRAINT DF_Promo_Estado DEFAULT N'Activa',
    Prioridad              INT               NOT NULL CONSTRAINT DF_Promo_Prioridad DEFAULT 0,
    MotivoInactivacion     NVARCHAR(300)     NULL,
    InactivadaPorUsuarioId INT               NULL,
    InactivadaPorNombre    NVARCHAR(150)     NULL,
    FechaInactivacion      DATETIME2         NULL,
    RegistradoPorUsuarioId INT               NULL,
    RegistradoPorNombre    NVARCHAR(150)     NULL,
    FechaRegistro          DATETIME2         NOT NULL CONSTRAINT DF_Promo_FReg DEFAULT SYSDATETIME(),
    FechaActualizacion     DATETIME2         NULL,
    CONSTRAINT PK_Promociones PRIMARY KEY (PromocionId),
    CONSTRAINT CK_Promo_Tipo     CHECK (Tipo IN (N'DescuentoPorcentual', N'RegaliaPorVolumen')),
    CONSTRAINT CK_Promo_Segmento CHECK (SegmentoCliente IN (N'Todos', N'Mayorista', N'Minorista')),
    CONSTRAINT CK_Promo_Estado   CHECK (Estado IN (N'Activa', N'Inactiva', N'Vencida')),
    CONSTRAINT CK_Promo_Fechas   CHECK (FechaFin >= FechaInicio),
    CONSTRAINT CK_Promo_CantMin  CHECK (CantidadMinima >= 1),
    CONSTRAINT CK_Promo_Config   CHECK (
        (Tipo = N'DescuentoPorcentual' AND PorcentajeDescuento IS NOT NULL AND PorcentajeDescuento > 0 AND PorcentajeDescuento <= 100)
        OR (Tipo = N'RegaliaPorVolumen' AND ProductoRegaloId IS NOT NULL AND CantidadRegalo IS NOT NULL AND CantidadRegalo > 0)
    ),
    CONSTRAINT FK_Promo_Producto       FOREIGN KEY (ProductoId)       REFERENCES dbo.Productos (ProductoId),
    CONSTRAINT FK_Promo_ProductoRegalo FOREIGN KEY (ProductoRegaloId) REFERENCES dbo.Productos (ProductoId)
);
GO

-- Historial de aplicaciones (CU-173) — trazabilidad
IF OBJECT_ID('dbo.PromocionAplicaciones','U') IS NULL
CREATE TABLE dbo.PromocionAplicaciones (
    AplicacionId    INT IDENTITY(1,1) NOT NULL,
    PromocionId     INT               NOT NULL,
    PedidoId        INT               NOT NULL,
    ProductoId      INT               NOT NULL,
    TipoBeneficio   NVARCHAR(20)      NOT NULL,   -- Descuento | Regalia
    MontoDescontado DECIMAL(18,2)     NULL,
    UnidadesRegalo  INT               NULL,
    FechaAplicacion DATETIME2         NOT NULL CONSTRAINT DF_PromoApp_Fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_PromocionAplicaciones PRIMARY KEY (AplicacionId),
    CONSTRAINT FK_PromoApp_Promo  FOREIGN KEY (PromocionId) REFERENCES dbo.Promociones (PromocionId),
    CONSTRAINT FK_PromoApp_Pedido FOREIGN KEY (PedidoId)    REFERENCES dbo.Pedidos (PedidoId)
);
GO

-- ============================================================
-- 3. PERMISOS
-- ============================================================
MERGE dbo.Permisos AS t
USING (VALUES
    (N'PROMOCIONES_GESTIONAR', N'Promociones', N'Gestionar promociones', N'Configurar, segmentar e inactivar promociones.')
) AS s (Codigo, Modulo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = s.Modulo, Nombre = s.Nombre, Descripcion = s.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (s.Codigo, s.Modulo, s.Nombre, s.Descripcion, 1);
GO
DECLARE @A TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @A (Rol, Codigo) VALUES
    (N'Administrador', N'PROMOCIONES_GESTIONAR'),
    (N'Gerente',       N'PROMOCIONES_GESTIONAR');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-171/174'
FROM @A a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

-- ============================================================
-- 4. STORED PROCEDURES
-- ============================================================

-- 4.1 CU-171/172 — Crear
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_Create
    @Nombre              NVARCHAR(150),
    @Descripcion         NVARCHAR(300) = NULL,
    @Tipo                NVARCHAR(25),
    @ProductoId          INT,
    @CantidadMinima      INT           = 1,
    @PorcentajeDescuento DECIMAL(5,2)  = NULL,
    @ProductoRegaloId    INT           = NULL,
    @CantidadRegalo      INT           = NULL,
    @SegmentoCliente     NVARCHAR(20)  = N'Todos',
    @FechaInicio         DATE,
    @FechaFin            DATE,
    @Prioridad           INT           = 0,
    @UsuarioId           INT           = NULL,
    @NombreUsr           NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    IF @Nombre IS NULL THROW 53090, 'El nombre de la promoción es obligatorio.', 1;
    IF @Tipo NOT IN (N'DescuentoPorcentual', N'RegaliaPorVolumen') THROW 53091, 'Tipo de promoción inválido.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE ProductoId = @ProductoId AND Activo = 1) THROW 53092, 'El producto estratégico no existe.', 1;
    IF @FechaFin < @FechaInicio THROW 53093, 'La fecha fin no puede ser anterior a la de inicio.', 1;
    IF @Tipo = N'DescuentoPorcentual' AND (@PorcentajeDescuento IS NULL OR @PorcentajeDescuento <= 0 OR @PorcentajeDescuento > 100)
        THROW 53094, 'El porcentaje de descuento debe estar entre 0 y 100.', 1;
    IF @Tipo = N'RegaliaPorVolumen' AND (@ProductoRegaloId IS NULL OR @CantidadRegalo IS NULL OR @CantidadRegalo <= 0)
        THROW 53095, 'Debe indicar producto de regalía y cantidad.', 1;
    IF @Tipo = N'RegaliaPorVolumen' AND NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE ProductoId = @ProductoRegaloId AND Activo = 1)
        THROW 53096, 'El producto de regalía no existe.', 1;
    IF ISNULL(@SegmentoCliente, N'Todos') NOT IN (N'Todos', N'Mayorista', N'Minorista') THROW 53097, 'Segmento de cliente inválido.', 1;

    INSERT INTO dbo.Promociones
        (Nombre, Descripcion, Tipo, ProductoId, CantidadMinima, PorcentajeDescuento, ProductoRegaloId, CantidadRegalo,
         SegmentoCliente, FechaInicio, FechaFin, Prioridad, RegistradoPorUsuarioId, RegistradoPorNombre)
    VALUES
        (@Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @Tipo, @ProductoId, ISNULL(NULLIF(@CantidadMinima, 0), 1),
         CASE WHEN @Tipo = N'DescuentoPorcentual' THEN @PorcentajeDescuento END,
         CASE WHEN @Tipo = N'RegaliaPorVolumen' THEN @ProductoRegaloId END,
         CASE WHEN @Tipo = N'RegaliaPorVolumen' THEN @CantidadRegalo END,
         ISNULL(@SegmentoCliente, N'Todos'), @FechaInicio, @FechaFin, ISNULL(@Prioridad, 0), @UsuarioId, @NombreUsr);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS PromocionId;
END;
GO

-- 4.2 CU-171/172 — Actualizar (solo promociones activas)
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_Update
    @PromocionId         INT,
    @Nombre              NVARCHAR(150),
    @Descripcion         NVARCHAR(300) = NULL,
    @Tipo                NVARCHAR(25),
    @ProductoId          INT,
    @CantidadMinima      INT           = 1,
    @PorcentajeDescuento DECIMAL(5,2)  = NULL,
    @ProductoRegaloId    INT           = NULL,
    @CantidadRegalo      INT           = NULL,
    @SegmentoCliente     NVARCHAR(20)  = N'Todos',
    @FechaInicio         DATE,
    @FechaFin            DATE,
    @Prioridad           INT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EstadoActual NVARCHAR(20) = (SELECT Estado FROM dbo.Promociones WHERE PromocionId = @PromocionId);
    IF @EstadoActual IS NULL       THROW 53098, 'No se encontró la promoción.', 1;
    IF @EstadoActual <> N'Activa'  THROW 53099, 'Solo se pueden editar promociones activas.', 1;
    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    IF @Nombre IS NULL THROW 53090, 'El nombre de la promoción es obligatorio.', 1;
    IF @Tipo NOT IN (N'DescuentoPorcentual', N'RegaliaPorVolumen') THROW 53091, 'Tipo de promoción inválido.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE ProductoId = @ProductoId AND Activo = 1) THROW 53092, 'El producto estratégico no existe.', 1;
    IF @FechaFin < @FechaInicio THROW 53093, 'La fecha fin no puede ser anterior a la de inicio.', 1;
    IF @Tipo = N'DescuentoPorcentual' AND (@PorcentajeDescuento IS NULL OR @PorcentajeDescuento <= 0 OR @PorcentajeDescuento > 100)
        THROW 53094, 'El porcentaje de descuento debe estar entre 0 y 100.', 1;
    IF @Tipo = N'RegaliaPorVolumen' AND (@ProductoRegaloId IS NULL OR @CantidadRegalo IS NULL OR @CantidadRegalo <= 0)
        THROW 53095, 'Debe indicar producto de regalía y cantidad.', 1;

    UPDATE dbo.Promociones
    SET Nombre = @Nombre,
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N''),
        Tipo = @Tipo,
        ProductoId = @ProductoId,
        CantidadMinima = ISNULL(NULLIF(@CantidadMinima, 0), 1),
        PorcentajeDescuento = CASE WHEN @Tipo = N'DescuentoPorcentual' THEN @PorcentajeDescuento END,
        ProductoRegaloId = CASE WHEN @Tipo = N'RegaliaPorVolumen' THEN @ProductoRegaloId END,
        CantidadRegalo = CASE WHEN @Tipo = N'RegaliaPorVolumen' THEN @CantidadRegalo END,
        SegmentoCliente = ISNULL(@SegmentoCliente, N'Todos'),
        FechaInicio = @FechaInicio, FechaFin = @FechaFin, Prioridad = ISNULL(@Prioridad, 0),
        FechaActualizacion = SYSDATETIME()
    WHERE PromocionId = @PromocionId;
END;
GO

-- 4.3 CU-174 — Inactivar (solo desde Activa)
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_Inactivar
    @PromocionId INT,
    @Motivo      NVARCHAR(300) = NULL,
    @UsuarioId   INT           = NULL,
    @Nombre      NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Estado NVARCHAR(20) = (SELECT Estado FROM dbo.Promociones WHERE PromocionId = @PromocionId);
    IF @Estado IS NULL       THROW 53098, 'No se encontró la promoción.', 1;
    IF @Estado <> N'Activa'  THROW 53099, 'Solo se pueden inactivar promociones activas.', 1;

    UPDATE dbo.Promociones
    SET Estado = N'Inactiva',
        MotivoInactivacion = NULLIF(LTRIM(RTRIM(@Motivo)), N''),
        InactivadaPorUsuarioId = @UsuarioId, InactivadaPorNombre = @Nombre,
        FechaInactivacion = SYSDATETIME(), FechaActualizacion = SYSDATETIME()
    WHERE PromocionId = @PromocionId;
END;
GO

-- 4.4 Listado (admin)
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_List
    @Estado NVARCHAR(20)  = NULL,
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SELECT
        pr.PromocionId, pr.Nombre, pr.Tipo, pr.SegmentoCliente, pr.Estado, pr.FechaInicio, pr.FechaFin,
        pr.CantidadMinima, pr.PorcentajeDescuento, pr.CantidadRegalo, pr.Prioridad,
        p.Nombre AS ProductoNombre, pg.Nombre AS ProductoRegaloNombre,
        CASE WHEN pr.Estado = N'Activa' AND CAST(SYSDATETIME() AS DATE) BETWEEN pr.FechaInicio AND pr.FechaFin THEN 1 ELSE 0 END AS Vigente
    FROM dbo.Promociones pr
    INNER JOIN dbo.Productos p ON p.ProductoId = pr.ProductoId
    LEFT JOIN dbo.Productos pg ON pg.ProductoId = pr.ProductoRegaloId
    WHERE (@Estado IS NULL OR pr.Estado = @Estado)
      AND (@Buscar IS NULL OR pr.Nombre LIKE N'%' + @Buscar + N'%' OR p.Nombre LIKE N'%' + @Buscar + N'%')
    ORDER BY pr.Estado, pr.Prioridad DESC, pr.FechaFin;
END;
GO

-- 4.5 Obtener por id
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_GetById
    @PromocionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PromocionId, Nombre, ISNULL(Descripcion, N'') AS Descripcion, Tipo, ProductoId, CantidadMinima,
           PorcentajeDescuento, ProductoRegaloId, CantidadRegalo, SegmentoCliente, FechaInicio, FechaFin,
           Estado, Prioridad
    FROM dbo.Promociones WHERE PromocionId = @PromocionId;
END;
GO

-- 4.6 CU-173 — Vigentes por segmento (motor del carrito)
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_Vigentes
    @SegmentoCliente NVARCHAR(20) = N'Minorista'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    SELECT
        pr.PromocionId, pr.Nombre, pr.Tipo, pr.ProductoId, pr.CantidadMinima, pr.PorcentajeDescuento,
        pr.ProductoRegaloId, pg.Nombre AS ProductoRegaloNombre, pg.Precio AS ProductoRegaloPrecio, pg.Stock AS ProductoRegaloStock,
        pr.CantidadRegalo, pr.Prioridad
    FROM dbo.Promociones pr
    LEFT JOIN dbo.Productos pg ON pg.ProductoId = pr.ProductoRegaloId
    WHERE pr.Estado = N'Activa'
      AND @Hoy BETWEEN pr.FechaInicio AND pr.FechaFin
      AND (pr.SegmentoCliente = N'Todos' OR pr.SegmentoCliente = @SegmentoCliente)
    ORDER BY pr.Prioridad DESC, pr.PromocionId;
END;
GO

-- 4.7 CU-173 — Persistir promociones aplicadas al pedido
--     (paso posterior a sp_Store_CreateOrder; NO lo modifica).
--     @AplicacionesJson: [{PromocionId, ProductoId, TipoBeneficio,
--                          MontoDescontado, UnidadesRegalo, ProductoRegaloId}]
CREATE OR ALTER PROCEDURE dbo.sp_Promociones_AplicarAPedido
    @PedidoId          INT,
    @AplicacionesJson  NVARCHAR(MAX),
    @UsuarioId         INT           = NULL,
    @Nombre            NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE PedidoId = @PedidoId) THROW 53100, 'El pedido no existe.', 1;
    IF @AplicacionesJson IS NULL OR LTRIM(RTRIM(@AplicacionesJson)) = N'' RETURN;

    DECLARE @App TABLE (
        PromocionId INT, ProductoId INT, TipoBeneficio NVARCHAR(20),
        MontoDescontado DECIMAL(18,2), UnidadesRegalo INT, ProductoRegaloId INT
    );
    INSERT INTO @App (PromocionId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo, ProductoRegaloId)
    SELECT PromocionId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo, ProductoRegaloId
    FROM OPENJSON(@AplicacionesJson) WITH (
        PromocionId      INT           '$.PromocionId',
        ProductoId       INT           '$.ProductoId',
        TipoBeneficio    NVARCHAR(20)  '$.TipoBeneficio',
        MontoDescontado  DECIMAL(18,2) '$.MontoDescontado',
        UnidadesRegalo   INT           '$.UnidadesRegalo',
        ProductoRegaloId INT           '$.ProductoRegaloId'
    );

    -- Regalías agregadas por producto
    DECLARE @Reg TABLE (ProductoId INT, Qty INT);
    INSERT INTO @Reg (ProductoId, Qty)
    SELECT ProductoRegaloId, SUM(UnidadesRegalo)
    FROM @App WHERE TipoBeneficio = N'Regalia' AND ProductoRegaloId IS NOT NULL
    GROUP BY ProductoRegaloId;

    IF EXISTS (SELECT 1 FROM @Reg r INNER JOIN dbo.Productos p ON p.ProductoId = r.ProductoId WHERE p.Stock < r.Qty)
        THROW 53101, 'Stock insuficiente para la regalía de una promoción.', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Descuentos: baja el PrecioUnitario prorrateado de la línea del producto estratégico
        UPDATE pd
        SET pd.PrecioUnitario = CASE WHEN pd.Cantidad > 0
             THEN CAST((pd.PrecioUnitario * pd.Cantidad - d.MontoDescontado) / pd.Cantidad AS DECIMAL(18,2))
             ELSE pd.PrecioUnitario END
        FROM dbo.PedidoDetalle pd
        INNER JOIN (
            SELECT ProductoId, SUM(MontoDescontado) AS MontoDescontado
            FROM @App WHERE TipoBeneficio = N'Descuento' GROUP BY ProductoId
        ) d ON d.ProductoId = pd.ProductoId
        WHERE pd.PedidoId = @PedidoId;

        -- Regalías: línea a precio 0 + baja de stock (set-based)
        INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitario)
        SELECT @PedidoId, ProductoId, Qty, 0 FROM @Reg;

        UPDATE p SET p.Stock = p.Stock - r.Qty
        FROM dbo.Productos p INNER JOIN @Reg r ON r.ProductoId = p.ProductoId;

        -- Historial de aplicaciones
        INSERT INTO dbo.PromocionAplicaciones (PromocionId, PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo)
        SELECT PromocionId, @PedidoId, ProductoId, TipoBeneficio, MontoDescontado, UnidadesRegalo FROM @App;

        -- Recalcular total del pedido
        UPDATE dbo.Pedidos
        SET Total = (SELECT SUM(Cantidad * PrecioUnitario) FROM dbo.PedidoDetalle WHERE PedidoId = @PedidoId),
            FechaActualizacion = SYSDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END;
GO

-- 4.8 CU-172 — Gestión del segmento de cliente (soporte)
CREATE OR ALTER PROCEDURE dbo.sp_Clientes_Segmentos_List
    @Buscar NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SELECT u.UsuarioId, u.NombreCompleto, u.Correo, u.SegmentoCliente
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles pf ON pf.PerfilId = u.PerfilId
    WHERE u.Activo = 1 AND pf.Nombre = N'Cliente'
      AND (@Buscar IS NULL OR u.NombreCompleto LIKE N'%' + @Buscar + N'%' OR u.Correo LIKE N'%' + @Buscar + N'%')
    ORDER BY u.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cliente_SetSegmento
    @UsuarioId INT,
    @Segmento  NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Segmento NOT IN (N'Minorista', N'Mayorista') THROW 53102, 'Segmento inválido (Minorista o Mayorista).', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId) THROW 53103, 'El cliente no existe.', 1;
    UPDATE dbo.Usuarios SET SegmentoCliente = @Segmento, FechaActualizacion = SYSDATETIME() WHERE UsuarioId = @UsuarioId;
END;
GO

-- 4.9 CU-173 — Segmento del usuario (lo consulta el motor del carrito)
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_GetSegmento
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SegmentoCliente, N'Minorista') AS SegmentoCliente FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId;
END;
GO

-- 4.10 Productos activos para los combos del formulario de promoción
CREATE OR ALTER PROCEDURE dbo.sp_Productos_Options
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductoId, Nombre, Precio FROM dbo.Productos WHERE Activo = 1 ORDER BY Nombre;
END;
GO

PRINT 'CU-171/172/173/174 aplicado: motor de promociones.';
GO
