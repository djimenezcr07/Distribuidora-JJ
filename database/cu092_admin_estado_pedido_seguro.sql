/* =========================================================
   CU-092 - Estado seguro de pedidos administrativos

   Objetivo:
   - Mantener la firma usada por AdminDbService.
   - Validar estados permitidos desde SQL.
   - Evitar inconsistencias en pedidos con factura asociada.
   - Evitar reactivar pedidos cancelados.
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateOrderStatus
    @PedidoId INT,
    @NuevoEstado NVARCHAR(50),
    @UsuarioId INT = NULL,
    @UsuarioNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @EstadoActual NVARCHAR(30),
        @TieneFactura BIT = 0;

    SET @NuevoEstado = NULLIF(LTRIM(RTRIM(@NuevoEstado)), N'');

    IF @PedidoId IS NULL OR @PedidoId <= 0
    BEGIN
        THROW 51001, 'El pedido indicado no es valido.', 1;
    END;

    IF @NuevoEstado IS NULL
       OR @NuevoEstado NOT IN (N'Pendiente', N'Aprobado', N'EnProceso', N'Entregado', N'Cancelado')
    BEGIN
        THROW 51002, 'El estado indicado no es valido.', 1;
    END;

    BEGIN TRANSACTION;

    SELECT @EstadoActual = Estado
    FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
    WHERE PedidoId = @PedidoId;

    IF @EstadoActual IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51003, 'No se encontro el pedido solicitado.', 1;
    END;

    SELECT @TieneFactura =
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM dbo.Facturas WITH (UPDLOCK, HOLDLOCK)
                WHERE PedidoId = @PedidoId
            )
            THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END;

    IF @TieneFactura = 1 AND @NuevoEstado <> N'Entregado'
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51004, 'El pedido facturado debe permanecer como Entregado.', 1;
    END;

    IF @EstadoActual = N'Cancelado' AND @NuevoEstado <> N'Cancelado'
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51005, 'No se puede reactivar un pedido cancelado.', 1;
    END;

    IF @TieneFactura = 0
       AND @EstadoActual <> @NuevoEstado
       AND NOT
       (
           (@EstadoActual = N'Pendiente' AND @NuevoEstado IN (N'Aprobado', N'Cancelado'))
        OR (@EstadoActual = N'Aprobado' AND @NuevoEstado IN (N'EnProceso', N'Cancelado'))
        OR (@EstadoActual = N'EnProceso' AND @NuevoEstado IN (N'Entregado', N'Cancelado'))
        OR (@EstadoActual = N'Entregado' AND @NuevoEstado = N'Cancelado')
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51006, 'La transicion de estado solicitada no es valida.', 1;
    END;

    UPDATE dbo.Pedidos
    SET Estado = @NuevoEstado
    WHERE PedidoId = @PedidoId;

    COMMIT TRANSACTION;
END;
GO
