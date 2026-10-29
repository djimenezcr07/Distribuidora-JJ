-- ============================================================
-- FASE 4: SEED DATA — DistribuidoraJJ_DB
-- Datos iniciales: roles, permisos, asignaciones, categorías,
-- productos, admin, empleados y clientes demo.
-- Idempotente: IF NOT EXISTS en cada INSERT.
-- Prerequisito: Fases 1, 2 y 3 ejecutadas sin errores.
-- ============================================================

USE DistribuidoraJJ_DB;
GO

SET NOCOUNT ON;

/*
   ADVERTENCIA P0: archivo historico, no es fuente de verdad ni debe ejecutarse en Azure SQL DEV.
   Contiene datos demo y requiere revision, respaldo y aprobacion explicita.
*/
THROW 51020, 'Archivo historico: no ejecutar sin un bloque aprobado.', 1;
GO

-- ===========================================================
-- 1. PERFILES (Roles del sistema)
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Administrador')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES (N'Administrador', N'Acceso total al sistema');

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Gerente')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES (N'Gerente', N'Autorización de pedidos retenidos');

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Empleado')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES (N'Empleado', N'Acceso al portal de empleados');

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Vendedor')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES (N'Vendedor', N'Registro de ventas móviles offline');

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Cliente')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES (N'Cliente', N'Acceso a la tienda en línea y portal de cliente');

PRINT '✔️ Perfiles OK';
GO

-- ===========================================================
-- 2. PERMISOS (catálogo completo)
-- ===========================================================

DECLARE @Permisos TABLE (
    Codigo      NVARCHAR(100),
    Modulo      NVARCHAR(80),
    Nombre      NVARCHAR(120),
    Descripcion NVARCHAR(255)
);

INSERT INTO @Permisos VALUES
-- Dashboard
(N'DASHBOARD_VER',                N'Dashboard',   N'Ver Dashboard',                  N'Acceso al panel de control y métricas'),
-- Inventario
(N'INVENTARIO_VER',               N'Inventario',  N'Ver Inventario',                 N'Consultar productos y movimientos de stock'),
(N'INVENTARIO_AGREGAR',           N'Inventario',  N'Agregar Producto',               N'Crear nuevos productos en el sistema'),
(N'INVENTARIO_EDITAR',            N'Inventario',  N'Editar Producto',                N'Modificar datos de productos existentes'),
(N'INVENTARIO_ELIMINAR',          N'Inventario',  N'Eliminar Producto',              N'Eliminar producto permanentemente'),
(N'INVENTARIO_AJUSTAR_STOCK',     N'Inventario',  N'Ajustar Stock',                  N'Registrar entradas, salidas y ajustes manuales'),
-- Pedidos
(N'PEDIDOS_VER',                  N'Pedidos',     N'Ver Pedidos',                    N'Consultar pedidos del sistema'),
(N'PEDIDOS_CAMBIAR_ESTADO',       N'Pedidos',     N'Cambiar Estado de Pedido',       N'Aprobar, procesar, entregar o cancelar pedidos'),
(N'PEDIDOS_RETENER_LIBERAR',      N'Pedidos',     N'Retener / Liberar Pedidos',      N'Autorizar o rechazar pedidos retenidos'),
-- Facturación
(N'FACTURACION_VER',              N'Facturación', N'Ver Facturas',                   N'Consultar historial de facturas emitidas'),
(N'FACTURACION_GENERAR',          N'Facturación', N'Generar Factura',                N'Emitir facturas desde pedidos aprobados'),
-- Roles
(N'ROLES_VER',                    N'Roles',       N'Ver Roles',                      N'Consultar los perfiles de usuario existentes'),
(N'ROLES_CREAR_EDITAR',           N'Roles',       N'Crear y Editar Roles',           N'Gestionar roles'),
-- Permisos
(N'PERMISOS_VER',                 N'Permisos',    N'Ver Permisos',                   N'Consultar permisos asignados a cada perfil'),
(N'PERMISOS_ASIGNAR',             N'Permisos',    N'Asignar Permisos',               N'Modificar permisos por perfil'),
-- Auditoría
(N'AUDITORIA_VER',                N'Auditoría',   N'Ver Auditoría',                  N'Consultar el registro de auditoría del sistema'),
-- Consultas
(N'CONSULTAS_VER',                N'Consultas',   N'Ver Consultas',                  N'Consultar formularios de contacto recibidos'),
(N'CONSULTAS_GESTIONAR',          N'Consultas',   N'Gestionar Consultas',            N'Atender y cerrar consultas de clientes'),
-- Clientes
(N'CLIENTES_VER',                 N'Clientes',    N'Ver Clientes',                   N'Consultar listado y detalle de clientes'),
(N'CLIENTES_CREAR',               N'Clientes',    N'Crear Cliente',                  N'Registrar nuevos clientes en el sistema'),
(N'CLIENTES_EDITAR',              N'Clientes',    N'Editar Cliente',                 N'Modificar clientes'),
(N'CLIENTES_ACTIVAR_DESACTIVAR',  N'Clientes',    N'Activar / Desactivar Cliente',   N'Cambiar el estado activo de un cliente'),
-- Créditos
(N'CREDITOS_VER',                 N'Créditos',    N'Ver Créditos',                   N'Consultar créditos de clientes'),
(N'CREDITOS_GESTIONAR',           N'Créditos',    N'Gestionar Créditos',             N'Modificar límites y estado de crédito'),
(N'CREDITOS_MOVIMIENTOS',         N'Créditos',    N'Registrar Movimientos',          N'Cargar o abonar saldo de crédito'),
(N'CREDITOS_BLOQUEAR',            N'Créditos',    N'Bloquear / Desbloquear Crédito', N'Controlar crédito del cliente'),
-- Venta Móvil
(N'VENTA_MOVIL_CREAR',            N'Venta Móvil', N'Crear Pedido Móvil',             N'Registrar ventas offline desde dispositivo'),
(N'VENTA_MOVIL_VER_PROPIOS',      N'Venta Móvil', N'Ver Mis Pedidos Móviles',        N'Consultar pedidos propios del vendedor'),
-- Empleados
(N'EMPLEADOS_VER',                N'Empleados',   N'Ver Empleados',                  N'Consultar listado y detalle de empleados'),
(N'EMPLEADOS_CREAR',              N'Empleados',   N'Crear Empleado',                 N'Registrar nuevos empleados'),
(N'EMPLEADOS_EDITAR',             N'Empleados',   N'Editar Empleado',                N'Modificar datos laborales de empleados'),
(N'EMPLEADOS_ACTIVAR_DESACTIVAR', N'Empleados',   N'Activar / Desactivar Empleado',  N'Cambiar el estado activo de un empleado'),
(N'EMPLEADOS_VER_SALARIO',        N'Empleados',   N'Ver Historial Salarial',         N'Consultar historial salarial de empleados');

INSERT INTO dbo.Permisos (Codigo, Modulo, Nombre, Descripcion)
SELECT p.Codigo, p.Modulo, p.Nombre, p.Descripcion
FROM @Permisos p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Permisos ex WHERE ex.Codigo = p.Codigo
);

PRINT '✔️ Permisos OK — ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' inserción(es)';
GO

-- ===========================================================
-- 3. ASIGNACIÓN DE PERMISOS POR ROL
-- ===========================================================

-- Administrador -> todos los permisos activos
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionNombre)
SELECT
    (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Administrador'),
    per.PermisoId,
    N'Sistema (seed)'
FROM dbo.Permisos per
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos pp
    WHERE pp.PerfilId = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Administrador')
      AND pp.PermisoId = per.PermisoId
);

-- Gerente -> dashboard + gestión de pedidos retenidos
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionNombre)
SELECT
    (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Gerente'),
    per.PermisoId,
    N'Sistema (seed)'
FROM dbo.Permisos per
WHERE per.Codigo IN (
    N'DASHBOARD_VER',
    N'PEDIDOS_VER',
    N'PEDIDOS_CAMBIAR_ESTADO',
    N'PEDIDOS_RETENER_LIBERAR'
)
AND NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos pp
    WHERE pp.PerfilId = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Gerente')
      AND pp.PermisoId = per.PermisoId
);

-- Vendedor -> venta móvil únicamente
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionNombre)
SELECT
    (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Vendedor'),
    per.PermisoId,
    N'Sistema (seed)'
FROM dbo.Permisos per
WHERE per.Codigo IN (
    N'VENTA_MOVIL_CREAR',
    N'VENTA_MOVIL_VER_PROPIOS'
)
AND NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos pp
    WHERE pp.PerfilId = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Vendedor')
      AND pp.PermisoId = per.PermisoId
);

PRINT '✔️ PerfilPermisos OK';
GO

-- ===========================================================
-- 4. CATEGORÍAS DE PRODUCTO
-- ===========================================================

DECLARE @Cats TABLE (Nombre NVARCHAR(100));
INSERT INTO @Cats VALUES
    (N'Licores'),
    (N'Cervezas'),
    (N'Vinos'),
    (N'Bebidas sin alcohol'),
    (N'Snacks y acompañantes');

INSERT INTO dbo.Categorias (Nombre)
SELECT c.Nombre FROM @Cats c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Categorias ex WHERE ex.Nombre = c.Nombre
);

PRINT '✔️ Categorías OK';
GO

-- ===========================================================
-- 5. PRODUCTOS (catálogo base — licorería)
-- ===========================================================

-- Licores
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Ron Centenario 7 Años')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Ron Centenario 7 Años', N'Licores',
           N'Ron añejado 7 años, 750 ml', 14500.00, 48, 10, 1
    FROM dbo.Categorias WHERE Nombre = N'Licores';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Ron Centenario 12 Años')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Ron Centenario 12 Años', N'Licores',
           N'Ron premium añejado 12 años, 750 ml', 22000.00, 30, 8, 1
    FROM dbo.Categorias WHERE Nombre = N'Licores';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Vodka Absolut Original')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Vodka Absolut Original', N'Licores',
           N'Vodka sueco importado, 750 ml', 18900.00, 24, 6, 0
    FROM dbo.Categorias WHERE Nombre = N'Licores';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Whisky Jack Daniel''s Old No. 7')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Whisky Jack Daniel''s Old No. 7', N'Licores',
           N'Tennessee Whiskey, 750 ml', 29500.00, 18, 5, 1
    FROM dbo.Categorias WHERE Nombre = N'Licores';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Tequila José Cuervo Especial')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Tequila José Cuervo Especial', N'Licores',
           N'Tequila Especial Silver, 750 ml', 16800.00, 20, 6, 0
    FROM dbo.Categorias WHERE Nombre = N'Licores';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Guaro Cacique 750 ml')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Guaro Cacique 750 ml', N'Licores',
           N'Aguardiente nacional de caña, 750 ml', 6500.00, 60, 12, 1
    FROM dbo.Categorias WHERE Nombre = N'Licores';

-- Cervezas
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Imperial Lata 355 ml')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Imperial Lata 355 ml', N'Cervezas',
           N'Cerveza nacional lata individual', 1100.00, 240, 48, 1
    FROM dbo.Categorias WHERE Nombre = N'Cervezas';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Imperial Six Pack Lata')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Imperial Six Pack Lata', N'Cervezas',
           N'Pack de 6 latas Imperial 355 ml', 5900.00, 80, 20, 1
    FROM dbo.Categorias WHERE Nombre = N'Cervezas';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Heineken Botella 330 ml')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Heineken Botella 330 ml', N'Cervezas',
           N'Cerveza holandesa importada', 1800.00, 120, 24, 0
    FROM dbo.Categorias WHERE Nombre = N'Cervezas';

-- Vinos
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Vino Santa Helena Cabernet Sauvignon')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Vino Santa Helena Cabernet Sauvignon', N'Vinos',
           N'Vino tinto chileno, 750 ml', 8500.00, 36, 8, 1
    FROM dbo.Categorias WHERE Nombre = N'Vinos';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Vino Concha y Toro Chardonnay')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Vino Concha y Toro Chardonnay', N'Vinos',
           N'Vino blanco chileno Frontera, 750 ml', 7200.00, 30, 8, 0
    FROM dbo.Categorias WHERE Nombre = N'Vinos';

-- Bebidas sin alcohol
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Agua Cristal 600 ml')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Agua Cristal 600 ml', N'Bebidas sin alcohol',
           N'Agua purificada en botella PET', 600.00, 200, 40, 0
    FROM dbo.Categorias WHERE Nombre = N'Bebidas sin alcohol';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Coca-Cola Lata 355 ml')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Coca-Cola Lata 355 ml', N'Bebidas sin alcohol',
           N'Gaseosa cola, lata individual', 900.00, 150, 30, 0
    FROM dbo.Categorias WHERE Nombre = N'Bebidas sin alcohol';

-- Snacks
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Maní Salado 100 g')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Maní Salado 100 g', N'Snacks y acompañantes',
           N'Maní tostado y salado, bolsa individual', 800.00, 100, 20, 0
    FROM dbo.Categorias WHERE Nombre = N'Snacks y acompañantes';

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = N'Papas Fritas Natuchips 60 g')
    INSERT INTO dbo.Productos (CategoriaId, Nombre, Categoria, Descripcion, Precio, Stock, StockMinimo, EsDestacado)
    SELECT CategoriaId, N'Papas Fritas Natuchips 60 g', N'Snacks y acompañantes',
           N'Papas fritas onduladas, bolsa individual', 750.00, 80, 20, 0
    FROM dbo.Categorias WHERE Nombre = N'Snacks y acompañantes';

PRINT '✔️ Productos OK';
GO

-- ===========================================================
-- 6. USUARIO ADMINISTRADOR
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'admin@distribuidorajj.com')
BEGIN
    DECLARE @PidAdmin INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Administrador');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Activo)
    VALUES
        (@PidAdmin, N'Administrador Sistema', N'admin@distribuidorajj.com',
         N'<SET_AT_EXECUTION>', N'2200-0000', 1);
END
GO

PRINT '✔️ Usuario admin OK';
GO

-- ===========================================================
-- 7. EMPLEADOS DEMO
-- ===========================================================

-- >> Gerente <<
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'carlos.mendez@distribuidorajj.com')
BEGIN
    DECLARE @PidGerente INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Gerente');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono)
    VALUES
        (@PidGerente, N'Carlos Méndez Rojas',
         N'carlos.mendez@distribuidorajj.com', N'<SET_AT_EXECUTION>', N'8800-1111');

    DECLARE @UidCarlos INT = SCOPE_IDENTITY();

    INSERT INTO dbo.Empleados
        (UsuarioId, Puesto, Departamento, Salario, FechaContratacion)
    VALUES
        (@UidCarlos, N'Gerente de Operaciones', N'Gerencia', 850000.00, '2021-03-15');

    INSERT INTO dbo.EmpleadoHistorialSalarios
        (EmpleadoId, SalarioNuevo, Motivo)
    VALUES
        (SCOPE_IDENTITY(), 850000.00, N'Salario inicial (seed)');
END
GO

-- >> Empleado 1 — Bodeguero <<
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'jose.solano@distribuidorajj.com')
BEGIN
    DECLARE @PidEmpl INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Empleado');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono)
    VALUES
        (@PidEmpl, N'José Solano Vargas',
         N'jose.solano@distribuidorajj.com', N'<SET_AT_EXECUTION>', N'8811-2222');

    DECLARE @UidJose INT = SCOPE_IDENTITY();

    INSERT INTO dbo.Empleados
        (UsuarioId, Puesto, Departamento, Salario, FechaContratacion,
         Responsabilidades)
    VALUES
        (@UidJose, N'Bodeguero', N'Bodega', 450000.00, '2022-06-01',
         N'Control de inventario físico, recepción de mercancía y despacho de pedidos.');

    INSERT INTO dbo.EmpleadoHistorialSalarios
        (EmpleadoId, SalarioNuevo, Motivo)
    VALUES
        (SCOPE_IDENTITY(), 450000.00, N'Salario inicial (seed)');
END
GO

-- >> Empleado 2 — Administrativa <<
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'maria.vargas@distribuidorajj.com')
BEGIN
    DECLARE @PidEmpl2 INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Empleado');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono)
    VALUES
        (@PidEmpl2, N'María Vargas Pérez',
         N'maria.vargas@distribuidorajj.com', N'<SET_AT_EXECUTION>', N'8822-3333');

    DECLARE @UidMaria INT = SCOPE_IDENTITY();

    INSERT INTO dbo.Empleados
        (UsuarioId, Puesto, Departamento, Salario, FechaContratacion,
         Responsabilidades)
    VALUES
        (@UidMaria, N'Asistente Administrativa', N'Administración', 520000.00, '2022-01-10',
         N'Gestión de documentos, atención al cliente y soporte administrativo general.');

    INSERT INTO dbo.EmpleadoHistorialSalarios
        (EmpleadoId, SalarioNuevo, Motivo)
    VALUES
        (SCOPE_IDENTITY(), 520000.00, N'Salario inicial (seed)');
END
GO

-- >> Vendedor externo <<
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'luis.fernandez@distribuidorajj.com')
BEGIN
    DECLARE @PidVend INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Vendedor');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono)
    VALUES
        (@PidVend, N'Luis Fernández Castro',
         N'luis.fernandez@distribuidorajj.com', N'<SET_AT_EXECUTION>', N'8833-4444');

    DECLARE @UidLuis INT = SCOPE_IDENTITY();

    INSERT INTO dbo.Empleados
        (UsuarioId, Puesto, Departamento, Salario, FechaContratacion,
         Responsabilidades)
    VALUES
        (@UidLuis, N'Vendedor Externo', N'Ventas', 480000.00, '2023-02-20',
         N'Visita a clientes en ruta, toma de pedidos offline y cobro en campo.');

    INSERT INTO dbo.EmpleadoHistorialSalarios
        (EmpleadoId, SalarioNuevo, Motivo)
    VALUES
        (SCOPE_IDENTITY(), 480000.00, N'Salario inicial (seed)');
END
GO

PRINT '✔️ Empleados demo OK';
GO

-- ===========================================================
-- 8. CLIENTES DEMO (con crédito pre-configurado)
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'ana.jimenez@correo.com')
BEGIN
    DECLARE @PidCli INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
    VALUES
        (@PidCli, N'Ana Jiménez Torres', N'ana.jimenez@correo.com',
         N'<SET_AT_EXECUTION>', N'8844-5555', N'San José, Escazú');

    DECLARE @UidAna INT = SCOPE_IDENTITY();

    INSERT INTO dbo.ClienteCreditos
        (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
    VALUES
        (@UidAna, 500000.00, 1, 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'pedro.mora@correo.com')
BEGIN
    DECLARE @PidCli2 INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
    VALUES
        (@PidCli2, N'Pedro Mora Salazar', N'pedro.mora@correo.com',
         N'<SET_AT_EXECUTION>', N'8855-6666', N'Heredia, Barva');

    DECLARE @UidPedro INT = SCOPE_IDENTITY();

    INSERT INTO dbo.ClienteCreditos
        (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
    VALUES
        (@UidPedro, 0, 0, 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'sofia.brenes@correo.com')
BEGIN
    DECLARE @PidCli3 INT = (SELECT PerfilId FROM dbo.Perfiles WHERE Nombre = N'Cliente');

    INSERT INTO dbo.Usuarios
        (PerfilId, NombreCompleto, Correo, Contrasena, Telefono, Direccion)
    VALUES
        (@PidCli3, N'Sofía Brenes Arias', N'sofia.brenes@correo.com',
         N'<SET_AT_EXECUTION>', N'8866-7777', N'Alajuela, Centro');

    DECLARE @UidSofia INT = SCOPE_IDENTITY();

    INSERT INTO dbo.ClienteCreditos
        (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
    VALUES
        (@UidSofia, 250000.00, 1, 0);
END
GO

PRINT '✔️ Clientes demo OK';
GO

-- ===========================================================
-- RESUMEN FINAL — verificar conteos esperados
-- ===========================================================

SELECT Tabla, Registros FROM (
    SELECT 'Perfiles'        AS Tabla, COUNT(*) AS Registros FROM dbo.Perfiles               UNION ALL
    SELECT 'Permisos',                 COUNT(*)              FROM dbo.Permisos               UNION ALL
    SELECT 'PerfilPermisos',           COUNT(*)              FROM dbo.PerfilPermisos         UNION ALL
    SELECT 'Categorias',               COUNT(*)              FROM dbo.Categorias             UNION ALL
    SELECT 'Productos',                COUNT(*)              FROM dbo.Productos              UNION ALL
    SELECT 'Usuarios',                 COUNT(*)              FROM dbo.Usuarios               UNION ALL
    SELECT 'Empleados',                COUNT(*)              FROM dbo.Empleados              UNION ALL
    SELECT 'ClienteCreditos',          COUNT(*)              FROM dbo.ClienteCreditos        UNION ALL
    SELECT 'EmpleadoHistorialSalarios',COUNT(*)              FROM dbo.EmpleadoHistorialSalarios
) r
ORDER BY Tabla;
GO

PRINT '✔️ FASE 4 completada — base de datos lista para desarrollo y pruebas.';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seller_GetProductsForOrder
    @Filtro NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductoId,     -- Índice 0 (Int)
        Nombre,         -- Índice 1 (String)
        Categoria,      -- Índice 2 (String)
        Descripcion,    -- Índice 3 (String)
        Precio,         -- Índice 4 (Decimal)
        Stock,          -- Índice 5 (Int)
        ImagenUrl       -- Índice 6 (String)
    FROM dbo.Productos
    WHERE Activo = 1 AND Stock > 0
      AND (@Filtro IS NULL OR Nombre LIKE N'%' + @Filtro + N'%'
                           OR Categoria LIKE N'%' + @Filtro + N'%')
    ORDER BY Nombre;
END
GO
