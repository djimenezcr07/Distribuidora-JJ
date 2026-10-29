SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

/*
  CU-101 a CU-104: proveedores, órdenes, recepción, sugerencias e histórico.
  Acepta una base sin el módulo o el esquema compatible creado por PR #116.
  Rechaza tablas incompletas, datos inválidos, duplicados y estados ambiguos.

  Ejecución: sqlcmd -b con MigrationSha256=<SHA-256 real del archivo>.
  Rollback: ver 0013_purchasing_suppliers_orders.rollback.md. No eliminar datos.
*/

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 54600, N'Falta dbo.SchemaMigrationHistory. Aplique primero 0001.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0013_purchasing_suppliers_orders' AND Status = N'Applied'
)
    THROW 54601, N'La migración 0013 ya figura como aplicada y no debe repetirse.', 1;

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
   OR OBJECT_ID(N'dbo.MovimientosInventario', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Permisos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Perfiles', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.sp_Admin_GetPurchaseSuggestions', N'P') IS NULL
    THROW 54602, N'Faltan dependencias base de productos, usuarios, inventario o permisos.', 1;

IF OBJECT_ID(N'dbo.OrdenesCompra', N'U') IS NOT NULL AND OBJECT_ID(N'dbo.Proveedores', N'U') IS NULL
    THROW 54603, N'Existe OrdenesCompra sin Proveedores; el estado legado es ambiguo.', 1;

IF OBJECT_ID(N'dbo.Proveedores', N'U') IS NOT NULL
   AND (COL_LENGTH(N'dbo.Proveedores', N'ProveedorId') IS NULL
        OR COL_LENGTH(N'dbo.Proveedores', N'Nombre') IS NULL
        OR COL_LENGTH(N'dbo.Proveedores', N'Contacto') IS NULL
        OR COL_LENGTH(N'dbo.Proveedores', N'Telefono') IS NULL
        OR COL_LENGTH(N'dbo.Proveedores', N'Email') IS NULL
        OR COL_LENGTH(N'dbo.Proveedores', N'Activo') IS NULL)
    THROW 54604, N'La tabla Proveedores existente no tiene el contrato compatible esperado.', 1;

IF OBJECT_ID(N'dbo.OrdenesCompra', N'U') IS NOT NULL
   AND (COL_LENGTH(N'dbo.OrdenesCompra', N'OrdenCompraId') IS NULL
        OR COL_LENGTH(N'dbo.OrdenesCompra', N'ProveedorId') IS NULL
        OR COL_LENGTH(N'dbo.OrdenesCompra', N'Estado') IS NULL
        OR COL_LENGTH(N'dbo.OrdenesCompra', N'FechaCreacion') IS NULL)
    THROW 54605, N'La tabla OrdenesCompra existente no tiene el contrato legado compatible.', 1;

IF OBJECT_ID(N'dbo.DetalleOrdenCompra', N'U') IS NOT NULL
   AND (COL_LENGTH(N'dbo.DetalleOrdenCompra', N'DetalleOrdenCompraId') IS NULL
        OR COL_LENGTH(N'dbo.DetalleOrdenCompra', N'OrdenCompraId') IS NULL
        OR COL_LENGTH(N'dbo.DetalleOrdenCompra', N'ProductoId') IS NULL
        OR COL_LENGTH(N'dbo.DetalleOrdenCompra', N'CantidadOrdenada') IS NULL
        OR COL_LENGTH(N'dbo.DetalleOrdenCompra', N'CantidadRecibida') IS NULL
        OR COL_LENGTH(N'dbo.DetalleOrdenCompra', N'PrecioUnitario') IS NULL)
    THROW 54606, N'La tabla DetalleOrdenCompra existente no tiene el contrato compatible esperado.', 1;

IF (OBJECT_ID(N'dbo.OrdenesCompra', N'U') IS NULL AND OBJECT_ID(N'dbo.DetalleOrdenCompra', N'U') IS NOT NULL)
   OR (OBJECT_ID(N'dbo.OrdenesCompra', N'U') IS NOT NULL AND OBJECT_ID(N'dbo.DetalleOrdenCompra', N'U') IS NULL)
    THROW 54607, N'Las tablas de órdenes y detalle deben existir juntas o no existir.', 1;

BEGIN TRANSACTION;
GO

IF OBJECT_ID(N'dbo.Proveedores', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Proveedores
    (
        ProveedorId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Proveedores PRIMARY KEY,
        Nombre NVARCHAR(150) NOT NULL,
        Contacto NVARCHAR(150) NULL,
        Telefono NVARCHAR(30) NULL,
        Email NVARCHAR(150) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Proveedores_Activo DEFAULT (1),
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_Proveedores_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        FechaActualizacionUtc DATETIME2(0) NULL
    );
END;

IF COL_LENGTH(N'dbo.Proveedores', N'FechaCreacionUtc') IS NULL
    ALTER TABLE dbo.Proveedores ADD FechaCreacionUtc DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.Proveedores', N'FechaActualizacionUtc') IS NULL
    ALTER TABLE dbo.Proveedores ADD FechaActualizacionUtc DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.Proveedores', N'FechaCreacion') IS NOT NULL
    EXEC(N'UPDATE dbo.Proveedores SET FechaCreacionUtc = COALESCE(FechaCreacionUtc, FechaCreacion);');
UPDATE dbo.Proveedores SET FechaCreacionUtc = COALESCE(FechaCreacionUtc, SYSUTCDATETIME());
ALTER TABLE dbo.Proveedores ALTER COLUMN FechaCreacionUtc DATETIME2(0) NOT NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.default_constraints defaultConstraint
    INNER JOIN sys.columns columnDefinition ON columnDefinition.object_id=defaultConstraint.parent_object_id AND columnDefinition.column_id=defaultConstraint.parent_column_id
    WHERE defaultConstraint.parent_object_id=OBJECT_ID(N'dbo.Proveedores') AND columnDefinition.name=N'FechaCreacionUtc'
)
    ALTER TABLE dbo.Proveedores ADD CONSTRAINT DF_Proveedores_FechaCreacionUtc_0013 DEFAULT SYSUTCDATETIME() FOR FechaCreacionUtc;

IF COL_LENGTH(N'dbo.Proveedores', N'NombreNormalizado') IS NULL
    ALTER TABLE dbo.Proveedores ADD NombreNormalizado AS UPPER(LTRIM(RTRIM(Nombre))) PERSISTED;
GO

IF EXISTS
(
    SELECT 1 FROM dbo.Proveedores
    GROUP BY UPPER(LTRIM(RTRIM(Nombre)))
    HAVING UPPER(LTRIM(RTRIM(Nombre))) = N'' OR COUNT(*) > 1
)
    THROW 54608, N'Proveedores contiene nombres vacíos o duplicados; se requiere reconciliación manual.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Proveedores') AND name = N'UX_Proveedores_NombreNormalizado')
    CREATE UNIQUE INDEX UX_Proveedores_NombreNormalizado ON dbo.Proveedores(NombreNormalizado);

IF OBJECT_ID(N'dbo.OrdenesCompra', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrdenesCompra
    (
        OrdenCompraId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrdenesCompra PRIMARY KEY,
        ProveedorId INT NOT NULL,
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_OrdenesCompra_Estado DEFAULT N'Pendiente',
        Notas NVARCHAR(300) NULL,
        UsuarioCreacionId INT NULL,
        UsuarioCreacionNombre NVARCHAR(150) NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_OrdenesCompra_FechaCreacionUtc DEFAULT SYSUTCDATETIME(),
        FechaRecepcionUtc DATETIME2(0) NULL,
        FechaCierreUtc DATETIME2(0) NULL,
        MotivoCierre NVARCHAR(500) NULL,
        TokenOperacion UNIQUEIDENTIFIER NULL,
        SolicitudHash BINARY(32) NULL,
        TokenFinalizacion UNIQUEIDENTIFIER NULL,
        FinalizacionHash BINARY(32) NULL,
        CONSTRAINT FK_OrdenesCompra_Proveedores FOREIGN KEY (ProveedorId) REFERENCES dbo.Proveedores(ProveedorId)
    );
END;

IF COL_LENGTH(N'dbo.OrdenesCompra', N'FechaCreacionUtc') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD FechaCreacionUtc DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'FechaRecepcionUtc') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD FechaRecepcionUtc DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'FechaCierreUtc') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD FechaCierreUtc DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'MotivoCierre') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD MotivoCierre NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'TokenOperacion') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD TokenOperacion UNIQUEIDENTIFIER NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'SolicitudHash') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD SolicitudHash BINARY(32) NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'TokenFinalizacion') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD TokenFinalizacion UNIQUEIDENTIFIER NULL;
IF COL_LENGTH(N'dbo.OrdenesCompra', N'FinalizacionHash') IS NULL
    ALTER TABLE dbo.OrdenesCompra ADD FinalizacionHash BINARY(32) NULL;
GO

IF COL_LENGTH(N'dbo.OrdenesCompra', N'FechaCreacion') IS NOT NULL
    EXEC(N'UPDATE dbo.OrdenesCompra SET FechaCreacionUtc = COALESCE(FechaCreacionUtc, FechaCreacion);');
IF COL_LENGTH(N'dbo.OrdenesCompra', N'FechaRecepcion') IS NOT NULL
    EXEC(N'UPDATE dbo.OrdenesCompra SET FechaRecepcionUtc = COALESCE(FechaRecepcionUtc, FechaRecepcion);');
UPDATE dbo.OrdenesCompra SET FechaCreacionUtc = COALESCE(FechaCreacionUtc, SYSUTCDATETIME());
ALTER TABLE dbo.OrdenesCompra ALTER COLUMN FechaCreacionUtc DATETIME2(0) NOT NULL;
IF NOT EXISTS
(
    SELECT 1 FROM sys.default_constraints defaultConstraint
    INNER JOIN sys.columns columnDefinition ON columnDefinition.object_id=defaultConstraint.parent_object_id AND columnDefinition.column_id=defaultConstraint.parent_column_id
    WHERE defaultConstraint.parent_object_id=OBJECT_ID(N'dbo.OrdenesCompra') AND columnDefinition.name=N'FechaCreacionUtc'
)
    ALTER TABLE dbo.OrdenesCompra ADD CONSTRAINT DF_OrdenesCompra_FechaCreacionUtc_0013 DEFAULT SYSUTCDATETIME() FOR FechaCreacionUtc;

IF EXISTS (SELECT 1 FROM dbo.OrdenesCompra WHERE Estado NOT IN (N'Pendiente', N'RecibidaParcial', N'Recibida', N'ConDiscrepancia', N'CerradaConDiscrepancia', N'Cancelada'))
    THROW 54609, N'OrdenesCompra contiene estados no reconocidos.', 1;
IF OBJECT_ID(N'dbo.CK_OrdenesCompra_Estado', N'C') IS NOT NULL
    ALTER TABLE dbo.OrdenesCompra DROP CONSTRAINT CK_OrdenesCompra_Estado;
ALTER TABLE dbo.OrdenesCompra ALTER COLUMN Estado NVARCHAR(30) NOT NULL;
UPDATE dbo.OrdenesCompra
SET Estado = N'CerradaConDiscrepancia',
    FechaCierreUtc = COALESCE(FechaCierreUtc, FechaRecepcionUtc, FechaCreacionUtc),
    MotivoCierre = COALESCE(NULLIF(MotivoCierre, N''), N'Migrado desde estado legado ConDiscrepancia.')
WHERE Estado = N'ConDiscrepancia';

ALTER TABLE dbo.OrdenesCompra WITH CHECK ADD CONSTRAINT CK_OrdenesCompra_Estado
    CHECK (Estado IN (N'Pendiente', N'RecibidaParcial', N'Recibida', N'CerradaConDiscrepancia', N'Cancelada'));

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrdenesCompra') AND name = N'UX_OrdenesCompra_TokenOperacion')
    CREATE UNIQUE INDEX UX_OrdenesCompra_TokenOperacion ON dbo.OrdenesCompra(TokenOperacion) WHERE TokenOperacion IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrdenesCompra') AND name = N'UX_OrdenesCompra_TokenFinalizacion')
    CREATE UNIQUE INDEX UX_OrdenesCompra_TokenFinalizacion ON dbo.OrdenesCompra(TokenFinalizacion) WHERE TokenFinalizacion IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrdenesCompra') AND name = N'IX_OrdenesCompra_ProveedorEstadoFecha')
    CREATE INDEX IX_OrdenesCompra_ProveedorEstadoFecha ON dbo.OrdenesCompra(ProveedorId, Estado, FechaCreacionUtc DESC);

IF OBJECT_ID(N'dbo.DetalleOrdenCompra', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DetalleOrdenCompra
    (
        DetalleOrdenCompraId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleOrdenCompra PRIMARY KEY,
        OrdenCompraId INT NOT NULL,
        ProductoId INT NOT NULL,
        CantidadOrdenada INT NOT NULL,
        CantidadRecibida INT NOT NULL CONSTRAINT DF_DetalleOrdenCompra_CantidadRecibida DEFAULT (0),
        PrecioUnitario DECIMAL(18,2) NOT NULL,
        CONSTRAINT FK_DetalleOrdenCompra_Ordenes FOREIGN KEY (OrdenCompraId) REFERENCES dbo.OrdenesCompra(OrdenCompraId),
        CONSTRAINT FK_DetalleOrdenCompra_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(ProductoId)
    );
END;

IF EXISTS
(
    SELECT 1 FROM dbo.DetalleOrdenCompra
    WHERE CantidadOrdenada <= 0 OR CantidadRecibida < 0 OR CantidadRecibida > CantidadOrdenada OR PrecioUnitario <= 0
)
    THROW 54610, N'DetalleOrdenCompra contiene cantidades o precios inválidos.', 1;
IF EXISTS (SELECT 1 FROM dbo.DetalleOrdenCompra GROUP BY OrdenCompraId, ProductoId HAVING COUNT(*) > 1)
    THROW 54611, N'DetalleOrdenCompra contiene productos duplicados por orden.', 1;

IF OBJECT_ID(N'dbo.CK_DetalleOrdenCompra_Cantidad', N'C') IS NOT NULL
    ALTER TABLE dbo.DetalleOrdenCompra DROP CONSTRAINT CK_DetalleOrdenCompra_Cantidad;
ALTER TABLE dbo.DetalleOrdenCompra WITH CHECK ADD CONSTRAINT CK_DetalleOrdenCompra_Cantidades
    CHECK (CantidadOrdenada > 0 AND CantidadRecibida >= 0 AND CantidadRecibida <= CantidadOrdenada);
IF OBJECT_ID(N'dbo.CK_DetalleOrdenCompra_Precio', N'C') IS NULL
    ALTER TABLE dbo.DetalleOrdenCompra WITH CHECK ADD CONSTRAINT CK_DetalleOrdenCompra_Precio CHECK (PrecioUnitario > 0);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DetalleOrdenCompra') AND name = N'UX_DetalleOrdenCompra_OrdenProducto')
    CREATE UNIQUE INDEX UX_DetalleOrdenCompra_OrdenProducto ON dbo.DetalleOrdenCompra(OrdenCompraId, ProductoId);

IF OBJECT_ID(N'dbo.ComprasRecepcionOperaciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ComprasRecepcionOperaciones
    (
        RecepcionOperacionId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComprasRecepcionOperaciones PRIMARY KEY,
        TokenOperacion UNIQUEIDENTIFIER NOT NULL,
        OrdenCompraId INT NOT NULL,
        DetalleOrdenCompraId INT NOT NULL,
        CantidadRecibida INT NOT NULL,
        UsuarioId INT NOT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_ComprasRecepcionOperaciones_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_ComprasRecepcionOperaciones_Token UNIQUE (TokenOperacion),
        CONSTRAINT CK_ComprasRecepcionOperaciones_Cantidad CHECK (CantidadRecibida > 0),
        CONSTRAINT FK_ComprasRecepcionOperaciones_Orden FOREIGN KEY (OrdenCompraId) REFERENCES dbo.OrdenesCompra(OrdenCompraId),
        CONSTRAINT FK_ComprasRecepcionOperaciones_Detalle FOREIGN KEY (DetalleOrdenCompraId) REFERENCES dbo.DetalleOrdenCompra(DetalleOrdenCompraId),
        CONSTRAINT FK_ComprasRecepcionOperaciones_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;

IF OBJECT_ID(N'dbo.ComprasAuditoria', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ComprasAuditoria
    (
        ComprasAuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComprasAuditoria PRIMARY KEY,
        Entidad NVARCHAR(30) NOT NULL,
        EntidadId INT NOT NULL,
        Accion NVARCHAR(50) NOT NULL,
        UsuarioId INT NOT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        UsuarioCorreo NVARCHAR(150) NULL,
        Rol NVARCHAR(50) NULL,
        Detalle NVARCHAR(500) NOT NULL,
        DireccionIp NVARCHAR(80) NULL,
        UserAgent NVARCHAR(300) NULL,
        FechaRegistroUtc DATETIME2(0) NOT NULL CONSTRAINT DF_ComprasAuditoria_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_ComprasAuditoria_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ComprasAuditoria') AND name = N'IX_ComprasAuditoria_EntidadFecha')
    CREATE INDEX IX_ComprasAuditoria_EntidadFecha ON dbo.ComprasAuditoria(Entidad, EntidadId, FechaRegistroUtc DESC);
GO

DECLARE @RequiredPermissions TABLE (Codigo NVARCHAR(100), Nombre NVARCHAR(150), Descripcion NVARCHAR(500));
INSERT @RequiredPermissions VALUES
    (N'PROVEEDORES_VER', N'Consultar proveedores', N'Permite consultar proveedores y sus datos de contacto.'),
    (N'PROVEEDORES_GESTIONAR', N'Gestionar proveedores', N'Permite crear, editar, activar e inactivar proveedores.'),
    (N'COMPRAS_ORDENES_VER', N'Consultar órdenes de compra', N'Permite consultar órdenes y recepciones.'),
    (N'COMPRAS_ORDENES_CREAR', N'Crear órdenes de compra', N'Permite crear órdenes para proveedores activos.'),
    (N'COMPRAS_ORDENES_RECIBIR', N'Recibir órdenes de compra', N'Permite registrar recepciones e ingresar inventario.'),
    (N'COMPRAS_ORDENES_CERRAR', N'Cerrar órdenes con discrepancias', N'Permite cerrar órdenes con faltantes documentados.'),
    (N'COMPRAS_ORDENES_CANCELAR', N'Cancelar órdenes de compra', N'Permite cancelar órdenes sin recepciones.'),
    (N'COMPRAS_SUGERENCIAS_VER', N'Consultar sugerencias de compra', N'Permite consultar sugerencias basadas en ventas y stock.'),
    (N'COMPRAS_PRECIOS_VER', N'Consultar histórico de precios', N'Permite comparar precios históricos por proveedor.');

UPDATE permission
SET Modulo = N'Compras', Nombre = required.Nombre, Descripcion = required.Descripcion, Activo = 1
FROM dbo.Permisos permission INNER JOIN @RequiredPermissions required ON required.Codigo = permission.Codigo;

INSERT dbo.Permisos(Codigo, Modulo, Nombre, Descripcion, Activo)
SELECT required.Codigo, N'Compras', required.Nombre, required.Descripcion, 1
FROM @RequiredPermissions required
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permisos permission WITH (UPDLOCK, HOLDLOCK) WHERE permission.Codigo = required.Codigo);

INSERT dbo.PerfilPermisos(PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT profile.PerfilId, permission.PermisoId, NULL, N'Migración 0013 compras'
FROM dbo.Perfiles profile
CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre IN (N'Compras', N'Administrador')
  AND permission.Codigo IN (SELECT Codigo FROM @RequiredPermissions)
  AND NOT EXISTS
      (SELECT 1 FROM dbo.PerfilPermisos assigned WHERE assigned.PerfilId = profile.PerfilId AND assigned.PermisoId = permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_ListarProveedores
    @SoloActivos BIT = NULL,
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Filtro = NULLIF(LTRIM(RTRIM(@Filtro)), N'');
    SELECT ProveedorId, Nombre, Contacto, Telefono, Email, Activo, FechaCreacionUtc, FechaActualizacionUtc
    FROM dbo.Proveedores
    WHERE (@SoloActivos IS NULL OR Activo = @SoloActivos)
      AND (@Filtro IS NULL OR Nombre LIKE N'%' + @Filtro + N'%' OR Contacto LIKE N'%' + @Filtro + N'%')
    ORDER BY Nombre, ProveedorId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_GuardarProveedor
    @ProveedorId INT = NULL,
    @Nombre NVARCHAR(150), @Contacto NVARCHAR(150) = NULL, @Telefono NVARCHAR(30) = NULL,
    @Email NVARCHAR(150) = NULL, @Activo BIT = 1,
    @UsuarioId INT, @UsuarioNombre NVARCHAR(150), @UsuarioCorreo NVARCHAR(150) = NULL,
    @Rol NVARCHAR(50) = NULL, @DireccionIp NVARCHAR(80) = NULL, @UserAgent NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF LEN(@Nombre) < 2 THROW 54622, N'Nombre de proveedor inválido.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Proveedores WITH (UPDLOCK, HOLDLOCK) WHERE NombreNormalizado = UPPER(@Nombre) AND ProveedorId <> ISNULL(@ProveedorId, 0))
            THROW 54621, N'Nombre de proveedor duplicado.', 1;
        IF @ProveedorId IS NULL OR @ProveedorId = 0
        BEGIN
            INSERT dbo.Proveedores(Nombre, Contacto, Telefono, Email, Activo)
            VALUES(@Nombre, NULLIF(LTRIM(RTRIM(@Contacto)), N''), NULLIF(LTRIM(RTRIM(@Telefono)), N''), NULLIF(LTRIM(RTRIM(@Email)), N''), @Activo);
            SET @ProveedorId = CONVERT(INT, SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            UPDATE dbo.Proveedores
            SET Nombre=@Nombre, Contacto=NULLIF(LTRIM(RTRIM(@Contacto)),N''), Telefono=NULLIF(LTRIM(RTRIM(@Telefono)),N''),
                Email=NULLIF(LTRIM(RTRIM(@Email)),N''), Activo=@Activo, FechaActualizacionUtc=SYSUTCDATETIME()
            WHERE ProveedorId=@ProveedorId;
            IF @@ROWCOUNT <> 1 THROW 54620, N'Proveedor inexistente.', 1;
        END;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'Proveedor',@ProveedorId,N'Guardar',@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,CONCAT(N'Proveedor ',@Nombre,N'; activo=',@Activo,N'.'),@DireccionIp,@UserAgent);
        COMMIT TRANSACTION;
        SELECT @ProveedorId;
    END TRY BEGIN CATCH IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_CambiarEstadoProveedor
    @ProveedorId INT, @Activo BIT,
    @UsuarioId INT, @UsuarioNombre NVARCHAR(150), @UsuarioCorreo NVARCHAR(150) = NULL,
    @Rol NVARCHAR(50) = NULL, @DireccionIp NVARCHAR(80) = NULL, @UserAgent NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.Proveedores WITH (UPDLOCK) SET Activo=@Activo, FechaActualizacionUtc=SYSUTCDATETIME() WHERE ProveedorId=@ProveedorId;
        IF @@ROWCOUNT <> 1 THROW 54620, N'Proveedor inexistente.', 1;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'Proveedor',@ProveedorId,IIF(@Activo=1,N'Reactivar',N'Desactivar'),@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,CONCAT(N'Activo=',@Activo,N'.'),@DireccionIp,@UserAgent);
        COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_CrearOrden
    @ProveedorId INT, @Notas NVARCHAR(300) = NULL, @TokenOperacion UNIQUEIDENTIFIER,
    @SolicitudHash BINARY(32), @LineasJson NVARCHAR(MAX),
    @UsuarioId INT, @UsuarioNombre NVARCHAR(150), @UsuarioCorreo NVARCHAR(150) = NULL,
    @Rol NVARCHAR(50) = NULL, @DireccionIp NVARCHAR(80) = NULL, @UserAgent NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @TokenOperacion IS NULL OR @SolicitudHash IS NULL OR ISJSON(@LineasJson) <> 1
        THROW 54631, N'Solicitud de orden inválida.', 1;
    DECLARE @Lines TABLE(ProductoId INT NOT NULL PRIMARY KEY, Cantidad INT NOT NULL, PrecioUnitario DECIMAL(18,2) NOT NULL);
    BEGIN TRY
        INSERT @Lines(ProductoId,Cantidad,PrecioUnitario)
        SELECT ProductoId,Cantidad,PrecioUnitario FROM OPENJSON(@LineasJson)
        WITH(ProductoId INT N'$.ProductoId', Cantidad INT N'$.Cantidad', PrecioUnitario DECIMAL(18,2) N'$.PrecioUnitario');
    END TRY BEGIN CATCH THROW 54631, N'Productos duplicados o inválidos.', 1; END CATCH;
    IF NOT EXISTS(SELECT 1 FROM @Lines) OR EXISTS(SELECT 1 FROM @Lines WHERE ProductoId<=0 OR Cantidad<=0 OR PrecioUnitario<=0)
        THROW 54631, N'Productos, cantidades o precios inválidos.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OrdenCompraId INT, @ExistingHash BINARY(32);
        SELECT @OrdenCompraId=OrdenCompraId,@ExistingHash=SolicitudHash FROM dbo.OrdenesCompra WITH(UPDLOCK,HOLDLOCK) WHERE TokenOperacion=@TokenOperacion;
        IF @OrdenCompraId IS NOT NULL
        BEGIN
            IF @ExistingHash <> @SolicitudHash THROW 54633, N'Token reutilizado con otra solicitud.', 1;
            COMMIT TRANSACTION; SELECT @OrdenCompraId; RETURN;
        END;
        IF NOT EXISTS(SELECT 1 FROM dbo.Proveedores WITH(UPDLOCK,HOLDLOCK) WHERE ProveedorId=@ProveedorId AND Activo=1)
            THROW 54630, N'Proveedor inexistente o inactivo.', 1;
        IF EXISTS(SELECT 1 FROM @Lines line LEFT JOIN dbo.Productos product ON product.ProductoId=line.ProductoId AND product.Activo=1 WHERE product.ProductoId IS NULL)
            THROW 54632, N'Producto inexistente o inactivo.', 1;
        INSERT dbo.OrdenesCompra(ProveedorId,Estado,Notas,UsuarioCreacionId,UsuarioCreacionNombre,TokenOperacion,SolicitudHash)
        VALUES(@ProveedorId,N'Pendiente',NULLIF(LTRIM(RTRIM(@Notas)),N''),@UsuarioId,@UsuarioNombre,@TokenOperacion,@SolicitudHash);
        SET @OrdenCompraId=CONVERT(INT,SCOPE_IDENTITY());
        INSERT dbo.DetalleOrdenCompra(OrdenCompraId,ProductoId,CantidadOrdenada,CantidadRecibida,PrecioUnitario)
        SELECT @OrdenCompraId,ProductoId,Cantidad,0,PrecioUnitario FROM @Lines;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'OrdenCompra',@OrdenCompraId,N'Crear',@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,CONCAT(N'Proveedor #',@ProveedorId,N'; líneas=',(SELECT COUNT(*) FROM @Lines),N'.'),@DireccionIp,@UserAgent);
        COMMIT TRANSACTION; SELECT @OrdenCompraId;
    END TRY BEGIN CATCH IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_RecibirDetalle
    @OrdenCompraId INT, @DetalleOrdenCompraId INT, @CantidadRecibidaAhora INT, @TokenOperacion UNIQUEIDENTIFIER,
    @UsuarioId INT, @UsuarioNombre NVARCHAR(150), @UsuarioCorreo NVARCHAR(150) = NULL,
    @Rol NVARCHAR(50) = NULL, @DireccionIp NVARCHAR(80) = NULL, @UserAgent NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @CantidadRecibidaAhora<=0 THROW 54642,N'Cantidad inválida.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ExistingOrder INT,@ExistingDetail INT,@ExistingQuantity INT;
        SELECT @ExistingOrder=OrdenCompraId,@ExistingDetail=DetalleOrdenCompraId,@ExistingQuantity=CantidadRecibida
        FROM dbo.ComprasRecepcionOperaciones WITH(UPDLOCK,HOLDLOCK) WHERE TokenOperacion=@TokenOperacion;
        IF @ExistingOrder IS NOT NULL
        BEGIN
            IF @ExistingOrder<>@OrdenCompraId OR @ExistingDetail<>@DetalleOrdenCompraId OR @ExistingQuantity<>@CantidadRecibidaAhora
                THROW 54644,N'Token de recepción reutilizado con datos diferentes.',1;
            COMMIT TRANSACTION; RETURN;
        END;
        DECLARE @Estado NVARCHAR(30);
        SELECT @Estado=Estado FROM dbo.OrdenesCompra WITH(UPDLOCK,HOLDLOCK) WHERE OrdenCompraId=@OrdenCompraId;
        IF @Estado IS NULL THROW 54640,N'Orden inexistente.',1;
        IF @Estado NOT IN(N'Pendiente',N'RecibidaParcial') THROW 54641,N'La orden no admite recepciones.',1;
        DECLARE @ProductoId INT,@Ordenada INT,@Recibida INT,@StockAnterior INT,@ProductoNombre NVARCHAR(150);
        SELECT @ProductoId=ProductoId,@Ordenada=CantidadOrdenada,@Recibida=CantidadRecibida
        FROM dbo.DetalleOrdenCompra WITH(UPDLOCK,HOLDLOCK)
        WHERE DetalleOrdenCompraId=@DetalleOrdenCompraId AND OrdenCompraId=@OrdenCompraId;
        IF @ProductoId IS NULL THROW 54640,N'Línea inexistente o ajena a la orden.',1;
        IF @Recibida+@CantidadRecibidaAhora>@Ordenada THROW 54643,N'La recepción excede lo ordenado.',1;
        SELECT @StockAnterior=Stock,@ProductoNombre=Nombre FROM dbo.Productos WITH(UPDLOCK,HOLDLOCK) WHERE ProductoId=@ProductoId;
        IF @StockAnterior IS NULL OR CONVERT(BIGINT,@StockAnterior)+@CantidadRecibidaAhora>2147483647 THROW 54645,N'Inventario no actualizable.',1;
        UPDATE dbo.DetalleOrdenCompra SET CantidadRecibida=CantidadRecibida+@CantidadRecibidaAhora WHERE DetalleOrdenCompraId=@DetalleOrdenCompraId;
        UPDATE dbo.Productos SET Stock=Stock+@CantidadRecibidaAhora WHERE ProductoId=@ProductoId;
        INSERT dbo.MovimientosInventario(ProductoId,ProductoNombre,TipoMovimiento,Cantidad,StockAnterior,StockNuevo,Motivo,UsuarioId,UsuarioNombre,FechaMovimiento)
        VALUES(@ProductoId,@ProductoNombre,N'Compra',@CantidadRecibidaAhora,@StockAnterior,@StockAnterior+@CantidadRecibidaAhora,CONCAT(N'Recepción orden #',@OrdenCompraId,N'.'),@UsuarioId,@UsuarioNombre,SYSDATETIME());
        INSERT dbo.ComprasRecepcionOperaciones(TokenOperacion,OrdenCompraId,DetalleOrdenCompraId,CantidadRecibida,UsuarioId,UsuarioNombre)
        VALUES(@TokenOperacion,@OrdenCompraId,@DetalleOrdenCompraId,@CantidadRecibidaAhora,@UsuarioId,@UsuarioNombre);
        DECLARE @TotalOrdenado BIGINT,@TotalRecibido BIGINT;
        SELECT @TotalOrdenado=SUM(CONVERT(BIGINT,CantidadOrdenada)),@TotalRecibido=SUM(CONVERT(BIGINT,CantidadRecibida)) FROM dbo.DetalleOrdenCompra WHERE OrdenCompraId=@OrdenCompraId;
        UPDATE dbo.OrdenesCompra SET Estado=IIF(@TotalRecibido=@TotalOrdenado,N'Recibida',N'RecibidaParcial'),FechaRecepcionUtc=IIF(@TotalRecibido=@TotalOrdenado,SYSUTCDATETIME(),FechaRecepcionUtc) WHERE OrdenCompraId=@OrdenCompraId;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'OrdenCompra',@OrdenCompraId,N'Recibir',@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,CONCAT(N'Línea #',@DetalleOrdenCompraId,N'; producto #',@ProductoId,N'; cantidad=',@CantidadRecibidaAhora,N'.'),@DireccionIp,@UserAgent);
        COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_CerrarConDiscrepancia
    @OrdenCompraId INT,@Motivo NVARCHAR(500),@TokenOperacion UNIQUEIDENTIFIER,
    @UsuarioId INT,@UsuarioNombre NVARCHAR(150),@UsuarioCorreo NVARCHAR(150)=NULL,@Rol NVARCHAR(50)=NULL,@DireccionIp NVARCHAR(80)=NULL,@UserAgent NVARCHAR(300)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @Motivo=LTRIM(RTRIM(@Motivo));
    IF LEN(@Motivo)<10 THROW 54651,N'Motivo insuficiente.',1;
    DECLARE @Hash BINARY(32)=HASHBYTES('SHA2_256',CONCAT(N'CERRAR|',@Motivo));
    BEGIN TRY BEGIN TRANSACTION;
        DECLARE @Estado NVARCHAR(30),@ExistingToken UNIQUEIDENTIFIER,@ExistingHash BINARY(32);
        SELECT @Estado=Estado,@ExistingToken=TokenFinalizacion,@ExistingHash=FinalizacionHash FROM dbo.OrdenesCompra WITH(UPDLOCK,HOLDLOCK) WHERE OrdenCompraId=@OrdenCompraId;
        IF @Estado=N'CerradaConDiscrepancia' AND @ExistingToken=@TokenOperacion
        BEGIN IF @ExistingHash<>@Hash THROW 54653,N'Token reutilizado con otro motivo.',1; COMMIT TRANSACTION; RETURN; END;
        IF @Estado NOT IN(N'Pendiente',N'RecibidaParcial') THROW 54650,N'Orden no cerrable.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.DetalleOrdenCompra WHERE OrdenCompraId=@OrdenCompraId AND CantidadRecibida<CantidadOrdenada) THROW 54652,N'No hay faltantes.',1;
        UPDATE dbo.OrdenesCompra SET Estado=N'CerradaConDiscrepancia',MotivoCierre=@Motivo,FechaCierreUtc=SYSUTCDATETIME(),TokenFinalizacion=@TokenOperacion,FinalizacionHash=@Hash WHERE OrdenCompraId=@OrdenCompraId;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'OrdenCompra',@OrdenCompraId,N'CerrarDiscrepancia',@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,@Motivo,@DireccionIp,@UserAgent);
        COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_CancelarOrden
    @OrdenCompraId INT,@Motivo NVARCHAR(500),@TokenOperacion UNIQUEIDENTIFIER,
    @UsuarioId INT,@UsuarioNombre NVARCHAR(150),@UsuarioCorreo NVARCHAR(150)=NULL,@Rol NVARCHAR(50)=NULL,@DireccionIp NVARCHAR(80)=NULL,@UserAgent NVARCHAR(300)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @Motivo=LTRIM(RTRIM(@Motivo));
    IF LEN(@Motivo)<10 THROW 54651,N'Motivo insuficiente.',1;
    DECLARE @Hash BINARY(32)=HASHBYTES('SHA2_256',CONCAT(N'CANCELAR|',@Motivo));
    BEGIN TRY BEGIN TRANSACTION;
        DECLARE @Estado NVARCHAR(30),@ExistingToken UNIQUEIDENTIFIER,@ExistingHash BINARY(32);
        SELECT @Estado=Estado,@ExistingToken=TokenFinalizacion,@ExistingHash=FinalizacionHash FROM dbo.OrdenesCompra WITH(UPDLOCK,HOLDLOCK) WHERE OrdenCompraId=@OrdenCompraId;
        IF @Estado=N'Cancelada' AND @ExistingToken=@TokenOperacion
        BEGIN IF @ExistingHash<>@Hash THROW 54661,N'Token reutilizado con otro motivo.',1; COMMIT TRANSACTION; RETURN; END;
        IF @Estado<>N'Pendiente' OR EXISTS(SELECT 1 FROM dbo.DetalleOrdenCompra WHERE OrdenCompraId=@OrdenCompraId AND CantidadRecibida>0) THROW 54660,N'Orden no cancelable.',1;
        UPDATE dbo.OrdenesCompra SET Estado=N'Cancelada',MotivoCierre=@Motivo,FechaCierreUtc=SYSUTCDATETIME(),TokenFinalizacion=@TokenOperacion,FinalizacionHash=@Hash WHERE OrdenCompraId=@OrdenCompraId;
        IF @@ROWCOUNT<>1 THROW 54660,N'Orden no cancelable.',1;
        INSERT dbo.ComprasAuditoria(Entidad,EntidadId,Accion,UsuarioId,UsuarioNombre,UsuarioCorreo,Rol,Detalle,DireccionIp,UserAgent)
        VALUES(N'OrdenCompra',@OrdenCompraId,N'Cancelar',@UsuarioId,@UsuarioNombre,@UsuarioCorreo,@Rol,@Motivo,@DireccionIp,@UserAgent);
        COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_ListarOrdenes @Estado NVARCHAR(30)=NULL,@ProveedorId INT=NULL AS
BEGIN
    SET NOCOUNT ON;
    SELECT orderHeader.OrdenCompraId,orderHeader.ProveedorId,supplier.Nombre ProveedorNombre,orderHeader.Estado,orderHeader.Notas,
           orderHeader.FechaCreacionUtc,orderHeader.FechaRecepcionUtc,orderHeader.FechaCierreUtc,
           CONVERT(DECIMAL(18,2),COALESCE(SUM(CONVERT(DECIMAL(38,2),detail.CantidadOrdenada)*detail.PrecioUnitario),0)) MontoTotal,
           CONVERT(INT,COALESCE(SUM(CONVERT(BIGINT,detail.CantidadOrdenada)),0)) TotalOrdenado,
           CONVERT(INT,COALESCE(SUM(CONVERT(BIGINT,detail.CantidadRecibida)),0)) TotalRecibido
    FROM dbo.OrdenesCompra orderHeader INNER JOIN dbo.Proveedores supplier ON supplier.ProveedorId=orderHeader.ProveedorId
    LEFT JOIN dbo.DetalleOrdenCompra detail ON detail.OrdenCompraId=orderHeader.OrdenCompraId
    WHERE (@Estado IS NULL OR orderHeader.Estado=@Estado) AND (@ProveedorId IS NULL OR orderHeader.ProveedorId=@ProveedorId)
    GROUP BY orderHeader.OrdenCompraId,orderHeader.ProveedorId,supplier.Nombre,orderHeader.Estado,orderHeader.Notas,orderHeader.FechaCreacionUtc,orderHeader.FechaRecepcionUtc,orderHeader.FechaCierreUtc
    ORDER BY orderHeader.FechaCreacionUtc DESC,orderHeader.OrdenCompraId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_ObtenerOrdenDetalle @OrdenCompraId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT orderHeader.OrdenCompraId,orderHeader.ProveedorId,supplier.Nombre ProveedorNombre,orderHeader.Estado,orderHeader.Notas,orderHeader.MotivoCierre,orderHeader.FechaCreacionUtc,orderHeader.FechaRecepcionUtc,orderHeader.FechaCierreUtc
    FROM dbo.OrdenesCompra orderHeader INNER JOIN dbo.Proveedores supplier ON supplier.ProveedorId=orderHeader.ProveedorId WHERE orderHeader.OrdenCompraId=@OrdenCompraId;
    SELECT detail.DetalleOrdenCompraId,detail.ProductoId,product.Nombre ProductoNombre,detail.CantidadOrdenada,detail.CantidadRecibida,detail.PrecioUnitario
    FROM dbo.DetalleOrdenCompra detail INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId WHERE detail.OrdenCompraId=@OrdenCompraId ORDER BY detail.DetalleOrdenCompraId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_HistoricoPrecios @ProductoId INT AS
BEGIN
    SET NOCOUNT ON;
    ;WITH history AS
    (
        SELECT orderHeader.OrdenCompraId,orderHeader.ProveedorId,supplier.Nombre ProveedorNombre,detail.PrecioUnitario,orderHeader.Estado,orderHeader.FechaCreacionUtc,
               LAG(detail.PrecioUnitario) OVER(PARTITION BY detail.ProductoId,orderHeader.ProveedorId ORDER BY orderHeader.FechaCreacionUtc,orderHeader.OrdenCompraId) PrecioAnterior
        FROM dbo.DetalleOrdenCompra detail INNER JOIN dbo.OrdenesCompra orderHeader ON orderHeader.OrdenCompraId=detail.OrdenCompraId
        INNER JOIN dbo.Proveedores supplier ON supplier.ProveedorId=orderHeader.ProveedorId
        WHERE detail.ProductoId=@ProductoId AND orderHeader.Estado<>N'Cancelada'
    )
    SELECT OrdenCompraId,ProveedorId,ProveedorNombre,PrecioUnitario,PrecioAnterior,
           CONVERT(DECIMAL(18,2),CASE WHEN PrecioAnterior>0 THEN ((PrecioUnitario-PrecioAnterior)/PrecioAnterior)*100 END) VariacionPorcentual,
           Estado,FechaCreacionUtc FROM history ORDER BY FechaCreacionUtc DESC,OrdenCompraId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compras_UltimosPrecios AS
BEGIN
    SET NOCOUNT ON;
    ;WITH latest AS
    (
        SELECT detail.ProductoId,detail.PrecioUnitario,supplier.Nombre ProveedorNombre,orderHeader.FechaCreacionUtc,
               ROW_NUMBER() OVER(PARTITION BY detail.ProductoId ORDER BY orderHeader.FechaCreacionUtc DESC,orderHeader.OrdenCompraId DESC) rowNumber
        FROM dbo.DetalleOrdenCompra detail INNER JOIN dbo.OrdenesCompra orderHeader ON orderHeader.OrdenCompraId=detail.OrdenCompraId
        INNER JOIN dbo.Proveedores supplier ON supplier.ProveedorId=orderHeader.ProveedorId WHERE orderHeader.Estado<>N'Cancelada'
    )
    SELECT ProductoId,PrecioUnitario UltimoPrecioPagado,ProveedorNombre UltimoProveedor,FechaCreacionUtc UltimaFecha FROM latest WHERE rowNumber=1;
END;
GO

IF XACT_STATE() <> 1 THROW 54612,N'La transacción de 0013 no está disponible para confirmar.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 54613,N'El SHA-256 de 0013 debe ser hexadecimal y tener 64 caracteres.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0013_purchasing_suppliers_orders',N'0013_purchasing_suppliers_orders.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-101 a CU-104: proveedores, órdenes idempotentes, recepción atómica, discrepancias, permisos y precios.');
COMMIT TRANSACTION;
GO

IF (SELECT COUNT(*) FROM dbo.Permisos WHERE Codigo IN
    (N'PROVEEDORES_VER',N'PROVEEDORES_GESTIONAR',N'COMPRAS_ORDENES_VER',N'COMPRAS_ORDENES_CREAR',N'COMPRAS_ORDENES_RECIBIR',N'COMPRAS_ORDENES_CERRAR',N'COMPRAS_ORDENES_CANCELAR',N'COMPRAS_SUGERENCIAS_VER',N'COMPRAS_PRECIOS_VER') AND Activo=1)<>9
    THROW 54614,N'La verificación posterior detectó permisos faltantes.',1;
GO
