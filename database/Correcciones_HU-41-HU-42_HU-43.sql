-- ==========================================
-- CU-041: Gestión de Roles (Perfiles)
-- ==========================================
-- La tabla dbo.Perfiles y su relación con dbo.Usuarios ya existen.
-- No se requiere DDL adicional para esta historia, solo la lógica en C#.


-- ==========================================
-- CU-042: Control de Acceso a Módulos
-- ==========================================
-- 1. Creamos el catálogo de los módulos del sistema
CREATE TABLE dbo.Modulos (
    ModuloId INT IDENTITY(1,1) PRIMARY KEY,
    NombreModulo NVARCHAR(100) NOT NULL UNIQUE -- Ej: 'Inventario', 'Facturacion', 'Admin'
);

-- 2. Creamos la tabla intermedia para relacionar Perfiles con Módulos
CREATE TABLE dbo.PermisosPerfil (
    PerfilId INT NOT NULL,
    ModuloId INT NOT NULL,
    CONSTRAINT PK_PermisosPerfil PRIMARY KEY (PerfilId, ModuloId),
    CONSTRAINT FK_PermisosPerfil_Perfiles FOREIGN KEY (PerfilId) REFERENCES dbo.Perfiles(PerfilId),
    CONSTRAINT FK_PermisosPerfil_Modulos FOREIGN KEY (ModuloId) REFERENCES dbo.Modulos(ModuloId)
);


-- ==========================================
-- CU-043: Registro de Auditoría y Trazabilidad
-- ==========================================
-- Creamos la bitácora de acciones
CREATE TABLE dbo.HistorialAuditoria (
    AuditoriaId INT IDENTITY(1,1) PRIMARY KEY,
    UsuarioId INT NOT NULL, 
    Accion NVARCHAR(100) NOT NULL, -- Ej: 'LOGIN', 'CREAR_PERFIL', 'ELIMINAR_PRODUCTO'
    Modulo NVARCHAR(50) NOT NULL,  -- Ej: 'Seguridad', 'Inventario'
    Detalles NVARCHAR(MAX),        -- JSON o texto con el detalle de qué cambió
    FechaHora DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_HistorialAuditoria_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
);

-- 1. Registrar los módulos del sistema (los mismos nombres que pusiste en los [AdminAuthorize])
INSERT INTO dbo.Modulos (NombreModulo) 
VALUES ('Admin'), ('Facturacion'), ('Inventario'), ('Pedidos'), ('Seguridad');

-- 2. Asignarle todos los permisos al perfil de Administrador.
-- OJO: Estoy asumiendo que tu perfil de Administrador en la tabla dbo.Perfiles tiene el PerfilId = 1.
-- Si tu ID de administrador es otro, cambia el '1' por el número correcto.
INSERT INTO dbo.PermisosPerfil (PerfilId, ModuloId)
SELECT 1, ModuloId FROM dbo.Modulos;