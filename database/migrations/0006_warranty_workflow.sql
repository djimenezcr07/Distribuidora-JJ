SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Flujo de garantías: propiedad del detalle, prevención transaccional de duplicados
  abiertos, resolución administrativa y auditoría. Rollback: retirar los SP nuevos y
  conservar tabla/historial; los estados terminales no deben revertirse sin una migración compensatoria.
*/
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.Garantias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Garantias
    (
        GarantiaId INT IDENTITY(1,1) NOT NULL,
        PedidoDetalleId INT NOT NULL,
        UsuarioId INT NOT NULL,
        FechaSolicitud DATETIME2(0) NOT NULL
            CONSTRAINT DF_Garantias_FechaSolicitud DEFAULT SYSUTCDATETIME(),
        Motivo NVARCHAR(250) NOT NULL,
        Descripcion NVARCHAR(1000) NULL,
        Telefono NVARCHAR(30) NULL,
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_Garantias_Estado DEFAULT N'Pendiente',
        Resolucion NVARCHAR(1000) NULL,
        FechaResolucion DATETIME2(0) NULL,
        ResueltoPorUsuarioId INT NULL,
        ResueltoPorNombre NVARCHAR(150) NULL,
        CONSTRAINT PK_Garantias PRIMARY KEY (GarantiaId),
        CONSTRAINT FK_Garantias_PedidoDetalle FOREIGN KEY (PedidoDetalleId)
            REFERENCES dbo.PedidoDetalle(PedidoDetalleId),
        CONSTRAINT FK_Garantias_Usuario FOREIGN KEY (UsuarioId)
            REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_Garantias_Estado CHECK (Estado IN (N'Pendiente', N'En revisión', N'Aprobada', N'Rechazada'))
    );
END;

IF COL_LENGTH(N'dbo.Garantias', N'ResueltoPorUsuarioId') IS NULL
    ALTER TABLE dbo.Garantias ADD ResueltoPorUsuarioId INT NULL;

IF COL_LENGTH(N'dbo.Garantias', N'ResueltoPorNombre') IS NULL
    ALTER TABLE dbo.Garantias ADD ResueltoPorNombre NVARCHAR(150) NULL;

IF COL_LENGTH(N'dbo.Garantias', N'Descripcion') IS NULL
    ALTER TABLE dbo.Garantias ADD Descripcion NVARCHAR(1000) NULL;

IF COL_LENGTH(N'dbo.Garantias', N'Telefono') IS NULL
    ALTER TABLE dbo.Garantias ADD Telefono NVARCHAR(30) NULL;

IF COL_LENGTH(N'dbo.Garantias', N'Resolucion') IS NULL
    ALTER TABLE dbo.Garantias ADD Resolucion NVARCHAR(1000) NULL;

IF COL_LENGTH(N'dbo.Garantias', N'FechaResolucion') IS NULL
    ALTER TABLE dbo.Garantias ADD FechaResolucion DATETIME2(0) NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Garantias')
      AND name = N'IX_Garantias_DuplicadoAbierto'
)
BEGIN
    CREATE INDEX IX_Garantias_DuplicadoAbierto
        ON dbo.Garantias (PedidoDetalleId, UsuarioId, Estado);
END;

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
        (N'GARANTIAS_GESTIONAR', N'Garantias', N'Gestionar garantías',
         N'Permite revisar, aprobar o rechazar solicitudes de garantía.')
    ) AS source (Codigo, Modulo, Nombre, Descripcion)
    ON target.Codigo = source.Codigo
    WHEN MATCHED THEN UPDATE SET
        target.Modulo = source.Modulo,
        target.Nombre = source.Nombre,
        target.Descripcion = source.Descripcion,
        target.Activo = 1
    WHEN NOT MATCHED THEN
        INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);

    IF OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
        SELECT perfil.PerfilId, permiso.PermisoId, NULL, N'Migración 0006'
        FROM dbo.Perfiles perfil
        INNER JOIN dbo.Permisos permiso ON permiso.Codigo = N'GARANTIAS_GESTIONAR'
        WHERE perfil.Nombre = N'Administrador'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerfilPermisos actual
              WHERE actual.PerfilId = perfil.PerfilId AND actual.PermisoId = permiso.PermisoId
          );
    END;
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_CreateWarrantyRequest
    @PedidoDetalleId INT,
    @UsuarioId INT,
    @Motivo NVARCHAR(250),
    @Descripcion NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');
    IF @Motivo IS NULL THROW 53300, N'El motivo de la garantía es obligatorio.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.PedidoDetalle detalle
        INNER JOIN dbo.Pedidos pedido ON pedido.PedidoId = detalle.PedidoId
        WHERE detalle.PedidoDetalleId = @PedidoDetalleId
          AND pedido.UsuarioId = @UsuarioId
          AND pedido.Estado = N'Entregado'
    )
        THROW 53301, N'El producto no pertenece a un pedido entregado del cliente.', 1;

    BEGIN TRANSACTION;
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Garantias WITH (UPDLOCK, HOLDLOCK)
        WHERE PedidoDetalleId = @PedidoDetalleId
          AND UsuarioId = @UsuarioId
          AND Estado IN (N'Pendiente', N'En revisión')
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 53302, N'Ya existe una solicitud abierta para este producto.', 1;
    END;

    INSERT INTO dbo.Garantias
        (PedidoDetalleId, UsuarioId, Motivo, Descripcion, Estado, FechaSolicitud)
    VALUES
        (@PedidoDetalleId, @UsuarioId, @Motivo,
         NULLIF(LTRIM(RTRIM(@Descripcion)), N''), N'Pendiente', SYSUTCDATETIME());
    DECLARE @GarantiaId INT = CONVERT(INT, SCOPE_IDENTITY());
    COMMIT TRANSACTION;
    SELECT @GarantiaId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetWarrantyRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT garantia.GarantiaId,
           garantia.UsuarioId,
           pedido.PedidoId,
           producto.Nombre AS Producto,
           cliente.NombreCompleto AS Cliente,
           garantia.FechaSolicitud,
           garantia.Estado,
           garantia.Motivo,
           garantia.Descripcion,
           garantia.Resolucion,
           garantia.FechaResolucion
    FROM dbo.Garantias garantia
    INNER JOIN dbo.PedidoDetalle detalle ON detalle.PedidoDetalleId = garantia.PedidoDetalleId
    INNER JOIN dbo.Pedidos pedido ON pedido.PedidoId = detalle.PedidoId
    INNER JOIN dbo.Productos producto ON producto.ProductoId = detalle.ProductoId
    INNER JOIN dbo.Usuarios cliente ON cliente.UsuarioId = garantia.UsuarioId
    ORDER BY CASE garantia.Estado WHEN N'Pendiente' THEN 0 WHEN N'En revisión' THEN 1 ELSE 2 END,
             garantia.FechaSolicitud DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateWarrantyStatus
    @GarantiaId INT,
    @Estado NVARCHAR(30),
    @Resolucion NVARCHAR(1000) = NULL,
    @ActorUsuarioId INT,
    @ActorNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Resolucion = NULLIF(LTRIM(RTRIM(@Resolucion)), N'');

    IF @Estado NOT IN (N'En revisión', N'Aprobada', N'Rechazada')
        THROW 53303, N'El estado de garantía no es válido.', 1;
    IF @Estado IN (N'Aprobada', N'Rechazada') AND @Resolucion IS NULL
        THROW 53304, N'La resolución es obligatoria para cerrar la garantía.', 1;

    BEGIN TRANSACTION;
    DECLARE @EstadoAnterior NVARCHAR(30);
    SELECT @EstadoAnterior = Estado
    FROM dbo.Garantias WITH (UPDLOCK, HOLDLOCK)
    WHERE GarantiaId = @GarantiaId;

    IF @EstadoAnterior IS NULL THROW 53305, N'La garantía no existe.', 1;
    IF @EstadoAnterior IN (N'Aprobada', N'Rechazada')
        THROW 53306, N'La garantía ya tiene una resolución terminal.', 1;

    UPDATE dbo.Garantias
    SET Estado = @Estado,
        Resolucion = CASE WHEN @Estado IN (N'Aprobada', N'Rechazada') THEN @Resolucion ELSE Resolucion END,
        FechaResolucion = CASE WHEN @Estado IN (N'Aprobada', N'Rechazada') THEN SYSUTCDATETIME() ELSE NULL END,
        ResueltoPorUsuarioId = @ActorUsuarioId,
        ResueltoPorNombre = @ActorNombre
    WHERE GarantiaId = @GarantiaId;

    IF OBJECT_ID(N'dbo.AuditoriaSistema', N'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.AuditoriaSistema
            (UsuarioId, UsuarioNombre, UsuarioCorreo, Rol, Accion, Modulo, Descripcion)
        SELECT actor.UsuarioId, actor.NombreCompleto, actor.Correo, perfil.Nombre,
               N'ACTUALIZAR_GARANTIA', N'Garantias',
               CONCAT(N'Garantía ', @GarantiaId, N': ', @EstadoAnterior, N' -> ', @Estado, N'.')
        FROM dbo.Usuarios actor
        INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = actor.PerfilId
        WHERE actor.UsuarioId = @ActorUsuarioId;
    END;
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0006_warranty_workflow')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0006_warranty_workflow', N'0006_warranty_workflow.sql',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', N'0006_warranty_workflow_v1'), 2),
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Prevención serializable de duplicados abiertos y resolución administrativa auditada.');
END;
GO
