SET NOCOUNT ON;SET XACT_ABORT ON;
IF SESSIONPROPERTY('QUOTED_IDENTIFIER')<>1 OR SESSIONPROPERTY('ANSI_NULLS')<>1 THROW 57410,N'Opciones SQL no acreditadas.',1;
DECLARE @Hash nvarchar(128)=N'$(MigrationSha256)';
IF LEN(@Hash)<>64 OR @Hash LIKE N'%[^0-9a-fA-F]%' THROW 57411,N'Hash no valido.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0040_stage2_document_ownership')
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0040_stage2_document_ownership' AND Status=N'Applied' AND FileSha256=UPPER(@Hash)) THROW 57412,N'Conflicto de ledger 0040.',1;
 RETURN;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0038_stage2_checkout_intent_owner' AND Status=N'Applied' AND FileSha256=N'B3FF29FF1DA8D05FA29DA944E1FDA688670B48D49A389CC462F7BF24DCF6C8BD') THROW 57413,N'Falta prerequisito acreditado.',1;
IF OBJECT_ID(N'dbo.DocumentosDigitales',N'U') IS NULL OR COL_LENGTH(N'dbo.DocumentosDigitales',N'ResponsableUsuarioId') IS NULL THROW 57414,N'Fuente de ownership ausente.',1;
IF EXISTS(SELECT 1 FROM sys.procedures WHERE name LIKE N'sp[_]Stage2[_]Document%') THROW 57415,N'Objetos anteriores no acreditados.',1;
BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'Stage2:0040:install',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 57416,N'Instalacion concurrente.',1;
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_GetOptions @Actor int AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;

    SET NOCOUNT ON;
    SELECT TipoDocumentoId, Nombre FROM dbo.TiposDocumento WHERE Activo=1 ORDER BY Nombre;
    SELECT DepartamentoId, Nombre FROM dbo.DepartamentosOperativos WHERE Activo=1 AND DepartamentoId IN(SELECT DepartamentoId FROM dbo.DocumentosDigitales WITH(HOLDLOCK) WHERE ResponsableUsuarioId=@Actor) ORDER BY Nombre;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_List @Actor int ,@Busqueda NVARCHAR(180)=NULL, @TipoDocumentoId INT=NULL, @DepartamentoId INT=NULL,
    @Estado NVARCHAR(30)=NULL, @Vencimiento NVARCHAR(30)=NULL, @FechaNegocio DATE,
    @DiasAviso INT=30, @Pagina INT=1, @TamanoPagina INT=20 AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;

    SET NOCOUNT ON;
    SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END;
    SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
    ;WITH base AS
    (
        SELECT d.DocumentoId, t.Nombre TipoDocumento, dep.Nombre Departamento, d.Titulo, d.NumeroReferencia,
               d.FechaEmision, d.FechaVencimiento, d.NoVence, d.Estado, d.Activo, v.Version, d.FechaActualizacionUtc,
               CASE WHEN d.NoVence=1 THEN N''No vence'' WHEN d.FechaVencimiento<@FechaNegocio THEN N''Vencido''
                    WHEN DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)<=@DiasAviso THEN N''Por vencer'' ELSE N''Vigente'' END EstadoVencimiento,
               CASE WHEN d.NoVence=1 THEN NULL ELSE DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento) END DiasRestantes
        FROM dbo.DocumentosDigitales d WITH(HOLDLOCK)
        INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId
        LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
        INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId AND v.StorageStatus=N''Ready''
        WHERE d.ResponsableUsuarioId=@Actor AND (@Busqueda IS NULL OR d.Titulo LIKE N''%''+@Busqueda+N''%'' OR d.NumeroReferencia LIKE N''%''+@Busqueda+N''%'')
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
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_Summary @Actor int ,@FechaNegocio DATE, @DiasAviso INT=30 AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;

    SET NOCOUNT ON;
    SELECT
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento>@FechaNegocio AND DATEDIFF(DAY,@FechaNegocio,FechaVencimiento)>@DiasAviso THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento>=@FechaNegocio AND DATEDIFF(DAY,@FechaNegocio,FechaVencimiento)<=@DiasAviso THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=0 AND FechaVencimiento<@FechaNegocio THEN 1 ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN NoVence=1 THEN 1 ELSE 0 END),0)
    FROM dbo.DocumentosDigitales WITH(HOLDLOCK) WHERE Activo=1 AND ResponsableUsuarioId=@Actor;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_GetById @Actor int ,@DocumentoId INT, @FechaNegocio DATE, @DiasAviso INT=30 AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON;
    SELECT d.DocumentoId,t.Nombre TipoDocumento,dep.Nombre Departamento,d.Titulo,d.NumeroReferencia,d.FechaEmision,d.FechaVencimiento,d.NoVence,d.Estado,d.Activo,
           v.Version,d.FechaActualizacionUtc,
           CASE WHEN d.NoVence=1 THEN N''No vence'' WHEN d.FechaVencimiento<@FechaNegocio THEN N''Vencido'' WHEN DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)<=@DiasAviso THEN N''Por vencer'' ELSE N''Vigente'' END EstadoVencimiento,
           CASE WHEN d.NoVence=1 THEN NULL ELSE DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento) END DiasRestantes,
           d.Descripcion,v.NombreOriginal,v.MimeType,v.TamanoBytes,v.HashSha256,d.CreadoPorNombre,d.FechaCreacionUtc
    FROM dbo.DocumentosDigitales d INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId
    LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
    INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId
    WHERE d.DocumentoId=@DocumentoId;
    SELECT DocumentoVersionId,Version,NombreOriginal,MimeType,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre,FechaCreacionUtc
    FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId ORDER BY Version DESC;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_GetForEdit @Actor int ,@DocumentoId INT AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;
 SET NOCOUNT ON; SELECT DocumentoId,TipoDocumentoId,DepartamentoId,Titulo,Descripcion,NumeroReferencia,FechaEmision,FechaVencimiento,NoVence,Estado FROM dbo.DocumentosDigitales WITH(HOLDLOCK) WHERE DocumentoId=@DocumentoId; END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_Create @Actor int ,@TipoDocumentoId INT,@DepartamentoId INT=NULL,@Titulo NVARCHAR(180),@Descripcion NVARCHAR(1000)=NULL,@NumeroReferencia NVARCHAR(100)=NULL,
    @FechaEmision DATE=NULL,@FechaVencimiento DATE=NULL,@NoVence BIT,@Estado NVARCHAR(30),@NombreOriginal NVARCHAR(255),@StorageKey NVARCHAR(80),
    @MimeType NVARCHAR(100),@Extension NVARCHAR(10),@TamanoBytes BIGINT,@HashSha256 CHAR(64),@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF @DepartamentoId IS NOT NULL THROW 57402,N''Autorizacion departamental no acreditada.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Estado NOT IN (N''Vigente'',N''Suspendido'',N''Archivado'') THROW 54000,N''Estado documental inválido.'',1;
    IF (@NoVence=0 AND @FechaVencimiento IS NULL) OR (@NoVence=1 AND @FechaVencimiento IS NOT NULL) THROW 54001,N''Vencimiento documental inconsistente.'',1;
    IF NULLIF(LTRIM(RTRIM(@Titulo)),N'''') IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TiposDocumento WHERE TipoDocumentoId=@TipoDocumentoId AND Activo=1) THROW 54008,N''Título o tipo documental inválido.'',1;
    IF @DepartamentoId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.DepartamentosOperativos WHERE DepartamentoId=@DepartamentoId AND Activo=1) THROW 54009,N''El departamento no está activo.'',1;
    BEGIN TRANSACTION;
    INSERT dbo.DocumentosDigitales(TipoDocumentoId,DepartamentoId,ResponsableUsuarioId,Titulo,Descripcion,NumeroReferencia,FechaEmision,FechaVencimiento,NoVence,Estado,CreadoPorUsuarioId,CreadoPorNombre,ActualizadoPorUsuarioId,ActualizadoPorNombre)
    VALUES(@TipoDocumentoId,@DepartamentoId,@UsuarioId,LTRIM(RTRIM(@Titulo)),NULLIF(LTRIM(RTRIM(@Descripcion)),N''''),NULLIF(LTRIM(RTRIM(@NumeroReferencia)),N''''),@FechaEmision,@FechaVencimiento,@NoVence,@Estado,@UsuarioId,@UsuarioNombre,@UsuarioId,@UsuarioNombre);
    DECLARE @DocumentoId INT=CONVERT(INT,SCOPE_IDENTITY());
    INSERT dbo.DocumentoVersiones(DocumentoId,Version,NombreOriginal,StorageKey,MimeType,Extension,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre)
    VALUES(@DocumentoId,1,@NombreOriginal,@StorageKey,@MimeType,@Extension,@TamanoBytes,@HashSha256,N''Pending'',@UsuarioId,@UsuarioNombre);
    UPDATE dbo.DocumentosDigitales SET VersionActualId=CONVERT(INT,SCOPE_IDENTITY()) WHERE DocumentoId=@DocumentoId;
    COMMIT; SELECT @DocumentoId;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_MarkReady @Actor int ,@DocumentoId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    UPDATE v SET StorageStatus=N''Ready'' FROM dbo.DocumentoVersiones v INNER JOIN dbo.DocumentosDigitales d ON d.VersionActualId=v.DocumentoVersionId
    WHERE d.DocumentoId=@DocumentoId AND v.StorageStatus=N''Pending'' AND v.CreadoPorUsuarioId=@UsuarioId;
    IF @@ROWCOUNT<>1 THROW 54002,N''No existe una carga documental pendiente autorizada.'',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N''Crear'',@UsuarioId,@UsuarioNombre,N''Archivo validado y confirmado en almacenamiento privado.'');
    COMMIT;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_DeletePending @Actor int ,@DocumentoId INT,@UsuarioId INT AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.DocumentosDigitales d INNER JOIN dbo.DocumentoVersiones v ON v.DocumentoVersionId=d.VersionActualId WHERE d.DocumentoId=@DocumentoId AND d.CreadoPorUsuarioId=@UsuarioId AND v.StorageStatus=N''Pending'')
    BEGIN UPDATE dbo.DocumentosDigitales SET VersionActualId=NULL WHERE DocumentoId=@DocumentoId; DELETE dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId; DELETE dbo.DocumentosDigitales WHERE DocumentoId=@DocumentoId; END;
    COMMIT;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_Update @Actor int ,@DocumentoId INT,@TipoDocumentoId INT,@DepartamentoId INT=NULL,@Titulo NVARCHAR(180),@Descripcion NVARCHAR(1000)=NULL,@NumeroReferencia NVARCHAR(100)=NULL,
    @FechaEmision DATE=NULL,@FechaVencimiento DATE=NULL,@NoVence BIT,@Estado NVARCHAR(30),@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ISNULL(DepartamentoId,-1)=ISNULL(@DepartamentoId,-1)) THROW 57402,N''Cambio de departamento no acreditado.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Estado NOT IN (N''Vigente'',N''Suspendido'',N''Archivado'') THROW 54003,N''Estado documental inválido.'',1;
    UPDATE dbo.DocumentosDigitales SET TipoDocumentoId=@TipoDocumentoId,DepartamentoId=@DepartamentoId,Titulo=LTRIM(RTRIM(@Titulo)),Descripcion=NULLIF(LTRIM(RTRIM(@Descripcion)),N''''),
      NumeroReferencia=NULLIF(LTRIM(RTRIM(@NumeroReferencia)),N''''),FechaEmision=@FechaEmision,FechaVencimiento=CASE WHEN @NoVence=1 THEN NULL ELSE @FechaVencimiento END,
      NoVence=@NoVence,Estado=@Estado,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    IF @@ROWCOUNT<>1 THROW 54004,N''El documento no existe.'',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N''Editar metadatos'',@UsuarioId,@UsuarioNombre,NULL);
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_ReplaceFile @Actor int ,@DocumentoId INT,@NombreOriginal NVARCHAR(255),@StorageKey NVARCHAR(80),@MimeType NVARCHAR(100),@Extension NVARCHAR(10),@TamanoBytes BIGINT,@HashSha256 CHAR(64),@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; BEGIN TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND Activo=1) THROW 54005,N''El documento no está activo.'',1;
    IF EXISTS(SELECT 1 FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId AND HashSha256=@HashSha256) THROW 54010,N''El mismo contenido ya existe en el historial del documento.'',1;
    DECLARE @Version INT=ISNULL((SELECT MAX(Version) FROM dbo.DocumentoVersiones WHERE DocumentoId=@DocumentoId),0)+1;
    INSERT dbo.DocumentoVersiones(DocumentoId,Version,NombreOriginal,StorageKey,MimeType,Extension,TamanoBytes,HashSha256,StorageStatus,CreadoPorUsuarioId,CreadoPorNombre)
    VALUES(@DocumentoId,@Version,@NombreOriginal,@StorageKey,@MimeType,@Extension,@TamanoBytes,@HashSha256,N''Pending'',@UsuarioId,@UsuarioNombre);
    DECLARE @VersionId INT=CONVERT(INT,SCOPE_IDENTITY()); COMMIT; SELECT @VersionId;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_MarkVersionReady @Actor int ,@DocumentoId INT,@DocumentoVersionId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
    UPDATE dbo.DocumentoVersiones SET StorageStatus=N''Ready'' WHERE DocumentoVersionId=@DocumentoVersionId AND DocumentoId=@DocumentoId AND StorageStatus=N''Pending'' AND CreadoPorUsuarioId=@UsuarioId;
    IF @@ROWCOUNT<>1 THROW 54006,N''No existe una versión pendiente autorizada.'',1;
    UPDATE dbo.DocumentosDigitales SET VersionActualId=@DocumentoVersionId,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,N''Reemplazar archivo'',@UsuarioId,@UsuarioNombre,CONCAT(N''Versión '',@DocumentoVersionId,N'' confirmada.''));
    COMMIT;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_DeletePendingVersion @Actor int ,@DocumentoId INT,@DocumentoVersionId INT,@UsuarioId INT AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;
 SET NOCOUNT ON; DELETE dbo.DocumentoVersiones WHERE DocumentoVersionId=@DocumentoVersionId AND DocumentoId=@DocumentoId AND StorageStatus=N''Pending'' AND CreadoPorUsuarioId=@UsuarioId; END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_SetStatus @Actor int ,@DocumentoId INT,@Activo BIT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
SELECT @UsuarioNombre=NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; UPDATE dbo.DocumentosDigitales SET Activo=@Activo,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE DocumentoId=@DocumentoId;
    IF @@ROWCOUNT<>1 THROW 54007,N''El documento no existe.'',1;
    INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) VALUES(@DocumentoId,CASE WHEN @Activo=1 THEN N''Reactivar'' ELSE N''Desactivar'' END,@UsuarioId,@UsuarioNombre,N''Borrado lógico; historial conservado.'');
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_Document_GetFileMetadata @Actor int ,@DocumentoId INT,@DocumentoVersionId INT=NULL,@UsuarioId INT,@PuedeAdministrar BIT=0 AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.DocumentosDigitales WITH(UPDLOCK,HOLDLOCK) WHERE DocumentoId=@DocumentoId AND ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON;
    SELECT v.DocumentoVersionId,v.StorageKey,v.NombreOriginal,v.MimeType FROM dbo.DocumentosDigitales d INNER JOIN dbo.DocumentoVersiones v
      ON v.DocumentoId=d.DocumentoId AND v.DocumentoVersionId=COALESCE(@DocumentoVersionId,d.VersionActualId)
    WHERE d.DocumentoId=@DocumentoId AND v.StorageStatus=N''Ready'' AND d.Activo=1;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DocumentAlert_Generate @Actor int ,@FechaNegocio DATE,@Umbrales NVARCHAR(100),@UsuarioId INT AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;

    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @t TABLE(Dias INT PRIMARY KEY);
    INSERT @t(Dias) SELECT DISTINCT TRY_CONVERT(INT,value) FROM STRING_SPLIT(@Umbrales,N'','') WHERE TRY_CONVERT(INT,value) BETWEEN 0 AND 365;
    DECLARE @nuevas TABLE(AlertaId INT,DocumentoId INT,UmbralDias INT);
    BEGIN TRANSACTION;
    INSERT dbo.AlertasDocumento(DocumentoId,FechaVencimiento,UmbralDias,GeneradaPorUsuarioId)
      OUTPUT inserted.AlertaId,inserted.DocumentoId,inserted.UmbralDias INTO @nuevas
    SELECT d.DocumentoId,d.FechaVencimiento,umbral.Dias,@UsuarioId
    FROM dbo.DocumentosDigitales d WITH(HOLDLOCK)
    CROSS APPLY(SELECT MIN(t.Dias) Dias FROM @t t WHERE t.Dias>=DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)) umbral
    WHERE d.ResponsableUsuarioId=@Actor AND d.Activo=1 AND d.NoVence=0 AND d.Estado=N''Vigente'' AND umbral.Dias IS NOT NULL
      AND NOT EXISTS(SELECT 1 FROM dbo.AlertasDocumento a WITH(UPDLOCK,HOLDLOCK) WHERE a.DocumentoId=d.DocumentoId AND a.FechaVencimiento=d.FechaVencimiento AND a.UmbralDias=umbral.Dias);
    COMMIT;
    SELECT n.AlertaId,n.DocumentoId,n.UmbralDias,d.Titulo,d.FechaVencimiento,ISNULL(u.Correo,N'''') Destinatario
    FROM @nuevas n INNER JOIN dbo.DocumentosDigitales d ON d.DocumentoId=n.DocumentoId
    LEFT JOIN dbo.Usuarios u ON u.UsuarioId=d.ResponsableUsuarioId;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DocumentAlert_List @Actor int ,@Estado NVARCHAR(30)=NULL,@DepartamentoId INT=NULL,@MaxDias INT=NULL,@FechaNegocio DATE,@Pagina INT=1,@TamanoPagina INT=20 AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;

 SET NOCOUNT ON; SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END; SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
 ;WITH q AS(
 SELECT a.AlertaId,d.DocumentoId,d.Titulo,t.Nombre TipoDocumento,dep.Nombre Departamento,u.NombreCompleto Responsable,
   a.FechaVencimiento,DATEDIFF(DAY,@FechaNegocio,a.FechaVencimiento) DiasRestantes,
   CASE WHEN a.FechaVencimiento<@FechaNegocio THEN N''Vencido'' WHEN a.FechaVencimiento=@FechaNegocio THEN N''Vence hoy'' ELSE N''Por vencer'' END EstadoVencimiento,
   a.Estado,a.FechaCreacionUtc,COUNT(*) OVER() TotalResultados
 FROM dbo.AlertasDocumento a INNER JOIN dbo.DocumentosDigitales d ON d.DocumentoId=a.DocumentoId
 INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
 INNER JOIN dbo.Usuarios u ON u.UsuarioId=d.ResponsableUsuarioId
 WHERE d.ResponsableUsuarioId=@Actor AND (@Estado IS NULL OR a.Estado=@Estado) AND (@DepartamentoId IS NULL OR d.DepartamentoId=@DepartamentoId)
   AND (@MaxDias IS NULL OR DATEDIFF(DAY,@FechaNegocio,a.FechaVencimiento)<=@MaxDias)
 ) SELECT * FROM q ORDER BY CASE Estado WHEN N''Activa'' THEN 0 ELSE 1 END,DiasRestantes,AlertaId DESC
 OFFSET (@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DocumentAlert_Summary @Actor int ,@FechaNegocio DATE AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
 SET NOCOUNT ON; SELECT COALESCE(SUM(CASE WHEN Estado=N''Activa'' THEN 1 ELSE 0 END),0),COALESCE(SUM(CASE WHEN Estado=N''Activa'' AND FechaVencimiento<@FechaNegocio THEN 1 ELSE 0 END),0) FROM dbo.AlertasDocumento WHERE DocumentoId IN(SELECT DocumentoId FROM dbo.DocumentosDigitales WITH(HOLDLOCK) WHERE ResponsableUsuarioId=@Actor); END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DocumentAlert_MarkHandled @Actor int ,@AlertaId INT,@UsuarioId INT AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF @UsuarioId<>@Actor OR @UsuarioId IS NULL THROW 57401,N''Documento no disponible.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.AlertasDocumento a WITH(UPDLOCK,HOLDLOCK) JOIN dbo.DocumentosDigitales d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentoId=a.DocumentoId WHERE a.AlertaId=@AlertaId AND d.ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;
 SET NOCOUNT ON; UPDATE dbo.AlertasDocumento SET Estado=N''Atendida'',AtendidaPorUsuarioId=@UsuarioId,FechaAtencionUtc=SYSUTCDATETIME() WHERE AlertaId=@AlertaId AND Estado=N''Activa''; IF @@ROWCOUNT=0 THROW 54100,N''La alerta no existe o ya fue atendida.'',1; INSERT dbo.DocumentoAuditoria(DocumentoId,Accion,UsuarioId,UsuarioNombre,Detalle) SELECT DocumentoId,N''Atender alerta'',@Actor,(SELECT NombreCompleto FROM dbo.Usuarios WHERE UsuarioId=@Actor),N''Alerta documental atendida.'' FROM dbo.AlertasDocumento WHERE AlertaId=@AlertaId; END;');
 EXEC(N'CREATE PROCEDURE dbo.sp_Stage2_DocumentAlert_RegisterNotification @Actor int ,@AlertaId INT,@Canal NVARCHAR(20),@Destinatario NVARCHAR(320),@EstadoEnvio NVARCHAR(20),@ErrorTecnicoResumido NVARCHAR(100)=NULL AS

BEGIN
IF @@TRANCOUNT=0 THROW 57400,N''Falta transaccion de login original.'',1;
IF NOT EXISTS(SELECT 1 FROM dbo.AlertasDocumento a WITH(UPDLOCK,HOLDLOCK) JOIN dbo.DocumentosDigitales d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentoId=a.DocumentoId WHERE a.AlertaId=@AlertaId AND d.ResponsableUsuarioId=@Actor) THROW 57401,N''Documento no disponible.'',1;

 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.NotificacionesAlertaDocumento WHERE AlertaId=@AlertaId AND Canal=@Canal)
   INSERT dbo.NotificacionesAlertaDocumento(AlertaId,Canal,Destinatario,EstadoEnvio,ErrorTecnicoResumido) VALUES(@AlertaId,@Canal,@Destinatario,@EstadoEnvio,@ErrorTecnicoResumido);
END;');
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
 VALUES(N'0040_stage2_document_ownership',N'0040_stage2_document_ownership.sql',UPPER(@Hash),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'Documents: propietario ResponsableUsuarioId; sin bypass. Delegacion departamental denegada por ausencia de fuente. Sin grants ni purgas.');
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION;THROW;END CATCH;
