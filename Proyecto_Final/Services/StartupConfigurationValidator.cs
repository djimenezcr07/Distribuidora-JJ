using System.Net.Mail;

namespace Proyecto_Final.Services;

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

        var apiBaseUrl = Require(configuration["ApiSettings:BaseUrl"], "ApiSettings:BaseUrl");
        if (!Uri.TryCreate(apiBaseUrl, UriKind.Absolute, out var apiUri))
            throw new InvalidOperationException("ApiSettings:BaseUrl debe ser una URL absoluta.");

        if (!environment.IsProduction())
            return;

        if (!string.Equals(apiUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            || apiUri.IsLoopback)
            throw new InvalidOperationException("ApiSettings:BaseUrl debe usar HTTPS y no puede apuntar a localhost en producción.");

        Require(configuration.GetConnectionString("DefaultConnection"), "ConnectionStrings:DefaultConnection");
        Require(configuration.GetConnectionString("DistributedCache"), "ConnectionStrings:DistributedCache");

        var allowedHosts = Require(configuration["AllowedHosts"], "AllowedHosts");
        if (allowedHosts.Trim() == "*")
            throw new InvalidOperationException("AllowedHosts no puede ser '*' en producción.");

        var contactRecipient = Require(configuration["Contact:NotificationRecipient"], "Contact:NotificationRecipient");
        try { _ = new MailAddress(contactRecipient); }
        catch (FormatException exception)
        {
            throw new InvalidOperationException("Contact:NotificationRecipient no es un correo válido.", exception);
        }
    }

    private static string Require(string? value, string key) =>
        !string.IsNullOrWhiteSpace(value)
            ? value.Trim()
            : throw new InvalidOperationException($"Falta la configuración obligatoria {key}.");
}
