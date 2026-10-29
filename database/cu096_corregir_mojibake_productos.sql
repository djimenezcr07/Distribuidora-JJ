/* =========================================================
   CU-096 - Correccion controlada de mojibake en productos

   Objetivo:
   - Corregir datos puntuales de productos con texto mal codificado.
   - Mantener la correccion idempotente y especifica.
   - Evitar cambios masivos o destructivos.

   Ejecutar manualmente en SSMS sobre DistribuidoraJJ_DB.
   ========================================================= */

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    THROW 59601, 'Falta tabla dbo.Productos.', 1;
END;

IF OBJECT_ID(N'dbo.FacturaDetalle', N'U') IS NULL
BEGIN
    THROW 59602, 'Falta tabla dbo.FacturaDetalle.', 1;
END;

/* Productos: nombre y descripcion del producto afectado. */
UPDATE dbo.Productos
SET
    Nombre = N'Ron Añejo 750ml',
    Descripcion = CASE
        WHEN Descripcion IN
        (
            N'Ron añejo de presentación estándar.',
            N'Ron aÃ±ejo de presentaciÃ³n estÃ¡ndar.',
            N'Ron aÃƒÂ±ejo de presentaciÃƒÂ³n estÃƒÂ¡ndar.',
            N'Ron a�ejo de presentaci�n est�ndar.'
        )
        THEN N'Ron añejo de presentación estándar.'
        ELSE Descripcion
    END
WHERE Nombre IN
(
    N'Ron AÃ±ejo 750ml',
    N'Ron AÃƒÂ±ejo 750ml',
    N'Ron A�ejo 750ml',
    N'Ron Añejo 750ml'
);

/* FacturaDetalle copia el nombre del producto al momento de facturar. */
UPDATE dbo.FacturaDetalle
SET ProductoNombre = N'Ron Añejo 750ml'
WHERE ProductoNombre IN
(
    N'Ron AÃ±ejo 750ml',
    N'Ron AÃƒÂ±ejo 750ml',
    N'Ron A�ejo 750ml'
);

PRINT 'CU-096 ejecutado: correccion controlada de mojibake en productos.';
