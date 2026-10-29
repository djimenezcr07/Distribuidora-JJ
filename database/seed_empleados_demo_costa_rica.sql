USE DistribuidoraJJ_DB;
GO

/* =========================================================
   Sprint 3 - Datos demo Costa Rica para módulo de empleados
   Objetivo:
   - Poblar el nuevo módulo de empleados con información ficticia.
   - Mostrar empleados, salarios, tareas y solicitudes de días libres.
   - Script seguro: no elimina datos y evita duplicados por correo/título.

   Requisito previo:
   - Ejecutar antes database/cu080_empleados_gestion_patch.sql
   ========================================================= */

IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
    THROW 52000, 'No existe dbo.Usuarios. Verifique la base de datos.', 1;

IF OBJECT_ID('dbo.Perfiles', 'U') IS NULL
    THROW 52001, 'No existe dbo.Perfiles. Verifique la base de datos.', 1;

IF OBJECT_ID('dbo.Empleados', 'U') IS NULL
    THROW 52002, 'No existe dbo.Empleados. Verifique la base de datos.', 1;

IF COL_LENGTH('dbo.Empleados', 'Departamento') IS NULL
    THROW 52003, 'Falta la columna Empleados.Departamento. Ejecute primero cu080_empleados_gestion_patch.sql.', 1;

IF OBJECT_ID('dbo.EmpleadoTareas', 'U') IS NULL
    THROW 52004, 'No existe dbo.EmpleadoTareas. Ejecute primero cu080_empleados_gestion_patch.sql.', 1;

IF OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre', 'U') IS NULL
    THROW 52005, 'No existe dbo.EmpleadoSolicitudesTiempoLibre. Ejecute primero cu080_empleados_gestion_patch.sql.', 1;

IF OBJECT_ID('dbo.EmpleadoHistorialSalarios', 'U') IS NULL
    THROW 52006, 'No existe dbo.EmpleadoHistorialSalarios. Ejecute primero cu080_empleados_gestion_patch.sql.', 1;
GO

/* Asegurar roles requeridos */
IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Empleado')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES ('Empleado', 'Rol para personal interno de la distribuidora.', 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Vendedor')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES ('Vendedor', 'Rol para vendedores que registran pedidos desde móvil.', 1);
END;
GO

DECLARE @DemoPassword NVARCHAR(256) = N'<SET_AT_EXECUTION>';
IF @DemoPassword = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 52008, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

DECLARE @UsuarioAdminId INT = (SELECT TOP 1 UsuarioId FROM dbo.Usuarios WHERE Correo = 'admin@distribuidorajj.com' ORDER BY UsuarioId);
DECLARE @UsuarioAdminNombre NVARCHAR(150) = ISNULL((SELECT TOP 1 NombreCompleto FROM dbo.Usuarios WHERE UsuarioId = @UsuarioAdminId), 'Sistema');

DECLARE @EmpleadosDemo TABLE (
    NombreCompleto NVARCHAR(150),
    Correo NVARCHAR(150),
    Telefono NVARCHAR(30),
    Direccion NVARCHAR(255),
    Rol NVARCHAR(50),
    Puesto NVARCHAR(100),
    Departamento NVARCHAR(100),
    Salario DECIMAL(18,2),
    FechaContratacion DATE,
    Responsabilidades NVARCHAR(MAX),
    ObservacionesInternas NVARCHAR(MAX)
);

INSERT INTO @EmpleadosDemo
(NombreCompleto, Correo, Telefono, Direccion, Rol, Puesto, Departamento, Salario, FechaContratacion, Responsabilidades, ObservacionesInternas)
VALUES
('María Fernanda Vargas', 'maria.vargas@distribuidorajj.com', '8888-1201', 'San Joaquín de Flores, Heredia', 'Empleado', 'Supervisora de inventario', 'Inventario', 625000, DATEADD(MONTH, -20, CAST(GETDATE() AS DATE)), 'Revisar existencias, validar stock mínimo, coordinar conteos físicos y reportar diferencias de inventario.', 'Empleado demo creado para pruebas del Sprint 3.'),
('José Andrés Solano', 'jose.solano@distribuidorajj.com', '8888-1202', 'San Rafael, Alajuela', 'Vendedor', 'Vendedor ruta GAM', 'Ventas', 520000, DATEADD(MONTH, -15, CAST(GETDATE() AS DATE)), 'Registrar pedidos móviles, visitar clientes comerciales, confirmar entregas y reportar oportunidades de venta.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Valeria Mora Castillo', 'valeria.mora@distribuidorajj.com', '8888-1203', 'Barva, Heredia', 'Empleado', 'Auxiliar de facturación', 'Facturación', 480000, DATEADD(MONTH, -12, CAST(GETDATE() AS DATE)), 'Emitir facturas, revisar datos fiscales, validar totales de pedidos y apoyar cierres diarios.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Kevin Rojas Brenes', 'kevin.rojas@distribuidorajj.com', '8888-1204', 'La Ribera de Belén, Heredia', 'Empleado', 'Encargado de bodega', 'Bodega', 500000, DATEADD(MONTH, -18, CAST(GETDATE() AS DATE)), 'Preparar pedidos, coordinar despacho, revisar entradas de producto y mantener orden de bodega.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Daniela Chaves Soto', 'daniela.chaves@distribuidorajj.com', '8888-1205', 'San Pablo, Heredia', 'Empleado', 'Ejecutiva de atención al cliente', 'Atención al cliente', 470000, DATEADD(MONTH, -10, CAST(GETDATE() AS DATE)), 'Atender consultas, dar seguimiento a pedidos, registrar solicitudes y escalar casos administrativos.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Bryan Castro Méndez', 'bryan.castro@distribuidorajj.com', '8888-1206', 'Guácima, Alajuela', 'Empleado', 'Chofer repartidor', 'Logística', 455000, DATEADD(MONTH, -9, CAST(GETDATE() AS DATE)), 'Realizar entregas, confirmar recepción del cliente, reportar atrasos y cuidar la unidad asignada.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Sofía Hernández Alfaro', 'sofia.hernandez@distribuidorajj.com', '8888-1207', 'Santo Domingo, Heredia', 'Empleado', 'Analista de crédito', 'Créditos', 560000, DATEADD(MONTH, -16, CAST(GETDATE() AS DATE)), 'Revisar límites de crédito, registrar abonos, validar deudas y apoyar bloqueos preventivos.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Andrés Jiménez Araya', 'andres.jimenez@distribuidorajj.com', '8888-1208', 'Tibás, San José', 'Empleado', 'Asistente de compras', 'Compras', 450000, DATEADD(MONTH, -7, CAST(GETDATE() AS DATE)), 'Solicitar cotizaciones, apoyar órdenes de compra, actualizar proveedores y dar seguimiento a faltantes.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Gabriela Alpízar Rojas', 'gabriela.alpizar@distribuidorajj.com', '8888-1209', 'Mercedes Norte, Heredia', 'Empleado', 'Coordinadora de personal', 'Recursos humanos', 610000, DATEADD(MONTH, -22, CAST(GETDATE() AS DATE)), 'Gestionar expedientes, revisar solicitudes internas, apoyar inducciones y controlar documentación laboral.', 'Empleado demo creado para pruebas del Sprint 3.'),
('Mauricio Quesada Vargas', 'mauricio.quesada@distribuidorajj.com', '8888-1210', 'Alajuela Centro, Alajuela', 'Empleado', 'Asistente administrativo', 'Administración', 490000, DATEADD(MONTH, -11, CAST(GETDATE() AS DATE)), 'Apoyar reportes administrativos, revisar documentación, coordinar archivos y colaborar con cierres operativos.', 'Empleado demo creado para pruebas del Sprint 3.');

DECLARE
    @NombreCompleto NVARCHAR(150),
    @Correo NVARCHAR(150),
    @Telefono NVARCHAR(30),
    @Direccion NVARCHAR(255),
    @Rol NVARCHAR(50),
    @Puesto NVARCHAR(100),
    @Departamento NVARCHAR(100),
    @Salario DECIMAL(18,2),
    @FechaContratacion DATE,
    @Responsabilidades NVARCHAR(MAX),
    @ObservacionesInternas NVARCHAR(MAX),
    @PerfilId INT,
    @UsuarioId INT,
    @EmpleadoId INT;

DECLARE empleados_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT NombreCompleto, Correo, Telefono, Direccion, Rol, Puesto, Departamento, Salario, FechaContratacion, Responsabilidades, ObservacionesInternas
FROM @EmpleadosDemo;

OPEN empleados_cursor;
FETCH NEXT FROM empleados_cursor INTO @NombreCompleto, @Correo, @Telefono, @Direccion, @Rol, @Puesto, @Departamento, @Salario, @FechaContratacion, @Responsabilidades, @ObservacionesInternas;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @PerfilId = PerfilId FROM dbo.Perfiles WHERE Nombre = @Rol;

    IF @PerfilId IS NULL
    BEGIN
        THROW 52007, 'No se encontró el perfil requerido para empleados demo.', 1;
    END;

    SELECT @UsuarioId = UsuarioId FROM dbo.Usuarios WHERE Correo = @Correo;

    IF @UsuarioId IS NULL
    BEGIN
        INSERT INTO dbo.Usuarios (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion, Activo)
        VALUES (@PerfilId, @NombreCompleto, @Correo, @DemoPassword, @Telefono, @Direccion, 1);

        SET @UsuarioId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Usuarios
        SET PerfilId = @PerfilId,
            NombreCompleto = @NombreCompleto,
            Telefono = @Telefono,
            Direccion = @Direccion,
            Activo = 1
        WHERE UsuarioId = @UsuarioId;
    END;

    SELECT @EmpleadoId = EmpleadoId FROM dbo.Empleados WHERE UsuarioId = @UsuarioId;

    IF @EmpleadoId IS NULL
    BEGIN
        INSERT INTO dbo.Empleados (UsuarioId, Puesto, Salario, FechaContratacion, Activo, Departamento, Responsabilidades, ObservacionesInternas, FechaActualizacion)
        VALUES (@UsuarioId, @Puesto, @Salario, @FechaContratacion, 1, @Departamento, @Responsabilidades, @ObservacionesInternas, SYSDATETIME());

        SET @EmpleadoId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Empleados
        SET Puesto = @Puesto,
            Salario = @Salario,
            FechaContratacion = @FechaContratacion,
            Activo = 1,
            Departamento = @Departamento,
            Responsabilidades = @Responsabilidades,
            ObservacionesInternas = @ObservacionesInternas,
            FechaActualizacion = SYSDATETIME()
        WHERE EmpleadoId = @EmpleadoId;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.EmpleadoHistorialSalarios
        WHERE EmpleadoId = @EmpleadoId
          AND Motivo = 'Carga demo inicial Sprint 3.'
    )
    BEGIN
        INSERT INTO dbo.EmpleadoHistorialSalarios (EmpleadoId, SalarioAnterior, SalarioNuevo, Motivo, UsuarioCambioId, UsuarioCambioNombre)
        VALUES (@EmpleadoId, NULL, @Salario, 'Carga demo inicial Sprint 3.', @UsuarioAdminId, @UsuarioAdminNombre);
    END;

    FETCH NEXT FROM empleados_cursor INTO @NombreCompleto, @Correo, @Telefono, @Direccion, @Rol, @Puesto, @Departamento, @Salario, @FechaContratacion, @Responsabilidades, @ObservacionesInternas;
END;

CLOSE empleados_cursor;
DEALLOCATE empleados_cursor;
GO

/* Tareas demo */
DECLARE @TareasDemo TABLE (
    Correo NVARCHAR(150),
    Titulo NVARCHAR(150),
    Descripcion NVARCHAR(700),
    Prioridad NVARCHAR(20),
    Estado NVARCHAR(30),
    DiasLimite INT
);

INSERT INTO @TareasDemo (Correo, Titulo, Descripcion, Prioridad, Estado, DiasLimite)
VALUES
('maria.vargas@distribuidorajj.com', 'Revisar stock mínimo de productos premium', 'Validar productos con stock bajo y preparar reporte para compras.', 'Alta', 'En proceso', 2),
('maria.vargas@distribuidorajj.com', 'Conteo físico de bodega principal', 'Coordinar conteo parcial de whisky, ron y cervezas importadas.', 'Media', 'Pendiente', 6),
('jose.solano@distribuidorajj.com', 'Visitar clientes de Heredia', 'Registrar pedidos móviles en clientes de Heredia y Belén.', 'Alta', 'Pendiente', 1),
('jose.solano@distribuidorajj.com', 'Sincronizar pedidos offline', 'Revisar pedidos pendientes del dispositivo móvil y sincronizarlos al volver a la oficina.', 'Media', 'Completada', -1),
('valeria.mora@distribuidorajj.com', 'Validar facturas pendientes', 'Revisar facturas generadas en la última semana y verificar montos.', 'Media', 'Pendiente', 4),
('kevin.rojas@distribuidorajj.com', 'Preparar despacho San José', 'Separar productos para ruta de San José y confirmar empaque.', 'Alta', 'En proceso', 1),
('daniela.chaves@distribuidorajj.com', 'Responder consultas web', 'Dar seguimiento a consultas entrantes desde el formulario de contacto.', 'Media', 'Pendiente', 3),
('bryan.castro@distribuidorajj.com', 'Ruta Alajuela Centro', 'Completar entregas programadas y reportar cualquier atraso.', 'Alta', 'Pendiente', 1),
('sofia.hernandez@distribuidorajj.com', 'Revisar clientes con crédito bloqueado', 'Analizar cuentas vencidas y actualizar observaciones internas.', 'Urgente', 'En proceso', 2),
('andres.jimenez@distribuidorajj.com', 'Cotizar reposición de inventario', 'Solicitar cotizaciones para productos de alta rotación.', 'Media', 'Pendiente', 5),
('gabriela.alpizar@distribuidorajj.com', 'Revisar solicitudes de días libres', 'Preparar resumen de solicitudes pendientes para aprobación administrativa.', 'Alta', 'Pendiente', 2),
('mauricio.quesada@distribuidorajj.com', 'Actualizar archivo administrativo', 'Ordenar documentación de empleados y comprobantes recientes.', 'Baja', 'Pendiente', 7);

INSERT INTO dbo.EmpleadoTareas (EmpleadoId, Titulo, Descripcion, Prioridad, Estado, FechaLimite, UsuarioAsignacionId, UsuarioAsignacionNombre, FechaActualizacion)
SELECT
    e.EmpleadoId,
    t.Titulo,
    t.Descripcion,
    t.Prioridad,
    t.Estado,
    CAST(DATEADD(DAY, t.DiasLimite, GETDATE()) AS DATE),
    (SELECT TOP 1 UsuarioId FROM dbo.Usuarios WHERE Correo = 'admin@distribuidorajj.com'),
    ISNULL((SELECT TOP 1 NombreCompleto FROM dbo.Usuarios WHERE Correo = 'admin@distribuidorajj.com'), 'Sistema'),
    CASE WHEN t.Estado IN ('Completada', 'En proceso') THEN SYSDATETIME() ELSE NULL END
FROM @TareasDemo t
INNER JOIN dbo.Usuarios u ON u.Correo = t.Correo
INNER JOIN dbo.Empleados e ON e.UsuarioId = u.UsuarioId
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.EmpleadoTareas existente
    WHERE existente.EmpleadoId = e.EmpleadoId
      AND existente.Titulo = t.Titulo
);
GO

/* Solicitudes demo */
DECLARE @SolicitudesDemo TABLE (
    Correo NVARCHAR(150),
    FechaInicio DATE,
    FechaFin DATE,
    TipoSolicitud NVARCHAR(30),
    Motivo NVARCHAR(500),
    Estado NVARCHAR(30),
    RespuestaAdmin NVARCHAR(500)
);

INSERT INTO @SolicitudesDemo (Correo, FechaInicio, FechaFin, TipoSolicitud, Motivo, Estado, RespuestaAdmin)
VALUES
('jose.solano@distribuidorajj.com', CAST(DATEADD(DAY, 8, GETDATE()) AS DATE), CAST(DATEADD(DAY, 9, GETDATE()) AS DATE), 'Con goce salarial', 'Cita familiar previamente programada.', 'Pendiente', NULL),
('daniela.chaves@distribuidorajj.com', CAST(DATEADD(DAY, 12, GETDATE()) AS DATE), CAST(DATEADD(DAY, 12, GETDATE()) AS DATE), 'Con goce salarial', 'Trámite personal en institución pública.', 'Pendiente', NULL),
('bryan.castro@distribuidorajj.com', CAST(DATEADD(DAY, -5, GETDATE()) AS DATE), CAST(DATEADD(DAY, -4, GETDATE()) AS DATE), 'Sin goce salarial', 'Asunto personal fuera del GAM.', 'Aprobada', 'Aprobado. Coordinar cobertura de ruta con logística.'),
('sofia.hernandez@distribuidorajj.com', CAST(DATEADD(DAY, -10, GETDATE()) AS DATE), CAST(DATEADD(DAY, -10, GETDATE()) AS DATE), 'Con goce salarial', 'Cita médica.', 'Aprobada', 'Aprobado. Dejar actualizado el reporte de créditos antes de la ausencia.'),
('andres.jimenez@distribuidorajj.com', CAST(DATEADD(DAY, 15, GETDATE()) AS DATE), CAST(DATEADD(DAY, 17, GETDATE()) AS DATE), 'Sin goce salarial', 'Viaje familiar.', 'Rechazada', 'No se aprueba por cierre de inventario programado esa semana.');

INSERT INTO dbo.EmpleadoSolicitudesTiempoLibre
(EmpleadoId, FechaInicio, FechaFin, CantidadDias, TipoSolicitud, Motivo, Estado, RespuestaAdmin, UsuarioRespuestaId, UsuarioRespuestaNombre, FechaSolicitud, FechaRespuesta)
SELECT
    e.EmpleadoId,
    s.FechaInicio,
    s.FechaFin,
    DATEDIFF(DAY, s.FechaInicio, s.FechaFin) + 1,
    s.TipoSolicitud,
    s.Motivo,
    s.Estado,
    s.RespuestaAdmin,
    CASE WHEN s.Estado = 'Pendiente' THEN NULL ELSE (SELECT TOP 1 UsuarioId FROM dbo.Usuarios WHERE Correo = 'admin@distribuidorajj.com') END,
    CASE WHEN s.Estado = 'Pendiente' THEN NULL ELSE ISNULL((SELECT TOP 1 NombreCompleto FROM dbo.Usuarios WHERE Correo = 'admin@distribuidorajj.com'), 'Sistema') END,
    DATEADD(DAY, -2, SYSDATETIME()),
    CASE WHEN s.Estado = 'Pendiente' THEN NULL ELSE DATEADD(DAY, -1, SYSDATETIME()) END
FROM @SolicitudesDemo s
INNER JOIN dbo.Usuarios u ON u.Correo = s.Correo
INNER JOIN dbo.Empleados e ON e.UsuarioId = u.UsuarioId
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.EmpleadoSolicitudesTiempoLibre existente
    WHERE existente.EmpleadoId = e.EmpleadoId
      AND existente.FechaInicio = s.FechaInicio
      AND existente.FechaFin = s.FechaFin
      AND existente.TipoSolicitud = s.TipoSolicitud
      AND existente.Motivo = s.Motivo
);
GO

/* Resumen de verificación */
SELECT
    COUNT(1) AS EmpleadosDemo
FROM dbo.Usuarios u
INNER JOIN dbo.Empleados e ON e.UsuarioId = u.UsuarioId
WHERE u.Correo LIKE '%@distribuidorajj.com'
  AND u.Correo <> 'admin@distribuidorajj.com';

SELECT TOP 20
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Rol,
    e.Puesto,
    e.Departamento,
    e.Salario,
    e.Activo
FROM dbo.Empleados e
INNER JOIN dbo.Usuarios u ON u.UsuarioId = e.UsuarioId
INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
WHERE u.Correo LIKE '%@distribuidorajj.com'
ORDER BY u.NombreCompleto;
GO
