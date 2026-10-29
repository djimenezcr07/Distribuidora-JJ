USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-095 - Permiso granular para generar facturas
   No modifica tablas, datos demo ni procedimientos de facturacion.
   ========================================================= */

MERGE dbo.Permisos AS target
USING (VALUES
    (
        'FACTURACION_GENERAR',
        N'Facturación',
        N'Generar facturas',
        N'Permite generar facturas desde pedidos administrativos.'
    )
) AS source (Codigo, Modulo, Nombre, Descripcion)
ON target.Codigo = source.Codigo
WHEN MATCHED THEN
    UPDATE SET
        target.Modulo = source.Modulo,
        target.Nombre = source.Nombre,
        target.Descripcion = source.Descripcion,
        target.Activo = 1
WHEN NOT MATCHED THEN
    INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);
GO

INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT
    p.PerfilId,
    pe.PermisoId,
    NULL,
    'Script CU-095'
FROM dbo.Perfiles p
INNER JOIN dbo.Permisos pe
    ON pe.Codigo = 'FACTURACION_GENERAR'
WHERE p.Nombre = 'Administrador'
  AND pe.Activo = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.PerfilPermisos pp
      WHERE pp.PerfilId = p.PerfilId
        AND pp.PermisoId = pe.PermisoId
  );
GO
