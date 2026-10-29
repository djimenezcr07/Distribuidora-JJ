SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  CU-201: repositorio documental privado, versionado y auditable.
  Rollback: retirar primero los procedimientos; conservar tablas y archivos privados.
  Cualquier eliminación de datos requiere una migración compensatoria aprobada.
*/
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.DepartamentosOperativos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DepartamentosOperativos
    (
        DepartamentoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DepartamentosOperativos PRIMARY KEY,
        Codigo NVARCHAR(30) NOT NULL,
        Nombre NVARCHAR(120) NOT NULL,
        Activo BIT NOT NULL CONSTRAINT DF_DepartamentosOperativos_Activo DEFAULT 1,
        CONSTRAINT UQ_DepartamentosOperativos_Codigo UNIQUE (Codigo),
        CONSTRAINT UQ_DepartamentosOperativos_Nombre UNIQUE (Nombre)
    );
END;

MERGE dbo.DepartamentosOperativos AS target
USING (VALUES
    (N'ADMIN', N'Administración'), (N'FIN', N'Finanzas'), (N'COMPRAS', N'Compras'),
    (N'OPER', N'Operaciones'), (N'RRHH', N'Recursos Humanos')
) AS source (Codigo, Nombre)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = source.Nombre, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Activo) VALUES (source.Codigo, source.Nombre, 1);

IF OBJECT_ID(N'dbo.TiposDocumento', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TiposDocumento
    (
        TipoDocumentoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TiposDocumento PRIMARY KEY,
        Nombre NVARCHAR(120) NOT NULL CONSTRAINT UQ_TiposDocumento_Nombre UNIQUE,
        Activo BIT NOT NULL CONSTRAINT DF_TiposDocumento_Activo DEFAULT 1
    );
END;

MERGE dbo.TiposDocumento AS target
USING (VALUES (N'Contrato'), (N'Permiso'), (N'Póliza'), (N'Certificación'), (N'Licencia'), (N'Otro')) AS source (Nombre)
ON target.Nombre = source.Nombre
WHEN MATCHED THEN UPDATE SET Activo = 1
WHEN NOT MATCHED THEN INSERT (Nombre, Activo) VALUES (source.Nombre, 1);

IF OBJECT_ID(N'dbo.DocumentosDigitales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentosDigitales
    (
        DocumentoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentosDigitales PRIMARY KEY,
        TipoDocumentoId INT NOT NULL,
        DepartamentoId INT NULL,
        ResponsableUsuarioId INT NOT NULL,
        Titulo NVARCHAR(180) NOT NULL,
        Descripcion NVARCHAR(1000) NULL,
        NumeroReferencia NVARCHAR(100) NULL,
        FechaEmision DATE NULL,
        FechaVencimiento DATE NULL,
        NoVence BIT NOT NULL CONSTRAINT DF_DocumentosDigitales_NoVence DEFAULT 0,
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_DocumentosDigitales_Estado DEFAULT N'Vigente',
        Activo BIT NOT NULL CONSTRAINT DF_DocumentosDigitales_Activo DEFAULT 1,
        VersionActualId INT NULL,
        CreadoPorUsuarioId INT NOT NULL,
        CreadoPorNombre NVARCHAR(150) NOT NULL,
        ActualizadoPorUsuarioId INT NOT NULL,
        ActualizadoPorNombre NVARCHAR(150) NOT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentosDigitales_Creacion DEFAULT SYSUTCDATETIME(),
        FechaActualizacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentosDigitales_Actualizacion DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_DocumentosDigitales_Tipo FOREIGN KEY (TipoDocumentoId) REFERENCES dbo.TiposDocumento(TipoDocumentoId),
        CONSTRAINT FK_DocumentosDigitales_Departamento FOREIGN KEY (DepartamentoId) REFERENCES dbo.DepartamentosOperativos(DepartamentoId),
        CONSTRAINT FK_DocumentosDigitales_Responsable FOREIGN KEY (ResponsableUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_DocumentosDigitales_Creador FOREIGN KEY (CreadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_DocumentosDigitales_Actualizador FOREIGN KEY (ActualizadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_DocumentosDigitales_Estado CHECK (Estado IN (N'Vigente', N'Suspendido', N'Archivado')),
        CONSTRAINT CK_DocumentosDigitales_Vencimiento CHECK ((NoVence = 1 AND FechaVencimiento IS NULL) OR (NoVence = 0 AND FechaVencimiento IS NOT NULL)),
        CONSTRAINT CK_DocumentosDigitales_Fechas CHECK (FechaEmision IS NULL OR FechaVencimiento IS NULL OR FechaVencimiento >= FechaEmision)
    );
END;

IF OBJECT_ID(N'dbo.DocumentoVersiones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentoVersiones
    (
        DocumentoVersionId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentoVersiones PRIMARY KEY,
        DocumentoId INT NOT NULL,
        Version INT NOT NULL,
        NombreOriginal NVARCHAR(255) NOT NULL,
        StorageKey NVARCHAR(80) NOT NULL,
        MimeType NVARCHAR(100) NOT NULL,
        Extension NVARCHAR(10) NOT NULL,
        TamanoBytes BIGINT NOT NULL,
        HashSha256 CHAR(64) NOT NULL,
        StorageStatus NVARCHAR(20) NOT NULL CONSTRAINT DF_DocumentoVersiones_Status DEFAULT N'Pending',
        CreadoPorUsuarioId INT NOT NULL,
        CreadoPorNombre NVARCHAR(150) NOT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentoVersiones_Creacion DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_DocumentoVersiones_Documento FOREIGN KEY (DocumentoId) REFERENCES dbo.DocumentosDigitales(DocumentoId),
        CONSTRAINT FK_DocumentoVersiones_Usuario FOREIGN KEY (CreadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT UQ_DocumentoVersiones_DocumentoVersion UNIQUE (DocumentoId, Version),
        CONSTRAINT UQ_DocumentoVersiones_StorageKey UNIQUE (StorageKey),
        CONSTRAINT CK_DocumentoVersiones_Formato CHECK (MimeType IN (N'application/pdf', N'image/jpeg', N'image/png') AND Extension IN (N'.pdf', N'.jpg', N'.png')),
        CONSTRAINT CK_DocumentoVersiones_Tamano CHECK (TamanoBytes > 0 AND TamanoBytes <= 10485760),
        CONSTRAINT CK_DocumentoVersiones_Status CHECK (StorageStatus IN (N'Pending', N'Ready'))
    );
    ALTER TABLE dbo.DocumentosDigitales ADD CONSTRAINT FK_DocumentosDigitales_VersionActual
        FOREIGN KEY (VersionActualId) REFERENCES dbo.DocumentoVersiones(DocumentoVersionId);
END;

IF OBJECT_ID(N'dbo.DocumentoAuditoria', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentoAuditoria
    (
        DocumentoAuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentoAuditoria PRIMARY KEY,
        DocumentoId INT NOT NULL,
        Accion NVARCHAR(60) NOT NULL,
        UsuarioId INT NOT NULL,
        UsuarioNombre NVARCHAR(150) NOT NULL,
        Detalle NVARCHAR(800) NULL,
        FechaUtc DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentoAuditoria_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_DocumentoAuditoria_Documento FOREIGN KEY (DocumentoId) REFERENCES dbo.DocumentosDigitales(DocumentoId)
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DocumentosDigitales') AND name = N'IX_DocumentosDigitales_Filtros')
    CREATE INDEX IX_DocumentosDigitales_Filtros ON dbo.DocumentosDigitales (Activo, FechaVencimiento, DepartamentoId, TipoDocumentoId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DocumentoVersiones') AND name = N'UX_DocumentoVersiones_HashPorDocumento')
    CREATE UNIQUE INDEX UX_DocumentoVersiones_HashPorDocumento ON dbo.DocumentoVersiones(DocumentoId,HashSha256);

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
        (N'DOCUMENTOS_VER', N'Documentos', N'Ver documentos', N'Consulta y descarga autorizada de documentos privados.'),
        (N'DOCUMENTOS_GESTIONAR', N'Documentos', N'Gestionar documentos', N'Crea, edita, versiona y desactiva documentos.')
    ) AS source (Codigo, Modulo, Nombre, Descripcion)
    ON target.Codigo = source.Codigo
    WHEN MATCHED THEN UPDATE SET Modulo=source.Modulo, Nombre=source.Nombre, Descripcion=source.Descripcion, Activo=1
    WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo) VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);

    IF OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NOT NULL
        INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
        SELECT p.PerfilId, pm.PermisoId, NULL, N'Migración 0007' FROM dbo.Perfiles p CROSS JOIN dbo.Permisos pm
        WHERE p.Nombre=N'Administrador' AND pm.Codigo IN (N'DOCUMENTOS_VER', N'DOCUMENTOS_GESTIONAR')
          AND NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=p.PerfilId AND x.PermisoId=pm.PermisoId);
END;

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_GetOptions AS
BEGIN
    SET NOCOUNT ON;
    SELECT TipoDocumentoId, Nombre FROM dbo.TiposDocumento WHERE Activo=1 ORDER BY Nombre;
    SELECT DepartamentoId, Nombre FROM dbo.DepartamentosOperativos WHERE Activo=1 ORDER BY Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_List
    @Busqueda NVARCHAR(180)=NULL, @TipoDocumentoId INT=NULL, @DepartamentoId INT=NULL,
    @Estado NVARCHAR(30)=NULL, @Vencimiento NVARCHAR(30)=NULL, @FechaNegocio DATE,
    @DiasAviso INT=30, @Pagina INT=1, @TamanoPagina INT=20
AS
BEGIN
    SET NOCOUNT ON;
    SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END;
    SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
    ;WITH base AS
    (
        SELECT d.DocumentoId, t.Nombre TipoDocumento, dep.Nombre Departamento, d.Titulo, d.NumeroReferencia,
               d.FechaEmision, d.FechaVencimiento, d.NoVence, d.Estado, d.Activo, v.Version, d.FechaActualizacionUtc,
               CASE WHEN d.NoVence=1 THEN N'No vence' WHEN d.FechaVencimiento<@FechaNegocio THEN N'Vencido'
                    WHEN DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)<=@DiasAviso THEN N'Por vencer' ELSE N'Vigente' END EstadoVencimiento,
               CASE WHEN d.NoVence=1 THEN NULL ELSE DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento) END DiasRestantes
        FROM dbo.DocumentosDigitales d
        INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId
        LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
        INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId AND v.StorageStatus=N'Ready'
        WHERE (@Busqueda IS NULL OR d.Titulo LIKE N'%'+@Busqueda+N'%' OR d.NumeroReferencia LIKE N'%'+@Busqueda+N'%')
          AND (@TipoDocumentoId IS NULL OR d.TipoDocumentoId=@TipoDocumentoId)
          AND (@DepartamentoId IS NULL OR d.DepartamentoId=@DepartamentoId)
          AND (@Estado IS NULL OR d.Estado=@Estado)
    ), filtrado AS
    (
        SELECT *, COUNT(*) OVER() TotalResultados FROM base
        WHERE @Vencimiento IS NULL OR EstadoVencimiento=@Vencimiento
    )
    SELECT * FROM filtrado ORDER BY FechaActualizacionUtc DESC, DocumentoId DESC
    OFFSET (@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_Summary @FechaNegocio DATE, @DiasAviso INT=30 AS
BEGIN
    SET NOCOUNT ON;
    SELECT
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento>@FechaNegocio AND DATEDIFF(DAY,@FechaNegocio,FechaVencimiento)>@DiasAviso THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento>=@FechaNegocio AND DATEDIFF(DAY,@FechaNegocio,FechaVencimiento)<=@DiasAviso THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento<@FechaNegocio THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=1 THEN 1 ELSE 0 END),0)
    FROM dbo.DocumentosDigitales WHERE Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_GetById @DocumentoId INT, @FechaNegocio DATE, @DiasAviso INT=30 AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DocumentoId,t.Nombre TipoDocumento,dep.Nombre Departamento,d.Titulo,d.NumeroReferencia,d.FechaEmision,d.FechaVencimiento,d.NoVence,d.Estado,d.Activo,
           v.Version,d.FechaActualizacionUtc,
           CASE WHEN d.NoVence=1 THEN N'No vence' WHEN d.FechaVencimiento<@FechaNegocio THEN N'Vencido' WHEN DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)<=@DiasAviso THEN N'Por vencer' ELSE N'Vigente' END EstadoVencimiento,
           CASE WHEN d.NoVence=1 THEN NULL ELSE DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento) END DiasRestantes,
           d.Descripcion,v.NombreOriginal,v.MimeType,v.TamanoBytes,v.HashSha256,d.CreadoPorNombre,d.FechaCreacionUtc
    FROM dbo.DocumentosDigitales d INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId
    LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
    INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId
    WHERE d.DocumentoId=@DocumentoId;
    SELECT DocumentoVersionId,Version,NombreOriginal,MimeType,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre,FechaCreacionUtc
    FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId ORDER BY Version DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_GetForEdit @DocumentoId INT AS
BEGIN SET NOCOUNT ON; SELECT DocumentoId,TipoDocumentoId,DepartamentoId,Titulo,Descripcion,NumeroReferencia,FechaEmision,FechaVencimiento,NoVence,Estado FROM dbo.DocumentosDigitales WHERE DocumentoId=@DocumentoId; END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_Create
    @TipoDocumentoId INT,@DepartamentoId INT=NULL,@Titulo NVARCHAR(180),@Descripcion NVARCHAR(1000)=NULL,@NumeroReferencia NVARCHAR(100)=NULL,
    @FechaEmision DATE=NULL,@FechaVencimiento DATE=NULL,@NoVence BIT,@Estado NVARCHAR(30),@NombreOriginal NVARCHAR(255),@StorageKey NVARCHAR(80),
    @MimeType NVARCHAR(100),@Extension NVARCHAR(10),@TamanoBytes BIGINT,@HashSha256 CHAR(64),@UsuarioId INT,@UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Estado NOT IN (N'Vigente',N'Suspendido',N'Archivado') THROW 54000,N'Estado documental inválido.',1;
    IF (@NoVence=0 AND @FechaVencimiento IS NULL) OR (@NoVence=1 AND @FechaVencimiento IS NOT NULL) THROW 54001,N'Vencimiento documental inconsistente.',1;
    IF NULLIF(LTRIM(RTRIM(@Titulo)),N'') IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TiposDocumento WHERE TipoDocumentoId=@TipoDocumentoId AND Activo=1) THROW 54008,N'Título o tipo documental inválido.',1;
    IF @DepartamentoId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.DepartamentosOperativos WHERE DepartamentoId=@DepartamentoId AND Activo=1) THROW 54009,N'El departamento no está activo.',1;
    BEGIN TRANSACTION;
    INSERT dbo.DocumentosDigitales(TipoDocumentoId,DepartamentoId,ResponsableUsuarioId,Titulo,Descripcion,NumeroReferencia,FechaEmision,FechaVencimiento,NoVence,Estado,CreadoPorUsuarioId,CreadoPorNombre,ActualizadoPorUsuarioId,ActualizadoPorNombre)
    VALUES(@TipoDocumentoId,@DepartamentoId,@UsuarioId,LTRIM(RTRIM(@Titulo)),NULLIF(LTRIM(RTRIM(@Descripcion)),N''),NULLIF(LTRIM(RTRIM(@NumeroReferencia)),N''),@FechaEmision,@FechaVencimiento,@NoVence,@Estado,@UsuarioId,@UsuarioNombre,@UsuarioId,@UsuarioNombre);
    DECLARE @DocumentoId INT=CONVERT(INT,SCOPE_IDENTITY());
    INSERT dbo.DocumentoVersiones(DocumentoId,Version,NombreOriginal,StorageKey,MimeType,Extension,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre)
    VALUES(@DocumentoId,1,@NombreOriginal,@StorageKey,@MimeType,@Extension,@TamanoBytes,@HashSha256,N'Pending',@UsuarioId,@UsuarioNombre);
    UPDATE dbo.DocumentosDigitales SET VersionActualId=CONVERT(INT,SCOPE_IDENTITY()) WHERE DocumentoId=@DocumentoId;
    COMMIT; SELECT @DocumentoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_MarkReady @DocumentoId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    UPDATE v SET StorageStatus=N'Ready' FROM dbo.DocumentoVersiones v INNER JOIN dbo.DocumentosDigitales d ON d.VersionActualId=v.DocumentoVersionId
    WHERE d.DocumentoId=@DocumentoId AND v.StorageStatus=N'Pending' AND v.CreadoPorUsuarioId=@UsuarioId;
    IF @@ROWCOUNT<>1 THROW 54002,N'No existe una carga documental pendiente autorizada.',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N'Crear',@UsuarioId,@UsuarioNombre,N'Archivo validado y confirmado en almacenamiento privado.');
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_DeletePending @DocumentoId INT,@UsuarioId INT AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.DocumentosDigitales d INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId WHERE d.DocumentoId=@DocumentoId AND d.CreadoPorUsuarioId=@UsuarioId AND v.StorageStatus=N'Pending')
    BEGIN UPDATE dbo.DocumentosDigitales SET VersionActualId=NULL WHERE DocumentoId=@DocumentoId; DELETE dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId; DELETE dbo.DocumentosDigitales WHERE DocumentoId=@DocumentoId; END;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_Update
    @DocumentoId INT,@TipoDocumentoId INT,@DepartamentoId INT=NULL,@Titulo NVARCHAR(180),@Descripcion NVARCHAR(1000)=NULL,@NumeroReferencia NVARCHAR(100)=NULL,
    @FechaEmision DATE=NULL,@FechaVencimiento DATE=NULL,@NoVence BIT,@Estado NVARCHAR(30),@UsuarioId INT,@UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Estado NOT IN (N'Vigente',N'Suspendido',N'Archivado') THROW 54003,N'Estado documental inválido.',1;
    UPDATE dbo.DocumentosDigitales SET TipoDocumentoId=@TipoDocumentoId,DepartamentoId=@DepartamentoId,Titulo=LTRIM(RTRIM(@Titulo)),Descripcion=NULLIF(LTRIM(RTRIM(@Descripcion)),N''),
      NumeroReferencia=NULLIF(LTRIM(RTRIM(@NumeroReferencia)),N''),FechaEmision=@FechaEmision,FechaVencimiento=CASE WHEN @NoVence=1 THEN NULL ELSE @FechaVencimiento END,
      NoVence=@NoVence,Estado=@Estado,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    IF @@ROWCOUNT<>1 THROW 54004,N'El documento no existe.',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N'Editar metadatos',@UsuarioId,@UsuarioNombre,NULL);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_ReplaceFile
    @DocumentoId INT,@NombreOriginal NVARCHAR(255),@StorageKey NVARCHAR(80),@MimeType NVARCHAR(100),@Extension NVARCHAR(10),@TamanoBytes BIGINT,@HashSha256 CHAR(64),@UsuarioId INT,@UsuarioNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; BEGIN TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND Activo=1) THROW 54005,N'El documento no está activo.',1;
    IF EXISTS(SELECT 1 FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId AND HashSha256=@HashSha256) THROW 54010,N'El mismo contenido ya existe en el historial del documento.',1;
    DECLARE @Version INT=ISNULL((SELECT MAX(Version) FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId),0)+1;
    INSERT dbo.DocumentoVersiones(DocumentoId,Version,NombreOriginal,StorageKey,MimeType,Extension,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre)
    VALUES(@DocumentoId,@Version,@NombreOriginal,@StorageKey,@MimeType,@Extension,@TamanoBytes,@HashSha256,N'Pending',@UsuarioId,@UsuarioNombre);
    DECLARE @VersionId INT=CONVERT(INT,SCOPE_IDENTITY()); COMMIT; SELECT @VersionId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_MarkVersionReady @DocumentoId INT,@DocumentoVersionId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    UPDATE dbo.DocumentoVersiones SET StorageStatus=N'Ready' WHERE DocumentoVersionId=@DocumentoVersionId AND DocumentoId=@DocumentoId AND StorageStatus=N'Pending' AND CreadoPorUsuarioId=@UsuarioId;
    IF @@ROWCOUNT<>1 THROW 54006,N'No existe una versión pendiente autorizada.',1;
    UPDATE dbo.DocumentosDigitales SET VersionActualId=@DocumentoVersionId,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N'Reemplazar archivo',@UsuarioId,@UsuarioNombre,CONCAT(N'Versión ',@DocumentoVersionId,N' confirmada.'));
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_DeletePendingVersion @DocumentoId INT,@DocumentoVersionId INT,@UsuarioId INT AS
BEGIN SET NOCOUNT ON; DELETE dbo.DocumentoVersiones WHERE DocumentoVersionId=@DocumentoVersionId AND DocumentoId=@DocumentoId AND StorageStatus=N'Pending' AND CreadoPorUsuarioId=@UsuarioId; END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_SetStatus @DocumentoId INT,@Activo BIT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
    SET NOCOUNT ON; UPDATE dbo.DocumentosDigitales SET Activo=@Activo,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    IF @@ROWCOUNT<>1 THROW 54007,N'El documento no existe.',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,CASE WHEN @Activo=1 THEN N'Reactivar' ELSE N'Desactivar' END,@UsuarioId,@UsuarioNombre,N'Borrado lógico; historial conservado.');
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Document_GetFileMetadata @DocumentoId INT,@DocumentoVersionId INT=NULL,@UsuarioId INT,@PuedeAdministrar BIT=0 AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.DocumentoVersionId,v.StorageKey,v.NombreOriginal,v.MimeType FROM dbo.DocumentosDigitales d INNER JOIN dbo.DocumentoVersiones v
      ON v.DocumentoId=d.DocumentoId AND v.DocumentoVersionId=COALESCE(@DocumentoVersionId,d.VersionActualId)
    WHERE d.DocumentoId=@DocumentoId AND v.StorageStatus=N'Ready' AND (@PuedeAdministrar=1 OR d.Activo=1);
END;
GO

IF OBJECT_ID(N'dbo.DocumentosDigitales',N'U') IS NULL OR OBJECT_ID(N'dbo.DocumentoVersiones',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_Document_Create',N'P') IS NULL OR OBJECT_ID(N'dbo.sp_Document_GetFileMetadata',N'P') IS NULL THROW 54090,N'Validación posterior 0007 fallida.',1;
GO
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0007_secure_document_management')
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)VALUES(N'0007_secure_document_management',N'0007_secure_document_management.sql',CONVERT(CHAR(64),HASHBYTES('SHA2_256',N'0007_secure_document_management_v1'),2),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-201: archivos privados versionados, hash SHA-256, borrado lógico y auditoría.');
GO
