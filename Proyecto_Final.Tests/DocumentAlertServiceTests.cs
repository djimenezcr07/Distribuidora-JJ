using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class DocumentAlertServiceTests
{
    [Fact]
    public async Task EmailDisabled_GeneratesInternalAlertsWithoutSendingMail()
    {
        var db = new Mock<IDocumentManagementDbService>();
        db.Setup(x => x.GenerateAlertsAsync(It.IsAny<DateTime>(), It.IsAny<IReadOnlyCollection<int>>(), 7))
            .ReturnsAsync([Candidate()]);
        var email = new Mock<IDocumentAlertEmailSender>();
        var service = Service(db, email, new Dictionary<string, string?>
        {
            ["DocumentAlerts:EmailEnabled"] = "false",
            ["DocumentAlerts:DefaultWarningDays:0"] = "30",
            ["DocumentAlerts:DefaultWarningDays:1"] = "7",
            ["DocumentAlerts:DefaultWarningDays:2"] = "0"
        });

        Assert.Equal(1, await service.GenerateAsync(7));
        email.Verify(x => x.SendAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
        db.Verify(x => x.GenerateAlertsAsync(new DateTime(2026, 7, 21),
            It.Is<IReadOnlyCollection<int>>(v => v.SequenceEqual(new[] { 0, 7, 30 })), 7), Times.Once);
    }

    [Fact]
    public async Task SmtpFailure_DoesNotBreakInternalAlertAndIsRecordedGenerically()
    {
        var db = new Mock<IDocumentManagementDbService>();
        var candidate = Candidate();
        db.Setup(x => x.GenerateAlertsAsync(It.IsAny<DateTime>(), It.IsAny<IReadOnlyCollection<int>>(), 7)).ReturnsAsync([candidate]);
        var email = new Mock<IDocumentAlertEmailSender>();
        email.Setup(x => x.SendAsync(candidate.Recipient, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("SMTP secret detail"));
        var service = Service(db, email, new Dictionary<string, string?>
        {
            ["DocumentAlerts:EmailEnabled"] = "true", ["ConfiguracionCorreo:Host"] = "smtp.invalid",
            ["ConfiguracionCorreo:Puerto"] = "587", ["ConfiguracionCorreo:Remitente"] = "sender@example.invalid",
            ["ConfiguracionCorreo:Contrasenna"] = "<smtp-app-password>"
        });

        Assert.Equal(1, await service.GenerateAsync(7));
        db.Verify(x => x.RegisterNotificationAsync(candidate, "Fallido", nameof(InvalidOperationException)), Times.Once);
    }

    private static DocumentAlertService Service(Mock<IDocumentManagementDbService> db, Mock<IDocumentAlertEmailSender> email,
        Dictionary<string, string?> settings) => new(db.Object, email.Object,
            new ConfigurationBuilder().AddInMemoryCollection(settings).Build(),
            new FixedTimeProvider(new DateTimeOffset(2026, 7, 22, 5, 30, 0, TimeSpan.Zero)),
            NullLogger<DocumentAlertService>.Instance);

    private static DocumentAlertNotificationCandidate Candidate() => new()
    {
        AlertId = 9, DocumentId = 4, ThresholdDays = 7, DocumentTitle = "Póliza & cobertura",
        ExpirationDate = new DateTime(2026, 7, 28), Recipient = "owner@example.invalid"
    };

    private sealed class FixedTimeProvider(DateTimeOffset value) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => value;
    }
}
