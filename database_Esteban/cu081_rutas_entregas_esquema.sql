-- ============================================================
-- CU-081 / CU-082 / CU-083  —  RUTAS Y ENTREGAS  (Esteban Valverde Fallas)
-- BLOQUE 1/4: ESQUEMA + LLAVES FORÁNEAS + PERMISOS + SEMILLA
--
-- Historias cubiertas por el módulo completo:
--   CU-081  Generar y organizar rutas de entrega (chofer + vehículo por zona)
--   CU-082  Chofer actualiza estado de entrega (con soporte offline)
--   CU-083  Registro y consulta de evidencia de entrega (foto/firma)
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO: no altera ni elimina tablas, columnas, datos ni SPs previos.
--   • IDEMPOTENTE: IF OBJECT_ID / IF NOT EXISTS antes de cada objeto.
--   • NO toca dbo.Pedidos ni su CHECK de Estado. Los estados de entrega
--     (EnRuta, Fallido) viven en dbo.RutaPedidos, NO en dbo.Pedidos.
--   • Sin secretos: no crea usuarios con contraseña. El usuario con perfil
--     'Chofer' lo aporta la semilla demo (seed_datos_demo_costa_rica.sql).
--
-- Prerrequisito: esquema base (Fase1/Fase2) ya aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

SET NOCOUNT ON;
GO

-- ============================================================
-- 1. TABLAS
-- ============================================================

-- 1.1 Vehículos (flota de reparto) ---------------------------
IF OBJECT_ID('dbo.Vehiculos', 'U') IS NULL
CREATE TABLE dbo.Vehiculos (
    VehiculoId    INT           IDENTITY(1,1) NOT NULL,
    Placa         NVARCHAR(20)                NOT NULL,
    Descripcion   NVARCHAR(150)               NOT NULL,
    Capacidad     INT                         NULL,       -- unidades/cajas aprox.
    Activo        BIT                         NOT NULL CONSTRAINT DF_Vehiculos_Activo        DEFAULT 1,
    FechaCreacion DATETIME2                   NOT NULL CONSTRAINT DF_Vehiculos_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Vehiculos       PRIMARY KEY (VehiculoId),
    CONSTRAINT UQ_Vehiculos_Placa UNIQUE      (Placa)
);
GO

-- 1.2 Rutas (cabecera de la ruta de entrega) -----------------
IF OBJECT_ID('dbo.Rutas', 'U') IS NULL
CREATE TABLE dbo.Rutas (
    RutaId             INT           IDENTITY(1,1) NOT NULL,
    Codigo             NVARCHAR(30)                NOT NULL,
    Zona               NVARCHAR(120)               NOT NULL,
    ChoferUsuarioId    INT                         NOT NULL,  -- FK -> Usuarios (perfil Chofer)
    VehiculoId         INT                         NOT NULL,  -- FK -> Vehiculos
    Estado             NVARCHAR(20)                NOT NULL CONSTRAINT DF_Rutas_Estado        DEFAULT N'Planificada',
    Observaciones      NVARCHAR(300)               NULL,
    CreadaPorUsuarioId INT                         NULL,      -- FK -> Usuarios
    CreadaPorNombre    NVARCHAR(150)               NULL,
    FechaCreacion      DATETIME2                   NOT NULL CONSTRAINT DF_Rutas_FechaCreacion DEFAULT SYSDATETIME(),
    FechaDespacho      DATETIME2                   NULL,
    FechaCierre        DATETIME2                   NULL,
    FechaActualizacion DATETIME2                   NULL,
    CONSTRAINT PK_Rutas        PRIMARY KEY (RutaId),
    CONSTRAINT UQ_Rutas_Codigo UNIQUE      (Codigo),
    CONSTRAINT CK_Rutas_Estado CHECK (Estado IN (
        N'Planificada', N'Despachada', N'Completada', N'Cancelada'
    ))
);
GO

-- 1.3 RutaPedidos (pedidos asignados a una ruta + estado de entrega)
--     El estado de entrega del pedido vive AQUÍ, no en dbo.Pedidos.
IF OBJECT_ID('dbo.RutaPedidos', 'U') IS NULL
CREATE TABLE dbo.RutaPedidos (
    RutaPedidoId       INT           IDENTITY(1,1) NOT NULL,
    RutaId             INT                         NOT NULL,  -- FK -> Rutas
    PedidoId           INT                         NOT NULL,  -- FK -> Pedidos
    Secuencia          INT                         NOT NULL CONSTRAINT DF_RutaPedidos_Secuencia     DEFAULT 0,
    EstadoEntrega      NVARCHAR(20)                NOT NULL CONSTRAINT DF_RutaPedidos_EstadoEntrega DEFAULT N'Pendiente',
    MotivoFallo        NVARCHAR(300)               NULL,
    FechaEntrega       DATETIME2                   NULL,
    FechaActualizacion DATETIME2                   NULL,
    CONSTRAINT PK_RutaPedidos PRIMARY KEY (RutaPedidoId),
    CONSTRAINT CK_RutaPedidos_EstadoEntrega CHECK (EstadoEntrega IN (
        N'Pendiente', N'EnRuta', N'Entregado', N'Fallido'
    ))
);
GO

-- Índices de apoyo (la unicidad "un pedido en una sola ruta activa"
-- se garantiza en los SPs con bloqueo, ya que depende del Estado de la Ruta padre).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RutaPedidos_RutaId'   AND object_id = OBJECT_ID('dbo.RutaPedidos'))
    CREATE INDEX IX_RutaPedidos_RutaId   ON dbo.RutaPedidos (RutaId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RutaPedidos_PedidoId' AND object_id = OBJECT_ID('dbo.RutaPedidos'))
    CREATE INDEX IX_RutaPedidos_PedidoId ON dbo.RutaPedidos (PedidoId);
GO

-- 1.4 EntregaEvidencias (foto/firma de la entrega) -----------
IF OBJECT_ID('dbo.EntregaEvidencias', 'U') IS NULL
CREATE TABLE dbo.EntregaEvidencias (
    EvidenciaId            INT           IDENTITY(1,1) NOT NULL,
    PedidoId               INT                         NOT NULL,  -- FK -> Pedidos
    RutaId                 INT                         NULL,      -- FK -> Rutas (opcional)
    TipoEvidencia          NVARCHAR(20)                NOT NULL,
    ArchivoUrl             NVARCHAR(300)               NOT NULL,
    Observaciones          NVARCHAR(300)               NULL,
    RegistradoPorUsuarioId INT                         NULL,      -- FK -> Usuarios
    RegistradoPorNombre    NVARCHAR(150)               NULL,
    FechaRegistro          DATETIME2                   NOT NULL CONSTRAINT DF_EntregaEvidencias_Fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EntregaEvidencias PRIMARY KEY (EvidenciaId),
    CONSTRAINT CK_EntregaEvidencias_Tipo CHECK (TipoEvidencia IN (N'Foto', N'Firma'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EntregaEvidencias_PedidoId' AND object_id = OBJECT_ID('dbo.EntregaEvidencias'))
    CREATE INDEX IX_EntregaEvidencias_PedidoId ON dbo.EntregaEvidencias (PedidoId);
GO

-- 1.5 EntregaSyncLog (idempotencia offline + historial con fecha/hora)
--     Cada cambio de estado del chofer trae un SyncGuid único generado
--     en el dispositivo; si llega repetido (reconexión), se ignora.
IF OBJECT_ID('dbo.EntregaSyncLog', 'U') IS NULL
CREATE TABLE dbo.EntregaSyncLog (
    EntregaSyncLogId INT              IDENTITY(1,1) NOT NULL,
    SyncGuid         UNIQUEIDENTIFIER               NOT NULL,
    RutaPedidoId     INT                            NOT NULL,  -- FK -> RutaPedidos
    EstadoAnterior   NVARCHAR(20)                   NULL,
    EstadoNuevo      NVARCHAR(20)                   NOT NULL,
    MotivoFallo      NVARCHAR(300)                  NULL,
    ChoferUsuarioId  INT                            NULL,
    ChoferNombre     NVARCHAR(150)                  NULL,
    FechaSync        DATETIME2                      NOT NULL CONSTRAINT DF_EntregaSyncLog_Fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EntregaSyncLog       PRIMARY KEY (EntregaSyncLogId),
    CONSTRAINT UQ_EntregaSyncLog_Guid  UNIQUE      (SyncGuid)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EntregaSyncLog_RutaPedidoId' AND object_id = OBJECT_ID('dbo.EntregaSyncLog'))
    CREATE INDEX IX_EntregaSyncLog_RutaPedidoId ON dbo.EntregaSyncLog (RutaPedidoId);
GO

-- ============================================================
-- 2. LLAVES FORÁNEAS (guardadas; padre -> hijo)
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Rutas_ChoferUsuarioId' AND parent_object_id = OBJECT_ID('dbo.Rutas'))
    ALTER TABLE dbo.Rutas ADD CONSTRAINT FK_Rutas_ChoferUsuarioId
        FOREIGN KEY (ChoferUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Rutas_VehiculoId' AND parent_object_id = OBJECT_ID('dbo.Rutas'))
    ALTER TABLE dbo.Rutas ADD CONSTRAINT FK_Rutas_VehiculoId
        FOREIGN KEY (VehiculoId) REFERENCES dbo.Vehiculos (VehiculoId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Rutas_CreadaPorUsuarioId' AND parent_object_id = OBJECT_ID('dbo.Rutas'))
    ALTER TABLE dbo.Rutas ADD CONSTRAINT FK_Rutas_CreadaPorUsuarioId
        FOREIGN KEY (CreadaPorUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RutaPedidos_RutaId' AND parent_object_id = OBJECT_ID('dbo.RutaPedidos'))
    ALTER TABLE dbo.RutaPedidos ADD CONSTRAINT FK_RutaPedidos_RutaId
        FOREIGN KEY (RutaId) REFERENCES dbo.Rutas (RutaId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RutaPedidos_PedidoId' AND parent_object_id = OBJECT_ID('dbo.RutaPedidos'))
    ALTER TABLE dbo.RutaPedidos ADD CONSTRAINT FK_RutaPedidos_PedidoId
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos (PedidoId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EntregaEvidencias_PedidoId' AND parent_object_id = OBJECT_ID('dbo.EntregaEvidencias'))
    ALTER TABLE dbo.EntregaEvidencias ADD CONSTRAINT FK_EntregaEvidencias_PedidoId
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos (PedidoId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EntregaEvidencias_RutaId' AND parent_object_id = OBJECT_ID('dbo.EntregaEvidencias'))
    ALTER TABLE dbo.EntregaEvidencias ADD CONSTRAINT FK_EntregaEvidencias_RutaId
        FOREIGN KEY (RutaId) REFERENCES dbo.Rutas (RutaId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EntregaSyncLog_RutaPedidoId' AND parent_object_id = OBJECT_ID('dbo.EntregaSyncLog'))
    ALTER TABLE dbo.EntregaSyncLog ADD CONSTRAINT FK_EntregaSyncLog_RutaPedidoId
        FOREIGN KEY (RutaPedidoId) REFERENCES dbo.RutaPedidos (RutaPedidoId);
GO

-- ============================================================
-- 3. ROLES Y PERMISOS
-- ============================================================

-- Perfil Chofer (por si solo se aplicó el esquema base sin la semilla demo).
IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = N'Chofer')
    INSERT INTO dbo.Perfiles (Nombre, Descripcion, Activo)
    VALUES (N'Chofer', N'Usuario encargado de entregar pedidos a clientes.', 1);
GO

-- Catálogo de permisos del módulo (idempotente).
MERGE dbo.Permisos AS target
USING (VALUES
    (N'RUTAS_GESTIONAR',               N'Rutas',    N'Gestionar rutas de entrega',        N'Crear, editar, despachar y cancelar rutas de reparto.'),
    (N'ENTREGAS_ACTUALIZAR',           N'Entregas', N'Actualizar estado de entrega',      N'Permite al chofer marcar En ruta, Entregado o Fallido.'),
    (N'ENTREGAS_EVIDENCIA_REGISTRAR',  N'Entregas', N'Registrar evidencia de entrega',    N'Adjuntar foto o firma al pedido entregado.'),
    (N'ENTREGAS_EVIDENCIA_VER',        N'Entregas', N'Consultar evidencias de entrega',   N'Ver el historial de evidencias por pedido o ruta.'),
    (N'REPORTES_DASHBOARD',            N'Reportes', N'Ver tablero gerencial',             N'Visualizar indicadores clave del negocio.')
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET Modulo      = source.Modulo,
               Nombre      = source.Nombre,
               Descripcion = source.Descripcion,
               Activo      = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

-- Asignación de permisos a perfiles (guardada, sin duplicar).
--   Administrador : todos
--   Gerente       : gestionar rutas, ver evidencias, tablero
--   Chofer        : actualizar entrega, registrar evidencia
DECLARE @Asignaciones TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @Asignaciones (Rol, Codigo)
VALUES
    (N'Administrador', N'RUTAS_GESTIONAR'),
    (N'Administrador', N'ENTREGAS_ACTUALIZAR'),
    (N'Administrador', N'ENTREGAS_EVIDENCIA_REGISTRAR'),
    (N'Administrador', N'ENTREGAS_EVIDENCIA_VER'),
    (N'Administrador', N'REPORTES_DASHBOARD'),
    (N'Gerente',       N'RUTAS_GESTIONAR'),
    (N'Gerente',       N'ENTREGAS_EVIDENCIA_VER'),
    (N'Gerente',       N'REPORTES_DASHBOARD'),
    (N'Chofer',        N'ENTREGAS_ACTUALIZAR'),
    (N'Chofer',        N'ENTREGAS_EVIDENCIA_REGISTRAR');

INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-081'
FROM @Asignaciones a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PerfilPermisos pp
    WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId
);
GO

-- ============================================================
-- 4. SEMILLA (vehículos demo) — idempotente, sin secretos
-- ============================================================
MERGE dbo.Vehiculos AS target
USING (VALUES
    (N'CRJ-001', N'Panel de reparto GAM (Toyota Hiace)', 120),
    (N'CRJ-002', N'Camión liviano zona Alajuela (Isuzu NPR)', 250),
    (N'CRJ-003', N'Pick-up reparto express (Nissan Frontier)', 80)
) AS source (Placa, Descripcion, Capacidad)
ON target.Placa = source.Placa
WHEN NOT MATCHED THEN
    INSERT (Placa, Descripcion, Capacidad, Activo)
    VALUES (source.Placa, source.Descripcion, source.Capacidad, 1);
GO

-- Aviso operativo: se requiere al menos un usuario con perfil 'Chofer' para
-- probar el portal del chofer. La semilla demo crea rquiros@labodega.cr.
IF NOT EXISTS (
    SELECT 1 FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = N'Chofer' AND u.Activo = 1
)
    PRINT 'AVISO: no existe ningún usuario activo con perfil Chofer. Ejecute la semilla demo o cree uno para probar el portal del chofer.';
GO

PRINT 'CU-081 (esquema) aplicado: Vehiculos, Rutas, RutaPedidos, EntregaEvidencias, EntregaSyncLog + permisos + semilla.';
GO
