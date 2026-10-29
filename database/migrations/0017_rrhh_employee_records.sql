SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 55000,N'Falta el ledger 0001.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0017_rrhh_employee_records' AND Status=N'Applied')
    THROW 55001,N'0017 ya figura aplicada.',1;
IF OBJECT_ID(N'dbo.Empleados',N'U') IS NULL OR OBJECT_ID(N'dbo.Usuarios',N'U') IS NULL OR OBJECT_ID(N'dbo.Perfiles',N'U') IS NULL
    THROW 55002,N'Faltan dependencias de empleados, usuarios o perfiles.',1;
IF OBJECT_ID(N'dbo.Permisos',N'U') IS NULL OR OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NULL
    THROW 55003,N'Faltan tablas de permisos.',1;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.Empleados',N'Departamento') IS NULL ALTER TABLE dbo.Empleados ADD Departamento NVARCHAR(100) NULL;
IF COL_LENGTH(N'dbo.Empleados',N'Responsabilidades') IS NULL ALTER TABLE dbo.Empleados ADD Responsabilidades NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.Empleados',N'ObservacionesInternas') IS NULL ALTER TABLE dbo.Empleados ADD ObservacionesInternas NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.Empleados',N'FechaActualizacion') IS NULL ALTER TABLE dbo.Empleados ADD FechaActualizacion DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.Empleados',N'VersionFila') IS NULL ALTER TABLE dbo.Empleados ADD VersionFila ROWVERSION NOT NULL;

IF OBJECT_ID(N'dbo.EmpleadoHistorialSalarios',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmpleadoHistorialSalarios
    (
        HistorialSalarioId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmpleadoHistorialSalarios PRIMARY KEY,
        EmpleadoId INT NOT NULL,
        SalarioAnterior DECIMAL(18,2) NULL,
        SalarioNuevo DECIMAL(18,2) NOT NULL,
        Motivo NVARCHAR(255) NULL,
        UsuarioCambioId INT NULL,
        UsuarioCambioNombre NVARCHAR(150) NULL,
        FechaCambio DATETIME2(0) NOT NULL CONSTRAINT DF_EmpleadoHistorialSalarios_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_EmpleadoHistorialSalarios_Empleado FOREIGN KEY(EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
        CONSTRAINT CK_EmpleadoHistorialSalarios_Valores CHECK(SalarioNuevo>=0 AND (SalarioAnterior IS NULL OR SalarioAnterior>=0))
    );
END;

IF OBJECT_ID(N'dbo.RRHHAuditoria',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RRHHAuditoria
    (
        AuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RRHHAuditoria PRIMARY KEY,
        Entidad NVARCHAR(40) NOT NULL,
        EntidadId BIGINT NOT NULL,
        Accion NVARCHAR(50) NOT NULL,
        Detalle NVARCHAR(1000) NOT NULL,
        ActorUsuarioId INT NULL,
        ActorNombre NVARCHAR(150) NOT NULL,
        FechaUtc DATETIME2(0) NOT NULL CONSTRAINT DF_RRHHAuditoria_Fecha DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_RRHHAuditoria_Entidad ON dbo.RRHHAuditoria(Entidad,EntidadId,FechaUtc DESC);
END;

DECLARE @Permissions TABLE(Codigo NVARCHAR(100),Nombre NVARCHAR(150),Descripcion NVARCHAR(500));
INSERT @Permissions VALUES
(N'EMPLEADOS_VER',N'Consultar expedientes de empleados',N'Permite consultar expedientes laborales.'),
(N'EMPLEADOS_CREAR',N'Crear expedientes de empleados',N'Permite registrar un empleado y su expediente.'),
(N'EMPLEADOS_EDITAR',N'Editar expedientes de empleados',N'Permite editar datos laborales y salario con control de concurrencia.'),
(N'EMPLEADOS_TAREAS',N'Gestionar tareas de empleados',N'Permite asignar y actualizar tareas.'),
(N'EMPLEADOS_SOLICITUDES',N'Gestionar solicitudes de empleados',N'Permite resolver solicitudes de tiempo libre.');
UPDATE p SET Modulo=N'Empleados',Nombre=r.Nombre,Descripcion=r.Descripcion,Activo=1 FROM dbo.Permisos p JOIN @Permissions r ON r.Codigo=p.Codigo;
INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo)
SELECT r.Codigo,N'Empleados',r.Nombre,r.Descripcion,1 FROM @Permissions r
WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos p WITH(UPDLOCK,HOLDLOCK) WHERE p.Codigo=r.Codigo);
INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0017 RRHH'
FROM dbo.Perfiles profile CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre=N'Administrador' AND permission.Codigo IN(SELECT Codigo FROM @Permissions)
AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=profile.PerfilId AND x.PermisoId=permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeById @EmpleadoId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmpleadoId,u.UsuarioId,u.PerfilId,p.Nombre,u.NombreCompleto,u.Correo,u.Telefono,u.Direccion,
           e.Puesto,e.Departamento,ISNULL(e.Salario,0),e.FechaContratacion,e.Responsabilidades,e.ObservacionesInternas,
           e.Activo,u.Activo,u.FechaRegistro,e.FechaActualizacion,e.VersionFila
    FROM dbo.Empleados e JOIN dbo.Usuarios u ON u.UsuarioId=e.UsuarioId JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId
    WHERE e.EmpleadoId=@EmpleadoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RRHH_UpdateEmployee
    @EmpleadoId INT,@PerfilId INT,@NombreCompleto NVARCHAR(150),@Correo NVARCHAR(150),@Contrasena NVARCHAR(255)=NULL,
    @Telefono NVARCHAR(30)=NULL,@Direccion NVARCHAR(255)=NULL,@Puesto NVARCHAR(100),@Departamento NVARCHAR(100)=NULL,
    @Salario DECIMAL(18,2)=0,@FechaContratacion DATE=NULL,@Responsabilidades NVARCHAR(MAX)=NULL,
    @ObservacionesInternas NVARCHAR(MAX)=NULL,@Activo BIT=1,@MotivoCambioSalario NVARCHAR(255)=NULL,
    @UsuarioCambioId INT=NULL,@UsuarioCambioNombre NVARCHAR(150)=NULL,@VersionFila BINARY(8)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Salario<0 THROW 55010,N'El salario no puede ser negativo.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @UsuarioId INT,@SalarioAnterior DECIMAL(18,2),@PuestoAnterior NVARCHAR(100),@DepartamentoAnterior NVARCHAR(100);
        SELECT @UsuarioId=e.UsuarioId,@SalarioAnterior=ISNULL(e.Salario,0),@PuestoAnterior=e.Puesto,@DepartamentoAnterior=e.Departamento
        FROM dbo.Empleados e WITH(UPDLOCK,HOLDLOCK) WHERE e.EmpleadoId=@EmpleadoId AND e.VersionFila=@VersionFila;
        IF @UsuarioId IS NULL THROW 55011,N'El expediente cambió o no existe.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE Correo=@Correo AND UsuarioId<>@UsuarioId) THROW 55012,N'El correo ya está asignado.',1;
        UPDATE dbo.Usuarios SET PerfilId=@PerfilId,NombreCompleto=@NombreCompleto,Correo=@Correo,Telefono=@Telefono,
            Direccion=@Direccion,Activo=@Activo,Contrasena=CASE WHEN NULLIF(LTRIM(RTRIM(@Contrasena)),N'') IS NULL THEN Contrasena ELSE @Contrasena END
        WHERE UsuarioId=@UsuarioId;
        UPDATE dbo.Empleados SET Puesto=@Puesto,Departamento=@Departamento,Salario=@Salario,FechaContratacion=@FechaContratacion,
            Responsabilidades=@Responsabilidades,ObservacionesInternas=@ObservacionesInternas,Activo=@Activo,FechaActualizacion=SYSUTCDATETIME()
        WHERE EmpleadoId=@EmpleadoId AND VersionFila=@VersionFila;
        IF @@ROWCOUNT<>1 THROW 55011,N'El expediente cambió mientras se editaba.',1;
        IF @SalarioAnterior<>@Salario
            INSERT dbo.EmpleadoHistorialSalarios(EmpleadoId,SalarioAnterior,SalarioNuevo,Motivo,UsuarioCambioId,UsuarioCambioNombre)
            VALUES(@EmpleadoId,@SalarioAnterior,@Salario,NULLIF(LTRIM(RTRIM(@MotivoCambioSalario)),N''),@UsuarioCambioId,@UsuarioCambioNombre);
        INSERT dbo.RRHHAuditoria(Entidad,EntidadId,Accion,Detalle,ActorUsuarioId,ActorNombre)
        VALUES(N'Empleado',@EmpleadoId,N'ACTUALIZAR',CONCAT(N'Puesto: ',COALESCE(@PuestoAnterior,N''),N' -> ',@Puesto,N'; departamento actualizado: ',CASE WHEN ISNULL(@DepartamentoAnterior,N'')<>ISNULL(@Departamento,N'') THEN N'sí' ELSE N'no' END,N'; salario actualizado: ',CASE WHEN @SalarioAnterior<>@Salario THEN N'sí' ELSE N'no' END),@UsuarioCambioId,COALESCE(NULLIF(@UsuarioCambioNombre,N''),N'Sistema'));
        COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

IF XACT_STATE()<>1 THROW 55004,N'La transacción 0017 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 55005,N'SHA-256 inválido para 0017.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0017_rrhh_employee_records',N'0017_rrhh_employee_records.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-111: expediente, historial salarial, permisos, concurrencia y auditoría transaccional.');
COMMIT TRANSACTION;
