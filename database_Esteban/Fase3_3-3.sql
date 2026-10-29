-- ============================================================
-- FASE 3 — BLOQUE 3/3
-- Módulos: Roles, Permisos, Empleados (Admin + Portal),
--          Historial Salarial, Tareas, Solicitudes, Auditoría
-- CREATE OR ALTER — idempotente.
-- Prerequisito: Bloques 1 y 2 ejecutados sin errores.
/* ADVERTENCIA P0: archivo historico con operaciones destructivas.
   No ejecutar contra Azure SQL DEV. Requiere respaldo y aprobacion explicita. */
-- ============================================================

USE DistribuidoraJJ_DB;
GO

-- ===========================================================
-- MÓDULO: ROLES
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRoles
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PerfilId,
        p.Nombre,
        p.Descripcion,
        p.Activo,
        p.FechaCreacion,
        (SELECT COUNT(*) FROM dbo.Usuarios u
         WHERE u.PerfilId = p.PerfilId AND u.Activo = 1) AS TotalUsuariosActivos
    FROM dbo.Perfiles p
    ORDER BY p.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRoleById
    @PerfilId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PerfilId, Nombre, Descripcion, Activo, FechaCreacion
    FROM dbo.Perfiles
    WHERE PerfilId = @PerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateRole
    @Nombre      NVARCHAR(50),
    @Descripcion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = @Nombre)
    BEGIN
        RAISERROR(N'Ya existe un rol con ese nombre.', 16, 1);
        RETURN;
    END
    INSERT INTO dbo.Perfiles (Nombre, Descripcion) VALUES (@Nombre, @Descripcion);
    SELECT SCOPE_IDENTITY() AS PerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateRole
    @PerfilId    INT,
    @Nombre      NVARCHAR(50),
    @Descripcion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM dbo.Perfiles
        WHERE Nombre = @Nombre AND PerfilId <> @PerfilId
    )
    BEGIN
        RAISERROR(N'Ya existe otro rol con ese nombre.', 16, 1);
        RETURN;
    END
    UPDATE dbo.Perfiles
    SET Nombre = @Nombre, Descripcion = @Descripcion
    WHERE PerfilId = @PerfilId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleRoleStatus
    @PerfilId INT,
    @Activo   BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Perfiles SET Activo = @Activo WHERE PerfilId = @PerfilId;
END
GO

-- ===========================================================
-- MÓDULO: PERMISOS
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetAllPermissions
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PermisoId, Codigo, Modulo, Nombre, Descripcion, Activo, FechaCreacion
    FROM dbo.Permisos
    WHERE Activo = 1
    ORDER BY Modulo, Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetRolePermissions
    @PerfilId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        per.PermisoId,
        per.Codigo,
        per.Modulo,
        per.Nombre,
        per.Descripcion,
        CASE WHEN pp.PerfilId IS NOT NULL THEN 1 ELSE 0 END AS Asignado,
        pp.FechaAsignacion,
        pp.UsuarioAsignacionNombre
    FROM dbo.Permisos per
    LEFT JOIN dbo.PerfilPermisos pp
           ON pp.PermisoId = per.PermisoId
          AND pp.PerfilId  = @PerfilId
    WHERE per.Activo = 1
    ORDER BY per.Modulo, per.Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateRolePermissions
    @PerfilId                INT,
    @PermisoIds              NVARCHAR(MAX),   -- CSV: "1,3,7" — cadena vacía = revocar t
    @UsuarioAsignacionId     INT,
    @UsuarioAsignacionNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        CREATE TABLE #NuevosPermisos (PermisoId INT);

        IF LTRIM(RTRIM(@PermisoIds)) <> ''
            INSERT INTO #NuevosPermisos (PermisoId)
            SELECT CAST(LTRIM(RTRIM(value)) AS INT)
            FROM STRING_SPLIT(@PermisoIds, ',')
            WHERE LTRIM(RTRIM(value)) <> '';

        -- Eliminar los que ya no están en la lista
        DELETE FROM dbo.PerfilPermisos
        WHERE PerfilId  = @PerfilId
          AND PermisoId NOT IN (SELECT PermisoId FROM #NuevosPermisos);

        -- Agregar los que aún no están asignados
        INSERT INTO dbo.PerfilPermisos
            (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
        SELECT
            @PerfilId, n.PermisoId, @UsuarioAsignacionId, @UsuarioAsignacionNombre
        FROM #NuevosPermisos n
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.PerfilPermisos pp
            WHERE pp.PerfilId = @PerfilId AND pp.PermisoId = n.PermisoId
        );

        DROP TABLE #NuevosPermisos;
        COMMIT;
        SELECT 1 AS Exito;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        IF OBJECT_ID('tempdb..#NuevosPermisos') IS NOT NULL
            DROP TABLE #NuevosPermisos;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_HasPermissionByCode
    @UsuarioId INT,
    @Codigo    NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.PerfilPermisos pp
            INNER JOIN dbo.Permisos per ON per.PermisoId = pp.PermisoId
            INNER JOIN dbo.Usuarios u   ON u.PerfilId    = pp.PerfilId
            WHERE u.UsuarioId  = @UsuarioId
              AND per.Codigo   = @Codigo
              AND per.Activo   = 1
        ) THEN 1 ELSE 0
    END AS TienePermiso;
END
GO

-- ===========================================================
-- MÓDULO: EMPLEADOS (ADMINISTRACIÓN)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeRoles
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PerfilId, Nombre
    FROM dbo.Perfiles
    WHERE Nombre IN (N'Empleado', N'Vendedor', N'Gerente', N'Administrador')
      AND Activo = 1
    ORDER BY Nombre;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployees
    @Filtro      NVARCHAR(100) = NULL,
    @SoloActivos BIT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.EmpleadoId,
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        e.Puesto,
        e.Departamento,
        e.Salario,
        e.FechaContratacion,
        e.Activo,
        p.Nombre AS NombrePerfil,
        u.FechaRegistro
    FROM dbo.Empleados e
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    INNER JOIN dbo.Perfiles p ON p.PerfilId  = u.PerfilId
    WHERE (@SoloActivos IS NULL OR e.Activo  = @SoloActivos)
      AND (@Filtro IS NULL
           OR u.NombreCompleto LIKE N'%' + @Filtro + N'%'
           OR e.Puesto         LIKE N'%' + @Filtro + N'%'
           OR e.Departamento   LIKE N'%' + @Filtro + N'%')
    ORDER BY u.NombreCompleto;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeById
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.EmpleadoId, u.UsuarioId,
        u.NombreCompleto, u.Correo, u.Telefono, u.Direccion,
        e.Puesto, e.Departamento, e.Salario, e.FechaContratacion,
        e.Activo, e.Responsabilidades, e.ObservacionesInternas,
        p.PerfilId, p.Nombre AS NombrePerfil,
        u.FechaRegistro
    FROM dbo.Empleados e
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
    INNER JOIN dbo.Perfiles p ON p.PerfilId  = u.PerfilId
    WHERE e.EmpleadoId = @EmpleadoId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateEmployee
    @NombreCompleto        NVARCHAR(150),
    @Correo                NVARCHAR(150),
    @Contrasena            NVARCHAR(255),
    @Telefono              NVARCHAR(30)  = NULL,
    @Direccion             NVARCHAR(255) = NULL,
    @PerfilId              INT,
    @Puesto                NVARCHAR(100),
    @Departamento          NVARCHAR(100) = NULL,
    @Salario               DECIMAL(18,2) = NULL,
    @FechaContratacion     DATE          = NULL,
    @Responsabilidades     NVARCHAR(MAX) = NULL,
    @ObservacionesInternas NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
        BEGIN
            RAISERROR(N'El correo ya está registrado.', 16, 1);
            ROLLBACK; RETURN;
        END

        INSERT INTO dbo.Usuarios
            (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
        VALUES
            (@PerfilId, @NombreCompleto, @Correo, @Contrasena, @Telefono, @Direccion);

        DECLARE @UsuarioId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Empleados
            (UsuarioId, Puesto, Departamento, Salario, FechaContratacion,
             Responsabilidades, ObservacionesInternas)
        VALUES
            (@UsuarioId, @Puesto, @Departamento, @Salario, @FechaContratacion,
             @Responsabilidades, @ObservacionesInternas);

        DECLARE @EmpleadoId INT = SCOPE_IDENTITY();

        IF @Salario IS NOT NULL
            INSERT INTO dbo.EmpleadoHistorialSalarios
                (EmpleadoId, SalarioAnterior, SalarioNuevo, Motivo)
            VALUES
                (@EmpleadoId, NULL, @Salario, N'Salario inicial al contratar');

        COMMIT;
        SELECT @EmpleadoId AS EmpleadoId, @UsuarioId AS UsuarioId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployee
    @EmpleadoId            INT,
    @NombreCompleto        NVARCHAR(150),
    @Telefono              NVARCHAR(30)  = NULL,
    @Direccion             NVARCHAR(255) = NULL,
    @PerfilId              INT,
    @Puesto                NVARCHAR(100),
    @Departamento          NVARCHAR(100) = NULL,
    @Salario               DECIMAL(18,2) = NULL,
    @FechaContratacion     DATE          = NULL,
    @Responsabilidades     NVARCHAR(MAX) = NULL,
    @ObservacionesInternas NVARCHAR(MAX) = NULL,
    @UsuarioCambioId       INT           = NULL,
    @UsuarioCambioNombre   NVARCHAR(150) = NULL,
    @MotivoSalario         NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @UsuarioId      INT;
        DECLARE @SalarioActual  DECIMAL(18,2);

        SELECT @UsuarioId = UsuarioId, @SalarioActual = Salario
        FROM dbo.Empleados WHERE EmpleadoId = @EmpleadoId;

        UPDATE dbo.Usuarios
        SET NombreCompleto     = @NombreCompleto,
            Telefono           = @Telefono,
            Direccion          = @Direccion,
            PerfilId           = @PerfilId,
            FechaActualizacion = SYSDATETIME()
        WHERE UsuarioId = @UsuarioId;

        UPDATE dbo.Empleados
        SET Puesto                = @Puesto,
            Departamento          = @Departamento,
            Salario               = @Salario,
            FechaContratacion     = @FechaContratacion,
            Responsabilidades     = @Responsabilidades,
            ObservacionesInternas = @ObservacionesInternas,
            FechaActualizacion    = SYSDATETIME()
        WHERE EmpleadoId = @EmpleadoId;

        -- Registrar cambio salarial solo si el valor cambió
        IF @Salario IS NOT NULL
           AND ISNULL(@SalarioActual, -1) <> @Salario
            INSERT INTO dbo.EmpleadoHistorialSalarios
                (EmpleadoId, UsuarioCambioId, SalarioAnterior,
                 SalarioNuevo, Motivo, UsuarioCambioNombre)
            VALUES
                (@EmpleadoId, @UsuarioCambioId, @SalarioActual,
                 @Salario, @MotivoSalario, @UsuarioCambioNombre);

        COMMIT;
        SELECT 1 AS Exito;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK; THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_ToggleEmployeeStatus
    @EmpleadoId         INT,
    @Activo             BIT,
    @MotivoInactivacion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UsuarioId INT = (
        SELECT UsuarioId FROM dbo.Empleados WHERE EmpleadoId = @EmpleadoId
    );

    UPDATE dbo.Empleados
    SET Activo = @Activo, FechaActualizacion = SYSDATETIME()
    WHERE EmpleadoId = @EmpleadoId;

    UPDATE dbo.Usuarios
    SET Activo             = @Activo,
        MotivoInactivacion = CASE WHEN @Activo = 0 THEN @MotivoInactivacion ELSE NULL END,
        FechaInactivacion  = CASE WHEN @Activo = 0 THEN SYSDATETIME()       ELSE NULL END,
        FechaActualizacion = SYSDATETIME()
    WHERE UsuarioId = @UsuarioId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeSalaryHistory
    @EmpleadoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.HistorialSalarioId,
        h.SalarioAnterior,
        h.SalarioNuevo,
        h.Motivo,
        h.UsuarioCambioNombre,
        h.FechaCambio
    FROM dbo.EmpleadoHistorialSalarios h
    WHERE h.EmpleadoId = @EmpleadoId
    ORDER BY h.FechaCambio DESC;
END
GO

-- ===========================================================
-- MÓDULO: TAREAS DE EMPLEADO
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeTasks
    @EmpleadoId INT          = NULL,
    @Estado     NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.TareaId,
        t.EmpleadoId,
        u.NombreCompleto        AS EmpleadoNombre,
        t.Titulo,
        t.Descripcion,
        t.Prioridad,
        t.Estado,
        t.FechaAsignacion,
        t.FechaLimite,
        t.UsuarioAsignacionNombre,
        t.FechaActualizacion
    FROM dbo.EmpleadoTareas t
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = t.EmpleadoId
    INNER JOIN dbo.Usuarios  u ON u.UsuarioId  = e.UsuarioId
    WHERE (@EmpleadoId IS NULL OR t.EmpleadoId = @EmpleadoId)
      AND (@Estado     IS NULL OR t.Estado     = @Estado)
    ORDER BY
        CASE t.Prioridad
            WHEN N'Urgente' THEN 1
            WHEN N'Alta'    THEN 2
            WHEN N'Media'   THEN 3
            ELSE 4
        END,
        t.FechaAsignacion DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateEmployeeTask
    @EmpleadoId              INT,
    @Titulo                  NVARCHAR(150),
    @Descripcion             NVARCHAR(700) = NULL,
    @Prioridad               NVARCHAR(20)  = N'Media',
    @FechaLimite             DATE          = NULL,
    @UsuarioAsignacionId     INT,
    @UsuarioAsignacionNombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.EmpleadoTareas
        (EmpleadoId, Titulo, Descripcion, Prioridad, FechaLimite,
         UsuarioAsignacionId, UsuarioAsignacionNombre)
    VALUES
        (@EmpleadoId, @Titulo, @Descripcion, @Prioridad, @FechaLimite,
         @UsuarioAsignacionId, @UsuarioAsignacionNombre);

    SELECT SCOPE_IDENTITY() AS TareaId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployeeTaskStatus
    @TareaId INT,
    @Estado  NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.EmpleadoTareas
    SET Estado = @Estado, FechaActualizacion = SYSDATETIME()
    WHERE TareaId = @TareaId;
END
GO

-- ===========================================================
-- MÓDULO: SOLICITUDES DE TIEMPO LIBRE
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetEmployeeLeaveRequests
    @EmpleadoId INT          = NULL,
    @Estado     NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.SolicitudId,
        s.EmpleadoId,
        u.NombreCompleto       AS EmpleadoNombre,
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
    INNER JOIN dbo.Usuarios  u ON u.UsuarioId  = e.UsuarioId
    WHERE (@EmpleadoId IS NULL OR s.EmpleadoId = @EmpleadoId)
      AND (@Estado     IS NULL OR s.Estado     = @Estado)
    ORDER BY s.FechaSolicitud DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateEmployeeLeaveRequestStatus
    @SolicitudId             INT,
    @Estado                  NVARCHAR(30),
    @RespuestaAdmin          NVARCHAR(500) = NULL,
    @UsuarioRespuestaId      INT,
    @UsuarioRespuestaNombre  NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.EmpleadoSolicitudesTiempoLibre
    SET Estado                 = @Estado,
        RespuestaAdmin         = @RespuestaAdmin,
        UsuarioRespuestaId     = @UsuarioRespuestaId,
        UsuarioRespuestaNombre = @UsuarioRespuestaNombre,
        FechaRespuesta         = SYSDATETIME()
    WHERE SolicitudId = @SolicitudId;
END
GO

-- ===========================================================
-- MÓDULO: PORTAL DEL EMPLEADO (autoservicio)
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetMyProfile
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Datos personales y laborales
    SELECT
        u.UsuarioId, u.NombreCompleto, u.Correo, u.Telefono, u.Direccion,
        p.Nombre       AS NombrePerfil,
        e.EmpleadoId,  e.Puesto, e.Departamento, e.Salario,
        e.FechaContratacion, e.Responsabilidades
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles  p ON p.PerfilId  = u.PerfilId
    LEFT  JOIN dbo.Empleados e ON e.UsuarioId = u.UsuarioId
    WHERE u.UsuarioId = @UsuarioId;

    -- Tareas activas (pendientes o en proceso)
    SELECT
        t.TareaId, t.Titulo, t.Descripcion,
        t.Prioridad, t.Estado, t.FechaAsignacion, t.FechaLimite
    FROM dbo.EmpleadoTareas t
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = t.EmpleadoId
    WHERE e.UsuarioId = @UsuarioId
      AND t.Estado NOT IN (N'Completada', N'Cancelada')
    ORDER BY
        CASE t.Prioridad
            WHEN N'Urgente' THEN 1
            WHEN N'Alta'    THEN 2
            WHEN N'Media'   THEN 3
            ELSE 4
        END,
        t.FechaLimite ASC;

    -- Solicitudes de tiempo libre recientes
    SELECT TOP 5
        s.SolicitudId, s.FechaInicio, s.FechaFin,
        s.CantidadDias, s.TipoSolicitud, s.Estado, s.FechaSolicitud
    FROM dbo.EmpleadoSolicitudesTiempoLibre s
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = s.EmpleadoId
    WHERE e.UsuarioId = @UsuarioId
    ORDER BY s.FechaSolicitud DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetMyTasks
    @UsuarioId INT,
    @Estado    NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.TareaId, t.Titulo, t.Descripcion,
        t.Prioridad, t.Estado,
        t.FechaAsignacion, t.FechaLimite,
        t.UsuarioAsignacionNombre, t.FechaActualizacion
    FROM dbo.EmpleadoTareas t
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = t.EmpleadoId
    WHERE e.UsuarioId = @UsuarioId
      AND (@Estado IS NULL OR t.Estado = @Estado)
    ORDER BY
        CASE t.Prioridad
            WHEN N'Urgente' THEN 1
            WHEN N'Alta'    THEN 2
            WHEN N'Media'   THEN 3
            ELSE 4
        END,
        t.FechaLimite ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_UpdateMyTaskStatus
    @TareaId   INT,
    @UsuarioId INT,
    @Estado    NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoId INT = (
        SELECT EmpleadoId FROM dbo.Empleados WHERE UsuarioId = @UsuarioId
    );

    IF @EmpleadoId IS NULL
    BEGIN
        RAISERROR(N'Perfil de empleado no encontrado.', 16, 1);
        RETURN;
    END

    UPDATE dbo.EmpleadoTareas
    SET Estado = @Estado, FechaActualizacion = SYSDATETIME()
    WHERE TareaId    = @TareaId
      AND EmpleadoId = @EmpleadoId;

    IF @@ROWCOUNT = 0
        RAISERROR(N'Tarea no encontrada o sin permiso para modificarla.', 16, 1);
    ELSE
        SELECT 1 AS Exito;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetMyLeaveRequests
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.SolicitudId, s.FechaInicio, s.FechaFin, s.CantidadDias,
        s.TipoSolicitud, s.Motivo, s.Estado, s.RespuestaAdmin,
        s.UsuarioRespuestaNombre, s.FechaSolicitud, s.FechaRespuesta
    FROM dbo.EmpleadoSolicitudesTiempoLibre s
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = s.EmpleadoId
    WHERE e.UsuarioId = @UsuarioId
    ORDER BY s.FechaSolicitud DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_CreateLeaveRequest
    @UsuarioId     INT,
    @FechaInicio   DATE,
    @FechaFin      DATE,
    @CantidadDias  INT,
    @TipoSolicitud NVARCHAR(30),
    @Motivo        NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoId INT = (
        SELECT EmpleadoId FROM dbo.Empleados WHERE UsuarioId = @UsuarioId
    );

    IF @EmpleadoId IS NULL
    BEGIN
        RAISERROR(N'Perfil de empleado no encontrado.', 16, 1);
        RETURN;
    END

    IF @FechaFin < @FechaInicio
    BEGIN
        RAISERROR(N'La fecha de fin no puede ser anterior a la de inicio.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.EmpleadoSolicitudesTiempoLibre
        (EmpleadoId, FechaInicio, FechaFin, CantidadDias, TipoSolicitud, Motivo)
    VALUES
        (@EmpleadoId, @FechaInicio, @FechaFin, @CantidadDias, @TipoSolicitud, @Motivo);

    SELECT SCOPE_IDENTITY() AS SolicitudId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetMySalaryHistory
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.HistorialSalarioId,
        h.SalarioAnterior,
        h.SalarioNuevo,
        h.Motivo,
        h.UsuarioCambioNombre,
        h.FechaCambio
    FROM dbo.EmpleadoHistorialSalarios h
    INNER JOIN dbo.Empleados e ON e.EmpleadoId = h.EmpleadoId
    WHERE e.UsuarioId = @UsuarioId
    ORDER BY h.FechaCambio DESC;
END
GO

-- ===========================================================
-- MÓDULO: AUDITORÍA
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Admin_CreateAuditLog
    @UsuarioId     INT           = NULL,
    @UsuarioNombre NVARCHAR(150),
    @UsuarioCorreo NVARCHAR(150),
    @Rol           NVARCHAR(50),
    @Accion        NVARCHAR(80),
    @Modulo        NVARCHAR(80),
    @Descripcion   NVARCHAR(500),
    @DireccionIp   NVARCHAR(80)  = NULL,
    @UserAgent     NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditoriaSistema
        (UsuarioId, UsuarioNombre, UsuarioCorreo, Rol,
         Accion, Modulo, Descripcion, DireccionIp, UserAgent)
    VALUES
        (@UsuarioId, @UsuarioNombre, @UsuarioCorreo, @Rol,
         @Accion, @Modulo, @Descripcion, @DireccionIp, @UserAgent);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetAuditLogs
    @Modulo NVARCHAR(80)  = NULL,
    @Accion NVARCHAR(80)  = NULL,
    @Desde  DATE          = NULL,
    @Hasta  DATE          = NULL,
    @Filtro NVARCHAR(100) = NULL,
    @Top    INT           = 200
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Top)
        a.AuditoriaId,
        a.UsuarioNombre,
        a.UsuarioCorreo,
        a.Rol,
        a.Accion,
        a.Modulo,
        a.Descripcion,
        a.DireccionIp,
        a.FechaRegistro
    FROM dbo.AuditoriaSistema a
    WHERE (@Modulo IS NULL OR a.Modulo = @Modulo)
      AND (@Accion IS NULL OR a.Accion = @Accion)
      AND (@Desde  IS NULL OR CAST(a.FechaRegistro AS DATE) >= @Desde)
      AND (@Hasta  IS NULL OR CAST(a.FechaRegistro AS DATE) <= @Hasta)
      AND (@Filtro IS NULL
           OR a.UsuarioNombre LIKE N'%' + @Filtro + N'%'
           OR a.Descripcion   LIKE N'%' + @Filtro + N'%'
           OR a.UsuarioCorreo LIKE N'%' + @Filtro + N'%')
    ORDER BY a.FechaRegistro DESC;
END
GO

-- Verificación final: contar todos los SPs del sistema
SELECT
    COUNT(*) AS TotalStoredProcedures
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'dbo'
  AND name LIKE N'sp_%';
GO

PRINT '✔️ FASE 3 completada — todos los stored procedures del sistema creados.';
GO
