SET NOCOUNT ON;
SET XACT_ABORT ON;

EXEC dbo.sp_Kilometraje_Cerrar
    @KilometrajeId = 1,
    @KmFinal = 160,
    @ActorUsuarioId = 42,
    @PuedeAdministrar = 0;
