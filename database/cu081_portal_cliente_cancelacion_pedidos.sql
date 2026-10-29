USE DistribuidoraJJ_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Client_CancelPendingOrder
    @PedidoId INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PedidoId <= 0 OR @UsuarioId <= 0
    BEGIN
        SELECT CAST(0 AS BIT) AS Cancelado;
        RETURN;
    END;

    BEGIN TRANSACTION;

    UPDATE dbo.Pedidos
    SET Estado = 'Cancelado'
    WHERE PedidoId = @PedidoId
      AND UsuarioId = @UsuarioId
      AND Estado = 'Pendiente'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Facturas f
          WHERE f.PedidoId = dbo.Pedidos.PedidoId
      );

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT CAST(0 AS BIT) AS Cancelado;
        RETURN;
    END;

    COMMIT TRANSACTION;

    SELECT CAST(1 AS BIT) AS Cancelado;
END;
GO
