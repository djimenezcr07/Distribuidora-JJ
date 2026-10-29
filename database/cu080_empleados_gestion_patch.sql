USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-080 / Sprint 3 - Gestión de empleados
   Objetivo:
   - Administrar empleados desde panel administrativo.
   - Permitir que el empleado vea sus datos, salario, tareas y solicitudes.
   - Registrar solicitudes de días libres con/sin goce salarial.
   - Registrar tareas y responsabilidades asignadas por administración.
   Script seguro: usa IF/CREATE OR ALTER y no elimina datos existentes.
   ========================================================= */

/* 1. Asegurar roles base */
IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Empleado')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES ('Empleado', 'Rol para personal interno de la distribuidora.', 1);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Vendedor')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES ('Vendedor', 'Rol para vendedores que registran pedidos desde móvil.', 1);
END;
GO

/* 2. Ampliar tabla Empleados existente sin perder datos */
IF COL_LENGTH('dbo.Empleados', 'Departamento') IS NULL
BEGIN
    ALTER TABLE dbo.Empleados ADD Departamento NVARCHAR(100) NULL;
END;
GO

IF COL_LENGTH('dbo.Empleados', 'Responsabilidades') IS NULL
BEGIN
    ALTER TABLE dbo.Empleados ADD Responsabilidades NVARCHAR(MAX) NULL;
END;
GO

IF COL_LENGTH('dbo.Empleados', 'ObservacionesInternas') IS NULL
BEGIN
    ALTER TABLE dbo.Empleados ADD ObservacionesInternas NVARCHAR(MAX) NULL;
END;
GO

IF COL_LENGTH('dbo.Empleados', 'FechaActualizacion') IS NULL
BEGIN
    ALTER TABLE dbo.Empleados ADD FechaActualizacion DATETIME2 NULL;
END;
GO

/* 3. Tablas nuevas */
IF OBJECT_ID('dbo.EmpleadoHistorialSalarios', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmpleadoHistorialSalarios (
        HistorialSalarioId INT IDENTITY(1,1) PRIMARY KEY,
        EmpleadoId INT NOT NULL,
        SalarioAnterior DECIMAL(18,2) NULL,
        SalarioNuevo DECIMAL(18,2) NOT NULL,
        Motivo NVARCHAR(255) NULL,
        UsuarioCambioId INT NULL,
        UsuarioCambioNombre NVARCHAR(150) NULL,
        FechaCambio DATETIME2 NOT NULL CONSTRAINT DF_EmpleadoHistorialSalarios_Fecha DEFAULT SYSDATETIME(),
        CONSTRAINT FK_EmpleadoHistorialSalarios_Empleado FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
        CONSTRAINT FK_EmpleadoHistorialSalarios_Usuario FOREIGN KEY (UsuarioCambioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
END;
GO

IF OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmpleadoSolicitudesTiempoLibre (
        SolicitudId INT IDENTITY(1,1) PRIMARY KEY,
        EmpleadoId INT NOT NULL,
        FechaInicio DATE NOT NULL,
        FechaFin DATE NOT NULL,
        CantidadDias INT NOT NULL,
        TipoSolicitud NVARCHAR(30) NOT NULL,
        Motivo NVARCHAR(500) NOT NULL,
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_EmpleadoSolicitudes_Estado DEFAULT 'Pendiente',
        RespuestaAdmin NVARCHAR(500) NULL,
        UsuarioRespuestaId INT NULL,
        UsuarioRespuestaNombre NVARCHAR(150) NULL,
        FechaSolicitud DATETIME2 NOT NULL CONSTRAINT DF_EmpleadoSolicitudes_Fecha DEFAULT SYSDATETIME(),
        FechaRespuesta DATETIME2 NULL,
        CONSTRAINT FK_EmpleadoSolicitudes_Empleado FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
        CONSTRAINT FK_EmpleadoSolicitudes_UsuarioRespuesta FOREIGN KEY (UsuarioRespuestaId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_EmpleadoSolicitudes_Tipo CHECK (TipoSolicitud IN ('Con goce salarial', 'Sin goce salarial')),
        CONSTRAINT CK_EmpleadoSolicitudes_Estado CHECK (Estado IN ('Pendiente', 'Aprobada', 'Rechazada', 'Cancelada')),
        CONSTRAINT CK_EmpleadoSolicitudes_Fechas CHECK (FechaFin >= FechaInicio),
        CONSTRAINT CK_EmpleadoSolicitudes_Dias CHECK (CantidadDias > 0)
    );
END;
GO

IF OBJECT_ID('dbo.EmpleadoTareas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmpleadoTareas (
        TareaId INT IDENTITY(1,1) PRIMARY KEY,
        EmpleadoId INT NOT NULL,
        Titulo NVARCHAR(150) NOT NULL,
        Descripcion NVARCHAR(700) NULL,
        Prioridad NVARCHAR(20) NOT NULL CONSTRAINT DF_EmpleadoTareas_Prioridad DEFAULT 'Media',
        Estado NVARCHAR(30) NOT NULL CONSTRAINT DF_EmpleadoTareas_Estado DEFAULT 'Pendiente',
        FechaAsignacion DATETIME2 NOT NULL CONSTRAINT DF_EmpleadoTareas_Fecha DEFAULT SYSDATETIME(),
        FechaLimite DATE NULL,
        UsuarioAsignacionId INT NULL,
        UsuarioAsignacionNombre NVARCHAR(150) NULL,
        FechaActualizacion DATETIME2 NULL,
        CONSTRAINT FK_EmpleadoTareas_Empleado FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados(EmpleadoId),
        CONSTRAINT FK_EmpleadoTareas_UsuarioAsignacion FOREIGN KEY (UsuarioAsignacionId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_EmpleadoTareas_Prioridad CHECK (Prioridad IN ('Baja', 'Media', 'Alta', 'Urgente')),
        CONSTRAINT CK_EmpleadoTareas_Estado CHECK (Estado IN ('Pendiente', 'En proceso', 'Completada', 'Cancelada'))
    );
END;
GO

/* 4. Permisos del módulo */
IF OBJECT_ID('dbo.Permisos', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'EMPLEADOS_VER')
        INSERT INTO dbo.Permisos (Codigo, Nombre, Descripcion, Modulo, Activo)
        VALUES ('EMPLEADOS_VER', 'Ver empleados', 'Permite consultar el listado y detalle de empleados.', 'Empleados', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'EMPLEADOS_CREAR')
        INSERT INTO dbo.Permisos (Codigo, Nombre, Descripcion, Modulo, Activo)
        VALUES ('EMPLEADOS_CREAR', 'Crear empleados', 'Permite registrar empleados internos.', 'Empleados', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'EMPLEADOS_EDITAR')
        INSERT INTO dbo.Permisos (Codigo, Nombre, Descripcion, Modulo, Activo)
        VALUES ('EMPLEADOS_EDITAR', 'Editar empleados', 'Permite modificar datos laborales y salariales de empleados.', 'Empleados', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'EMPLEADOS_TAREAS')
        INSERT INTO dbo.Permisos (Codigo, Nombre, Descripcion, Modulo, Activo)
        VALUES ('EMPLEADOS_TAREAS', 'Gestionar tareas de empleados', 'Permite asignar y actualizar tareas de empleados.', 'Empleados', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = 'EMPLEADOS_SOLICITUDES')
        INSERT INTO dbo.Permisos (Codigo, Nombre, Descripcion, Modulo, Activo)
        VALUES ('EMPLEADOS_SOLICITUDES', 'Gestionar solicitudes de empleados', 'Permite aprobar o rechazar días libres solicitados por empleados.', 'Empleados', 1);

    IF OBJECT_ID('dbo.PerfilPermisos', 'U') IS NOT NULL
    BEGIN
        DECLARE @PerfilAdminId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador');
        DECLARE @UsuarioAdminPermisoId INT = (SELECT TOP 1 UsuarioId FROM dbo.Usuarios ORDER BY UsuarioId);

        IF @PerfilAdminId IS NOT NULL
        BEGIN
            INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
            SELECT @PerfilAdminId, p.PermisoId, @UsuarioAdminPermisoId, 'Sistema'
            FROM dbo.Permisos p
            WHERE p.Codigo IN ('EMPLEADOS_VER', 'EMPLEADOS_CREAR', 'EMPLEADOS_EDITAR', 'EMPLEADOS_TAREAS', 'EMPLEADOS_SOLICITUDES')
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.PerfilPermisos pp
                  WHERE pp.PerfilId = @PerfilAdminId
                    AND pp.PermisoId = p.PermisoId
              );
        END;
    END;
END;
GO

/* 5. Procedimientos administrativos */
CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeRoles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT PerfilId, Nombre
    FROM dbo.Perfiles
    WHERE Activo = 1
      AND Nombre <> 'Cliente'
    ORDER BY
        CASE Nombre
            WHEN 'Empleado' THEN 1
            WHEN 'Vendedor' THEN 2
            WHEN 'Administrador' THEN 3
            ELSE 4
        END,
        Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployees
    @Buscar NVARCHAR(150) = NULL,
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        ISNULL(u.Telefono, '') AS Telefono,
        ISNULL(u.Direccion, '') AS Direccion,
        p.Nombre AS Rol,
        e.Puesto,
        ISNULL(e.Departamento, '') AS Departamento,
        ISNULL(e.Salario, 0) AS Salario,
        e.FechaContratacion,
        e.Activo,
        u.Activo AS UsuarioActivo,
        ISNULL((SELECT COUNT(1) FROM dbo.EmpleadoTareas t WHERE t.EmpleadoId = e.EmpleadoId AND t.Estado IN ('Pendiente', 'En proceso')), 0) AS TareasPendientes,
        ISNULL((SELECT COUNT(1) FROM dbo.EmpleadoSolicitudesTiempoLibre s WHERE s.EmpleadoId = e.EmpleadoId AND s.Estado = 'Pendiente'), 0) AS SolicitudesPendientes
    FROM dbo.Empleados e
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE
        (@Buscar IS NULL OR @Buscar = '' OR
            u.NombreCompleto LIKE '%' + @Buscar + '%' OR
            u.Correo LIKE '%' + @Buscar + '%' OR
            e.Puesto LIKE '%' + @Buscar + '%' OR
            ISNULL(e.Departamento, '') LIKE '%' + @Buscar + '%')
        AND (
            @Estado IS NULL OR @Estado = '' OR
            (@Estado = 'Activo' AND e.Activo = 1 AND u.Activo = 1) OR
            (@Estado = 'Inactivo' AND (e.Activo = 0 OR u.Activo = 0))
        )
    ORDER BY e.Activo DESC, u.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeById
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        u.UsuarioId,
        u.PerfilId,
        p.Nombre AS Rol,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        e.Puesto,
        e.Departamento,
        ISNULL(e.Salario, 0) AS Salario,
        e.FechaContratacion,
        e.Responsabilidades,
        e.ObservacionesInternas,
        e.Activo,
        u.Activo AS UsuarioActivo,
        u.FechaRegistro,
        e.FechaActualizacion
    FROM dbo.Empleados e
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE e.EmpleadoId = @EmpleadoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateEmployee
    @PerfilId INT,
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255),
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

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
    BEGIN
        THROW 51000, 'Ya existe un usuario registrado con ese correo.', 1;
    END;

    DECLARE @UsuarioId INT;
    DECLARE @EmpleadoId INT;

    BEGIN TRANSACTION;

    BEGIN TRY
        INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion, Activo)
        VALUES (@PerfilId, @NombreCompleto, @Correo, @Contrasena, @Telefono, @Direccion, @Activo);

        SET @UsuarioId = SCOPE_IDENTITY();

        INSERT INTO dbo.Empleados (UsuarioId, Puesto, Salario, FechaContratacion, Activo, Departamento, Responsabilidades, ObservacionesInternas, FechaActualizacion)
        VALUES (@UsuarioId, @Puesto, @Salario, @FechaContratacion, @Activo, @Departamento, @Responsabilidades, @ObservacionesInternas, SYSDATETIME());

        SET @EmpleadoId = SCOPE_IDENTITY();

        IF ISNULL(@Salario, 0) > 0
        BEGIN
            INSERT INTO dbo.EmpleadoHistorialSalarios (EmpleadoId, SalarioAnterior, SalarioNuevo, Motivo, UsuarioCambioId, UsuarioCambioNombre)
            VALUES (@EmpleadoId, NULL, @Salario, 'Salario inicial registrado.', @UsuarioCambioId, @UsuarioCambioNombre);
        END;

        COMMIT TRANSACTION;

        SELECT @EmpleadoId AS EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployee
    @EmpleadoId INT,
    @PerfilId INT,
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255) = NULL,
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(255) = NULL,
    @Puesto NVARCHAR(100),
    @Departamento NVARCHAR(100) = NULL,
    @Salario DECIMAL(18,2) = 0,
    @FechaContratacion DATE = NULL,
    @Responsabilidades NVARCHAR(MAX) = NULL,
    @ObservacionesInternas NVARCHAR(MAX) = NULL,
    @Activo BIT = 1,
    @MotivoCambioSalario NVARCHAR(255) = NULL,
    @UsuarioCambioId INT = NULL,
    @UsuarioCambioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UsuarioId INT;
    DECLARE @SalarioAnterior DECIMAL(18,2);

    SELECT
        @UsuarioId = e.UsuarioId,
        @SalarioAnterior = ISNULL(e.Salario, 0)
    FROM dbo.Empleados e
    WHERE e.EmpleadoId = @EmpleadoId;

    IF @UsuarioId IS NULL
    BEGIN
        THROW 51001, 'No se encontró el empleado solicitado.', 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo AND UsuarioId <> @UsuarioId)
    BEGIN
        THROW 51002, 'Ya existe otro usuario registrado con ese correo.', 1;
    END;

    BEGIN TRANSACTION;

    BEGIN TRY
        UPDATE dbo.Usuarios
        SET PerfilId = @PerfilId,
            NombreCompleto = @NombreCompleto,
            Correo = @Correo,
            Telefono = @Telefono,
            Direccion = @Direccion,
            Activo = @Activo
        WHERE UsuarioId = @UsuarioId;

        IF @Contrasena IS NOT NULL AND LTRIM(RTRIM(@Contrasena)) <> ''
        BEGIN
            UPDATE dbo.Usuarios
            SET Contrasena = @Contrasena
            WHERE UsuarioId = @UsuarioId;
        END;

        UPDATE dbo.Empleados
        SET Puesto = @Puesto,
            Departamento = @Departamento,
            Salario = @Salario,
            FechaContratacion = @FechaContratacion,
            Responsabilidades = @Responsabilidades,
            ObservacionesInternas = @ObservacionesInternas,
            Activo = @Activo,
            FechaActualizacion = SYSDATETIME()
        WHERE EmpleadoId = @EmpleadoId;

        IF ISNULL(@SalarioAnterior, 0) <> ISNULL(@Salario, 0)
        BEGIN
            INSERT INTO dbo.EmpleadoHistorialSalarios (EmpleadoId, SalarioAnterior, SalarioNuevo, Motivo, UsuarioCambioId, UsuarioCambioNombre)
            VALUES (@EmpleadoId, @SalarioAnterior, @Salario, NULLIF(@MotivoCambioSalario, ''), @UsuarioCambioId, @UsuarioCambioNombre);
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleEmployeeStatus
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UsuarioId INT;
    DECLARE @NuevoEstado BIT;

    SELECT @UsuarioId = UsuarioId, @NuevoEstado = CASE WHEN Activo = 1 THEN 0 ELSE 1 END
    FROM dbo.Empleados
    WHERE EmpleadoId = @EmpleadoId;

    IF @UsuarioId IS NULL
    BEGIN
        THROW 51003, 'No se encontró el empleado solicitado.', 1;
    END;

    UPDATE dbo.Empleados
    SET Activo = @NuevoEstado,
        FechaActualizacion = SYSDATETIME()
    WHERE EmpleadoId = @EmpleadoId;

    UPDATE dbo.Usuarios
    SET Activo = @NuevoEstado
    WHERE UsuarioId = @UsuarioId;

    SELECT @NuevoEstado AS Activo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeTasks
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TareaId,
        EmpleadoId,
        Titulo,
        Descripcion,
        Prioridad,
        Estado,
        FechaAsignacion,
        FechaLimite,
        UsuarioAsignacionNombre,
        FechaActualizacion
    FROM dbo.EmpleadoTareas
    WHERE EmpleadoId = @EmpleadoId
    ORDER BY
        CASE Estado WHEN 'Pendiente' THEN 1 WHEN 'En proceso' THEN 2 WHEN 'Completada' THEN 3 ELSE 4 END,
        CASE Prioridad WHEN 'Urgente' THEN 1 WHEN 'Alta' THEN 2 WHEN 'Media' THEN 3 ELSE 4 END,
        FechaAsignacion DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateEmployeeTask
    @EmpleadoId INT,
    @Titulo NVARCHAR(150),
    @Descripcion NVARCHAR(700) = NULL,
    @Prioridad NVARCHAR(20),
    @FechaLimite DATE = NULL,
    @UsuarioAsignacionId INT = NULL,
    @UsuarioAsignacionNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Empleados WHERE EmpleadoId = @EmpleadoId)
    BEGIN
        THROW 51004, 'No se encontró el empleado solicitado.', 1;
    END;

    INSERT INTO dbo.EmpleadoTareas (EmpleadoId, Titulo, Descripcion, Prioridad, Estado, FechaLimite, UsuarioAsignacionId, UsuarioAsignacionNombre)
    VALUES (@EmpleadoId, @Titulo, @Descripcion, @Prioridad, 'Pendiente', @FechaLimite, @UsuarioAsignacionId, @UsuarioAsignacionNombre);

    SELECT SCOPE_IDENTITY() AS TareaId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployeeTaskStatus
    @TareaId INT,
    @Estado NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.EmpleadoTareas WHERE TareaId = @TareaId)
    BEGIN
        THROW 51005, 'No se encontró la tarea solicitada.', 1;
    END;

    UPDATE dbo.EmpleadoTareas
    SET Estado = @Estado,
        FechaActualizacion = SYSDATETIME()
    WHERE TareaId = @TareaId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeLeaveRequests
    @Estado NVARCHAR(30) = NULL,
    @EmpleadoId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SolicitudId,
        s.EmpleadoId,
        u.NombreCompleto,
        u.Correo,
        e.Puesto,
        s.FechaInicio,
        s.FechaFin,
        s.CantidadDias,
        s.TipoSolicitud,
        s.Motivo,
        s.Estado,
        s.RespuestaAdmin,
        s.UsuarioRespuestaNombre,
        s.FechaSolicitud,
        s.FechaRespuesta
    FROM dbo.EmpleadoSolicitudesTiempoLibre s
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = s.EmpleadoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    WHERE (@Estado IS NULL OR @Estado = '' OR s.Estado = @Estado)
      AND (@EmpleadoId IS NULL OR s.EmpleadoId = @EmpleadoId)
    ORDER BY
        CASE s.Estado WHEN 'Pendiente' THEN 1 WHEN 'Aprobada' THEN 2 WHEN 'Rechazada' THEN 3 ELSE 4 END,
        s.FechaSolicitud DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployeeLeaveRequestStatus
    @SolicitudId INT,
    @Estado NVARCHAR(30),
    @RespuestaAdmin NVARCHAR(500) = NULL,
    @UsuarioRespuestaId INT = NULL,
    @UsuarioRespuestaNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.EmpleadoSolicitudesTiempoLibre WHERE SolicitudId = @SolicitudId)
    BEGIN
        THROW 51006, 'No se encontró la solicitud indicada.', 1;
    END;

    UPDATE dbo.EmpleadoSolicitudesTiempoLibre
    SET Estado = @Estado,
        RespuestaAdmin = @RespuestaAdmin,
        UsuarioRespuestaId = @UsuarioRespuestaId,
        UsuarioRespuestaNombre = @UsuarioRespuestaNombre,
        FechaRespuesta = SYSDATETIME()
    WHERE SolicitudId = @SolicitudId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeSalaryHistory
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        HistorialSalarioId,
        EmpleadoId,
        SalarioAnterior,
        SalarioNuevo,
        Motivo,
        UsuarioCambioNombre,
        FechaCambio
    FROM dbo.EmpleadoHistorialSalarios
    WHERE EmpleadoId = @EmpleadoId
    ORDER BY FechaCambio DESC;
END;
GO

/* 6. Procedimientos del portal del empleado */
CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetMyProfile
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        p.Nombre AS Rol,
        e.Puesto,
        e.Departamento,
        ISNULL(e.Salario, 0) AS Salario,
        e.FechaContratacion,
        e.Responsabilidades,
        e.Activo,
        u.Activo AS UsuarioActivo
    FROM dbo.Empleados e
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE u.UsuarioId = @UsuarioId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_CreateLeaveRequest
    @UsuarioId INT,
    @FechaInicio DATE,
    @FechaFin DATE,
    @TipoSolicitud NVARCHAR(30),
    @Motivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpleadoId INT;
    DECLARE @CantidadDias INT;

    SELECT @EmpleadoId = EmpleadoId
    FROM dbo.Empleados
    WHERE UsuarioId = @UsuarioId AND Activo = 1;

    IF @EmpleadoId IS NULL
    BEGIN
        THROW 51007, 'No se encontró un perfil de empleado activo para el usuario actual.', 1;
    END;

    IF @FechaFin < @FechaInicio
    BEGIN
        THROW 51008, 'La fecha final no puede ser menor a la fecha inicial.', 1;
    END;

    SET @CantidadDias = DATEDIFF(DAY, @FechaInicio, @FechaFin) + 1;

    INSERT INTO dbo.EmpleadoSolicitudesTiempoLibre (EmpleadoId, FechaInicio, FechaFin, CantidadDias, TipoSolicitud, Motivo, Estado)
    VALUES (@EmpleadoId, @FechaInicio, @FechaFin, @CantidadDias, @TipoSolicitud, @Motivo, 'Pendiente');

    SELECT SCOPE_IDENTITY() AS SolicitudId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_UpdateMyTaskStatus
    @UsuarioId INT,
    @TareaId INT,
    @Estado NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.EmpleadoTareas t
        INNER JOIN dbo.Empleados e ON e.EmpleadoId = t.EmpleadoId
        WHERE t.TareaId = @TareaId
          AND e.UsuarioId = @UsuarioId
    )
    BEGIN
        THROW 51009, 'No se encontró la tarea para el usuario actual.', 1;
    END;

    UPDATE dbo.EmpleadoTareas
    SET Estado = @Estado,
        FechaActualizacion = SYSDATETIME()
    WHERE TareaId = @TareaId;
END;
GO

PRINT 'CU-080 empleados aplicado correctamente.';
GO
