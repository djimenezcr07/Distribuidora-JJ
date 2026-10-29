using System.Globalization;
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class AssetsPresentationTests
{
    [Theory]
    [InlineData("Assets/Index")]
    [InlineData("Assets/Create")]
    [InlineData("Assets/Edit")]
    [InlineData("Assets/Details")]
    [InlineData("Comodatos/Index")]
    [InlineData("Comodatos/Assign")]
    [InlineData("Comodatos/Profitability")]
    public void PagesUseAccessibleWorkspaceAndPreservePostProtection(string path)
    {
        var view = Read("Views/" + path + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Contains("_AssetsNavigation", view);
        Assert.Single(Regex.Matches(view, "<h1>"));
        Assert.DoesNotMatch("custom-theme|bootstrap|fa fa-|data-toggle=|style=|class=\"(?:btn |form-control|row )", view);
        foreach (Match form in Regex.Matches(view, "<form[^>]*method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(view, "<table.*?</table>", RegexOptions.Singleline))
        { Assert.Contains("<caption", table.Value); Assert.Contains("scope=\"col\"", table.Value); }
    }

    [Theory]
    [InlineData("Disponible", "success")]
    [InlineData("Prestado", "info")]
    [InlineData("Mantenimiento", "warning")]
    [InlineData("Baja", "neutral")]
    [InlineData("Inactivo", "neutral")]
    [InlineData("Estado nuevo", "neutral")]
    [InlineData(null, "neutral")]
    public void AssetStatesDoNotInferDamageOrReturns(string? state, string tone) => Assert.Equal(tone, AssetPresentation.AssetTone(state));

    [Theory]
    [InlineData("Activo", "info")]
    [InlineData("Devuelto", "success")]
    [InlineData("Retirado", "warning")]
    [InlineData("Otro", "neutral")]
    [InlineData(null, "neutral")]
    public void ComodatoStatesRemainLiteral(string? state, string tone) => Assert.Equal(tone, AssetPresentation.ComodatoTone(state));

    [Theory]
    [InlineData("12345678.90")]
    [InlineData("0")]
    [InlineData("-1500.25")]
    public void MoneyAlwaysUsesCostaRicanFormat(string value)
    {
        var old = CultureInfo.CurrentCulture;
        try { CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-US"); var amount = decimal.Parse(value, CultureInfo.InvariantCulture); Assert.Equal("₡" + amount.ToString("N2", CultureInfo.GetCultureInfo("es-CR")), AssetPresentation.Money(amount)); }
        finally { CultureInfo.CurrentCulture = old; }
    }

    [Fact]
    public void SharedFieldsKeepBindingWithoutReintroducingObsoleteStateEditors()
    {
        var fields = Read("Views/Assets/_AssetFields.cshtml");
        Assert.DoesNotContain("Layout =", fields);
        foreach (var field in new[] { "CodigoActivo", "Nombre", "Tipo", "Descripcion" })
        { Assert.Contains($"asp-for=\"{field}\"", fields); Assert.Contains($"asp-validation-for=\"{field}\"", fields); }
        Assert.DoesNotContain("asp-for=\"Estado\"", fields); Assert.DoesNotContain("asp-for=\"ClientePrestamo\"", fields);
        Assert.Contains("option value=\"@Model.Tipo\"", fields);
        foreach (var page in new[] { "Create", "Edit" }) Assert.Contains("partial name=\"_AssetFields\" model=\"Model\"", Read($"Views/Assets/{page}.cshtml"));
        Assert.Contains("type=\"hidden\" asp-for=\"ActivoId\"", Read("Views/Assets/Edit.cshtml"));
    }

    [Fact]
    public void OperationalFieldsAndMutationIdentitiesRemainAvailable()
    {
        var index = Read("Views/Assets/Index.cshtml");
        Assert.Contains("a.FechaRegistro", index); Assert.Contains("a.Activo", index); Assert.Contains("asp-action=\"Delete\" asp-route-id=\"@a.ActivoId\"", index);
        var details = Read("Views/Assets/Details.cshtml"); Assert.Contains("h.Observaciones", details); Assert.Contains("h.ComodatoId", details);
        var loans = Read("Views/Comodatos/Index.cshtml");
        foreach (var field in new[] { "FechaDevolucion", "DestinoDevolucion", "ClienteIdentificacion", "Ubicacion", "DiasEnComodato" }) Assert.Contains("c." + field, loans);
        foreach (var field in new[] { "ComodatoId", "Destino", "CondicionDevolucion" }) Assert.Contains($"name=\"{field}\"", loans);
        Assert.Contains("c.Estado == \"Activo\"", loans); Assert.Contains("data-djj-confirm=", loans);
    }

    [Fact]
    public void AssignKeepsAvailableResourcesAndIdentificationValidation()
    {
        var view = Read("Views/Comodatos/Assign.cshtml");
        foreach (var field in new[] { "ActivoId", "ClienteNombre", "ClienteIdentificacion", "Ubicacion", "FechaAsignacion", "CondicionEntrega", "Observaciones" })
        { Assert.Contains($"asp-for=\"{field}\"", view); Assert.Contains($"asp-validation-for=\"{field}\"", view); }
        Assert.Contains("disabled=\"@(!Model.ActivosDisponibles.Any())\"", view);
        Assert.DoesNotContain("asp-for=\"ClienteUsuarioId\"", view);
    }

    [Fact]
    public void ProfitabilityDoesNotSumRepeatedClientPurchasesOrInventReturns()
    {
        var view = Read("Views/Comodatos/Profitability.cshtml");
        foreach (var field in new[] { "ComodatoId", "ActivoTipo", "ClienteUsuarioId", "FechaAsignacion", "DiasEnComodato", "NumPedidos", "TotalComprado", "UltimaCompra" }) Assert.Contains("r." + field, view);
        Assert.Contains("AssetPresentation.Money(r.TotalComprado)", view);
        Assert.Contains("no utilidad ni retorno", view); Assert.Contains("no se suman", view);
        Assert.DoesNotContain(".Sum(", view); Assert.DoesNotContain("<script", view);
        Assert.Contains("djj-align-right djj-table__nowrap", view);
    }

    [Fact]
    public void NavigationTracksActualEndpointPoliciesAndActionOverride()
    {
        foreach (var controller in new[] { typeof(AssetsController), typeof(ComodatosController) })
            Assert.Equal("ACTIVOS_GESTIONAR", controller.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        Assert.Equal("COMODATOS_CONSULTAR", typeof(ComodatosController).GetMethod("Profitability")!.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        var nav = Read("Views/Shared/_AssetsNavigation.cshtml");
        Assert.Contains("Can(\"ACTIVOS_GESTIONAR\")", nav); Assert.Contains("Can(\"COMODATOS_CONSULTAR\")", nav);
        var layout = Read("Views/Shared/_WorkspaceLayout.cshtml"); Assert.Contains("canAssetProfitability", layout); Assert.Contains("asp-controller=\"Comodatos\" asp-action=\"Profitability\">Workspace", layout);
        foreach (var type in new[] { typeof(AssetsController), typeof(ComodatosController) })
            foreach (var method in type.GetMethods().Where(m => m.GetCustomAttribute<HttpPostAttribute>() is not null)) Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
    }

    private static string Read(string path)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "Proyecto_Final.slnx"))) dir = dir.Parent;
        return File.ReadAllText(Path.Combine(dir?.FullName ?? throw new DirectoryNotFoundException(), "Proyecto_Final", path));
    }
}
