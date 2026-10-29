namespace Proyecto_Final.Models.Presentation;

public static class OrderActions
{
    // Presentation of the manual workflow only. SQL independently enforces it.
    public static IReadOnlyList<string> ManualStates(string? state, bool hasInvoice) => hasInvoice ? [] : state switch
    {
        "Pendiente" => ["Aprobado", "Cancelado"],
        "Aprobado" => ["EnProceso", "Cancelado"],
        "EnProceso" or "Liberado" => ["Cancelado"],
        _ => []
    };
}
