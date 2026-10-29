using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Configuration;
using Proyecto_Final.Controllers;
using Proyecto_Final.Middleware;
using Proyecto_Final.Models;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class ProductionReadinessTests
{
    [Fact]
    public void BusinessClock_UsesCostaRicaDateAcrossUtcMidnight()
    {
        var provider = new FixedTimeProvider(new DateTimeOffset(2026, 8, 20, 3, 30, 0, TimeSpan.Zero));
        var clock = new BusinessClock(provider);

        Assert.Equal(new DateTime(2026, 8, 19), clock.Today);
        Assert.Equal(21, clock.LocalNow.Hour);
    }

    [Theory]
    [InlineData("short", false)]
    [InlineData("twelve-chars", true)]
    public void MvcAndApiPasswordPolicies_AreCoherent(string password, bool expected)
    {
        Assert.Equal(expected, Proyecto_Final.Validation.PasswordPolicy.IsValid(password));
        Assert.Equal(expected, Proyecto_FinalAPI.Services.PasswordPolicy.IsValid(password));
        Assert.Equal(
            Proyecto_Final.Validation.PasswordPolicy.MinimumLength,
            Proyecto_FinalAPI.Services.PasswordPolicy.MinimumLength);
    }

    [Fact]
    public void RegistrationAnnotation_EnforcesTwelveCharacterMinimum()
    {
        var model = new RegistroViewModel
        {
            FullName = "Persona de prueba",
            Email = "qa@example.test",
            Password = string.Concat("short", "-pass!"),
            ConfirmPassword = string.Concat("short", "-pass!"),
            AcceptTerms = true
        };
        var results = new List<ValidationResult>();

        Assert.False(Validator.TryValidateObject(model, new ValidationContext(model), results, true));
        Assert.Contains(results, result => result.MemberNames.Contains(nameof(model.Password)));
    }

    [Fact]
    public void AuthenticatedResponses_AreNoStoreWithoutRouteAllowlist()
    {
        Assert.True(SecurityHeadersMiddleware.ShouldDisableCaching(true, new PathString("/FutureModule/Index")));
        Assert.False(SecurityHeadersMiddleware.ShouldDisableCaching(false, new PathString("/Home/Index")));
        Assert.True(SecurityHeadersMiddleware.ShouldDisableCaching(false, new PathString("/Account/Login")));
    }

    [Fact]
    public void ContactPost_HasDedicatedRateLimitAndNoEmbeddedRecipient()
    {
        var action = typeof(HomeController).GetMethods().Single(method => method.Name == nameof(HomeController.Contact)
            && method.GetCustomAttributes(typeof(HttpPostAttribute), true).Any());
        var limit = Assert.IsType<EnableRateLimitingAttribute>(Assert.Single(
            action.GetCustomAttributes(typeof(EnableRateLimitingAttribute), true)));
        Assert.Equal("public-contact", limit.PolicyName);

        var source = File.ReadAllText(SourcePath("Controllers", "HomeController.cs"));
        Assert.DoesNotContain("@gmail.com", source, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Contact:NotificationRecipient", source, StringComparison.Ordinal);
    }

    [Fact]
    public void MvcProductionConfiguration_RejectsLocalhostAndWildcardHosts()
    {
        var values = new Dictionary<string, string?>
        {
            ["Company:BrandName"] = "Distribuidora JJ",
            ["Company:BrandSubtitle"] = "Licorera - Distribuidora",
            ["ApiSettings:BaseUrl"] = "https://localhost:5001",
            ["ConnectionStrings:DefaultConnection"] = "Server=example.invalid;Database=test",
            ["ConnectionStrings:DistributedCache"] = "example.invalid:6380",
            ["Contact:NotificationRecipient"] = "ops@example.test",
            ["AllowedHosts"] = "*"
        };
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().AddInMemoryCollection(values).Build();

        var exception = Record.Exception(() => StartupConfigurationValidator.Validate(configuration, new ProductionEnvironment()));
        Assert.IsType<InvalidOperationException>(exception);
    }

    private static string SourcePath(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return Path.Combine(new[] { directory?.FullName ?? throw new DirectoryNotFoundException(), "Proyecto_Final" }.Concat(segments).ToArray());
    }

    private sealed class FixedTimeProvider(DateTimeOffset utcNow) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => utcNow;
    }

    private sealed class ProductionEnvironment : Microsoft.Extensions.Hosting.IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Microsoft.Extensions.Hosting.Environments.Production;
        public string ApplicationName { get; set; } = "Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public Microsoft.Extensions.FileProviders.IFileProvider ContentRootFileProvider { get; set; } = null!;
    }
}
