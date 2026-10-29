SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-202. Rollback: retirar SP; conservar alertas/notificaciones como evidencia de auditoría. */
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.AlertasDocumento', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AlertasDocumento
    (
        AlertaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertasDocumento PRIMARY KEY,
        DocumentoId INT NOT NULL,
        FechaVencimiento DATE NOT NULL,
        UmbralDias INT NOT NULL,
        Estado NVARCHAR(20) NOT NULL CONSTRAINT DF_AlertasDocumento_Estado DEFAULT N'Activa',
        GeneradaPorUsuarioId INT NOT NULL,
        AtendidaPorUsuarioId INT NULL,
        FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_AlertasDocumento_Creacion DEFAULT SYSUTCDATETIME(),
        FechaAtencionUtc DATETIME2(0) NULL,
        CONSTRAINT FK_AlertasDocumento_Documento FOREIGN KEY (DocumentoId) REFERENCES dbo.DocumentosDigitales(DocumentoId),
        CONSTRAINT UQ_AlertasDocumento_Idempotencia UNIQUE (DocumentoId, FechaVencimiento, UmbralDias),
        CONSTRAINT CK_AlertasDocumento_Umbral CHECK (UmbralDias BETWEEN 0 AND 365),
        CONSTRAINT CK_AlertasDocumento_Estado CHECK (Estado IN (N'Activa', N'Atendida'))
    );
END;

IF OBJECT_ID(N'dbo.NotificacionesAlertaDocumento', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.NotificacionesAlertaDocumento
    (
        NotificacionId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_NotificacionesAlertaDocumento PRIMARY KEY,
        AlertaId INT NOT NULL,
        Canal NVARCHAR(20) NOT NULL,
        Destinatario NVARCHAR(320) NOT NULL,
        EstadoEnvio NVARCHAR(20) NOT NULL,
        ErrorTecnicoResumido NVARCHAR(100) NULL,
        FechaIntentoUtc DATETIME2(0) NOT NULL CONSTRAINT DF_NotificacionesAlertaDocumento_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_NotificacionesAlertaDocumento_Alerta FOREIGN KEY (AlertaId) REFERENCES dbo.AlertasDocumento(AlertaId),
        CONSTRAINT UQ_NotificacionesAlertaDocumento_Canal UNIQUE (AlertaId, Canal),
        CONSTRAINT CK_NotificacionesAlertaDocumento_Estado CHECK (EstadoEnvio IN (N'Enviado', N'Fallido'))
    );
END;

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
      (N'DOCUMENTOS_ALERTAS_GENERAR',N'Documentos',N'Generar alertas documentales',N'Ejecuta la generación idempotente de alertas.'),
      (N'DOCUMENTOS_ALERTAS_ATENDER',N'Documentos',N'Atender alertas documentales',N'Marca alertas internas como atendidas.')
    ) AS source(Codigo,Modulo,Nombre,Descripcion) ON target.Codigo=source.Codigo
    WHEN MATCHED THEN UPDATE SET Modulo=source.Modulo,Nombre=source.Nombre,Descripcion=source.Descripcion,Activo=1
    WHEN NOT MATCHED THEN INSERT(Codigo,Modulo,Nombre,Descripcion,Activo) VALUES(source.Codigo,source.Modulo,source.Nombre,source.Descripcion,1);
    IF OBJECT_ID(N'dbo.PerfilPermisos', N'U') IS NOT NULL
      INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
      SELECT p.PerfilId,pm.PermisoId,NULL,N'Migración 0008' FROM dbo.Perfiles p CROSS JOIN dbo.Permisos pm
      WHERE p.Nombre=N'Administrador' AND pm.Codigo IN(N'DOCUMENTOS_ALERTAS_GENERAR',N'DOCUMENTOS_ALERTAS_ATENDER')
        AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=p.PerfilId AND x.PermisoId=pm.PermisoId);
END;
COMMIT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocumentAlert_Generate @FechaNegocio DATE,@Umbrales NVARCHAR(100),@UsuarioId INT AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @t TABLE(Dias INT PRIMARY KEY);
    INSERT @t(Dias) SELECT DISTINCT TRY_CONVERT(INT,value) FROM STRING_SPLIT(@Umbrales,N',') WHERE TRY_CONVERT(INT,value) BETWEEN 0 AND 365;
    DECLARE @nuevas TABLE(AlertaId INT,DocumentoId INT,UmbralDias INT);
    BEGIN TRANSACTION;
    INSERT dbo.AlertasDocumento(DocumentoId,FechaVencimiento,UmbralDias,GeneradaPorUsuarioId)
      OUTPUT inserted.AlertaId,inserted.DocumentoId,inserted.UmbralDias INTO @nuevas
    SELECT d.DocumentoId,d.FechaVencimiento,umbral.Dias,@UsuarioId
    FROM dbo.DocumentosDigitales d
    CROSS APPLY(SELECT MIN(t.Dias) Dias FROM @t t WHERE t.Dias>=DATEDIFF(DAY,@FechaNegocio,d.FechaVencimiento)) umbral
    WHERE d.Activo=1 AND d.NoVence=0 AND d.Estado=N'Vigente' AND umbral.Dias IS NOT NULL
      AND NOT EXISTS(SELECT 1 FROM dbo.AlertasDocumento a WITH(UPDLOCK,HOLDLOCK) WHERE a.DocumentoId=d.DocumentoId AND a.FechaVencimiento=d.FechaVencimiento AND a.UmbralDias=umbral.Dias);
    COMMIT;
    SELECT n.AlertaId,n.DocumentoId,n.UmbralDias,d.Titulo,d.FechaVencimiento,ISNULL(u.Correo,N'') Destinatario
    FROM @nuevas n INNER JOIN dbo.DocumentosDigitales d ON d.DocumentoId=n.DocumentoId
    LEFT JOIN dbo.Usuarios u ON u.UsuarioId=d.ResponsableUsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocumentAlert_List
 @Estado NVARCHAR(30)=NULL,@DepartamentoId INT=NULL,@MaxDias INT=NULL,@FechaNegocio DATE,@Pagina INT=1,@TamanoPagina INT=20
AS
BEGIN
 SET NOCOUNT ON; SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END; SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
 ;WITH q AS(
 SELECT a.AlertaId,d.DocumentoId,d.Titulo,t.Nombre TipoDocumento,dep.Nombre Departamento,u.NombreCompleto Responsable,
   a.FechaVencimiento,DATEDIFF(DAY,@FechaNegocio,a.FechaVencimiento) DiasRestantes,
   CASE WHEN a.FechaVencimiento<@FechaNegocio THEN N'Vencido' WHEN a.FechaVencimiento=@FechaNegocio THEN N'Vence hoy' ELSE N'Por vencer' END EstadoVencimiento,
   a.Estado,a.FechaCreacionUtc,COUNT(*) OVER() TotalResultados
 FROM dbo.AlertasDocumento a INNER JOIN dbo.DocumentosDigitales d ON d.DocumentoId=a.DocumentoId
 INNER JOIN dbo.TiposDocumento t ON t.TipoDocumentoId=d.TipoDocumentoId LEFT JOIN dbo.DepartamentosOperativos dep ON dep.DepartamentoId=d.DepartamentoId
 INNER JOIN dbo.Usuarios u ON u.UsuarioId=d.ResponsableUsuarioId
 WHERE (@Estado IS NULL OR a.Estado=@Estado) AND (@DepartamentoId IS NULL OR d.DepartamentoId=@DepartamentoId)
   AND (@MaxDias IS NULL OR DATEDIFF(DAY,@FechaNegocio,a.FechaVencimiento)<=@MaxDias)
 ) SELECT * FROM q ORDER BY CASE Estado WHEN N'Activa' THEN 0 ELSE 1 END,DiasRestantes,AlertaId DESC
 OFFSET (@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocumentAlert_Summary @FechaNegocio DATE AS
BEGIN SET NOCOUNT ON; SELECT COALESCE(SUM(CASE WHEN Estado=N'Activa' THEN 1 ELSE 0 END),0),COALESCE(SUM(CASE WHEN Estado=N'Activa' AND FechaVencimiento<@FechaNegocio THEN 1 ELSE 0 END),0) FROM dbo.AlertasDocumento; END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocumentAlert_MarkHandled @AlertaId INT,@UsuarioId INT AS
BEGIN SET NOCOUNT ON; UPDATE dbo.AlertasDocumento SET Estado=N'Atendida',AtendidaPorUsuarioId=@UsuarioId,FechaAtencionUtc=SYSUTCDATETIME() WHERE AlertaId=@AlertaId AND Estado=N'Activa'; IF @@ROWCOUNT=0 THROW 54100,N'La alerta no existe o ya fue atendida.',1; END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocumentAlert_RegisterNotification @AlertaId INT,@Canal NVARCHAR(20),@Destinatario NVARCHAR(320),@EstadoEnvio NVARCHAR(20),@ErrorTecnicoResumido NVARCHAR(100)=NULL AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.NotificacionesAlertaDocumento WHERE AlertaId=@AlertaId AND Canal=@Canal)
   INSERT dbo.NotificacionesAlertaDocumento(AlertaId,Canal,Destinatario,EstadoEnvio,ErrorTecnicoResumido) VALUES(@AlertaId,@Canal,@Destinatario,@EstadoEnvio,@ErrorTecnicoResumido);
END;
GO

IF OBJECT_ID(N'dbo.AlertasDocumento',N'U') IS NULL OR OBJECT_ID(N'dbo.NotificacionesAlertaDocumento',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_DocumentAlert_Generate',N'P') IS NULL THROW 54190,N'Validación posterior 0008 fallida.',1;
GO
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0008_document_expiration_alerts')
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)VALUES(N'0008_document_expiration_alerts',N'0008_document_expiration_alerts.sql',CONVERT(CHAR(64),HASHBYTES('SHA2_256',N'0008_document_expiration_alerts_v1'),2),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-202: alertas idempotentes por documento, fecha y umbral; correo opcional.');
GO
