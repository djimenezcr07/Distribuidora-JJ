namespace Proyecto_FinalAPI.Services;

public sealed class CompanyOptions
{
    public string BrandName { get; set; } = string.Empty;
    public string BrandSubtitle { get; set; } = string.Empty;
}

public static class StartupConfigurationValidator
{
    public static void Validate(IConfiguration configuration, IHostEnvironment environment)
    {
        Require(configuration["Company:BrandName"], "Company:BrandName");
        Require(configuration["Company:BrandSubtitle"], "Company:BrandSubtitle");
        if (!environment.IsProduction())
            return;

        Require(configuration.GetConnectionString("DefaultConnection"), "ConnectionStrings:DefaultConnection");
        var publicBaseUrl = Require(configuration["PasswordRecovery:PublicBaseUrl"], "PasswordRecovery:PublicBaseUrl");
        if (!Uri.TryCreate(publicBaseUrl, UriKind.Absolute, out var publicUri)
            || !string.Equals(publicUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            || publicUri.IsLoopback)
            throw new InvalidOperationException("PasswordRecovery:PublicBaseUrl debe usar HTTPS y no puede apuntar a localhost en producción.");

        if (Require(configuration["AllowedHosts"], "AllowedHosts") == "*")
            throw new InvalidOperationException("AllowedHosts no puede ser '*' en producción.");
    }

    private static string Require(string? value, string key) =>
        !string.IsNullOrWhiteSpace(value)
            ? value.Trim()
            : throw new InvalidOperationException($"Falta la configuración obligatoria {key}.");
}
