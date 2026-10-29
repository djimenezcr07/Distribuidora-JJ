SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = N'0015_sales_and_seller_reports'
      AND Status = N'Applied'
      AND LEN(FileSha256) = 64
)
    THROW 54840, N'0015 no figura aplicada correctamente.', 1;

IF OBJECT_ID(N'dbo.sp_Reportes_VentasDetallado', N'P') IS NULL
    THROW 54841, N'Falta sp_Reportes_VentasDetallado.', 1;
IF OBJECT_ID(N'dbo.sp_Reportes_DesempenoVendedores', N'P') IS NULL
    THROW 54842, N'Falta sp_Reportes_DesempenoVendedores.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'REPORTES_VENTAS_VER' AND Activo = 1)
    THROW 54843, N'Falta REPORTES_VENTAS_VER.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'REPORTES_VENDEDORES_VER' AND Activo = 1)
    THROW 54844, N'Falta REPORTES_VENDEDORES_VER.', 1;

SELECT permission.Codigo, profile.Nombre AS Perfil
FROM dbo.Permisos permission
LEFT JOIN dbo.PerfilPermisos assigned ON assigned.PermisoId = permission.PermisoId
LEFT JOIN dbo.Perfiles profile ON profile.PerfilId = assigned.PerfilId
WHERE permission.Codigo IN (N'REPORTES_VENTAS_VER', N'REPORTES_VENDEDORES_VER')
ORDER BY permission.Codigo, profile.Nombre;
