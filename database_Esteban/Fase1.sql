-- ============================================================
-- FASE 1: DDL BASE — DistribuidoraJJ_DB
-- Crea la base de datos y las 21 tablas con PKs, columnas
-- computadas, defaults y constraints INTERNOS.
-- SIN llaves foráneas (se agregan en Fase 2).
-- Idempotente: IF OBJECT_ID IS NULL antes de cada tabla.
-- ============================================================

USE master;
GO

IF DB_ID('DistribuidoraJJ_DB') IS NULL
    CREATE DATABASE DistribuidoraJJ_DB
        COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE DistribuidoraJJ_DB;
GO

-- ?? 1. Perfiles (roles del sistema) ????????????????????????
IF OBJECT_ID('dbo.Perfiles', 'U') IS NULL
CREATE TABLE dbo.Perfiles (
    PerfilId      INT           IDENTITY(1,1) NOT NULL,
    Nombre        NVARCHAR(50)               NOT NULL,
    Descripcion   NVARCHAR(255)              NULL,
    Activo        BIT                        NOT NULL CONSTRAINT DF_Perfiles_Activo       DEFAULT 1,
    FechaCreacion DATETIME2                  NOT NULL CONSTRAINT DF_Perfiles_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Perfiles      PRIMARY KEY (PerfilId),
    CONSTRAINT UQ_Perfiles_Nombre UNIQUE    (Nombre)
);
GO

-- ?? 2. Categorias (categorías de producto) ?????????????????
IF OBJECT_ID('dbo.Categorias', 'U') IS NULL
CREATE TABLE dbo.Categorias (
    CategoriaId   INT           IDENTITY(1,1) NOT NULL,
    Nombre        NVARCHAR(100)               NOT NULL,
    Activo        BIT                         NOT NULL CONSTRAINT DF_Categorias_Activo       DEFAULT 1,
    FechaCreacion DATETIME2                   NOT NULL CONSTRAINT DF_Categorias_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Categorias       PRIMARY KEY (CategoriaId),
    CONSTRAINT UQ_Categorias_Nombre UNIQUE    (Nombre)
);
GO

-- ?? 3. Permisos (catálogo de permisos) ?????????????????????
IF OBJECT_ID('dbo.Permisos', 'U') IS NULL
CREATE TABLE dbo.Permisos (
    PermisoId     INT           IDENTITY(1,1) NOT NULL,
    Codigo        NVARCHAR(100)               NOT NULL,
    Modulo        NVARCHAR(80)                NOT NULL,
    Nombre        NVARCHAR(120)               NOT NULL,
    Descripcion   NVARCHAR(255)               NULL,
    Activo        BIT                         NOT NULL CONSTRAINT DF_Permisos_Activo       DEFAULT 1,
    FechaCreacion DATETIME2                   NOT NULL CONSTRAINT DF_Permisos_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Permisos      PRIMARY KEY (PermisoId),
    CONSTRAINT UQ_Permisos_Codigo UNIQUE    (Codigo)
);
GO

-- ?? 4. Usuarios ?????????????????????????????????????????????
IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
CREATE TABLE dbo.Usuarios (
    UsuarioId          INT           IDENTITY(1,1) NOT NULL,
    PerfilId           INT                         NOT NULL,  -- FK ? Perfiles (Fase 2)
    NombreCompleto     NVARCHAR(150)               NOT NULL,
    Correo             NVARCHAR(150)               NOT NULL,
    Contrasena         NVARCHAR(255)               NOT NULL,
    Telefono           NVARCHAR(30)                NULL,
    Direccion          NVARCHAR(255)               NULL,
    Activo             BIT                         NOT NULL CONSTRAINT DF_Usuarios_Activo       DEFAULT 1,
    FechaRegistro      DATETIME2                   NOT NULL CONSTRAINT DF_Usuarios_FechaRegistro DEFAULT SYSDATETIME(),
    MotivoInactivacion NVARCHAR(255)               NULL,
    FechaInactivacion  DATETIME2                   NULL,
    FechaActualizacion DATETIME2                   NULL,
    CONSTRAINT PK_Usuarios       PRIMARY KEY (UsuarioId),
    CONSTRAINT UQ_Usuarios_Correo UNIQUE    (Correo)
);
GO

-- ?? 5. Empleados ????????????????????????????????????????????
IF OBJECT_ID('dbo.Empleados', 'U') IS NULL
CREATE TABLE dbo.Empleados (
    EmpleadoId            INT           IDENTITY(1,1) NOT NULL,
    UsuarioId             INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    Puesto                NVARCHAR(100)               NOT NULL,
    Salario               DECIMAL(18,2)               NULL,
    FechaContratacion     DATE                        NULL,
    Activo                BIT                         NOT NULL CONSTRAINT DF_Empleados_Activo DEFAULT 1,
    Departamento          NVARCHAR(100)               NULL,
    Responsabilidades     NVARCHAR(MAX)               NULL,
    ObservacionesInternas NVARCHAR(MAX)               NULL,
    FechaActualizacion    DATETIME2                   NULL,
    CONSTRAINT PK_Empleados          PRIMARY KEY (EmpleadoId),
    CONSTRAINT UQ_Empleados_UsuarioId UNIQUE    (UsuarioId)
);
GO

-- ?? 6. Productos ????????????????????????????????????????????
IF OBJECT_ID('dbo.Productos', 'U') IS NULL
CREATE TABLE dbo.Productos (
    ProductoId    INT           IDENTITY(1,1) NOT NULL,
    CategoriaId   INT                         NOT NULL,  -- FK ? Categorias (Fase 2)
    Nombre        NVARCHAR(150)               NOT NULL,
    Categoria     NVARCHAR(100)               NOT NULL,  -- denormalizado para consultas rápidas
    Descripcion   NVARCHAR(255)               NULL,
    Precio        DECIMAL(18,2)               NOT NULL,
    Stock         INT                         NOT NULL CONSTRAINT DF_Productos_Stock        DEFAULT 0,
    StockMinimo   INT                         NOT NULL CONSTRAINT DF_Productos_StockMinimo  DEFAULT 5,
    EstadoStock   AS (
                    CASE
                      WHEN Stock <= 0           THEN N'Agotado'
                      WHEN Stock <= StockMinimo THEN N'Bajo'
                      ELSE N'Normal'
                    END
                  ) PERSISTED,
    Activo        BIT                         NOT NULL CONSTRAINT DF_Productos_Activo       DEFAULT 1,
    FechaCreacion DATETIME2                   NOT NULL CONSTRAINT DF_Productos_FechaCreacion DEFAULT SYSDATETIME(),
    ImagenUrl     NVARCHAR(255)               NULL,
    EsDestacado   BIT                         NULL     CONSTRAINT DF_Productos_EsDestacado  DEFAULT 0,
    CONSTRAINT PK_Productos PRIMARY KEY (ProductoId)
);
GO

-- ?? 7. Pedidos ??????????????????????????????????????????????
IF OBJECT_ID('dbo.Pedidos', 'U') IS NULL
CREATE TABLE dbo.Pedidos (
    PedidoId              INT              IDENTITY(1,1) NOT NULL,
    UsuarioId             INT                            NOT NULL,  -- FK ? Usuarios (Fase 2)
    VendedorUsuarioId     INT                            NULL,      -- FK ? Usuarios (Fase 2)
    FechaPedido           DATETIME2                      NOT NULL CONSTRAINT DF_Pedidos_FechaPedido  DEFAULT SYSDATETIME(),
    Estado                NVARCHAR(30)                   NOT NULL CONSTRAINT DF_Pedidos_Estado        DEFAULT N'Pendiente',
    TipoEntrega           NVARCHAR(50)                   NULL,
    DireccionEntrega      NVARCHAR(255)                  NULL,
    Total                 DECIMAL(18,2)                  NOT NULL CONSTRAINT DF_Pedidos_Total          DEFAULT 0,
    Observaciones         NVARCHAR(255)                  NULL,
    VendedorNombre        NVARCHAR(150)                  NULL,
    CanalPedido           NVARCHAR(50)                   NULL,
    FechaActualizacion    DATETIME2                      NULL,
    PedidoOfflineGuid     UNIQUEIDENTIFIER               NULL,
    IdentificacionCliente NVARCHAR(100)                  NULL,
    MetodoPago            NVARCHAR(40)                   NOT NULL CONSTRAINT DF_Pedidos_MetodoPago    DEFAULT N'No especificado',
    EstadoPago            NVARCHAR(30)                   NOT NULL CONSTRAINT DF_Pedidos_EstadoPago    DEFAULT N'Pendiente',
    ReferenciaPago        NVARCHAR(80)                   NULL,
    FechaPago             DATETIME2                      NULL,
    InventarioDescontado  BIT                            NOT NULL CONSTRAINT DF_Pedidos_InvDesc       DEFAULT 0,
    MotivoRechazo         NVARCHAR(500)                  NULL,
    CONSTRAINT PK_Pedidos PRIMARY KEY (PedidoId),
    CONSTRAINT CK_Pedidos_Estado CHECK (Estado IN (
        N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado',
        N'Cancelado', N'Retenido', N'Liberado', N'Rechazado'
    )),
    CONSTRAINT CK_Pedidos_EstadoPago CHECK (EstadoPago IN (
        N'Pendiente', N'Confirmado simulado'
    ))
);
GO

-- Índice filtrado: GUIDs únicos sólo cuando no son NULL
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Pedidos')
      AND name = 'UX_Pedidos_PedidoOfflineGuid'
)
    CREATE UNIQUE INDEX UX_Pedidos_PedidoOfflineGuid
        ON dbo.Pedidos (PedidoOfflineGuid)
        WHERE PedidoOfflineGuid IS NOT NULL;
GO

-- ?? 8. PedidoDetalle ????????????????????????????????????????
IF OBJECT_ID('dbo.PedidoDetalle', 'U') IS NULL
CREATE TABLE dbo.PedidoDetalle (
    PedidoDetalleId INT           IDENTITY(1,1) NOT NULL,
    PedidoId        INT                         NOT NULL,  -- FK ? Pedidos (Fase 2)
    ProductoId      INT                         NOT NULL,  -- FK ? Productos (Fase 2)
    Cantidad        INT                         NOT NULL,
    PrecioUnitario  DECIMAL(18,2)               NOT NULL,
    Subtotal        AS (Cantidad * PrecioUnitario) PERSISTED,
    CONSTRAINT PK_PedidoDetalle PRIMARY KEY (PedidoDetalleId)
);
GO

-- ?? 9. Facturas ?????????????????????????????????????????????
IF OBJECT_ID('dbo.Facturas', 'U') IS NULL
CREATE TABLE dbo.Facturas (
    FacturaId     INT           IDENTITY(1,1) NOT NULL,
    PedidoId      INT                         NOT NULL,  -- FK ? Pedidos (Fase 2)
    UsuarioId     INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    NumeroFactura NVARCHAR(30)                NOT NULL,
    ClienteNombre NVARCHAR(150)               NOT NULL,
    ClienteCorreo NVARCHAR(150)               NOT NULL,
    FechaFactura  DATETIME2                   NOT NULL CONSTRAINT DF_Facturas_FechaFactura DEFAULT SYSDATETIME(),
    Subtotal      DECIMAL(18,2)               NOT NULL,
    Impuesto      DECIMAL(18,2)               NOT NULL,
    Total         DECIMAL(18,2)               NOT NULL,
    Estado        NVARCHAR(20)                NOT NULL CONSTRAINT DF_Facturas_Estado       DEFAULT N'Generada',
    CONSTRAINT PK_Facturas             PRIMARY KEY (FacturaId),
    CONSTRAINT UQ_Facturas_PedidoId      UNIQUE    (PedidoId),
    CONSTRAINT UQ_Facturas_NumeroFactura UNIQUE    (NumeroFactura)
);
GO

-- ?? 10. FacturaDetalle ??????????????????????????????????????
IF OBJECT_ID('dbo.FacturaDetalle', 'U') IS NULL
CREATE TABLE dbo.FacturaDetalle (
    FacturaDetalleId INT           IDENTITY(1,1) NOT NULL,
    FacturaId        INT                         NOT NULL,  -- FK ? Facturas (Fase 2)
    ProductoId       INT                         NOT NULL,  -- FK ? Productos (Fase 2)
    ProductoNombre   NVARCHAR(150)               NOT NULL,
    Cantidad         INT                         NOT NULL,
    PrecioUnitario   DECIMAL(18,2)               NOT NULL,
    Subtotal         AS (Cantidad * PrecioUnitario) PERSISTED,
    CONSTRAINT PK_FacturaDetalle PRIMARY KEY (FacturaDetalleId)
);
GO

-- ?? 11. MovimientosInventario ???????????????????????????????
IF OBJECT_ID('dbo.MovimientosInventario', 'U') IS NULL
CREATE TABLE dbo.MovimientosInventario (
    MovimientoId    INT           IDENTITY(1,1) NOT NULL,
    ProductoId      INT                         NOT NULL,  -- FK ? Productos (Fase 2)
    UsuarioId       INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    ProductoNombre  NVARCHAR(150)               NOT NULL,
    TipoMovimiento  NVARCHAR(30)                NOT NULL,
    Cantidad        INT                         NOT NULL,
    StockAnterior   INT                         NOT NULL,
    StockNuevo      INT                         NOT NULL,
    Motivo          NVARCHAR(250)               NULL,
    UsuarioNombre   NVARCHAR(150)               NOT NULL,
    FechaMovimiento DATETIME2                   NOT NULL CONSTRAINT DF_MovInv_FechaMovimiento DEFAULT SYSDATETIME(),
    CONSTRAINT PK_MovimientosInventario PRIMARY KEY (MovimientoId),
    CONSTRAINT CK_MovInv_Tipo CHECK (TipoMovimiento IN (N'Entrada', N'Salida', N'Ajuste'))
);
GO

-- ?? 12. PasswordResetTokens ?????????????????????????????????
IF OBJECT_ID('dbo.PasswordResetTokens', 'U') IS NULL
CREATE TABLE dbo.PasswordResetTokens (
    PasswordResetTokenId INT           IDENTITY(1,1) NOT NULL,
    UsuarioId            INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    Token                NVARCHAR(120)               NOT NULL,
    FechaExpiracion      DATETIME2                   NOT NULL,
    Usado                BIT                         NOT NULL CONSTRAINT DF_PRT_Usado        DEFAULT 0,
    FechaCreacion        DATETIME2                   NOT NULL CONSTRAINT DF_PRT_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_PasswordResetTokens  PRIMARY KEY (PasswordResetTokenId),
    CONSTRAINT UQ_PasswordResetTokens_Token UNIQUE (Token)
);
GO

-- ?? 13. ErrorLog ????????????????????????????????????????????
IF OBJECT_ID('dbo.ErrorLog', 'U') IS NULL
CREATE TABLE dbo.ErrorLog (
    ErrorId    INT           IDENTITY(1,1) NOT NULL,
    UsuarioId  INT                         NULL,      -- FK ? Usuarios (Fase 2), nullable
    Mensaje    NVARCHAR(500)               NOT NULL,
    Origen     NVARCHAR(255)               NULL,
    StackTrace NVARCHAR(MAX)               NULL,
    Fecha      DATETIME2                   NOT NULL CONSTRAINT DF_ErrorLog_Fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ErrorLog PRIMARY KEY (ErrorId)
);
GO

-- ?? 14. PerfilPermisos ??????????????????????????????????????
IF OBJECT_ID('dbo.PerfilPermisos', 'U') IS NULL
CREATE TABLE dbo.PerfilPermisos (
    PerfilId                INT           NOT NULL,  -- FK ? Perfiles (Fase 2)
    PermisoId               INT           NOT NULL,  -- FK ? Permisos (Fase 2)
    UsuarioAsignacionId     INT           NULL,       -- FK ? Usuarios (Fase 2)
    FechaAsignacion         DATETIME2     NOT NULL CONSTRAINT DF_PP_FechaAsignacion DEFAULT SYSDATETIME(),
    UsuarioAsignacionNombre NVARCHAR(150) NULL,
    CONSTRAINT PK_PerfilPermisos PRIMARY KEY (PerfilId, PermisoId)
);
GO

-- ?? 15. Consultas ???????????????????????????????????????????
IF OBJECT_ID('dbo.Consultas', 'U') IS NULL
CREATE TABLE dbo.Consultas (
    ConsultaId           INT            IDENTITY(1,1) NOT NULL,
    AtendidoPorUsuarioId INT                          NULL,      -- FK ? Usuarios (Fase 2)
    Nombre               NVARCHAR(100)                NOT NULL,
    Correo               NVARCHAR(150)                NOT NULL,
    Asunto               NVARCHAR(120)                NOT NULL,
    Mensaje              NVARCHAR(1000)               NOT NULL,
    Estado               NVARCHAR(30)                 NOT NULL CONSTRAINT DF_Consultas_Estado       DEFAULT N'Pendiente',
    RespuestaInterna     NVARCHAR(1000)               NULL,
    AtendidoPorNombre    NVARCHAR(150)                NULL,
    FechaAtencion        DATETIME2                    NULL,
    FechaCreacion        DATETIME2                    NOT NULL CONSTRAINT DF_Consultas_FechaCreacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Consultas PRIMARY KEY (ConsultaId),
    CONSTRAINT CK_Consultas_Estado CHECK (Estado IN (N'Pendiente', N'Atendida', N'Cerrada'))
);
GO

-- ?? 16. ClienteCreditos ?????????????????????????????????????
IF OBJECT_ID('dbo.ClienteCreditos', 'U') IS NULL
CREATE TABLE dbo.ClienteCreditos (
    ClienteCreditoId   INT           IDENTITY(1,1) NOT NULL,
    UsuarioId          INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    LimiteCredito      DECIMAL(18,2)               NOT NULL CONSTRAINT DF_CC_LimiteCredito    DEFAULT 0,
    CreditoActivo      BIT                         NOT NULL CONSTRAINT DF_CC_CreditoActivo    DEFAULT 0,
    CreditoBloqueado   BIT                         NOT NULL CONSTRAINT DF_CC_CreditoBloqueado DEFAULT 0,
    MotivoBloqueo      NVARCHAR(255)               NULL,
    FechaCreacion      DATETIME2                   NOT NULL CONSTRAINT DF_CC_FechaCreacion    DEFAULT SYSDATETIME(),
    FechaActualizacion DATETIME2                   NOT NULL CONSTRAINT DF_CC_FechaActualizacion DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ClienteCreditos          PRIMARY KEY (ClienteCreditoId),
    CONSTRAINT UQ_ClienteCreditos_UsuarioId UNIQUE    (UsuarioId),
    CONSTRAINT CK_CC_LimiteCredito         CHECK     (LimiteCredito >= 0)
);
GO

-- ?? 17. ClienteCreditoMovimientos ???????????????????????????
IF OBJECT_ID('dbo.ClienteCreditoMovimientos', 'U') IS NULL
CREATE TABLE dbo.ClienteCreditoMovimientos (
    CreditoMovimientoId    INT           IDENTITY(1,1) NOT NULL,
    UsuarioId              INT                         NOT NULL,  -- FK ? Usuarios (Fase 2)
    RegistradoPorUsuarioId INT                         NULL,      -- FK ? Usuarios (Fase 2)
    TipoMovimiento         NVARCHAR(30)                NOT NULL,
    Monto                  DECIMAL(18,2)               NOT NULL,
    Descripcion            NVARCHAR(500)               NOT NULL,
    Referencia             NVARCHAR(100)               NULL,
    RegistradoPorNombre    NVARCHAR(150)               NULL,
    FechaMovimiento        DATETIME2                   NOT NULL CONSTRAINT DF_CCM_FechaMovimiento DEFAULT SYSDATETIME(),
    CONSTRAINT PK_ClienteCreditoMovimientos PRIMARY KEY (CreditoMovimientoId),
    CONSTRAINT CK_CCM_TipoMovimiento CHECK (TipoMovimiento IN (
        N'Cargo', N'Abono', N'AjustePositivo', N'AjusteNegativo'
    )),
    CONSTRAINT CK_CCM_Monto CHECK (Monto > 0)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ClienteCreditoMovimientos')
      AND name = 'IX_ClienteCreditoMovimientos_Usuario_Fecha'
)
    CREATE INDEX IX_ClienteCreditoMovimientos_Usuario_Fecha
        ON dbo.ClienteCreditoMovimientos (UsuarioId, FechaMovimiento DESC);
GO

-- ?? 18. AuditoriaSistema ????????????????????????????????????
IF OBJECT_ID('dbo.AuditoriaSistema', 'U') IS NULL
CREATE TABLE dbo.AuditoriaSistema (
    AuditoriaId   INT           IDENTITY(1,1) NOT NULL,
    UsuarioId     INT                         NULL,      -- FK ? Usuarios (Fase 2), nullable
    UsuarioNombre NVARCHAR(150)               NOT NULL,
    UsuarioCorreo NVARCHAR(150)               NOT NULL,
    Rol           NVARCHAR(50)                NOT NULL,
    Accion        NVARCHAR(80)                NOT NULL,
    Modulo        NVARCHAR(80)                NOT NULL,
    Descripcion   NVARCHAR(500)               NOT NULL,
    DireccionIp   NVARCHAR(80)                NULL,
    UserAgent     NVARCHAR(300)               NULL,
    FechaRegistro DATETIME2                   NOT NULL CONSTRAINT DF_Auditoria_FechaRegistro DEFAULT SYSDATETIME(),
    CONSTRAINT PK_AuditoriaSistema PRIMARY KEY (AuditoriaId)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.AuditoriaSistema') AND name = 'IX_AuditoriaSistema_FechaRegistro')
    CREATE INDEX IX_AuditoriaSistema_FechaRegistro ON dbo.AuditoriaSistema (FechaRegistro DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.AuditoriaSistema') AND name = 'IX_AuditoriaSistema_Modulo_Accion')
    CREATE INDEX IX_AuditoriaSistema_Modulo_Accion  ON dbo.AuditoriaSistema (Modulo, Accion);
GO

-- ?? 19. EmpleadoHistorialSalarios ???????????????????????????
IF OBJECT_ID('dbo.EmpleadoHistorialSalarios', 'U') IS NULL
CREATE TABLE dbo.EmpleadoHistorialSalarios (
    HistorialSalarioId  INT           IDENTITY(1,1) NOT NULL,
    EmpleadoId          INT                         NOT NULL,  -- FK ? Empleados (Fase 2)
    UsuarioCambioId     INT                         NULL,      -- FK ? Usuarios (Fase 2)
    SalarioAnterior     DECIMAL(18,2)               NULL,
    SalarioNuevo        DECIMAL(18,2)               NOT NULL,
    Motivo              NVARCHAR(255)               NULL,
    UsuarioCambioNombre NVARCHAR(150)               NULL,
    FechaCambio         DATETIME2                   NOT NULL CONSTRAINT DF_EHS_FechaCambio DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EmpleadoHistorialSalarios PRIMARY KEY (HistorialSalarioId)
);
GO

-- ?? 20. EmpleadoSolicitudesTiempoLibre ?????????????????????
IF OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre', 'U') IS NULL
CREATE TABLE dbo.EmpleadoSolicitudesTiempoLibre (
    SolicitudId              INT           IDENTITY(1,1) NOT NULL,
    EmpleadoId               INT                         NOT NULL,  -- FK ? Empleados (Fase 2)
    UsuarioRespuestaId       INT                         NULL,      -- FK ? Usuarios (Fase 2)
    FechaInicio              DATE                        NOT NULL,
    FechaFin                 DATE                        NOT NULL,
    CantidadDias             INT                         NOT NULL,
    TipoSolicitud            NVARCHAR(30)                NOT NULL,
    Motivo                   NVARCHAR(500)               NOT NULL,
    Estado                   NVARCHAR(30)                NOT NULL CONSTRAINT DF_ESTL_Estado        DEFAULT N'Pendiente',
    RespuestaAdmin           NVARCHAR(500)               NULL,
    UsuarioRespuestaNombre   NVARCHAR(150)               NULL,
    FechaSolicitud           DATETIME2                   NOT NULL CONSTRAINT DF_ESTL_FechaSolicitud DEFAULT SYSDATETIME(),
    FechaRespuesta           DATETIME2                   NULL,
    CONSTRAINT PK_EmpleadoSolicitudesTiempoLibre PRIMARY KEY (SolicitudId),
    CONSTRAINT CK_ESTL_TipoSolicitud CHECK (TipoSolicitud IN (N'Con goce salarial', N'Sin goce salarial')),
    CONSTRAINT CK_ESTL_Estado        CHECK (Estado IN (N'Pendiente', N'Aprobada', N'Rechazada', N'Cancelada')),
    CONSTRAINT CK_ESTL_Dias          CHECK (CantidadDias > 0),
    CONSTRAINT CK_ESTL_Fechas        CHECK (FechaFin >= FechaInicio)
);
GO

-- ?? 21. EmpleadoTareas ??????????????????????????????????????
IF OBJECT_ID('dbo.EmpleadoTareas', 'U') IS NULL
CREATE TABLE dbo.EmpleadoTareas (
    TareaId                 INT           IDENTITY(1,1) NOT NULL,
    EmpleadoId              INT                         NOT NULL,  -- FK ? Empleados (Fase 2)
    UsuarioAsignacionId     INT                         NULL,      -- FK ? Usuarios (Fase 2)
    Titulo                  NVARCHAR(150)               NOT NULL,
    Descripcion             NVARCHAR(700)               NULL,
    Prioridad               NVARCHAR(20)                NOT NULL CONSTRAINT DF_ET_Prioridad      DEFAULT N'Media',
    Estado                  NVARCHAR(30)                NOT NULL CONSTRAINT DF_ET_Estado         DEFAULT N'Pendiente',
    FechaAsignacion         DATETIME2                   NOT NULL CONSTRAINT DF_ET_FechaAsignacion DEFAULT SYSDATETIME(),
    FechaLimite             DATE                        NULL,
    UsuarioAsignacionNombre NVARCHAR(150)               NULL,
    FechaActualizacion      DATETIME2                   NULL,
    CONSTRAINT PK_EmpleadoTareas PRIMARY KEY (TareaId),
    CONSTRAINT CK_ET_Prioridad CHECK (Prioridad IN (N'Baja', N'Media', N'Alta', N'Urgente')),
    CONSTRAINT CK_ET_Estado    CHECK (Estado IN (N'Pendiente', N'En proceso', N'Completada', N'Cancelada'))
);
GO

PRINT '? FASE 1 completada — 21 tablas creadas sin llaves foráneas.';
GO