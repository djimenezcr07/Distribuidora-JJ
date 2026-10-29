SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 55100,N'Falta el ledger 0001.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0017_rrhh_employee_records' AND Status=N'Applied') THROW 55101,N'Falta aplicar 0017.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0018_rrhh_attendance' AND Status=N'Applied') THROW 55102,N'0018 ya figura aplicada.',1;
BEGIN TRANSACTION;

CREATE TABLE dbo.EmpleadoJornadas
(
    JornadaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmpleadoJornadas PRIMARY KEY,
    EmpleadoId INT NOT NULL,
    Fecha DATE NOT NULL,
    HorasOrdinarias DECIMAL(5,2) NOT NULL,
    HorasExtra DECIMAL(5,2) NOT NULL,
    HorasAusencia DECIMAL(5,2) NOT NULL,
    Observaciones NVARCHAR(500) NULL,
    Estado NVARCHAR(20) NOT NULL,
    IdempotencyKey UNIQUEIDENTIFIER NOT NULL,
    SupervisorUsuarioId INT NULL,
    SupervisorNombre NVARCHAR(150) NULL,
    RespuestaSupervisor NVARCHAR(500) NULL,
    FechaEnvioUtc DATETIME2(0) NULL,
    FechaDecisionUtc DATETIME2(0) NULL,
    FechaRegistroUtc DATETIME2(0) NOT NULL CONSTRAINT DF_EmpleadoJornadas_Fecha DEFAULT SYSUTCDATETIME(),
    VersionFila ROWVERSION NOT NULL,
    CONSTRAINT FK_EmpleadoJornadas_Empleado FOREIGN KEY(EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
    CONSTRAINT UQ_EmpleadoJornadas_Fecha UNIQUE(EmpleadoId,Fecha),
    CONSTRAINT UQ_EmpleadoJornadas_Token UNIQUE(IdempotencyKey),
    CONSTRAINT CK_EmpleadoJornadas_Horas CHECK(HorasOrdinarias>=0 AND HorasExtra>=0 AND HorasAusencia>=0 AND HorasOrdinarias+HorasExtra+HorasAusencia>0 AND HorasOrdinarias+HorasExtra+HorasAusencia<=24),
    CONSTRAINT CK_EmpleadoJornadas_Estado CHECK(Estado IN(N'Borrador',N'Enviada',N'Aprobada',N'Rechazada'))
);
CREATE INDEX IX_EmpleadoJornadas_EstadoFecha ON dbo.EmpleadoJornadas(Estado,Fecha DESC);

DECLARE @Permissions TABLE(Codigo NVARCHAR(100),Nombre NVARCHAR(150),Descripcion NVARCHAR(500));
INSERT @Permissions VALUES
(N'RRHH_JORNADAS_VER_PROPIAS',N'Consultar jornadas propias',N'Permite consultar únicamente las jornadas del usuario.'),
(N'RRHH_JORNADAS_REGISTRAR',N'Registrar jornadas propias',N'Permite crear, editar y enviar jornadas propias.'),
(N'RRHH_JORNADAS_APROBAR',N'Aprobar jornadas',N'Permite aprobar o rechazar jornadas enviadas con segregación.');
UPDATE p SET Modulo=N'RRHH',Nombre=r.Nombre,Descripcion=r.Descripcion,Activo=1 FROM dbo.Permisos p JOIN @Permissions r ON r.Codigo=p.Codigo;
INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo) SELECT r.Codigo,N'RRHH',r.Nombre,r.Descripcion,1 FROM @Permissions r
WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos p WITH(UPDLOCK,HOLDLOCK) WHERE p.Codigo=r.Codigo);
INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0018 jornadas' FROM dbo.Perfiles profile CROSS JOIN dbo.Permisos permission
WHERE ((profile.Nombre=N'Administrador') OR (profile.Nombre IN(N'Empleado',N'Vendedor') AND permission.Codigo IN(N'RRHH_JORNADAS_VER_PROPIAS',N'RRHH_JORNADAS_REGISTRAR')))
AND permission.Codigo IN(SELECT Codigo FROM @Permissions)
AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=profile.PerfilId AND x.PermisoId=permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_RRHH_GuardarMiJornada
 @UsuarioId INT,@JornadaId BIGINT=NULL,@Fecha DATE,@HorasOrdinarias DECIMAL(5,2),@HorasExtra DECIMAL(5,2),@HorasAusencia DECIMAL(5,2),
 @Observaciones NVARCHAR(500)=NULL,@Enviar BIT,@IdempotencyKey UNIQUEIDENTIFIER,@VersionFila BINARY(8)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @HorasOrdinarias+@HorasExtra+@HorasAusencia<=0 OR @HorasOrdinarias+@HorasExtra+@HorasAusencia>24 THROW 55110,N'Horas inválidas.',1;
 BEGIN TRY BEGIN TRANSACTION;
 DECLARE @EmpleadoId INT=(SELECT EmpleadoId FROM dbo.Empleados WITH(UPDLOCK,HOLDLOCK) WHERE UsuarioId=@UsuarioId AND Activo=1);
 IF @EmpleadoId IS NULL THROW 55111,N'No existe empleado activo para el usuario.',1;
 IF EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas WHERE IdempotencyKey=@IdempotencyKey)
 BEGIN
   IF EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas WHERE IdempotencyKey=@IdempotencyKey AND EmpleadoId=@EmpleadoId AND Fecha=@Fecha AND HorasOrdinarias=@HorasOrdinarias AND HorasExtra=@HorasExtra AND HorasAusencia=@HorasAusencia) BEGIN COMMIT TRANSACTION; RETURN; END;
   THROW 55112,N'Token reutilizado con otros datos.',1;
 END;
 IF @JornadaId IS NULL
 BEGIN
   IF EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas WHERE EmpleadoId=@EmpleadoId AND Fecha=@Fecha) THROW 55113,N'Ya existe una jornada para la fecha.',1;
   INSERT dbo.EmpleadoJornadas(EmpleadoId,Fecha,HorasOrdinarias,HorasExtra,HorasAusencia,Observaciones,Estado,IdempotencyKey,FechaEnvioUtc)
   VALUES(@EmpleadoId,@Fecha,@HorasOrdinarias,@HorasExtra,@HorasAusencia,@Observaciones,CASE WHEN @Enviar=1 THEN N'Enviada' ELSE N'Borrador' END,@IdempotencyKey,CASE WHEN @Enviar=1 THEN SYSUTCDATETIME() END);
   SET @JornadaId=SCOPE_IDENTITY();
 END ELSE
 BEGIN
   UPDATE dbo.EmpleadoJornadas SET Fecha=@Fecha,HorasOrdinarias=@HorasOrdinarias,HorasExtra=@HorasExtra,HorasAusencia=@HorasAusencia,
      Observaciones=@Observaciones,Estado=CASE WHEN @Enviar=1 THEN N'Enviada' ELSE N'Borrador' END,IdempotencyKey=@IdempotencyKey,FechaEnvioUtc=CASE WHEN @Enviar=1 THEN SYSUTCDATETIME() END
   WHERE JornadaId=@JornadaId AND EmpleadoId=@EmpleadoId AND Estado IN(N'Borrador',N'Rechazada') AND VersionFila=@VersionFila;
   IF @@ROWCOUNT<>1 THROW 55114,N'La jornada cambió o no puede editarse.',1;
 END;
 INSERT dbo.RRHHAuditoria(Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(N'Jornada',@JornadaId,CASE WHEN @Enviar=1 THEN N'ENVIAR' ELSE N'GUARDAR' END,N'Registro de horas sin aplicar reglas legales.',@UsuarioId,N'Empleado');
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RRHH_ResolverJornada @JornadaId BIGINT,@Decision NVARCHAR(20),@RespuestaSupervisor NVARCHAR(500)=NULL,@SupervisorUsuarioId INT,@SupervisorNombre NVARCHAR(150),@VersionFila BINARY(8) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Decision NOT IN(N'Aprobada',N'Rechazada') THROW 55120,N'Decisión inválida.',1;
 BEGIN TRY BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.EmpleadoJornadas j JOIN dbo.Empleados e ON e.EmpleadoId=j.EmpleadoId WHERE j.JornadaId=@JornadaId AND e.UsuarioId=@SupervisorUsuarioId) THROW 55121,N'No puede resolver su propia jornada.',1;
 UPDATE dbo.EmpleadoJornadas SET Estado=@Decision,SupervisorUsuarioId=@SupervisorUsuarioId,SupervisorNombre=@SupervisorNombre,RespuestaSupervisor=@RespuestaSupervisor,FechaDecisionUtc=SYSUTCDATETIME()
 WHERE JornadaId=@JornadaId AND Estado=N'Enviada' AND VersionFila=@VersionFila;
 IF @@ROWCOUNT<>1 THROW 55122,N'La jornada cambió o ya fue resuelta.',1;
 INSERT dbo.RRHHAuditoria(Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(N'Jornada',@JornadaId,UPPER(@Decision),COALESCE(NULLIF(@RespuestaSupervisor,N''),N'Sin observación.'),@SupervisorUsuarioId,@SupervisorNombre);
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RRHH_ListarMisJornadas @UsuarioId INT,@Desde DATE,@Hasta DATE AS
BEGIN SET NOCOUNT ON; SELECT j.JornadaId,j.EmpleadoId,u.NombreCompleto,j.Fecha,j.HorasOrdinarias,j.HorasExtra,j.HorasAusencia,j.Observaciones,j.Estado,j.RespuestaSupervisor,j.VersionFila FROM dbo.EmpleadoJornadas j JOIN dbo.Empleados e ON e.EmpleadoId=j.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId WHERE e.UsuarioId=@UsuarioId AND j.Fecha BETWEEN @Desde AND @Hasta ORDER BY j.Fecha DESC; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_RRHH_ListarJornadasPendientes @Desde DATE,@Hasta DATE AS
BEGIN SET NOCOUNT ON; SELECT j.JornadaId,j.EmpleadoId,u.NombreCompleto,j.Fecha,j.HorasOrdinarias,j.HorasExtra,j.HorasAusencia,j.Observaciones,j.Estado,j.RespuestaSupervisor,j.VersionFila FROM dbo.EmpleadoJornadas j JOIN dbo.Empleados e ON e.EmpleadoId=j.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId WHERE j.Estado=N'Enviada' AND j.Fecha BETWEEN @Desde AND @Hasta ORDER BY j.Fecha,u.NombreCompleto; END;
GO

IF XACT_STATE()<>1 THROW 55103,N'La transacción 0018 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)'; IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55104,N'SHA-256 inválido para 0018.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes) VALUES(N'0018_rrhh_attendance',N'0018_rrhh_attendance.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-112: jornadas propias, envío, aprobación, segregación, idempotencia y auditoría.');
COMMIT TRANSACTION;
