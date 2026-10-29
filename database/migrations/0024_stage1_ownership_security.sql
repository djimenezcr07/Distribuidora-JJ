SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 55240, N'Falta el ledger de migraciones 0001.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId = N'0024_stage1_ownership_security' AND Status = N'Applied')
    THROW 55241, N'0024 ya figura aplicada.', 1;
IF OBJECT_ID(N'dbo.VehiculoKilometraje', N'U') IS NULL OR OBJECT_ID(N'dbo.Vehiculos', N'U') IS NULL
    THROW 55242, N'Faltan objetos de kilometraje requeridos.', 1;

BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'FLOTA_KILOMETRAJE_ADMIN')
BEGIN
    INSERT dbo.Permisos (Codigo, Modulo, Nombre, Descripcion, Activo)
    VALUES (N'FLOTA_KILOMETRAJE_ADMIN', N'Flota', N'Administrar kilometraje',
            N'Consultar y cerrar jornadas de kilometraje de otros usuarios.', 1);
END
ELSE
BEGIN
    UPDATE dbo.Permisos
    SET Modulo = N'Flota', Nombre = N'Administrar kilometraje',
        Descripcion = N'Consultar y cerrar jornadas de kilometraje de otros usuarios.', Activo = 1
    WHERE Codigo = N'FLOTA_KILOMETRAJE_ADMIN';
END;

INSERT dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
SELECT perfil.PerfilId, permiso.PermisoId, NULL, N'Migración 0024'
FROM dbo.Perfiles perfil
CROSS JOIN dbo.Permisos permiso
WHERE perfil.Nombre = N'Administrador'
  AND permiso.Codigo = N'FLOTA_KILOMETRAJE_ADMIN'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.PerfilPermisos asignacion
      WHERE asignacion.PerfilId = perfil.PerfilId
        AND asignacion.PermisoId = permiso.PermisoId
  );

COMMIT TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Kilometraje_Cerrar
    @KilometrajeId INT,
    @KmFinal INT,
    @ActorUsuarioId INT,
    @PuedeAdministrar BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ActorUsuarioId <= 0 THROW 53047, N'Actor inválido.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @KmInicial INT, @KmFinalActual INT, @VehiculoId INT, @ChoferUsuarioId INT;
        SELECT @KmInicial = KmInicial,
               @KmFinalActual = KmFinal,
               @VehiculoId = VehiculoId,
               @ChoferUsuarioId = ChoferUsuarioId
        FROM dbo.VehiculoKilometraje WITH (UPDLOCK, HOLDLOCK)
        WHERE KilometrajeId = @KilometrajeId;

        IF @KmInicial IS NULL THROW 53043, N'No se encontró la jornada indicada.', 1;
        IF ISNULL(@PuedeAdministrar, 0) = 0 AND ISNULL(@ChoferUsuarioId, 0) <> @ActorUsuarioId
            THROW 53048, N'La jornada no pertenece al usuario autenticado.', 1;
        IF @KmFinalActual IS NOT NULL THROW 53044, N'La jornada ya fue cerrada.', 1;
        IF @KmFinal < @KmInicial THROW 53045, N'El kilometraje final no puede ser menor al inicial.', 1;

        UPDATE dbo.VehiculoKilometraje
        SET KmFinal = @KmFinal, FechaCierre = SYSDATETIME()
        WHERE KilometrajeId = @KilometrajeId
          AND KmFinal IS NULL
          AND (ISNULL(@PuedeAdministrar, 0) = 1 OR ChoferUsuarioId = @ActorUsuarioId);

        IF @@ROWCOUNT <> 1
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.VehiculoKilometraje WHERE KilometrajeId = @KilometrajeId AND KmFinal IS NOT NULL)
                THROW 53044, N'La jornada ya fue cerrada.', 1;
            THROW 53048, N'La jornada no pertenece al usuario autenticado.', 1;
        END;

        UPDATE dbo.Vehiculos
        SET KilometrajeActual = @KmFinal
        WHERE VehiculoId = @VehiculoId AND KilometrajeActual < @KmFinal;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

DECLARE @MigrationSha256 NVARCHAR(128) = N'$(MigrationSha256)';
IF LEN(@MigrationSha256) <> 64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%'
    THROW 55243, N'SHA-256 inválido para 0024.', 1;

INSERT dbo.SchemaMigrationHistory
    (MigrationId, FileName, FileSha256, Status, AppliedBy, EnvironmentName, Notes)
VALUES
    (N'0024_stage1_ownership_security', N'0024_stage1_ownership_security.sql', UPPER(@MigrationSha256),
     N'Applied', ORIGINAL_LOGIN(), DB_NAME(),
     N'Ownership obligatorio para cierre de kilometraje y permiso administrativo explícito.');
GO
