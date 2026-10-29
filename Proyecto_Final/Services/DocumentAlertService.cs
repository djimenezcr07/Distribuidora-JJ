using System.Net;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

public interface IDocumentAlertEmailSender
{
    Task SendAsync(string recipient, string subject, string html, CancellationToken cancellationToken);
}

public sealed class SmtpDocumentAlertEmailSender : IDocumentAlertEmailSender
{
    private readonly EmailService _email;
    public SmtpDocumentAlertEmailSender(EmailService email) => _email = email;

    public Task SendAsync(string recipient, string subject, string html, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _email.SendEmail(recipient, subject, html);
        return Task.CompletedTask;
    }
}

public interface IDocumentAlertService
{
    DateTime CurrentBusinessDate();
    int DefaultWarningDays { get; }
    Task<int> GenerateAsync(int userId, CancellationToken cancellationToken = default);
}

public sealed class DocumentAlertService : IDocumentAlertService
{
    private static readonly int[] FallbackThresholds = [30, 15, 7, 1, 0];
    private readonly IDocumentManagementDbService _db;
    private readonly IDocumentAlertEmailSender _email;
    private readonly IConfiguration _configuration;
    private readonly TimeProvider _timeProvider;
    private readonly ILogger<DocumentAlertService> _logger;

    public DocumentAlertService(
        IDocumentManagementDbService db,
        IDocumentAlertEmailSender email,
        IConfiguration configuration,
        TimeProvider timeProvider,
        ILogger<DocumentAlertService> logger)
    {
        _db = db;
        _email = email;
        _configuration = configuration;
        _timeProvider = timeProvider;
        _logger = logger;
    }

    public DateTime CurrentBusinessDate() => DocumentExpirationPolicy.BusinessDate(_timeProvider.GetUtcNow());

    public int DefaultWarningDays => Thresholds().DefaultIfEmpty(30).Max();

    public async Task<int> GenerateAsync(int userId, CancellationToken cancellationToken = default)
    {
        var candidates = await _db.GenerateAlertsAsync(CurrentBusinessDate(), Thresholds(), userId);
        if (!_configuration.GetValue("DocumentAlerts:EmailEnabled", false) || !SmtpConfigured()) return candidates.Count;

        foreach (var candidate in candidates.Where(item => !string.IsNullOrWhiteSpace(item.Recipient)))
        {
            try
            {
                var title = WebUtility.HtmlEncode(candidate.DocumentTitle);
                var body = $"<p>El documento <strong>{title}</strong> vence el {candidate.ExpirationDate:dd/MM/yyyy}.</p>";
                await _email.SendAsync(candidate.Recipient, $"Alerta de vencimiento: {candidate.DocumentTitle}", body, cancellationToken);
                await _db.RegisterNotificationAsync(candidate, "Enviado", null);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No se pudo enviar la alerta {AlertId} del documento {DocumentId}.", candidate.AlertId, candidate.DocumentId);
                await _db.RegisterNotificationAsync(candidate, "Fallido", exception.GetType().Name);
            }
        }
        return candidates.Count;
    }

    private int[] Thresholds()
    {
        var values = _configuration.GetSection("DocumentAlerts:DefaultWarningDays").Get<int[]>();
        return (values is { Length: > 0 } ? values : FallbackThresholds)
            .Where(value => value is >= 0 and <= 365).Distinct().OrderBy(value => value).ToArray();
    }

    private bool SmtpConfigured() =>
        !string.IsNullOrWhiteSpace(_configuration["ConfiguracionCorreo:Host"]) &&
        _configuration.GetValue<int>("ConfiguracionCorreo:Puerto") > 0 &&
        !string.IsNullOrWhiteSpace(_configuration["ConfiguracionCorreo:Remitente"]) &&
        !string.IsNullOrWhiteSpace(_configuration["ConfiguracionCorreo:Contrasenna"]);
}
