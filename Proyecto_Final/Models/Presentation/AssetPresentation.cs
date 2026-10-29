using System.Globalization;

namespace Proyecto_Final.Models.Presentation;

public static class AssetPresentation
{
    public static string AssetTone(string? state) => state switch
    {
        "Disponible" => "success", "Prestado" => "info", "Mantenimiento" => "warning",
        "Baja" => "neutral", _ => "neutral"
    };
    public static string ComodatoTone(string? state) => state switch
    {
        "Activo" => "info", "Devuelto" => "success", "Retirado" => "warning", _ => "neutral"
    };
    public static string Money(decimal value) => "₡" + value.ToString("N2", CultureInfo.GetCultureInfo("es-CR"));
}
