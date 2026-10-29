namespace Proyecto_Final.Services;

public sealed class LogisticsSettlementUnavailableException : InvalidOperationException
{
    public LogisticsSettlementUnavailableException() : base(
        "Liquidaciones, devoluciones y reentregas requieren reglas aprobadas de stock, facturas y notas de crédito.") { }
}
