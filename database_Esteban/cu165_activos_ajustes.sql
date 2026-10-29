-- ============================================================
-- CU-165 — AJUSTES A ACTIVOS (soporte a comodatos)
--
--   • sp_Activos_UpdateInfo: actualiza SOLO datos descriptivos
--     (código, nombre, tipo, descripción). El Estado y "Prestado a"
--     los gobierna el flujo de Comodatos, NO la edición del activo.
--   • sp_Activos_Delete: baja lógica del activo (Activo=0, Estado='Baja').
--     Bloquea si el activo está Prestado (comodato activo).
--
-- 100 % ADITIVO e IDEMPOTENTE. No altera tablas ni SPs previos.
-- Prerrequisito: cu152_153_154_161 (dbo.Activos) y cu162_163_164 (Comodatos).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Activos_UpdateInfo
    @ActivoId     INT,
    @CodigoActivo NVARCHAR(40),
    @Nombre       NVARCHAR(150),
    @Tipo         NVARCHAR(40),
    @Descripcion  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @CodigoActivo = NULLIF(LTRIM(RTRIM(@CodigoActivo)), N'');
    SET @Nombre       = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
    IF @CodigoActivo IS NULL OR @Nombre IS NULL THROW 53060, 'El código y el nombre del activo son obligatorios.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Activos WHERE ActivoId = @ActivoId) THROW 53062, 'No se encontró el activo.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Activos WHERE CodigoActivo = @CodigoActivo AND ActivoId <> @ActivoId)
        THROW 53061, 'Ya existe un activo con ese código.', 1;

    -- No se tocan Estado ni ClientePrestamo: son responsabilidad del módulo de Comodatos.
    UPDATE dbo.Activos
    SET CodigoActivo = @CodigoActivo,
        Nombre = @Nombre,
        Tipo = @Tipo,
        Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N''),
        FechaActualizacion = SYSDATETIME()
    WHERE ActivoId = @ActivoId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Activos_Delete
    @ActivoId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Estado NVARCHAR(20) = (SELECT Estado FROM dbo.Activos WHERE ActivoId = @ActivoId);
    IF @Estado IS NULL          THROW 53062, 'No se encontró el activo.', 1;
    IF @Estado = N'Prestado'    THROW 53063, 'No se puede eliminar un activo que está prestado. Registre primero su devolución.', 1;

    -- Baja lógica: preserva historial (comodatos, referencias) e integridad referencial.
    UPDATE dbo.Activos
    SET Activo = 0, Estado = N'Baja', FechaActualizacion = SYSDATETIME()
    WHERE ActivoId = @ActivoId;
END;
GO

PRINT 'CU-165 aplicado: sp_Activos_UpdateInfo y sp_Activos_Delete.';
GO
