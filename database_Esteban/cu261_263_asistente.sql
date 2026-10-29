-- ============================================================
-- CU-261 / CU-263 — ASISTENTE VIRTUAL
--
--   CU-261  Consultar métricas clave por lenguaje natural.
--   CU-263  Solicitar ayuda sobre cómo usar un módulo específico.
--
-- CARACTERÍSTICAS DE SEGURIDAD (sistema en producción):
--   • 100 % ADITIVO: una tabla de bitácora + un SP. Sin dependencias de IA
--     externas: el motor de intención (reglas) vive en C#, y las métricas
--     se reutilizan de sp_Reportes_DashboardKpis (CU-131).
--   • IDEMPOTENTE.
--
-- Prerrequisito: esquema base (Usuarios) aplicado.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- CU-263 E3 — Bitácora de consultas al asistente (para mejorar respuestas)
IF OBJECT_ID('dbo.AsistenteConsultas', 'U') IS NULL
CREATE TABLE dbo.AsistenteConsultas (
    ConsultaId      INT           IDENTITY(1,1) NOT NULL,
    UsuarioId       INT                         NULL,   -- FK -> Usuarios
    UsuarioNombre   NVARCHAR(150)               NULL,
    Pregunta        NVARCHAR(500)               NOT NULL,
    IntentDetectado NVARCHAR(60)                NULL,
    Modulo          NVARCHAR(60)                NULL,
    Interpretado    BIT                         NOT NULL CONSTRAINT DF_AsisCons_Interp DEFAULT 0,
    FechaConsulta   DATETIME2                   NOT NULL CONSTRAINT DF_AsisCons_Fecha  DEFAULT SYSDATETIME(),
    CONSTRAINT PK_AsistenteConsultas PRIMARY KEY (ConsultaId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AsistenteConsultas_Fecha' AND object_id = OBJECT_ID('dbo.AsistenteConsultas'))
    CREATE INDEX IX_AsistenteConsultas_Fecha ON dbo.AsistenteConsultas (FechaConsulta DESC);
GO

CREATE OR ALTER PROCEDURE dbo.sp_Asistente_Log
    @UsuarioId       INT           = NULL,
    @UsuarioNombre   NVARCHAR(150) = NULL,
    @Pregunta        NVARCHAR(500),
    @IntentDetectado NVARCHAR(60)  = NULL,
    @Modulo          NVARCHAR(60)  = NULL,
    @Interpretado    BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AsistenteConsultas (UsuarioId, UsuarioNombre, Pregunta, IntentDetectado, Modulo, Interpretado)
    VALUES (@UsuarioId, @UsuarioNombre, @Pregunta, @IntentDetectado, @Modulo, ISNULL(@Interpretado, 0));
END;
GO

-- Permiso (opcional; el acceso base se controla por sesión).
MERGE dbo.Permisos AS target
USING (VALUES
    (N'ASISTENTE_METRICAS', N'Asistente', N'Consultar métricas por asistente', N'Consultar KPIs del negocio mediante el asistente virtual.')
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN UPDATE SET Modulo = source.Modulo, Nombre = source.Nombre, Descripcion = source.Descripcion, Activo = 1
WHEN NOT MATCHED THEN INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

DECLARE @Asig TABLE (Rol NVARCHAR(50), Codigo NVARCHAR(100));
INSERT INTO @Asig (Rol, Codigo) VALUES
    (N'Administrador', N'ASISTENTE_METRICAS'),
    (N'Gerente',       N'ASISTENTE_METRICAS');
INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT p.PerfilId, pe.PermisoId, NULL, N'Script CU-261/263'
FROM @Asig a
INNER JOIN dbo.Perfiles p  ON p.Nombre  = a.Rol
INNER JOIN dbo.Permisos pe ON pe.Codigo = a.Codigo AND pe.Activo = 1
WHERE NOT EXISTS (SELECT 1 FROM dbo.PerfilPermisos pp WHERE pp.PerfilId = p.PerfilId AND pp.PermisoId = pe.PermisoId);
GO

PRINT 'CU-261/263 aplicado: bitácora del asistente + permiso de métricas.';
GO
