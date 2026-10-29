SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 55200,N'Falta el ledger 0001.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0018_rrhh_attendance' AND Status=N'Applied') THROW 55201,N'Falta aplicar 0018.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0019_payroll_engine' AND Status=N'Applied') THROW 55202,N'0019 ya figura aplicada.',1;
BEGIN TRANSACTION;

CREATE TABLE dbo.PlanillaReglas
(
    ReglaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaReglas PRIMARY KEY,
    Codigo NVARCHAR(50) NOT NULL,
    Nombre NVARCHAR(150) NOT NULL,
    Tipo NVARCHAR(20) NOT NULL,
    TipoCalculo NVARCHAR(30) NOT NULL,
    Valor DECIMAL(18,6) NOT NULL,
    Tope DECIMAL(18,2) NULL,
    VigenteDesde DATE NOT NULL,
    VigenteHasta DATE NULL,
    Fuente NVARCHAR(500) NOT NULL,
    ActorUsuarioId INT NOT NULL,
    ActorNombre NVARCHAR(150) NOT NULL,
    FechaRegistroUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PlanillaReglas_Fecha DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_PlanillaReglas_CodigoVigencia UNIQUE(Codigo,VigenteDesde),
    CONSTRAINT CK_PlanillaReglas_Tipo CHECK(Tipo IN(N'Ingreso',N'Deduccion')),
    CONSTRAINT CK_PlanillaReglas_Calculo CHECK(TipoCalculo IN(N'MontoFijo',N'PorcentajeSalario',N'PorHoraExtra',N'PorcentajeBruto')),
    CONSTRAINT CK_PlanillaReglas_Valores CHECK(Valor>=0 AND (Tope IS NULL OR Tope>=0) AND (VigenteHasta IS NULL OR VigenteHasta>=VigenteDesde)),
    CONSTRAINT CK_PlanillaReglas_Fuente CHECK(LEN(LTRIM(RTRIM(Fuente)))>0)
);
CREATE INDEX IX_PlanillaReglas_Vigencia ON dbo.PlanillaReglas(Codigo,VigenteDesde DESC,VigenteHasta);

CREATE TABLE dbo.PlanillaPeriodos
(
    PeriodoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaPeriodos PRIMARY KEY,
    Tipo NVARCHAR(20) NOT NULL,
    Desde DATE NOT NULL,
    Hasta DATE NOT NULL,
    FactorSalario DECIMAL(9,6) NOT NULL,
    FuenteConfiguracion NVARCHAR(500) NOT NULL,
    Estado NVARCHAR(20) NOT NULL CONSTRAINT DF_PlanillaPeriodos_Estado DEFAULT N'Abierto',
    ActorUsuarioId INT NOT NULL,
    ActorNombre NVARCHAR(150) NOT NULL,
    FechaRegistroUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PlanillaPeriodos_Fecha DEFAULT SYSUTCDATETIME(),
    VersionFila ROWVERSION NOT NULL,
    CONSTRAINT UQ_PlanillaPeriodos_Fechas UNIQUE(Desde,Hasta),
    CONSTRAINT CK_PlanillaPeriodos_Tipo CHECK(Tipo IN(N'Quincenal',N'Mensual')),
    CONSTRAINT CK_PlanillaPeriodos_Fechas CHECK(Hasta>=Desde AND DATEDIFF(DAY,Desde,Hasta)<=31),
    CONSTRAINT CK_PlanillaPeriodos_Factor CHECK(FactorSalario>0 AND FactorSalario<=1),
    CONSTRAINT CK_PlanillaPeriodos_Fuente CHECK(LEN(LTRIM(RTRIM(FuenteConfiguracion)))>0),
    CONSTRAINT CK_PlanillaPeriodos_Estado CHECK(Estado IN(N'Abierto',N'Cerrado'))
);

CREATE TABLE dbo.PlanillaCalculos
(
    CalculoId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaCalculos PRIMARY KEY,
    PeriodoId INT NOT NULL,
    EmpleadoId INT NOT NULL,
    SalarioBase DECIMAL(18,2) NOT NULL,
    HorasOrdinarias DECIMAL(8,2) NOT NULL,
    HorasExtra DECIMAL(8,2) NOT NULL,
    Comisiones DECIMAL(18,2) NOT NULL,
    TotalIngresos DECIMAL(18,2) NOT NULL,
    TotalDeducciones DECIMAL(18,2) NOT NULL,
    TotalBruto DECIMAL(18,2) NOT NULL,
    TotalNeto DECIMAL(18,2) NOT NULL,
    ReglasSnapshotJson NVARCHAR(MAX) NOT NULL,
    Fingerprint BINARY(32) NOT NULL,
    IdempotencyKey UNIQUEIDENTIFIER NOT NULL,
    Estado NVARCHAR(20) NOT NULL,
    CalculadoPorUsuarioId INT NOT NULL,
    CalculadoPorNombre NVARCHAR(150) NOT NULL,
    AprobadoPorUsuarioId INT NULL,
    AprobadoPorNombre NVARCHAR(150) NULL,
    PagadoPorUsuarioId INT NULL,
    PagadoPorNombre NVARCHAR(150) NULL,
    MotivoReversion NVARCHAR(500) NULL,
    FechaCalculoUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PlanillaCalculos_Fecha DEFAULT SYSUTCDATETIME(),
    FechaAprobacionUtc DATETIME2(0) NULL,
    FechaPagoUtc DATETIME2(0) NULL,
    FechaReversionUtc DATETIME2(0) NULL,
    VersionFila ROWVERSION NOT NULL,
    CONSTRAINT FK_PlanillaCalculos_Periodo FOREIGN KEY(PeriodoId) REFERENCES dbo.PlanillaPeriodos(PeriodoId),
    CONSTRAINT FK_PlanillaCalculos_Empleado FOREIGN KEY(EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
    CONSTRAINT UQ_PlanillaCalculos_EmpleadoPeriodo UNIQUE(PeriodoId,EmpleadoId),
    CONSTRAINT UQ_PlanillaCalculos_Token UNIQUE(IdempotencyKey),
    CONSTRAINT CK_PlanillaCalculos_Valores CHECK(SalarioBase>=0 AND HorasOrdinarias>=0 AND HorasExtra>=0 AND Comisiones>=0 AND TotalIngresos>=0 AND TotalDeducciones>=0 AND TotalBruto>=0 AND TotalNeto>=0 AND TotalNeto=TotalBruto-TotalDeducciones),
    CONSTRAINT CK_PlanillaCalculos_Snapshot CHECK(ISJSON(ReglasSnapshotJson)=1),
    CONSTRAINT CK_PlanillaCalculos_Estado CHECK(Estado IN(N'Borrador',N'Aprobada',N'Pagada',N'Revertida'))
);
CREATE INDEX IX_PlanillaCalculos_Estado ON dbo.PlanillaCalculos(Estado,PeriodoId DESC);

CREATE TABLE dbo.PlanillaDetalle
(
    DetalleId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaDetalle PRIMARY KEY,
    CalculoId BIGINT NOT NULL,
    Codigo NVARCHAR(50) NOT NULL,
    Nombre NVARCHAR(150) NOT NULL,
    Tipo NVARCHAR(20) NOT NULL,
    Monto DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_PlanillaDetalle_Calculo FOREIGN KEY(CalculoId) REFERENCES dbo.PlanillaCalculos(CalculoId),
    CONSTRAINT CK_PlanillaDetalle_Tipo CHECK(Tipo IN(N'Ingreso',N'Deduccion')),
    CONSTRAINT CK_PlanillaDetalle_Monto CHECK(Monto>=0)
);

CREATE TABLE dbo.PlanillaAuditoria
(
    AuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanillaAuditoria PRIMARY KEY,
    CalculoId BIGINT NULL,
    Entidad NVARCHAR(50) NOT NULL,
    EntidadId BIGINT NOT NULL,
    Accion NVARCHAR(50) NOT NULL,
    EstadoAnterior NVARCHAR(20) NULL,
    EstadoNuevo NVARCHAR(20) NULL,
    Detalle NVARCHAR(500) NULL,
    ActorUsuarioId INT NOT NULL,
    ActorNombre NVARCHAR(150) NOT NULL,
    FechaUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PlanillaAuditoria_Fecha DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_PlanillaAuditoria_Calculo FOREIGN KEY(CalculoId) REFERENCES dbo.PlanillaCalculos(CalculoId)
);

DECLARE @Permissions TABLE(Codigo NVARCHAR(100),Nombre NVARCHAR(150),Descripcion NVARCHAR(500));
INSERT @Permissions VALUES
(N'PLANILLA_VER',N'Consultar planilla',N'Permite consultar cálculos de planilla.'),
(N'PLANILLA_CONFIGURAR',N'Configurar reglas de planilla',N'Permite crear versiones de reglas con fuente y vigencia.'),
(N'PLANILLA_GESTIONAR',N'Gestionar periodos de planilla',N'Permite crear periodos con factor salarial documentado.'),
(N'PLANILLA_CALCULAR',N'Calcular planilla',N'Permite generar cálculos reproducibles.'),
(N'PLANILLA_APROBAR',N'Aprobar planilla',N'Permite aprobar cálculos realizados por otra persona.'),
(N'PLANILLA_PAGAR',N'Registrar pago de planilla',N'Permite registrar pagos aprobados con segregación.'),
(N'PLANILLA_REVERTIR',N'Revertir planilla',N'Permite revertir con motivo obligatorio.');
UPDATE p SET Modulo=N'Planilla',Nombre=r.Nombre,Descripcion=r.Descripcion,Activo=1 FROM dbo.Permisos p JOIN @Permissions r ON r.Codigo=p.Codigo;
INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo) SELECT r.Codigo,N'Planilla',r.Nombre,r.Descripcion,1 FROM @Permissions r
WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos p WITH(UPDLOCK,HOLDLOCK) WHERE p.Codigo=r.Codigo);
INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0019 planilla' FROM dbo.Perfiles profile CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre=N'Administrador' AND permission.Codigo IN(SELECT Codigo FROM @Permissions)
AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=profile.PerfilId AND x.PermisoId=permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_GuardarRegla
 @Codigo NVARCHAR(50),@Nombre NVARCHAR(150),@Tipo NVARCHAR(20),@TipoCalculo NVARCHAR(30),@Valor DECIMAL(18,6),@Tope DECIMAL(18,2)=NULL,
 @VigenteDesde DATE,@VigenteHasta DATE=NULL,@Fuente NVARCHAR(500),@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Codigo=UPPER(LTRIM(RTRIM(@Codigo))); SET @Fuente=LTRIM(RTRIM(@Fuente));
 IF @Codigo=N'' OR @Codigo LIKE N'%[^A-Z0-9_]%' THROW 55210,N'Código de regla inválido.',1;
 IF @Tipo NOT IN(N'Ingreso',N'Deduccion') OR @TipoCalculo NOT IN(N'MontoFijo',N'PorcentajeSalario',N'PorHoraExtra',N'PorcentajeBruto') THROW 55211,N'Tipo de regla inválido.',1;
 IF @Valor<0 OR @Tope<0 OR @Fuente=N'' OR (@VigenteHasta IS NOT NULL AND @VigenteHasta<@VigenteDesde) THROW 55212,N'Configuración de regla inválida.',1;
 BEGIN TRY BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.PlanillaReglas WITH(UPDLOCK,HOLDLOCK) WHERE Codigo=@Codigo AND VigenteDesde>=@VigenteDesde) THROW 55213,N'La nueva versión debe iniciar después de las versiones existentes.',1;
 UPDATE dbo.PlanillaReglas SET VigenteHasta=DATEADD(DAY,-1,@VigenteDesde) WHERE Codigo=@Codigo AND VigenteHasta IS NULL;
 INSERT dbo.PlanillaReglas(Codigo,Nombre,Tipo,TipoCalculo,Valor,Tope,VigenteDesde,VigenteHasta,Fuente,ActorUsuarioId,ActorNombre)
 VALUES(@Codigo,LTRIM(RTRIM(@Nombre)),@Tipo,@TipoCalculo,@Valor,@Tope,@VigenteDesde,@VigenteHasta,@Fuente,@ActorUsuarioId,@ActorNombre);
 INSERT dbo.PlanillaAuditoria(Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(N'Regla',SCOPE_IDENTITY(),N'CREAR_VERSION',@Fuente,@ActorUsuarioId,@ActorNombre);
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_CrearPeriodo
 @Tipo NVARCHAR(20),@Desde DATE,@Hasta DATE,@FactorSalario DECIMAL(9,6),@FuenteConfiguracion NVARCHAR(500),@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Tipo NOT IN(N'Quincenal',N'Mensual') OR @Hasta<@Desde OR DATEDIFF(DAY,@Desde,@Hasta)>31 OR @FactorSalario<=0 OR @FactorSalario>1 OR LEN(LTRIM(RTRIM(@FuenteConfiguracion)))=0 THROW 55220,N'Periodo o configuración inválidos.',1;
 BEGIN TRY BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.PlanillaPeriodos WITH(UPDLOCK,HOLDLOCK) WHERE NOT(@Hasta<Desde OR @Desde>Hasta)) THROW 55221,N'El periodo se traslapa con otro existente.',1;
 INSERT dbo.PlanillaPeriodos(Tipo,Desde,Hasta,FactorSalario,FuenteConfiguracion,ActorUsuarioId,ActorNombre) VALUES(@Tipo,@Desde,@Hasta,@FactorSalario,LTRIM(RTRIM(@FuenteConfiguracion)),@ActorUsuarioId,@ActorNombre);
 DECLARE @PeriodoId INT=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.PlanillaAuditoria(Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre) VALUES(N'Periodo',@PeriodoId,N'CREAR',@FuenteConfiguracion,@ActorUsuarioId,@ActorNombre);
 COMMIT TRANSACTION; SELECT @PeriodoId;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_ObtenerEntradaCalculo @PeriodoId INT,@EmpleadoId INT
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PlanillaPeriodos WHERE PeriodoId=@PeriodoId AND Estado=N'Abierto') THROW 55230,N'El periodo no existe o está cerrado.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE EmpleadoId=@EmpleadoId AND Activo=1) THROW 55231,N'El empleado no existe o está inactivo.',1;
 SELECT CONVERT(DECIMAL(18,2),ROUND(ISNULL(e.Salario,0)*p.FactorSalario,2)),
        CONVERT(DECIMAL(8,2),ISNULL(SUM(j.HorasOrdinarias),0)),CONVERT(DECIMAL(8,2),ISNULL(SUM(j.HorasExtra),0)),p.Hasta,p.FactorSalario,p.FuenteConfiguracion
 FROM dbo.Empleados e CROSS JOIN dbo.PlanillaPeriodos p
 LEFT JOIN dbo.EmpleadoJornadas j ON j.EmpleadoId=e.EmpleadoId AND j.Fecha BETWEEN p.Desde AND p.Hasta AND j.Estado=N'Aprobada'
 WHERE e.EmpleadoId=@EmpleadoId AND p.PeriodoId=@PeriodoId GROUP BY e.Salario,p.Hasta,p.FactorSalario,p.FuenteConfiguracion;
 SELECT ReglaId,Codigo,Nombre,Tipo,TipoCalculo,Valor,Tope,VigenteDesde,VigenteHasta,Fuente FROM dbo.PlanillaReglas
 WHERE VigenteDesde<=CONVERT(DATE,(SELECT Hasta FROM dbo.PlanillaPeriodos WHERE PeriodoId=@PeriodoId)) AND (VigenteHasta IS NULL OR VigenteHasta>=CONVERT(DATE,(SELECT Hasta FROM dbo.PlanillaPeriodos WHERE PeriodoId=@PeriodoId))) ORDER BY Codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_GuardarCalculo
 @PeriodoId INT,@EmpleadoId INT,@SalarioBase DECIMAL(18,2),@HorasOrdinarias DECIMAL(8,2),@HorasExtra DECIMAL(8,2),@Comisiones DECIMAL(18,2),
 @TotalIngresos DECIMAL(18,2),@TotalDeducciones DECIMAL(18,2),@TotalBruto DECIMAL(18,2),@TotalNeto DECIMAL(18,2),
 @ReglasSnapshotJson NVARCHAR(MAX),@DetalleJson NVARCHAR(MAX),@Fingerprint BINARY(32),@IdempotencyKey UNIQUEIDENTIFIER,@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF ISJSON(@ReglasSnapshotJson)<>1 OR ISJSON(@DetalleJson)<>1 OR @TotalNeto<>@TotalBruto-@TotalDeducciones OR @TotalDeducciones>@TotalBruto THROW 55240,N'Cálculo inválido.',1;
 BEGIN TRY BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WITH(UPDLOCK,HOLDLOCK) WHERE IdempotencyKey=@IdempotencyKey)
 BEGIN
   IF EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WHERE IdempotencyKey=@IdempotencyKey AND PeriodoId=@PeriodoId AND EmpleadoId=@EmpleadoId AND Fingerprint=@Fingerprint) BEGIN COMMIT TRANSACTION; RETURN; END;
   THROW 55241,N'Token reutilizado con otro cálculo.',1;
 END;
 IF EXISTS(SELECT 1 FROM dbo.PlanillaCalculos WITH(UPDLOCK,HOLDLOCK) WHERE PeriodoId=@PeriodoId AND EmpleadoId=@EmpleadoId) THROW 55242,N'Ya existe cálculo para el empleado y periodo.',1;
 INSERT dbo.PlanillaCalculos(PeriodoId,EmpleadoId,SalarioBase,HorasOrdinarias,HorasExtra,Comisiones,TotalIngresos,TotalDeducciones,TotalBruto,TotalNeto,ReglasSnapshotJson,Fingerprint,IdempotencyKey,Estado,CalculadoPorUsuarioId,CalculadoPorNombre)
 VALUES(@PeriodoId,@EmpleadoId,@SalarioBase,@HorasOrdinarias,@HorasExtra,@Comisiones,@TotalIngresos,@TotalDeducciones,@TotalBruto,@TotalNeto,@ReglasSnapshotJson,@Fingerprint,@IdempotencyKey,N'Borrador',@ActorUsuarioId,@ActorNombre);
 DECLARE @CalculoId BIGINT=SCOPE_IDENTITY();
 INSERT dbo.PlanillaDetalle(CalculoId,Codigo,Nombre,Tipo,Monto)
 SELECT @CalculoId,Codigo,Nombre,Tipo,Monto FROM OPENJSON(@DetalleJson) WITH(Codigo NVARCHAR(50) '$.Codigo',Nombre NVARCHAR(150) '$.Nombre',Tipo NVARCHAR(20) '$.Tipo',Monto DECIMAL(18,2) '$.Monto');
 IF EXISTS(SELECT 1 FROM dbo.PlanillaDetalle WHERE CalculoId=@CalculoId AND (Codigo IS NULL OR Nombre IS NULL OR Tipo NOT IN(N'Ingreso',N'Deduccion') OR Monto<0)) THROW 55243,N'Detalle de cálculo inválido.',1;
 INSERT dbo.PlanillaAuditoria(CalculoId,Entidad,EntidadId,Accion,EstadoNuevo,Detalle,ActorUsuarioId,ActorNombre) VALUES(@CalculoId,N'Cálculo',@CalculoId,N'CALCULAR',N'Borrador',CONVERT(NVARCHAR(64),@Fingerprint,2),@ActorUsuarioId,@ActorNombre);
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_CambiarEstado @CalculoId BIGINT,@Estado NVARCHAR(20),@Motivo NVARCHAR(500)=NULL,@VersionFila BINARY(8),@ActorUsuarioId INT,@ActorNombre NVARCHAR(150)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Estado NOT IN(N'Aprobada',N'Pagada',N'Revertida') THROW 55250,N'Estado destino inválido.',1;
 IF @Estado=N'Revertida' AND LEN(LTRIM(RTRIM(ISNULL(@Motivo,N''))))=0 THROW 55251,N'La reversión exige motivo.',1;
 BEGIN TRY BEGIN TRANSACTION;
 DECLARE @Anterior NVARCHAR(20),@CalculadoPor INT,@AprobadoPor INT;
 SELECT @Anterior=Estado,@CalculadoPor=CalculadoPorUsuarioId,@AprobadoPor=AprobadoPorUsuarioId FROM dbo.PlanillaCalculos WITH(UPDLOCK,HOLDLOCK) WHERE CalculoId=@CalculoId AND VersionFila=@VersionFila;
 IF @Anterior IS NULL THROW 55252,N'El cálculo cambió o no existe.',1;
 IF @Estado=N'Aprobada' AND (@Anterior<>N'Borrador' OR @ActorUsuarioId=@CalculadoPor) THROW 55253,N'La aprobación requiere un actor distinto del calculador.',1;
 IF @Estado=N'Pagada' AND (@Anterior<>N'Aprobada' OR @ActorUsuarioId IN(@CalculadoPor,@AprobadoPor)) THROW 55254,N'El pago requiere un tercer actor y aprobación previa.',1;
 IF @Estado=N'Revertida' AND @Anterior NOT IN(N'Aprobada',N'Pagada') THROW 55255,N'Solo una planilla aprobada o pagada puede revertirse.',1;
 UPDATE dbo.PlanillaCalculos SET Estado=@Estado,
   AprobadoPorUsuarioId=CASE WHEN @Estado=N'Aprobada' THEN @ActorUsuarioId ELSE AprobadoPorUsuarioId END,
   AprobadoPorNombre=CASE WHEN @Estado=N'Aprobada' THEN @ActorNombre ELSE AprobadoPorNombre END,
   FechaAprobacionUtc=CASE WHEN @Estado=N'Aprobada' THEN SYSUTCDATETIME() ELSE FechaAprobacionUtc END,
   PagadoPorUsuarioId=CASE WHEN @Estado=N'Pagada' THEN @ActorUsuarioId ELSE PagadoPorUsuarioId END,
   PagadoPorNombre=CASE WHEN @Estado=N'Pagada' THEN @ActorNombre ELSE PagadoPorNombre END,
   FechaPagoUtc=CASE WHEN @Estado=N'Pagada' THEN SYSUTCDATETIME() ELSE FechaPagoUtc END,
   MotivoReversion=CASE WHEN @Estado=N'Revertida' THEN LTRIM(RTRIM(@Motivo)) ELSE MotivoReversion END,
   FechaReversionUtc=CASE WHEN @Estado=N'Revertida' THEN SYSUTCDATETIME() ELSE FechaReversionUtc END WHERE CalculoId=@CalculoId AND VersionFila=@VersionFila;
 IF @@ROWCOUNT<>1 THROW 55256,N'Conflicto de concurrencia.',1;
 INSERT dbo.PlanillaAuditoria(CalculoId,Entidad,EntidadId,Accion,EstadoAnterior,EstadoNuevo,Detalle,ActorUsuarioId,ActorNombre) VALUES(@CalculoId,N'Cálculo',@CalculoId,N'CAMBIAR_ESTADO',@Anterior,@Estado,@Motivo,@ActorUsuarioId,@ActorNombre);
 COMMIT TRANSACTION; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Payroll_ListarCalculos
AS
BEGIN
 SET NOCOUNT ON;
 SELECT c.CalculoId,c.PeriodoId,CONCAT(CONVERT(NVARCHAR(10),p.Desde,23),N' — ',CONVERT(NVARCHAR(10),p.Hasta,23)),c.EmpleadoId,u.NombreCompleto,c.TotalBruto,c.TotalDeducciones,c.TotalNeto,c.Estado,c.VersionFila
 FROM dbo.PlanillaCalculos c JOIN dbo.PlanillaPeriodos p ON p.PeriodoId=c.PeriodoId JOIN dbo.Empleados e ON e.EmpleadoId=c.EmpleadoId JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId
 ORDER BY p.Hasta DESC,u.NombreCompleto;
END;
GO

IF XACT_STATE()<>1 THROW 55203,N'La transacción 0019 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)'; IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55204,N'SHA-256 inválido para 0019.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes) VALUES(N'0019_payroll_engine',N'0019_payroll_engine.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-113: reglas versionadas sin tasas precargadas, periodos configurables, cálculo reproducible, segregación e idempotencia.');
COMMIT TRANSACTION;
