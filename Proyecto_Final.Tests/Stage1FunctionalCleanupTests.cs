using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Tests;

public sealed class Stage1FunctionalCleanupTests
{
    [Fact]
    public void CheckoutContract_DoesNotExposeUnimplementedFields()
    {
        var properties = typeof(CheckoutViewModel).GetProperties().Select(property => property.Name).ToHashSet();

        Assert.DoesNotContain("FacturaElectronica", properties);
        Assert.DoesNotContain("TipoCliente", properties);
        Assert.DoesNotContain("Telefono2", properties);
    }

    [Fact]
    public void LegacySecurityBridge_HasNoMutationNamedPostRedirects()
    {
        var postActions = typeof(SecurityController).GetMethods()
            .Where(method => method.DeclaringType == typeof(SecurityController)
                && method.GetCustomAttributes(typeof(HttpPostAttribute), true).Any())
            .ToArray();

        Assert.Empty(postActions);
        Assert.All(typeof(SecurityController).GetMethods().Where(method => method.DeclaringType == typeof(SecurityController)),
            method => Assert.NotEmpty(method.GetCustomAttributes(typeof(ObsoleteAttribute), true)));
    }

    [Fact]
    public void Inventory_HasNoMisleadingDeleteCompatibilityAction() =>
        Assert.DoesNotContain(typeof(InventoryController).GetMethods(), method =>
            method.DeclaringType == typeof(InventoryController) && method.Name == "Delete");

    [Fact]
    public void Navigation_PublishesOnlyCanonicalAccountsReceivableExperience()
    {
        var layout = File.ReadAllText(SourcePath("Views", "Shared", "_Layout.cshtml"));
        var dashboard = File.ReadAllText(SourcePath("Views", "Admin", "Index.cshtml"));

        Assert.DoesNotContain("asp-controller=\"Credits\"", layout, StringComparison.Ordinal);
        Assert.DoesNotContain("asp-controller=\"Credits\"", dashboard, StringComparison.Ordinal);
        Assert.Contains("asp-controller=\"AccountsReceivableAdmin\"", layout, StringComparison.Ordinal);
        Assert.Contains("asp-controller=\"AccountsReceivableAdmin\"", dashboard, StringComparison.Ordinal);
    }

    [Fact]
    public void PurchaseOrderForm_PostsOnlyAddedLinesAndDoesNotRaiseGlobalFormLimit()
    {
        var view = File.ReadAllText(SourcePath("Views", "PurchaseOrders", "Create.cshtml"));
        var program = File.ReadAllText(SourcePath("Program.cs"));

        Assert.Contains("id=\"product-catalog\"", view, StringComparison.Ordinal);
        Assert.Contains("Productos[${index}]", view, StringComparison.Ordinal);
        Assert.DoesNotContain("class=\"select-product\"", view, StringComparison.Ordinal);
        Assert.DoesNotContain("ValueCountLimit = 4096", program, StringComparison.Ordinal);
    }

    private static string SourcePath(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
            directory = directory.Parent;
        var root = directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz de la solución.");
        return Path.Combine(new[] { root, "Proyecto_Final" }.Concat(segments).ToArray());
    }
}
