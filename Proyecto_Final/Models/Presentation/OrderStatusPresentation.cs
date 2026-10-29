namespace Proyecto_Final.Models.Presentation;

// Presentation only: keep the domain state intact, including unrecognized values.
public static class OrderStatusPresentation
{
    public static string Tone(string? state) => state switch
    {
        "Retenido" => "warning",
        "Rechazado" => "danger",
        "Liberado" or "Aprobado" or "Entregado" => "success",
        "Pendiente" or "EnProceso" or "Facturado" => "info",
        _ => "neutral"
    };
}
