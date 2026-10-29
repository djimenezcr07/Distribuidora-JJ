namespace Proyecto_Final.Models.Presentation;

public static class DocumentPresentation
{
    // Tones describe server states; no expiration rules are recalculated here.
    public static string ExpirationTone(string? state) => state switch
    {
        "Vigente" => "success", "Por vencer" or "Vence hoy" => "warning",
        "Vencido" => "danger", _ => "neutral"
    };
    public static string DocumentTone(bool active, string? state) => !active ? "neutral" : state switch
    { "Vigente" => "success", "Suspendido" => "warning", _ => "neutral" };
    public static string StorageTone(string? state) => state switch
    { "Ready" => "success", "Pending" => "warning", _ => "neutral" };
    public static string StorageLabel(string? state) => state switch
    { "Ready" => "Disponible (Ready)", "Pending" => "Pendiente (Pending)",
      "Legacy" => "Heredado (Legacy)", null or "" => "Sin información", _ => state };
    // Visibility is not authorization. The Download endpoint remains authoritative.
    public static bool ShowDownload(string? storageStatus, bool active, bool canManage) =>
        storageStatus == "Ready" && (active || canManage);
}
