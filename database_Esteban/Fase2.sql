-- ============================================================
-- FASE 2: RELACIONES — DistribuidoraJJ_DB
-- Agrega todas las llaves foráneas en orden seguro (padre ? hijo).
-- Idempotente: verifica sys.foreign_keys antes de cada ADD.
-- Prerequisito: Fase 1 ejecutada sin errores.
-- ============================================================

USE DistribuidoraJJ_DB;
GO

-- ?? GRUPO 1: Usuarios depende de Perfiles ??????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Usuarios_PerfilId'
      AND parent_object_id = OBJECT_ID('dbo.Usuarios')
)
    ALTER TABLE dbo.Usuarios
        ADD CONSTRAINT FK_Usuarios_PerfilId
        FOREIGN KEY (PerfilId) REFERENCES dbo.Perfiles (PerfilId);
GO

-- ?? GRUPO 2: Empleados depende de Usuarios ?????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Empleados_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.Empleados')
)
    ALTER TABLE dbo.Empleados
        ADD CONSTRAINT FK_Empleados_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 3: Productos depende de Categorias ???????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Productos_CategoriaId'
      AND parent_object_id = OBJECT_ID('dbo.Productos')
)
    ALTER TABLE dbo.Productos
        ADD CONSTRAINT FK_Productos_CategoriaId
        FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias (CategoriaId);
GO

-- ?? GRUPO 4: Pedidos depende de Usuarios (×2) ??????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Pedidos_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.Pedidos')
)
    ALTER TABLE dbo.Pedidos
        ADD CONSTRAINT FK_Pedidos_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Pedidos_VendedorUsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.Pedidos')
)
    ALTER TABLE dbo.Pedidos
        ADD CONSTRAINT FK_Pedidos_VendedorUsuarioId
        FOREIGN KEY (VendedorUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 5: PedidoDetalle depende de Pedidos + Productos ??

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PedidoDetalle_PedidoId'
      AND parent_object_id = OBJECT_ID('dbo.PedidoDetalle')
)
    ALTER TABLE dbo.PedidoDetalle
        ADD CONSTRAINT FK_PedidoDetalle_PedidoId
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos (PedidoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PedidoDetalle_ProductoId'
      AND parent_object_id = OBJECT_ID('dbo.PedidoDetalle')
)
    ALTER TABLE dbo.PedidoDetalle
        ADD CONSTRAINT FK_PedidoDetalle_ProductoId
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (ProductoId);
GO

-- ?? GRUPO 6: Facturas depende de Pedidos + Usuarios ????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Facturas_PedidoId'
      AND parent_object_id = OBJECT_ID('dbo.Facturas')
)
    ALTER TABLE dbo.Facturas
        ADD CONSTRAINT FK_Facturas_PedidoId
        FOREIGN KEY (PedidoId) REFERENCES dbo.Pedidos (PedidoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Facturas_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.Facturas')
)
    ALTER TABLE dbo.Facturas
        ADD CONSTRAINT FK_Facturas_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 7: FacturaDetalle depende de Facturas + Productos ?

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_FacturaDetalle_FacturaId'
      AND parent_object_id = OBJECT_ID('dbo.FacturaDetalle')
)
    ALTER TABLE dbo.FacturaDetalle
        ADD CONSTRAINT FK_FacturaDetalle_FacturaId
        FOREIGN KEY (FacturaId) REFERENCES dbo.Facturas (FacturaId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_FacturaDetalle_ProductoId'
      AND parent_object_id = OBJECT_ID('dbo.FacturaDetalle')
)
    ALTER TABLE dbo.FacturaDetalle
        ADD CONSTRAINT FK_FacturaDetalle_ProductoId
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (ProductoId);
GO

-- ?? GRUPO 8: MovimientosInventario ?????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_MovimientosInventario_ProductoId'
      AND parent_object_id = OBJECT_ID('dbo.MovimientosInventario')
)
    ALTER TABLE dbo.MovimientosInventario
        ADD CONSTRAINT FK_MovimientosInventario_ProductoId
        FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (ProductoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_MovimientosInventario_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.MovimientosInventario')
)
    ALTER TABLE dbo.MovimientosInventario
        ADD CONSTRAINT FK_MovimientosInventario_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 9: PasswordResetTokens ???????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PasswordResetTokens_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.PasswordResetTokens')
)
    ALTER TABLE dbo.PasswordResetTokens
        ADD CONSTRAINT FK_PasswordResetTokens_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 10: ErrorLog ??????????????????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ErrorLog_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.ErrorLog')
)
    ALTER TABLE dbo.ErrorLog
        ADD CONSTRAINT FK_ErrorLog_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 11: PerfilPermisos depende de Perfiles + Permisos + Usuarios ?

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PerfilPermisos_PerfilId'
      AND parent_object_id = OBJECT_ID('dbo.PerfilPermisos')
)
    ALTER TABLE dbo.PerfilPermisos
        ADD CONSTRAINT FK_PerfilPermisos_PerfilId
        FOREIGN KEY (PerfilId) REFERENCES dbo.Perfiles (PerfilId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PerfilPermisos_PermisoId'
      AND parent_object_id = OBJECT_ID('dbo.PerfilPermisos')
)
    ALTER TABLE dbo.PerfilPermisos
        ADD CONSTRAINT FK_PerfilPermisos_PermisoId
        FOREIGN KEY (PermisoId) REFERENCES dbo.Permisos (PermisoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_PerfilPermisos_UsuarioAsignacionId'
      AND parent_object_id = OBJECT_ID('dbo.PerfilPermisos')
)
    ALTER TABLE dbo.PerfilPermisos
        ADD CONSTRAINT FK_PerfilPermisos_UsuarioAsignacionId
        FOREIGN KEY (UsuarioAsignacionId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 12: Consultas ?????????????????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_Consultas_AtendidoPorUsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.Consultas')
)
    ALTER TABLE dbo.Consultas
        ADD CONSTRAINT FK_Consultas_AtendidoPorUsuarioId
        FOREIGN KEY (AtendidoPorUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 13: ClienteCreditos ???????????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ClienteCreditos_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.ClienteCreditos')
)
    ALTER TABLE dbo.ClienteCreditos
        ADD CONSTRAINT FK_ClienteCreditos_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 14: ClienteCreditoMovimientos (×2) ???????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ClienteCreditoMovimientos_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.ClienteCreditoMovimientos')
)
    ALTER TABLE dbo.ClienteCreditoMovimientos
        ADD CONSTRAINT FK_ClienteCreditoMovimientos_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ClienteCreditoMovimientos_RegistradoPorUsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.ClienteCreditoMovimientos')
)
    ALTER TABLE dbo.ClienteCreditoMovimientos
        ADD CONSTRAINT FK_ClienteCreditoMovimientos_RegistradoPorUsuarioId
        FOREIGN KEY (RegistradoPorUsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 15: AuditoriaSistema ??????????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_AuditoriaSistema_UsuarioId'
      AND parent_object_id = OBJECT_ID('dbo.AuditoriaSistema')
)
    ALTER TABLE dbo.AuditoriaSistema
        ADD CONSTRAINT FK_AuditoriaSistema_UsuarioId
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 16: EmpleadoHistorialSalarios ????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_EmpleadoHistorialSalarios_EmpleadoId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoHistorialSalarios')
)
    ALTER TABLE dbo.EmpleadoHistorialSalarios
        ADD CONSTRAINT FK_EmpleadoHistorialSalarios_EmpleadoId
        FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados (EmpleadoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_EmpleadoHistorialSalarios_UsuarioCambioId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoHistorialSalarios')
)
    ALTER TABLE dbo.EmpleadoHistorialSalarios
        ADD CONSTRAINT FK_EmpleadoHistorialSalarios_UsuarioCambioId
        FOREIGN KEY (UsuarioCambioId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 17: EmpleadoSolicitudesTiempoLibre ???????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ESTL_EmpleadoId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre')
)
    ALTER TABLE dbo.EmpleadoSolicitudesTiempoLibre
        ADD CONSTRAINT FK_ESTL_EmpleadoId
        FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados (EmpleadoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_ESTL_UsuarioRespuestaId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre')
)
    ALTER TABLE dbo.EmpleadoSolicitudesTiempoLibre
        ADD CONSTRAINT FK_ESTL_UsuarioRespuestaId
        FOREIGN KEY (UsuarioRespuestaId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- ?? GRUPO 18: EmpleadoTareas ????????????????????????????????

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_EmpleadoTareas_EmpleadoId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoTareas')
)
    ALTER TABLE dbo.EmpleadoTareas
        ADD CONSTRAINT FK_EmpleadoTareas_EmpleadoId
        FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleados (EmpleadoId);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_EmpleadoTareas_UsuarioAsignacionId'
      AND parent_object_id = OBJECT_ID('dbo.EmpleadoTareas')
)
    ALTER TABLE dbo.EmpleadoTareas
        ADD CONSTRAINT FK_EmpleadoTareas_UsuarioAsignacionId
        FOREIGN KEY (UsuarioAsignacionId) REFERENCES dbo.Usuarios (UsuarioId);
GO

-- Verificación rápida: contar FKs registradas
SELECT COUNT(*) AS TotalFKsCreadas FROM sys.foreign_keys
WHERE parent_object_id IN (
    OBJECT_ID('dbo.Usuarios'), OBJECT_ID('dbo.Empleados'),
    OBJECT_ID('dbo.Productos'), OBJECT_ID('dbo.Pedidos'),
    OBJECT_ID('dbo.PedidoDetalle'), OBJECT_ID('dbo.Facturas'),
    OBJECT_ID('dbo.FacturaDetalle'), OBJECT_ID('dbo.MovimientosInventario'),
    OBJECT_ID('dbo.PasswordResetTokens'), OBJECT_ID('dbo.ErrorLog'),
    OBJECT_ID('dbo.PerfilPermisos'), OBJECT_ID('dbo.Consultas'),
    OBJECT_ID('dbo.ClienteCreditos'), OBJECT_ID('dbo.ClienteCreditoMovimientos'),
    OBJECT_ID('dbo.AuditoriaSistema'), OBJECT_ID('dbo.EmpleadoHistorialSalarios'),
    OBJECT_ID('dbo.EmpleadoSolicitudesTiempoLibre'), OBJECT_ID('dbo.EmpleadoTareas')
);
GO

PRINT '? FASE 2 completada — 29 llaves foráneas agregadas.';
GO