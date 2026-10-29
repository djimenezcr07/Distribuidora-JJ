using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Models.Presentation;

// Display only: SQL's Vigente remains authoritative for commercial applicability.
public sealed record PromotionStatusPresentation(string Label, string Tone)
{
    public static PromotionStatusPresentation From(PromotionListItemViewModel promotion, DateTime today)
    {
        if (promotion.Estado == "Inactiva") return new("Inactiva", "neutral");
        if (promotion.Estado == "Vencida") return new("Vencida", "neutral");
        if (promotion.Estado != "Activa") return new(promotion.Estado, "neutral");
        if (promotion.Vigente) return new("Activa", "success");
        if (promotion.FechaInicio.Date > today.Date) return new("Próxima", "warning");
        if (promotion.FechaFin.Date < today.Date) return new("Vencida", "neutral");
        return new("No vigente", "neutral");
    }
}
