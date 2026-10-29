SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;
EXEC dbo.sp_Kilometraje_Cerrar
    @KilometrajeId = 1,
    @KmFinal = 150,
    @ActorUsuarioId = 42,
    @PuedeAdministrar = 0;
SELECT N'A_SUCCESS' AS Resultado;
WAITFOR DELAY '00:00:04';
COMMIT TRANSACTION;
