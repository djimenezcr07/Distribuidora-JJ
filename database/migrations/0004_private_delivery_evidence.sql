SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Evidencia privada fuera de wwwroot. El archivo se prepara temporalmente, el SP valida
  pertenencia y registra estado Pending, la aplicación hace un movimiento atómico y luego
  cambia el estado a Ready. Los registros legados quedan en estado Legacy y no se publican.
  Rollback: desactivar los SP nuevos y restaurar los SP anteriores; no eliminar metadatos.
*/
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.EntregaEvidencias', N'StorageKey') IS NULL
    ALTER TABLE dbo.EntregaEvidencias ADD StorageKey NVARCHAR(160) NULL;

IF COL_LENGTH(N'dbo.EntregaEvidencias', N'MimeType') IS NULL
    ALTER TABLE dbo.EntregaEvidencias ADD MimeType NVARCHAR(100) NULL;

IF COL_LENGTH(N'dbo.EntregaEvidencias', N'StorageStatus') IS NULL
    ALTER TABLE dbo.EntregaEvidencias ADD StorageStatus NVARCHAR(20) NOT NULL
        CONSTRAINT DF_EntregaEvidencias_StorageStatus DEFAULT N'Legacy';

IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.EntregaEvidencias')
      AND name = N'CK_EntregaEvidencias_StorageStatus'
)
BEGIN
    ALTER TABLE dbo.EntregaEvidencias WITH CHECK ADD CONSTRAINT CK_EntregaEvidencias_StorageStatus
        CHECK (StorageStatus IN (N'Legacy', N'Pending', N'Ready'));
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.EntregaEvidencias')
      AND name = N'UX_EntregaEvidencias_StorageKey'
)
BEGIN
    CREATE UNIQUE INDEX UX_EntregaEvidencias_StorageKey
        ON dbo.EntregaEvidencias (StorageKey)
        WHERE StorageKey IS NOT NULL;
END;

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
        (N'ENTREGAS_EVIDENCIA_VER', N'Entregas', N'Ver evidencia de entregas',
         N'Permite consultar archivos privados de evidencia de entrega.')
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
        SELECT p.PerfilId, pe.PermisoId, NULL, N'Migración 0004'
        FROM dbo.Perfiles p
        INNER JOIN dbo.Permisos pe ON pe.Codigo = N'ENTREGAS_EVIDENCIA_VER'
        WHERE p.Nombre = N'Administrador'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerfilPermisos pp
              WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId
          );
    END;
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_RegisterEvidence
    @PedidoId INT,
    @RutaId INT,
    @TipoEvidencia NVARCHAR(20),
    @StorageKey NVARCHAR(160),
    @MimeType NVARCHAR(100),
    @Observaciones NVARCHAR(300) = NULL,
    @RegistradoPorUsuarioId INT,
    @RegistradoPorNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TipoEvidencia = NULLIF(LTRIM(RTRIM(@TipoEvidencia)), N'');
    SET @StorageKey = NULLIF(LTRIM(RTRIM(@StorageKey)), N'');
    SET @MimeType = LOWER(NULLIF(LTRIM(RTRIM(@MimeType)), N''));

    IF @TipoEvidencia NOT IN (N'Foto', N'Firma')
        THROW 52080, N'El tipo de evidencia no es válido.', 1;
    IF @MimeType NOT IN (N'image/jpeg', N'image/png', N'image/webp')
        THROW 52081, N'El tipo de contenido no es válido.', 1;
    IF @StorageKey IS NULL OR @StorageKey LIKE N'%/%' OR @StorageKey LIKE N'%\%' OR @StorageKey LIKE N'%:%'
        THROW 52082, N'La referencia de almacenamiento no es válida.', 1;
    IF (@MimeType = N'image/jpeg' AND RIGHT(@StorageKey, 4) <> N'.jpg')
       OR (@MimeType = N'image/png' AND RIGHT(@StorageKey, 4) <> N'.png')
       OR (@MimeType = N'image/webp' AND RIGHT(@StorageKey, 5) <> N'.webp')
        THROW 52083, N'La referencia no coincide con el tipo de contenido.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.RutaPedidos rp
        INNER JOIN dbo.Rutas r ON r.RutaId = rp.RutaId
        INNER JOIN dbo.Usuarios actor ON actor.UsuarioId = @RegistradoPorUsuarioId AND actor.Activo = 1
        INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = actor.PerfilId
        WHERE rp.RutaId = @RutaId
          AND rp.PedidoId = @PedidoId
          AND (r.ChoferUsuarioId = @RegistradoPorUsuarioId OR perfil.Nombre = N'Administrador')
    )
        THROW 52084, N'El usuario no está autorizado para registrar evidencia en esta entrega.', 1;

    INSERT INTO dbo.EntregaEvidencias
        (PedidoId, RutaId, TipoEvidencia, ArchivoUrl, StorageKey, MimeType, StorageStatus,
         Observaciones, RegistradoPorUsuarioId, RegistradoPorNombre, FechaRegistro)
    VALUES
        (@PedidoId, @RutaId, @TipoEvidencia, N'[private]', @StorageKey, @MimeType, N'Pending',
         NULLIF(LTRIM(RTRIM(@Observaciones)), N''), @RegistradoPorUsuarioId,
         NULLIF(LTRIM(RTRIM(@RegistradoPorNombre)), N''), SYSUTCDATETIME());

    SELECT CONVERT(INT, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_MarkEvidenceReady
    @EvidenciaId INT,
    @RegistradoPorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.EntregaEvidencias
    SET StorageStatus = N'Ready'
    WHERE EvidenciaId = @EvidenciaId
      AND RegistradoPorUsuarioId = @RegistradoPorUsuarioId
      AND StorageStatus = N'Pending';
    IF @@ROWCOUNT = 0 THROW 52085, N'No fue posible confirmar la evidencia pendiente.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_DeletePendingEvidence
    @EvidenciaId INT,
    @RegistradoPorUsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.EntregaEvidencias
    WHERE EvidenciaId = @EvidenciaId
      AND RegistradoPorUsuarioId = @RegistradoPorUsuarioId
      AND StorageStatus = N'Pending';
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_GetAuthorizedEvidence
    @EvidenciaId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        e.EvidenciaId,
        e.PedidoId,
        e.StorageKey,
        e.MimeType,
        e.TipoEvidencia
    FROM dbo.EntregaEvidencias e
    INNER JOIN dbo.Pedidos pedido ON pedido.PedidoId = e.PedidoId
    INNER JOIN dbo.Usuarios usuario ON usuario.UsuarioId = @UsuarioId AND usuario.Activo = 1
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId AND perfil.Activo = 1
    LEFT JOIN dbo.Rutas ruta ON ruta.RutaId = e.RutaId
    WHERE e.EvidenciaId = @EvidenciaId
      AND e.StorageStatus = N'Ready'
      AND e.StorageKey IS NOT NULL
      AND e.MimeType IN (N'image/jpeg', N'image/png', N'image/webp')
      AND
      (
          pedido.UsuarioId = @UsuarioId
          OR ruta.ChoferUsuarioId = @UsuarioId
          OR perfil.Nombre = N'Administrador'
          OR EXISTS
          (
              SELECT 1
              FROM dbo.PerfilPermisos pp
              INNER JOIN dbo.Permisos permiso ON permiso.PermisoId = pp.PermisoId
              WHERE pp.PerfilId = perfil.PerfilId
                AND permiso.Codigo = N'ENTREGAS_EVIDENCIA_VER'
                AND permiso.Activo = 1
          )
      );
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_GetEvidencesByOrder
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EvidenciaId, e.PedidoId, e.RutaId, e.TipoEvidencia,
           e.StorageKey, e.MimeType,
           ISNULL(e.Observaciones, N'') AS Observaciones,
           ISNULL(e.RegistradoPorNombre, N'') AS RegistradoPorNombre,
           e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    WHERE e.PedidoId = @PedidoId AND e.StorageStatus = N'Ready'
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrega_GetEvidencesByRoute
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rp.PedidoId, rp.EstadoEntrega, u.NombreCompleto AS Cliente,
           (SELECT COUNT(*) FROM dbo.EntregaEvidencias e
            WHERE e.PedidoId = rp.PedidoId AND e.StorageStatus = N'Ready') AS TotalEvidencias,
           CONVERT(BIT, IIF(EXISTS
           (
               SELECT 1 FROM dbo.EntregaEvidencias e
               WHERE e.PedidoId = rp.PedidoId AND e.StorageStatus = N'Ready'
           ), 0, 1)) AS SinEvidencia
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos p ON p.PedidoId = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia, rp.PedidoId;

    SELECT e.EvidenciaId, e.PedidoId, e.TipoEvidencia, e.StorageKey, e.MimeType,
           ISNULL(e.Observaciones, N'') AS Observaciones,
           ISNULL(e.RegistradoPorNombre, N'') AS RegistradoPorNombre,
           e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    INNER JOIN dbo.RutaPedidos rp ON rp.PedidoId = e.PedidoId AND rp.RutaId = @RutaId
    WHERE e.StorageStatus = N'Ready'
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;
GO

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0004_private_delivery_evidence')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
    VALUES
        (N'0004_private_delivery_evidence', N'0004_private_delivery_evidence.sql',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', N'0004_private_delivery_evidence_v1'), 2),
         N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
         N'Los archivos legados requieren migración operativa al almacenamiento privado antes de marcarlos Ready.');
END;
GO
