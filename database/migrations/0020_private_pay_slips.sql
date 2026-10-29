SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 55300,N'Falta el ledger 0001.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0019_payroll_engine' AND Status=N'Applied') THROW 55301,N'Falta aplicar 0019.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0020_private_pay_slips' AND Status=N'Applied') THROW 55302,N'0020 ya figura aplicada.',1;
BEGIN TRANSACTION;

CREATE TABLE dbo.PlanillaBoletaEnvios
(
    EnvioId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaBoletaEnvios PRIMARY KEY,
    CalculoId BIGINT NOT NULL,
    Destinatario NVARCHAR(320) NOT NULL,
    Estado NVARCHAR(20) NOT NULL,
    CodigoError NVARCHAR(100) NULL,
    IdempotencyKey UNIQUEIDENTIFIER NOT NULL,
    Intentos INT NOT NULL CONSTRAINT DF_PlanillaBoletaEnvios_Intentos DEFAULT 1,
    ActorUsuarioId INT NOT NULL,
    ActorNombre NVARCHAR(150) NOT NULL,
    FechaPreparacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PlanillaBoletaEnvios_Preparacion DEFAULT SYSUTCDATETIME(),
    FechaResultadoUtc DATETIME2(0) NULL,
    VersionFila ROWVERSION NOT NULL,
    CONSTRAINT FK_PlanillaBoletaEnvios_Calculo FOREIGN KEY(CalculoId) REFERENCES dbo.PlanillaCalculos(CalculoId),
    CONSTRAINT UQ_PlanillaBoletaEnvios_Token UNIQUE(IdempotencyKey),
    CONSTRAINT CK_PlanillaBoletaEnvios_Estado CHECK(Estado IN(N'Pendiente',N'Exitoso',N'Fallido')),
    CONSTRAINT CK_PlanillaBoletaEnvios_Intentos CHECK(Intentos>0),
    CONSTRAINT CK_PlanillaBoletaEnvios_Destinatario CHECK(LEN(LTRIM(RTRIM(Destinatario)))>3)
);
CREATE INDEX IX_PlanillaBoletaEnvios_Calculo ON dbo.PlanillaBoletaEnvios(CalculoId,FechaPreparacionUtc DESC);

DECLARE @Codigo NVARCHAR(100)=N'PLANILLA_BOLETAS_GESTIONAR';
UPDATE dbo.Permisos SET Modulo=N'Planilla',Nombre=N'Gestionar boletas de pago',Descripcion=N'Permite consultar boletas y notificar al correo registrado mediante enlace privado.',Activo=1 WHERE Codigo=@Codigo;
IF NOT EXISTS(SELECT 1 FROM dbo.Permisos WITH(UPDLOCK,HOLDLOCK) WHERE Codigo=@Codigo)
 INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo) VALUES(@Codigo,N'Planilla',N'Gestionar boletas de pago',N'Permite consultar boletas y notificar al correo registrado mediante enlace privado.',1);
INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0020 boletas' FROM dbo.Perfiles profile JOIN dbo.Permisos permission ON permission.Codigo=@Codigo
WHERE profile.Nombre=N'Administrador' AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=profile.PerfilId AND x.PermisoId=permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_PaySlip_Listar @UsuarioId INT,@IncluirTodas BIT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT c.CalculoId,CONCAT(CONVERT(NVARCHAR(10),p.Desde,23),N' — ',CONVERT(NVARCHAR(10),p.Hasta,23)),u.NombreCompleto,c.TotalBruto,c.TotalDeducciones,c.TotalNeto,c.Estado,
        (SELECT TOP(1) envio.Estado FROM dbo.PlanillaBoletaEnvios envio WHERE envio.CalculoId=c.CalculoId ORDER BY envio.FechaPreparacionUtc DESC,envio.EnvioId DESC)
 FROM dbo.PlanillaCalculos c JOIN dbo.PlanillaPeriodos p ON p.PeriodoId=c.PeriodoId JOIN dbo.Empleados e ON e.EmpleadoId=c.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId
 WHERE c.Estado IN(N'Pagada',N'Revertida') AND (@IncluirTodas=1 OR e.UsuarioId=@UsuarioId) ORDER BY p.Hasta DESC,u.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_PaySlip_Obtener @CalculoId BIGINT,@UsuarioId INT,@PuedeGestionar BIT
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PlanillaCalculos c JOIN dbo.Empleados e ON e.EmpleadoId=c.EmpleadoId WHERE c.CalculoId=@CalculoId AND c.Estado IN(N'Pagada',N'Revertida') AND (@PuedeGestionar=1 OR e.UsuarioId=@UsuarioId)) RETURN;
 SELECT c.CalculoId,u.UsuarioId,u.NombreCompleto,CONCAT(CONVERT(NVARCHAR(10),p.Desde,23),N' — ',CONVERT(NVARCHAR(10),p.Hasta,23)),c.SalarioBase,c.HorasOrdinarias,c.HorasExtra,c.Comisiones,c.TotalBruto,c.TotalDeducciones,c.TotalNeto,c.Estado,c.FechaPagoUtc
 FROM dbo.PlanillaCalculos c JOIN dbo.PlanillaPeriodos p ON p.PeriodoId=c.PeriodoId JOIN dbo.Empleados e ON e.EmpleadoId=c.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId WHERE c.CalculoId=@CalculoId;
 SELECT Codigo,Nombre,Tipo,Monto FROM dbo.PlanillaDetalle WHERE CalculoId=@CalculoId ORDER BY Tipo,Codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_PaySlip_PrepararEnvio @CalculoId BIGINT,@IdempotencyKey UNIQUEIDENTIFIER,@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Destinatario NVARCHAR(320),@Empleado NVARCHAR(150),@EnvioId BIGINT,@Estado NVARCHAR(20),@DebeEnviar BIT=0;
 SELECT @Destinatario=u.Correo,@Empleado=u.NombreCompleto FROM dbo.PlanillaCalculos c JOIN dbo.Empleados e ON e.EmpleadoId=c.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId WHERE c.CalculoId=@CalculoId AND c.Estado=N'Pagada' AND u.Activo=1;
 IF @Destinatario IS NULL OR LEN(LTRIM(RTRIM(@Destinatario)))<4 THROW 55310,N'La boleta no está pagada o el destinatario no es válido.',1;
 SELECT @EnvioId=EnvioId,@Estado=Estado FROM dbo.PlanillaBoletaEnvios WITH(UPDLOCK,HOLDLOCK) WHERE IdempotencyKey=@IdempotencyKey;
 IF @EnvioId IS NOT NULL
 BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.PlanillaBoletaEnvios WHERE EnvioId=@EnvioId AND CalculoId=@CalculoId AND Destinatario=@Destinatario) THROW 55311,N'Token reutilizado para otra boleta.',1;
   IF @Estado=N'Fallido' BEGIN UPDATE dbo.PlanillaBoletaEnvios SET Estado=N'Pendiente',CodigoError=NULL,Intentos=Intentos+1,FechaPreparacionUtc=SYSUTCDATETIME(),FechaResultadoUtc=NULL WHERE EnvioId=@EnvioId; SET @DebeEnviar=1; END;
 END
 ELSE
 BEGIN
   INSERT dbo.PlanillaBoletaEnvios(CalculoId,Destinatario,Estado,IdempotencyKey,ActorUsuarioId,ActorNombre) VALUES(@CalculoId,@Destinatario,N'Pendiente',@IdempotencyKey,@ActorUsuarioId,@ActorNombre);
   SET @EnvioId=SCOPE_IDENTITY(); SET @DebeEnviar=1;
   INSERT dbo.PlanillaAuditoria(CalculoId,Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(@CalculoId,N'BoletaEnvio',@EnvioId,N'PREPARAR_ENVIO',N'Notificación privada preparada; contenido sensible no incluido en correo.',@ActorUsuarioId,@ActorNombre);
 END;
 COMMIT TRANSACTION; SELECT @EnvioId,@Destinatario,@Empleado,@DebeEnviar;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_PaySlip_CompletarEnvio @EnvioId BIGINT,@Exitoso BIT,@CodigoError NVARCHAR(100)=NULL,@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY BEGIN TRANSACTION;
 DECLARE @CalculoId BIGINT=(SELECT CalculoId FROM dbo.PlanillaBoletaEnvios WITH(UPDLOCK,HOLDLOCK) WHERE EnvioId=@EnvioId AND Estado=N'Pendiente' AND ActorUsuarioId=@ActorUsuarioId);
 IF @CalculoId IS NULL THROW 55320,N'El envío no existe, ya fue resuelto o pertenece a otro actor.',1;
 UPDATE dbo.PlanillaBoletaEnvios SET Estado=CASE WHEN @Exitoso=1 THEN N'Exitoso' ELSE N'Fallido' END,CodigoError=CASE WHEN @Exitoso=1 THEN NULL ELSE LEFT(COALESCE(NULLIF(@CodigoError,N''),N'UNSPECIFIED'),100) END,FechaResultadoUtc=SYSUTCDATETIME() WHERE EnvioId=@EnvioId;
 INSERT dbo.PlanillaAuditoria(CalculoId,Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(@CalculoId,N'BoletaEnvio',@EnvioId,CASE WHEN @Exitoso=1 THEN N'ENVIO_EXITOSO' ELSE N'ENVIO_FALLIDO' END,CASE WHEN @Exitoso=1 THEN N'Entrega SMTP confirmada.' ELSE LEFT(COALESCE(NULLIF(@CodigoError,N''),N'UNSPECIFIED'),100) END,@ActorUsuarioId,@ActorNombre);
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

IF XACT_STATE()<>1 THROW 55303,N'La transacción 0020 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)'; IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55304,N'SHA-256 inválido para 0020.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes) VALUES(N'0020_private_pay_slips',N'0020_private_pay_slips.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-114: boleta derivada del snapshot, autorización por propietario, enlace HTTPS e idempotencia de correo.');
COMMIT TRANSACTION;
