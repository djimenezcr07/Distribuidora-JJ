SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0014_delivery_board_permission' AND Status=N'Applied' AND LEN(FileSha256)=64)
    THROW 54710,N'0014 no figura aplicada correctamente.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Permisos WHERE Codigo=N'ENTREGAS_TABLERO_VER' AND Activo=1)
    THROW 54711,N'Falta ENTREGAS_TABLERO_VER.',1;
SELECT permission.Codigo,profile.Nombre Perfil
FROM dbo.Permisos permission LEFT JOIN dbo.PerfilPermisos assigned ON assigned.PermisoId=permission.PermisoId
LEFT JOIN dbo.Perfiles profile ON profile.PerfilId=assigned.PerfilId WHERE permission.Codigo=N'ENTREGAS_TABLERO_VER';
