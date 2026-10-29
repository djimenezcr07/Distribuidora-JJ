using System.Globalization;

namespace Proyecto_Final.Models.Presentation;

// Presentation only: amounts and ordering come from the existing report models.
public sealed record AnalyticsChartRow(string Label, decimal Value, decimal? Target = null);

public sealed class AnalyticsChartViewModel
{
    public string Title { get; init; } = string.Empty;
    public string Context { get; init; } = string.Empty;
    public string ValueLabel { get; init; } = "Ventas";
    public string? TargetLabel { get; init; }
    public IReadOnlyList<AnalyticsChartRow> Rows { get; init; } = [];
    public decimal Maximum => Rows.Select(row => Math.Max(row.Value, row.Target ?? 0m)).DefaultIfEmpty().Max();

    public static string Width(decimal value, decimal maximum) =>
        (maximum > 0m ? Math.Clamp(value / maximum * 100m, 0m, 100m) : 0m).ToString("0.####", CultureInfo.InvariantCulture);
}
