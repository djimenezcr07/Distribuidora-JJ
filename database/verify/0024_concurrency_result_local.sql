SET NOCOUNT ON;

IF (SELECT KmFinal FROM dbo.VehiculoKilometraje WHERE KilometrajeId = 1) <> 150
    THROW 55420, N'El cierre concurrente no conservó el único valor exitoso.', 1;
IF (SELECT KilometrajeActual FROM dbo.Vehiculos WHERE VehiculoId = 1) <> 150
    THROW 55421, N'El odómetro no coincide con el único cierre exitoso.', 1;
IF (SELECT COUNT(*) FROM dbo.VehiculoKilometraje WHERE KilometrajeId = 1 AND KmFinal IS NOT NULL) <> 1
    THROW 55422, N'La jornada no quedó cerrada exactamente una vez.', 1;

SELECT KilometrajeId, KmInicial, KmFinal, FechaCierre
FROM dbo.VehiculoKilometraje
WHERE KilometrajeId = 1;
