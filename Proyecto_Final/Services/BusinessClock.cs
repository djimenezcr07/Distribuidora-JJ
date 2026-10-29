namespace Proyecto_Final.Services;

public sealed class BusinessClock
{
    public const string IanaTimeZoneId = "America/Costa_Rica";
    public const string WindowsTimeZoneId = "Central America Standard Time";

    private readonly TimeProvider _timeProvider;
    private readonly TimeZoneInfo _timeZone;

    public BusinessClock(TimeProvider timeProvider)
    {
        _timeProvider = timeProvider;
        _timeZone = ResolveCostaRicaTimeZone();
    }

    public DateTimeOffset UtcNow => _timeProvider.GetUtcNow();
    public DateTime LocalNow => TimeZoneInfo.ConvertTime(UtcNow, _timeZone).DateTime;
    public DateTime Today => LocalNow.Date;

    private static TimeZoneInfo ResolveCostaRicaTimeZone()
    {
        foreach (var id in new[] { IanaTimeZoneId, WindowsTimeZoneId })
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
            catch (TimeZoneNotFoundException) { }
            catch (InvalidTimeZoneException) { }
        }
        throw new InvalidOperationException("No se encontró la zona horaria de Costa Rica.");
    }
}
