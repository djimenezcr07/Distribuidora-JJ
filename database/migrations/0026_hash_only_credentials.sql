SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55260, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0026_hash_only_credentials' AND Status = N'Applied')
    THROW 55261, N'0026 ya figura aplicada.', 1;
IF COL_LENGTH(N'dbo.Usuarios', N'ContrasenaHash') IS NULL OR
   COL_LENGTH(N'dbo.Usuarios', N'PasswordVersion') IS NULL OR
   COL_LENGTH(N'dbo.Usuarios', N'SecurityStamp') IS NULL
    THROW 55262, N'Faltan las migraciones 0022 o 0025.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.Usuarios
    WHERE Activo = 1 AND NULLIF(LTRIM(RTRIM(ContrasenaHash)), N'') IS NULL
)
    THROW 55263, N'Hay usuarios activos sin hash. Complete restablecimientos controlados antes de retirar el fallback legado.', 1;

BEGIN TRANSACTION;

UPDATE dbo.Usuarios
SET Contrasena = N''
WHERE NULLIF(LTRIM(RTRIM(ContrasenaHash)), N'') IS NOT NULL
  AND ISNULL(Contrasena, N'') <> N'';

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetLoginCredential
    @Correo NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        usuario.UsuarioId,
        usuario.NombreCompleto,
        usuario.Correo,
        perfil.Nombre AS PerfilNombre,
        usuario.Activo,
        usuario.ContrasenaHash,
        usuario.SecurityStamp
    FROM dbo.Usuarios usuario
    INNER JOIN dbo.Perfiles perfil ON perfil.PerfilId = usuario.PerfilId
    WHERE usuario.Correo = @Correo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_RegisterClient
    @NombreCompleto NVARCHAR(200),
    @Correo NVARCHAR(200),
    @ContrasenaHash NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), N'') IS NULL OR
       NULLIF(LTRIM(RTRIM(@Correo)), N'') IS NULL OR
       NULLIF(LTRIM(RTRIM(@ContrasenaHash)), N'') IS NULL
        THROW 55012, N'Datos de registro inválidos.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = LTRIM(RTRIM(@Correo)))
        THROW 55013, N'El correo ya se encuentra registrado.', 1;

    DECLARE @PerfilId INT = (SELECT TOP (1) PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');
    IF @PerfilId IS NULL THROW 55014, N'No existe el perfil Cliente.', 1;

    INSERT dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, ContrasenaHash, PasswordVersion,
         DebeCambiarContrasena, PasswordActualizadaUtc, Activo)
    VALUES
        (@PerfilId, LTRIM(RTRIM(@NombreCompleto)), LTRIM(RTRIM(@Correo)), N'', @ContrasenaHash, 1,
         0, SYSUTCDATETIME(), 1);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_UpdatePassword
    @UsuarioId INT,
    @ContrasenaHash NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Auth_SetPasswordHash @UsuarioId = @UsuarioId, @ContrasenaHash = @ContrasenaHash;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateClient
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @ContrasenaHash NVARCHAR(512),
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @Activo BIT = 1,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP (1) PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');
    SET @NombreCompleto = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
    SET @Correo = LOWER(LTRIM(RTRIM(ISNULL(@Correo, N''))));
    SET @ContrasenaHash = LTRIM(RTRIM(ISNULL(@ContrasenaHash, N'')));
    SET @Telefono = NULLIF(LTRIM(RTRIM(ISNULL(@Telefono, N''))), N'');
    SET @Direccion = NULLIF(LTRIM(RTRIM(ISNULL(@Direccion, N''))), N'');
    SET @MotivoInactivacion = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoInactivacion, N''))), N'');

    IF @ClientePerfilId IS NULL THROW 51002, N'No existe el perfil Cliente.', 1;
    IF @NombreCompleto = N'' OR @Correo = N'' OR @ContrasenaHash = N''
        THROW 51003, N'Nombre, correo y credencial hash son obligatorios.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
        THROW 51004, N'Ya existe un usuario registrado con ese correo.', 1;
    IF ISNULL(@Activo, 1) = 0 AND @MotivoInactivacion IS NULL
        THROW 51005, N'Debe indicar un motivo para registrar el cliente como inactivo.', 1;

    INSERT dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, ContrasenaHash, PasswordVersion,
         DebeCambiarContrasena, PasswordActualizadaUtc, Telefono, Direccion, Activo,
         MotivoInactivacion, FechaInactivacion, FechaActualizacion)
    VALUES
        (@ClientePerfilId, @NombreCompleto, @Correo, N'', @ContrasenaHash, 1, 0, SYSUTCDATETIME(),
         @Telefono, @Direccion, ISNULL(@Activo, 1),
         CASE WHEN ISNULL(@Activo, 1) = 0 THEN @MotivoInactivacion ELSE NULL END,
         CASE WHEN ISNULL(@Activo, 1) = 0 THEN SYSDATETIME() ELSE NULL END, SYSDATETIME());

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateClient
    @UsuarioId INT,
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @ContrasenaHash NVARCHAR(512) = NULL,
    @Activo BIT = 1,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP (1) PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');
    DECLARE @ActivoAnterior BIT;
    SELECT @ActivoAnterior = CAST(ISNULL(Activo, 1) AS BIT)
    FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND PerfilId = @ClientePerfilId;
    IF @ActivoAnterior IS NULL THROW 51006, N'El cliente seleccionado no existe.', 1;

    SET @NombreCompleto = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
    SET @Correo = LOWER(LTRIM(RTRIM(ISNULL(@Correo, N''))));
    SET @Telefono = NULLIF(LTRIM(RTRIM(ISNULL(@Telefono, N''))), N'');
    SET @Direccion = NULLIF(LTRIM(RTRIM(ISNULL(@Direccion, N''))), N'');
    SET @ContrasenaHash = NULLIF(LTRIM(RTRIM(ISNULL(@ContrasenaHash, N''))), N'');
    SET @MotivoInactivacion = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoInactivacion, N''))), N'');

    IF @NombreCompleto = N'' OR @Correo = N'' THROW 51007, N'Nombre y correo son obligatorios.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo AND UsuarioId <> @UsuarioId)
        THROW 51008, N'Ya existe otro usuario registrado con ese correo.', 1;
    IF ISNULL(@Activo, 1) = 0 AND @MotivoInactivacion IS NULL
        THROW 51009, N'Debe indicar un motivo para inactivar el cliente.', 1;

    UPDATE dbo.Usuarios
    SET NombreCompleto = @NombreCompleto,
        Correo = @Correo,
        Telefono = @Telefono,
        Direccion = @Direccion,
        Contrasena = CASE WHEN @ContrasenaHash IS NULL THEN Contrasena ELSE N'' END,
        ContrasenaHash = COALESCE(@ContrasenaHash, ContrasenaHash),
        PasswordVersion = CASE WHEN @ContrasenaHash IS NULL THEN PasswordVersion ELSE PasswordVersion + 1 END,
        PasswordActualizadaUtc = CASE WHEN @ContrasenaHash IS NULL THEN PasswordActualizadaUtc ELSE SYSUTCDATETIME() END,
        Activo = ISNULL(@Activo, 1),
        MotivoInactivacion = CASE WHEN ISNULL(@Activo, 1) = 0 THEN @MotivoInactivacion ELSE NULL END,
        FechaInactivacion = CASE
            WHEN ISNULL(@Activo, 1) = 0 AND @ActivoAnterior = 1 THEN SYSDATETIME()
            WHEN ISNULL(@Activo, 1) = 0 AND @ActivoAnterior = 0 THEN ISNULL(FechaInactivacion, SYSDATETIME())
            ELSE NULL END,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId AND PerfilId = @ClientePerfilId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateEmployee
    @PerfilId INT,
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @ContrasenaHash NVARCHAR(512),
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @Puesto NVARCHAR(100),
    @Departamento NVARCHAR(100) = NULL,
    @Salario DECIMAL(18,2) = 0,
    @FechaContratacion DATE = NULL,
    @Responsabilidades NVARCHAR(MAX) = NULL,
    @ObservacionesInternas NVARCHAR(MAX) = NULL,
    @Activo BIT = 1,
    @UsuarioCambioId INT = NULL,
    @UsuarioCambioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@ContrasenaHash)), N'') IS NULL THROW 55264, N'La credencial hash es obligatoria.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo) THROW 51000, N'Ya existe un usuario registrado con ese correo.', 1;

    BEGIN TRANSACTION;
    DECLARE @UsuarioId INT, @EmpleadoId INT;
    INSERT dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, ContrasenaHash, PasswordVersion,
         DebeCambiarContrasena, PasswordActualizadaUtc, Telefono, Direccion, Activo)
    VALUES
        (@PerfilId, @NombreCompleto, @Correo, N'', @ContrasenaHash, 1, 0, SYSUTCDATETIME(),
         @Telefono, @Direccion, @Activo);
    SET @UsuarioId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT dbo.Empleados
        (UsuarioId, Puesto, Salario, FechaContratacion, Activo, Departamento,
         Responsabilidades, ObservacionesInternas, FechaActualizacion)
    VALUES
        (@UsuarioId, @Puesto, @Salario, @FechaContratacion, @Activo, @Departamento,
         @Responsabilidades, @ObservacionesInternas, SYSUTCDATETIME());
    SET @EmpleadoId = CAST(SCOPE_IDENTITY() AS INT);

    IF ISNULL(@Salario, 0) > 0
        INSERT dbo.EmpleadoHistorialSalarios
            (EmpleadoId, SalarioAnterior, SalarioNuevo, Motivo, UsuarioCambioId, UsuarioCambioNombre)
        VALUES (@EmpleadoId, NULL, @Salario, N'Salario inicial registrado.', @UsuarioCambioId, @UsuarioCambioNombre);

    COMMIT TRANSACTION;
    SELECT @EmpleadoId AS EmpleadoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RRHH_UpdateEmployee
    @EmpleadoId INT,@PerfilId INT,@NombreCompleto NVARCHAR(150),@Correo NVARCHAR(150),@ContrasenaHash NVARCHAR(512)=NULL,
    @Telefono NVARCHAR(30)=NULL,@Direccion NVARCHAR(255)=NULL,@Puesto NVARCHAR(100),@Departamento NVARCHAR(100)=NULL,
    @Salario DECIMAL(18,2)=0,@FechaContratacion DATE=NULL,@Responsabilidades NVARCHAR(MAX)=NULL,
    @ObservacionesInternas NVARCHAR(MAX)=NULL,@Activo BIT=1,@MotivoCambioSalario NVARCHAR(255)=NULL,
    @UsuarioCambioId INT=NULL,@UsuarioCambioNombre NVARCHAR(150)=NULL,@VersionFila BINARY(8)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Salario<0 THROW 55010,N'El salario no puede ser negativo.',1;
    SET @ContrasenaHash = NULLIF(LTRIM(RTRIM(ISNULL(@ContrasenaHash, N''))), N'');
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @UsuarioId INT,@SalarioAnterior DECIMAL(18,2),@PuestoAnterior NVARCHAR(100),@DepartamentoAnterior NVARCHAR(100);
        SELECT @UsuarioId=e.UsuarioId,@SalarioAnterior=ISNULL(e.Salario,0),@PuestoAnterior=e.Puesto,@DepartamentoAnterior=e.Departamento
        FROM dbo.Empleados e WITH(UPDLOCK,HOLDLOCK) WHERE e.EmpleadoId=@EmpleadoId AND e.VersionFila=@VersionFila;
        IF @UsuarioId IS NULL THROW 55011,N'El expediente cambió o no existe.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE Correo=@Correo AND UsuarioId<>@UsuarioId) THROW 55012,N'El correo ya está asignado.',1;
        UPDATE dbo.Usuarios SET PerfilId=@PerfilId,NombreCompleto=@NombreCompleto,Correo=@Correo,Telefono=@Telefono,
            Direccion=@Direccion,Activo=@Activo,
            Contrasena=CASE WHEN @ContrasenaHash IS NULL THEN Contrasena ELSE N'' END,
            ContrasenaHash=COALESCE(@ContrasenaHash,ContrasenaHash),
            PasswordVersion=CASE WHEN @ContrasenaHash IS NULL THEN PasswordVersion ELSE PasswordVersion+1 END,
            PasswordActualizadaUtc=CASE WHEN @ContrasenaHash IS NULL THEN PasswordActualizadaUtc ELSE SYSUTCDATETIME() END
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

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55265, N'SHA-256 inválido para 0026.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0026_hash_only_credentials', N'0026_hash_only_credentials.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Retira fallback plaintext y exige PBKDF2 para login, registro y administración de usuarios.');
GO
