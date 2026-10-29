using System.Reflection;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Controllers.Admin;

namespace Proyecto_Final.Tests;

public sealed class ControllerSurfaceAuditTests
{
    [Fact]
    public void AuditScope_IncludesControllersFromAllSubnamespaces()
    {
        var controllers = GetControllers();
        var apiControllers = typeof(Proyecto_FinalAPI.Controllers.AuthController).Assembly
            .GetTypes()
            .Count(type => IsControllerInNamespace(type, typeof(Proyecto_FinalAPI.Controllers.AuthController).Namespace!));

        Assert.True(controllers.Count >= 57);
        Assert.Equal(2, apiControllers);
        Assert.Contains(typeof(BudgetsController), controllers);
        Assert.Contains(typeof(ChatController), controllers);
        Assert.Contains(typeof(PayrollController), controllers);
        Assert.Contains(typeof(PurchaseOrdersController), controllers);
        Assert.Contains(typeof(WarrantyRequestsAdminController), controllers);
    }

    [Fact]
    public void EveryFormPostRequiresAntiforgeryExceptTheJsonOfflineSyncEndpoint()
    {
        var unsafePosts = GetControllers()
            .SelectMany(type => type.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly))
            .Where(IsMvcAction)
            .Where(method => method.GetCustomAttributes<HttpPostAttribute>(true).Any())
            .Where(method => !(method.DeclaringType == typeof(SellerOrdersController) && method.Name == nameof(SellerOrdersController.SyncOffline)))
            .Where(method => !method.GetCustomAttributes<ValidateAntiForgeryTokenAttribute>(true).Any())
            .ToArray();

        Assert.Empty(unsafePosts);
    }

    [Fact]
    public void GlobalErrorActionLogsTheExceptionAndReturns503()
    {
        var source = File.ReadAllText(SourcePath("Controllers", "HomeController.cs"));
        Assert.Contains("IExceptionHandlerFeature", source, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
        Assert.Contains("TraceId", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ChatTechnicalFailuresUse503InsteadOfRaw500()
    {
        var source = File.ReadAllText(SourcePath("Controllers", "ChatController.cs"));
        Assert.DoesNotContain("StatusCode(500", source, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
    }

    [Fact]
    public void PriorityFlowsExpose404_422And503InsteadOfRedirectingOrThrowing()
    {
        var expenses = File.ReadAllText(SourcePath("Controllers", "ExpensesController.cs"));
        var documents = File.ReadAllText(SourcePath("Controllers", "DocumentsController.cs"));
        var purchases = File.ReadAllText(SourcePath("Controllers", "PurchaseOrdersController.cs"));

        Assert.Contains("if (id <= 0) return NotFound();", expenses, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status422UnprocessableEntity", expenses, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", expenses, StringComparison.Ordinal);
        Assert.Contains("if (id <= 0) return NotFound();", documents, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status422UnprocessableEntity", documents, StringComparison.Ordinal);
        Assert.Equal(2, purchases.Split("return UnprocessableEntity(", StringSplitOptions.None).Length - 1);
    }

    [Fact]
    public void DirectedClientCheckoutAndPayrollFlowsPreserveHttpSemantics()
    {
        var clients = File.ReadAllText(SourcePath("Controllers", "ClientsController.cs"));
        var credits = File.ReadAllText(SourcePath("Controllers", "CreditsController.cs"));
        var cart = File.ReadAllText(SourcePath("Controllers", "CartController.cs"));
        var payroll = File.ReadAllText(SourcePath("Controllers", "PayrollController.cs"));

        Assert.Contains("InvalidClientForm", clients, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", clients, StringComparison.Ordinal);
        Assert.Contains("if (id <= 0) return NotFound();", credits, StringComparison.Ordinal);
        Assert.Contains("InvalidCheckout", cart, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status422UnprocessableEntity", cart, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status503ServiceUnavailable", payroll, StringComparison.Ordinal);
        Assert.Contains("return UnprocessableEntity", payroll, StringComparison.Ordinal);
    }

    private static IReadOnlyList<Type> GetControllers() => typeof(HomeController).Assembly
        .GetTypes()
        .Where(type => IsControllerInNamespace(type, typeof(HomeController).Namespace!))
        .OrderBy(type => type.Name)
        .ToArray();

    private static bool IsControllerInNamespace(Type type, string rootNamespace) =>
        type.IsClass
        && !type.IsAbstract
        && typeof(ControllerBase).IsAssignableFrom(type)
        && (string.Equals(type.Namespace, rootNamespace, StringComparison.Ordinal)
            || type.Namespace?.StartsWith(rootNamespace + ".", StringComparison.Ordinal) == true)
        && type.Name.EndsWith("Controller", StringComparison.Ordinal);

    private static bool IsMvcAction(MethodInfo method) => !method.IsSpecialName && !method.IsDefined(typeof(NonActionAttribute), true);

    private static string SourcePath(params string[] parts) => Path.Combine([AppContext.BaseDirectory, "..", "..", "..", "..", "Proyecto_Final", .. parts]);
}
