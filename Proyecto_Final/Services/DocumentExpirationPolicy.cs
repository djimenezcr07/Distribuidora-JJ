namespace Proyecto_Final.Services;

public static class DocumentExpirationPolicy
{
    public const string CostaRicaTimeZone = "America/Costa_Rica";

    public static DateTime BusinessDate(DateTimeOffset utcNow)
    {
        var zone = FindCostaRicaTimeZone();
        return TimeZoneInfo.ConvertTime(utcNow, zone).Date;
    }

    public static string Classify(bool active, bool doesNotExpire, DateTime? expirationDate, DateTime businessDate, int warningDays)
    {
        if (!active) return "Inactivo";
        if (doesNotExpire || !expirationDate.HasValue) return "No vence";
        var days = (expirationDate.Value.Date - businessDate.Date).Days;
        if (days < 0) return "Vencido";
        if (days == 0) return "Vence hoy";
        if (days <= Math.Max(0, warningDays)) return "Por vencer";
        return "Vigente";
    }

    public static int? DaysRemaining(bool doesNotExpire, DateTime? expirationDate, DateTime businessDate) =>
        doesNotExpire || !expirationDate.HasValue
            ? null
            : (expirationDate.Value.Date - businessDate.Date).Days;

    public static int ThresholdFor(int daysRemaining, IReadOnlyCollection<int> configuredThresholds)
    {
        if (daysRemaining < 0) return -1;
        var ordered = configuredThresholds.Where(value => value >= 0).Distinct().OrderBy(value => value).ToArray();
        return ordered.FirstOrDefault(value => daysRemaining <= value, int.MinValue);
    }

    private static TimeZoneInfo FindCostaRicaTimeZone()
    {
        if (TimeZoneInfo.TryFindSystemTimeZoneById(CostaRicaTimeZone, out var zone)) return zone;
        if (TimeZoneInfo.TryFindSystemTimeZoneById("Central America Standard Time", out zone)) return zone;
        return TimeZoneInfo.CreateCustomTimeZone(CostaRicaTimeZone, TimeSpan.FromHours(-6), "Costa Rica", "Costa Rica");
    }
}
