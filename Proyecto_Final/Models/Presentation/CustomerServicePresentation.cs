namespace Proyecto_Final.Models.Presentation;

public static class CustomerServicePresentation
{
    // Presentation of audited server states, never a transition policy or SLA.
    public static string ConsultationTone(string? state) => state switch
    { "Pendiente" => "info", "Atendida" => "success", _ => "neutral" };
    public static string ComplaintTone(string? state) => state switch
    { "Abierto" => "info", "EnProceso" => "warning", _ => "neutral" };
    public static string PriorityTone(string? priority) => priority switch
    { "Alta" => "danger", "Media" => "warning", _ => "neutral" };
    public static string WarrantyTone(string? state) => state switch
    { "Pendiente" => "info", "En revisión" => "warning", "Aprobada" => "success", "Rechazada" => "danger", _ => "neutral" };
    public static bool ComplaintClosed(string? state) => state == "Cerrado";
    public static bool WarrantyClosed(string? state) => state is "Aprobada" or "Rechazada";
}
