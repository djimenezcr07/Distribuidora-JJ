-- ============================================================
-- CU-083  —  EVIDENCIA DE ENTREGA
-- BLOQUE 3/4: STORED PROCEDURES  (registro y consulta de evidencias)
--
--   E1 Evidencia registrada : guarda foto o firma junto al pedido entregado.
--   E2 Entrega sin evidencia : se permite entregar sin adjuntar; las consultas
--                              marcan los pedidos "sin evidencia".
--   E3 Consulta de evidencias: por pedido o por ruta.
--
-- CREATE OR ALTER — idempotente. No modifica SPs existentes.
-- Prerrequisito: cu081 y cu082 aplicados.
-- ============================================================
-- Ejecute este script sobre la base de datos seleccionada por el operador.
GO

/* =========================================================
   1. sp_Entrega_RegisterEvidence   (CU-083 E1)
      El archivo (foto/firma) se guarda en disco por la capa web;
      aquí se registra la referencia (ArchivoUrl) y metadatos.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Entrega_RegisterEvidence
    @PedidoId               INT,
    @RutaId                 INT           = NULL,
    @TipoEvidencia          NVARCHAR(20),
    @ArchivoUrl             NVARCHAR(300),
    @Observaciones          NVARCHAR(300) = NULL,
    @RegistradoPorUsuarioId INT           = NULL,
    @RegistradoPorNombre    NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @TipoEvidencia = NULLIF(LTRIM(RTRIM(@TipoEvidencia)), N'');
    SET @ArchivoUrl    = NULLIF(LTRIM(RTRIM(@ArchivoUrl)), N'');

    IF @TipoEvidencia IS NULL OR @TipoEvidencia NOT IN (N'Foto', N'Firma')
        THROW 52080, 'El tipo de evidencia debe ser Foto o Firma.', 1;

    IF @ArchivoUrl IS NULL
        THROW 52081, 'Falta la referencia del archivo de evidencia.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos WHERE PedidoId = @PedidoId)
        THROW 52082, 'No se encontró el pedido indicado.', 1;

    IF @RutaId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Rutas WHERE RutaId = @RutaId)
        SET @RutaId = NULL;   -- referencia opcional; si no existe, se ignora

    INSERT INTO dbo.EntregaEvidencias
        (PedidoId, RutaId, TipoEvidencia, ArchivoUrl, Observaciones,
         RegistradoPorUsuarioId, RegistradoPorNombre, FechaRegistro)
    VALUES
        (@PedidoId, @RutaId, @TipoEvidencia, @ArchivoUrl,
         NULLIF(LTRIM(RTRIM(@Observaciones)), N''),
         @RegistradoPorUsuarioId, @RegistradoPorNombre, SYSDATETIME());

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS EvidenciaId;
END;
GO

/* =========================================================
   2. sp_Entrega_GetEvidencesByOrder   (CU-083 E3)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Entrega_GetEvidencesByOrder
    @PedidoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EvidenciaId,
        e.PedidoId,
        e.RutaId,
        e.TipoEvidencia,
        e.ArchivoUrl,
        ISNULL(e.Observaciones, N'')        AS Observaciones,
        ISNULL(e.RegistradoPorNombre, N'')  AS RegistradoPorNombre,
        e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    WHERE e.PedidoId = @PedidoId
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;
GO

/* =========================================================
   3. sp_Entrega_GetEvidencesByRoute   (CU-083 E3)
      Devuelve todos los pedidos de la ruta con su conteo de
      evidencias; los que tienen 0 quedan marcados "sin evidencia" (E2).
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Entrega_GetEvidencesByRoute
    @RutaId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Resumen por pedido de la ruta
    SELECT
        rp.PedidoId,
        rp.EstadoEntrega,
        u.NombreCompleto                     AS Cliente,
        (SELECT COUNT(*) FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId) AS TotalEvidencias,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.EntregaEvidencias e WHERE e.PedidoId = rp.PedidoId)
                  THEN 0 ELSE 1 END AS BIT)  AS SinEvidencia
    FROM dbo.RutaPedidos rp
    INNER JOIN dbo.Pedidos  p ON p.PedidoId  = rp.PedidoId
    INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
    WHERE rp.RutaId = @RutaId
    ORDER BY rp.Secuencia ASC, rp.PedidoId ASC;

    -- Evidencias detalladas de la ruta
    SELECT
        e.EvidenciaId,
        e.PedidoId,
        e.TipoEvidencia,
        e.ArchivoUrl,
        ISNULL(e.Observaciones, N'')        AS Observaciones,
        ISNULL(e.RegistradoPorNombre, N'')  AS RegistradoPorNombre,
        e.FechaRegistro
    FROM dbo.EntregaEvidencias e
    INNER JOIN dbo.RutaPedidos rp ON rp.PedidoId = e.PedidoId AND rp.RutaId = @RutaId
    ORDER BY e.FechaRegistro DESC, e.EvidenciaId DESC;
END;
GO

PRINT 'CU-083 (SPs de evidencias) aplicado correctamente.';
GO
