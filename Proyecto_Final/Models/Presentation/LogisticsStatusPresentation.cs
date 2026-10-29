namespace Proyecto_Final.Models.Presentation;

public static class LogisticsStatusPresentation
{
    public static string RouteTone(string? state) => state switch
    {
        "Planificada" => "warning", "Despachada" => "info",
        "Completada" => "success", "Cancelada" => "danger", _ => "neutral"
    };
    public static string DeliveryTone(string? state) => state switch
    {
        "Pendiente" => "warning", "EnRuta" => "info",
        "Entregado" => "success", "Fallido" => "danger", _ => "neutral"
    };
    public static string MaintenanceTone(string? state) => state switch
    {
        "Programada" => "warning", "EnProceso" => "info",
        "Completada" => "success", _ => "neutral"
    };
    public static string AlertTone(string? severity) => severity switch
    {
        "Vencido" => "danger", "PorVencer" => "warning", _ => "neutral"
    };
}
