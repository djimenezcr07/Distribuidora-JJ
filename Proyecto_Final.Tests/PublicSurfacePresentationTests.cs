using System.ComponentModel.DataAnnotations;
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Presentation;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class PublicSurfacePresentationTests
{
    [Theory]
    [InlineData("FinancialReportAdmin/Index", "_WorkspaceLayout")]
    [InlineData("Home/Contact", "_StorefrontLayout")]
    [InlineData("Home/Privacy", "_StorefrontLayout")]
    [InlineData("Account/AccesoDenegado", "_StatusLayout")]
    [InlineData("Shared/Error", "_StatusLayout")]
    [InlineData("Shared/ServiceUnavailable", "_StatusLayout")]
    public void ResidualViewsUseStage2AndDoNotOverrideTheHttpStatus(string view, string layout)
    {
        var source = Read("Views/" + view + ".cshtml");
        Assert.Contains("Layout = \"" + layout + "\"", source);
        Assert.Single(Regex.Matches(source, "<h1(?:>| )"));
        Assert.DoesNotMatch("custom-theme|bootstrap|fa fa-|form-control|onclick=|Html.Raw|Response.StatusCode", source);
    }

    [Theory]
    [InlineData(null)] [InlineData("")] [InlineData("<script>synthetic</script>")]
    [InlineData("password=synthetic")] [InlineData("C:\\private\\synthetic.log")]
    [InlineData("SELECT * FROM synthetic")] [InlineData("actor@example.invalid")]
    public void PublicTraceRejectsNonIdentifiers(string? input) => Assert.Null(PublicSurfacePresentation.SafeRequestId(input));

    [Theory]
    [InlineData("00-abcdef123456-9876543210-00")]
    [InlineData("0HQA1234:00000001")]
    [InlineData("qa.trace_20261010")]
    public void PublicTracePreservesBoundedServerIdentifiers(string input) => Assert.Equal(input, PublicSurfacePresentation.SafeRequestId(input));

    [Fact]
    public void PublicTraceRejectsOversizedIdentifiers() => Assert.Null(PublicSurfacePresentation.SafeRequestId(new string('a', 161)));

    [Fact]
    public void FailureShellHasNoOperationalOrExternalDependencies()
    {
        var shell = Read("Views/Shared/_StatusLayout.cshtml");
        Assert.DoesNotMatch("<script|@inject|Session|TempData|RenderSection|fonts.googleapis|https://|SignalR|chatHub|PermissionService", shell);
        Assert.Contains("djj-skip-link", shell);
        Assert.Contains("icon_stage2-identity_favicon", shell);
        Assert.Contains("lang=\"es\"", shell);
    }

    [Fact]
    public async Task ContactBindingAntiforgeryAndInvalidModelDoNotInvokePersistence()
    {
        var controller = Home();
        var get = Assert.IsType<ViewResult>(controller.Contact());
        Assert.IsType<ContactViewModel>(get.Model);
        controller.ModelState.AddModelError("Nombre", "Falta el nombre.");
        var model = new ContactViewModel();
        Assert.Same(model, Assert.IsType<ViewResult>(await controller.Contact(model)).Model);
        var post = typeof(HomeController).GetMethod("Contact", [typeof(ContactViewModel)])!;
        Assert.NotNull(post.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        var source = Read("Views/Home/Contact.cshtml");
        Assert.Contains("@Html.AntiForgeryToken()", source);
        Assert.Contains("asp-controller=\"Home\" asp-action=\"Contact\" method=\"post\"", source);
        foreach (var field in new[] { "Nombre", "Correo", "Asunto", "Mensaje" })
        { Assert.Contains("label asp-for=\"" + field + "\"", source); Assert.Contains("asp-validation-for=\"" + field + "\"", source); }
        Assert.Contains("role=\"alert\"", source);
        Assert.Contains("_ValidationScriptsPartial", source);
    }

    [Fact]
    public void ContactAnnotationsRejectInvalidInputs()
    {
        var model = new ContactViewModel { Nombre = new string('N', 101), Correo = "invalid", Asunto = new string('A', 121), Mensaje = new string('M', 1001) };
        var failures = new List<ValidationResult>();
        Assert.False(Validator.TryValidateObject(model, new ValidationContext(model), failures, true));
        Assert.Equal(4, failures.Count);
    }

    [Fact]
    public void FinancialReportPreservesMetricsFiltersAndEveryMovementField()
    {
        var model = new FinancialReportViewModel { TotalIngresos = 150.25m, TotalEgresos = 50.75m };
        Assert.Equal(99.50m, model.Balance);
        var view = Read("Views/FinancialReportAdmin/Index.cshtml");
        foreach (var name in new[] { "TotalIngresos", "TotalEgresos", "Balance", "FechaInicio", "FechaFin" }) Assert.Contains("Model." + name, view);
        foreach (var name in new[] { "Fecha", "Tipo", "Descripcion", "Referencia", "Monto" }) Assert.Contains("movimiento." + name, view);
        Assert.Contains("Confirmado simulado", view);
        Assert.Contains("no acredita ingresos fiscales", view);
        Assert.Contains("<caption>", view); Assert.Contains("scope=\"col\"", view);
        Assert.Contains("Sin movimientos", view);
        Assert.Equal("Finanzas", typeof(FinancialReportAdminController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![0]);
        Assert.Contains("WHERE EstadoPago = N'Confirmado simulado'", Read("Services/AdminDbService.cs"));
    }

    [Fact]
    public void PrivacyExplicitlyRemainsPendingRatherThanInventingAnApprovedPolicy()
    {
        var view = Read("Views/Home/Privacy.cshtml");
        Assert.Contains("Contenido pendiente de aprobación", view);
        Assert.Contains("no constituye una política de privacidad", view);
        Assert.DoesNotMatch("consentimiento|retención|base jurídica|garantizamos|derecho de", view);
    }

    [Fact]
    public void ExistingErrorActionKeeps503AndTraceWithoutOperationalServices()
    {
        var controller = Home();
        var result = Assert.IsType<ViewResult>(controller.Error());
        Assert.Equal(503, controller.Response.StatusCode);
        Assert.Equal(controller.HttpContext.TraceIdentifier, Assert.IsType<ErrorViewModel>(result.Model).RequestId);
        Assert.Equal(403, AuthorizationResults.AccessDenied().StatusCode);
        var denial = Read("Views/Account/AccesoDenegado.cshtml");
        Assert.DoesNotMatch("history.back|returnUrl|Redirect|asp-controller=\"Admin\"", denial);
        Assert.Contains("if (!authenticated)", denial);
    }

    [Theory]
    [InlineData("Budgets")] [InlineData("Clients")] [InlineData("Expenses")]
    [InlineData("Payroll")] [InlineData("Cart")]
    public void ExistingUnavailableCallersKeep503AndGeneralViewHasNoBudgetAssumption(string controller)
    {
        var source = Read("Controllers/" + controller + "Controller.cs");
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("View(\"ServiceUnavailable\")", source);
        var view = Read("Views/Shared/ServiceUnavailable.cshtml");
        Assert.DoesNotMatch("presupuesto|Exception|Message|Html.Raw|asp-controller=\"Budgets\"", view);
        Assert.Contains("SafeRequestId", view);
    }

    private static HomeController Home() => new(null!, null!, null!, null!, NullLogger<HomeController>.Instance,
        new ConfigurationBuilder().Build(), Options.Create(new CompanyOptions()))
        { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };

    private static string Read(string path)
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !Directory.Exists(Path.Combine(root.FullName, "Proyecto_Final"))) root = root.Parent;
        return File.ReadAllText(Path.Combine(root!.FullName, "Proyecto_Final", path));
    }
}
