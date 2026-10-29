USE DistribuidoraJJ_DB;
GO

/*
    CU-101: Alinea la validacion de credenciales con el contrato actual del API.
    No modifica tablas ni datos.
*/
CREATE OR ALTER PROCEDURE dbo.sp_Auth_ValidateUser
    @Correo NVARCHAR(150),
    @Contrasena NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.PerfilId,
        p.Nombre AS PerfilNombre,
        u.Activo
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Perfiles AS p
        ON p.PerfilId = u.PerfilId
    WHERE u.Correo = @Correo
      AND u.Contrasena = @Contrasena
      AND u.Activo = 1;
END;
GO
