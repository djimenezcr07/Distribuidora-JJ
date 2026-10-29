-- ============================================================
-- CU-152 (refuerzo) — ODÓMETRO COHERENTE DE LA FLOTA
--
-- Problema corregido: el kilometraje de jornada no validaba contra el
-- odómetro del vehículo (se podía iniciar con un valor menor al último
-- registrado). Ahora cada vehículo mantiene su KilometrajeActual y toda
-- jornada respeta una secuencia lógica y monótona creciente.
--
-- 100 % ADITIVO e IDEMPOTENTE. Reutiliza dbo.Vehiculos y las tablas de
-- kilometraje/mantenimiento. Re-declara SPs con CREATE OR ALTER.
--
-- Prerrequisito: cu081 (Vehiculos), cu151 (Marca), cu152 (kilometraje).
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO
SET NOCOUNT ON;
GO

-- 1) Atributo de odómetro en el vehículo -------------------------------
IF COL_LENGTH('dbo.Vehiculos', 'KilometrajeActual') IS NULL
    ALTER TABLE dbo.Vehiculos ADD KilometrajeActual INT NOT NULL CONSTRAINT DF_Vehiculos_KmActual DEFAULT 0;
GO

-- Backfill: sembrar el odómetro con el mayor km final registrado (solo si aún está en 0).
UPDATE v
SET v.KilometrajeActual = km.MaxKm
FROM dbo.Vehiculos v
INNER JOIN (
    SELECT VehiculoId, MAX(KmFinal) AS MaxKm
    FROM dbo.VehiculoKilometraje
    WHERE KmFinal IS NOT NULL
    GROUP BY VehiculoId
) km ON km.VehiculoId = v.VehiculoId
WHERE v.KilometrajeActual = 0 AND km.MaxKm > 0;
GO

-- 2) sp_Vehiculos_List — incluye KilometrajeActual al final -------------
CREATE OR ALTER PROCEDURE dbo.sp_Vehiculos_List
    @Buscar NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');

    SELECT
        v.VehiculoId,
        v.Placa,
        v.Descripcion,
        ISNULL(v.Capacidad, 0) AS Capacidad,
        v.Activo,
        (SELECT COUNT(*) FROM dbo.Rutas r
          WHERE r.VehiculoId = v.VehiculoId
            AND r.Estado IN (N'Planificada', N'Despachada')) AS RutasAbiertas,
        v.Marca,
        v.KilometrajeActual
    FROM dbo.Vehiculos v
    WHERE (@Buscar IS NULL
           OR v.Placa       LIKE N'%' + @Buscar + N'%'
           OR v.Descripcion LIKE N'%' + @Buscar + N'%'
           OR v.Marca       LIKE N'%' + @Buscar + N'%')
    ORDER BY v.Activo DESC, v.Placa ASC;
END;
GO

-- 3) sp_Kilometraje_Abrir — valida contra el odómetro y lo avanza -------
CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_Abrir
    @VehiculoId INT,
    @ChoferUsuarioId INT           = NULL,
    @ChoferNombre    NVARCHAR(150)  = NULL,
    @KmInicial       INT,
    @Observaciones   NVARCHAR(300)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Odometro INT;
    SELECT @Odometro = KilometrajeActual FROM dbo.Vehiculos WHERE VehiculoId = @VehiculoId AND Activo = 1;

    IF @Odometro IS NULL THROW 53040, 'El vehículo no existe o está inactivo.', 1;
    IF ISNULL(@KmInicial, -1) < 0 THROW 53041, 'El kilometraje inicial no es válido.', 1;
    IF EXISTS (SELECT 1 FROM dbo.VehiculoKilometraje WHERE VehiculoId = @VehiculoId AND KmFinal IS NULL)
        THROW 53042, 'El vehículo tiene una jornada de kilometraje sin cerrar.', 1;

    IF @KmInicial < @Odometro
    BEGIN
        DECLARE @msg NVARCHAR(200) = CONCAT(
            N'El kilometraje inicial (', @KmInicial, N' km) no puede ser menor al odómetro actual del vehículo (', @Odometro, N' km).');
        THROW 53046, @msg, 1;
    END;

    BEGIN TRANSACTION;

    INSERT INTO dbo.VehiculoKilometraje (VehiculoId, ChoferUsuarioId, ChoferNombre, KmInicial, Observaciones)
    VALUES (@VehiculoId, @ChoferUsuarioId, @ChoferNombre, @KmInicial, NULLIF(LTRIM(RTRIM(@Observaciones)), N''));

    DECLARE @KilometrajeId INT = CAST(SCOPE_IDENTITY() AS INT);

    -- El odómetro nunca retrocede
    UPDATE dbo.Vehiculos SET KilometrajeActual = @KmInicial
    WHERE VehiculoId = @VehiculoId AND KilometrajeActual < @KmInicial;

    COMMIT TRANSACTION;

    SELECT @KilometrajeId AS KilometrajeId;
END;
GO

-- 4) sp_Kilometraje_Cerrar — actualiza el odómetro al km final ----------
CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_Cerrar
    @KilometrajeId INT,
    @KmFinal       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @KmInicial INT, @KmFinalActual INT, @VehiculoId INT;
    SELECT @KmInicial = KmInicial, @KmFinalActual = KmFinal, @VehiculoId = VehiculoId
    FROM dbo.VehiculoKilometraje WHERE KilometrajeId = @KilometrajeId;

    IF @KmInicial IS NULL         THROW 53043, 'No se encontró la jornada indicada.', 1;
    IF @KmFinalActual IS NOT NULL THROW 53044, 'La jornada ya fue cerrada.', 1;
    IF @KmFinal < @KmInicial      THROW 53045, 'El kilometraje final no puede ser menor al inicial.', 1;

    BEGIN TRANSACTION;

    UPDATE dbo.VehiculoKilometraje
    SET KmFinal = @KmFinal, FechaCierre = SYSDATETIME()
    WHERE KilometrajeId = @KilometrajeId;

    -- El odómetro del vehículo avanza al km final de la jornada
    UPDATE dbo.Vehiculos SET KilometrajeActual = @KmFinal
    WHERE VehiculoId = @VehiculoId AND KilometrajeActual < @KmFinal;

    COMMIT TRANSACTION;
END;
GO

-- 5) sp_Flota_Alertas — usa el odómetro del vehículo (coherencia) -------
CREATE OR ALTER PROCEDURE dbo.sp_Flota_Alertas
    @DiasAviso INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);

    SELECT * FROM (
        -- Documentos legales por vencer o vencidos
        SELECT
            N'Documento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(d.Tipo, N' vence el ', FORMAT(d.FechaVencimiento, 'dd/MM/yyyy')) AS Detalle,
            d.FechaVencimiento AS Fecha,
            DATEDIFF(DAY, @Hoy, d.FechaVencimiento) AS DiasRestantes,
            CASE WHEN d.FechaVencimiento < @Hoy THEN N'Vencido' ELSE N'PorVencer' END AS Severidad
        FROM dbo.VehiculoDocumentos d
        INNER JOIN dbo.Vehiculos v ON v.VehiculoId = d.VehiculoId
        WHERE DATEDIFF(DAY, @Hoy, d.FechaVencimiento) <= @DiasAviso

        UNION ALL

        -- Mantenimientos preventivos programados por fecha
        SELECT
            N'Mantenimiento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(N'Preventivo programado: ', m.Descripcion) AS Detalle,
            m.FechaProgramada AS Fecha,
            DATEDIFF(DAY, @Hoy, m.FechaProgramada) AS DiasRestantes,
            CASE WHEN m.FechaProgramada < @Hoy THEN N'Vencido' ELSE N'PorVencer' END AS Severidad
        FROM dbo.OrdenesMantenimiento m
        INNER JOIN dbo.Vehiculos v ON v.VehiculoId = m.VehiculoId
        WHERE m.Tipo = N'Preventivo' AND m.Estado = N'Programada'
          AND m.FechaProgramada IS NOT NULL
          AND DATEDIFF(DAY, @Hoy, m.FechaProgramada) <= @DiasAviso

        UNION ALL

        -- Mantenimientos preventivos por desgaste (odómetro del vehículo)
        SELECT
            N'Mantenimiento' AS Categoria,
            v.Placa AS VehiculoPlaca,
            CONCAT(N'Preventivo por kilometraje (', m.KilometrajeProximo, N' km, actual ', v.KilometrajeActual, N' km): ', m.Descripcion) AS Detalle,
            NULL AS Fecha,
            NULL AS DiasRestantes,
            N'Vencido' AS Severidad
        FROM dbo.OrdenesMantenimiento m
        INNER JOIN dbo.Vehiculos v ON v.VehiculoId = m.VehiculoId
        WHERE m.Tipo = N'Preventivo' AND m.Estado = N'Programada'
          AND m.KilometrajeProximo IS NOT NULL
          AND v.KilometrajeActual >= m.KilometrajeProximo
    ) AS Alertas
    ORDER BY CASE Severidad WHEN N'Vencido' THEN 0 ELSE 1 END, DiasRestantes;
END;
GO

PRINT 'cu301 aplicado: odómetro de flota + validaciones de kilometraje + alertas por desgaste.';
GO
