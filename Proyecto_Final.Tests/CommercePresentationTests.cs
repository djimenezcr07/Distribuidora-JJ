using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class CommercePresentationTests
{
    [Theory]
    [InlineData("Combos/Index")]
    [InlineData("Combos/Create")]
    [InlineData("Combos/Detail")]
    [InlineData("Promotions/Index")]
    [InlineData("Promotions/Create")]
    [InlineData("Promotions/Edit")]
    [InlineData("Promotions/Segments")]
    public void AdministrativeRoutes_UseWorkspaceAndSemanticMarkup(string route)
    {
        var view = Read("Proyecto_Final/Views/" + route + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Single(Regex.Matches(view, "<h1>").Cast<Match>());
        Assert.DoesNotMatch("custom-theme|bootstrap|fa fa-|class=\"(?:btn |form-control|container-fluid|row )", view);
        foreach (Match form in Regex.Matches(view, "<form[^>]+method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(view, "<table.*?</table>", RegexOptions.Singleline))
            Assert.Contains("<caption", table.Value);
    }

    [Theory]
    [InlineData("Activa", true, -1, 1, "Activa", "success")]
    [InlineData("Activa", false, 1, 2, "Próxima", "warning")]
    [InlineData("Activa", false, -2, -1, "Vencida", "neutral")]
    [InlineData("Activa", false, 0, 0, "No vigente", "neutral")]
    [InlineData("Inactiva", true, -1, 1, "Inactiva", "neutral")]
    [InlineData("Vencida", false, 1, 2, "Vencida", "neutral")]
    [InlineData("Otro", false, -1, 1, "Otro", "neutral")]
    public void CommercialStatus_PreservesSqlAuthorityAndTechnicalState(string state, bool current, int start, int end, string label, string tone)
    {
        var today = new DateTime(2026, 10, 8);
        var promotion = new PromotionListItemViewModel { Estado = state, Vigente = current, FechaInicio = today.AddDays(start), FechaFin = today.AddDays(end) };
        Assert.Equal(new PromotionStatusPresentation(label, tone), PromotionStatusPresentation.From(promotion, today));
        Assert.Equal(state, promotion.Estado);
        Assert.Equal(current, promotion.Vigente);
    }

    [Fact]
    public void SharedPromotionFields_PreserveBindingAndConditionalHooks()
    {
        var partial = Read("Proyecto_Final/Views/Promotions/_PromotionFields.cshtml");
        foreach (var name in new[] { "Nombre", "Descripcion", "Tipo", "ProductoId", "CantidadMinima", "PorcentajeDescuento", "ProductoRegaloId", "CantidadRegalo", "SegmentoCliente", "FechaInicio", "FechaFin", "Prioridad" })
        {
            Assert.Matches($"<(?:input|select|textarea)[^>]*asp-for=\"{name}\"", partial);
            Assert.Contains($"asp-validation-for=\"{name}\"", partial);
        }
        Assert.Contains("for=\"promoTipo\"", partial);
        Assert.Contains("id=\"promoTipo\"", partial);
        Assert.Contains("promo-descuento", partial);
        Assert.Contains("promo-regalia", partial);
        Assert.DoesNotContain("Layout =", partial);
        foreach (var action in new[] { "Create", "Edit" })
        {
            var view = Read($"Proyecto_Final/Views/Promotions/{action}.cshtml");
            Assert.Contains($"asp-action=\"{action}\"", view);
            Assert.Contains("<partial name=\"_PromotionFields\" model=\"Model\"", view);
            Assert.Contains("~/js/stage2/promotions.js", view);
        }
        Assert.Contains("type=\"hidden\" asp-for=\"PromocionId\"", Read("Proyecto_Final/Views/Promotions/Edit.cshtml"));
    }

    [Fact]
    public void ComboComposition_PreservesIndexedBindingAndVisibleValidation()
    {
        var view = Read("Proyecto_Final/Views/Combos/Create.cshtml");
        foreach (var field in new[] { "ProductoId", "Nombre", "StockActual", "Seleccionado", "Cantidad" })
            Assert.Contains($"asp-for=\"Productos[i].{field}\"", view);
        Assert.Contains("asp-validation-for=\"Productos\"", view);
        Assert.Contains("asp-validation-for=\"Productos[i].Cantidad\"", view);
        Assert.Contains("asp-validation-summary=\"All\"", view);
        Assert.Contains("label asp-for=\"Productos[i].Cantidad\"", view);
    }

    [Fact]
    public void StateChanges_KeepContractsAndRequireConfirmation()
    {
        foreach (var (route, action, fields) in new[] {
            ("Combos/Index", "ToggleStatus", new[] { "asp-route-id=\"@combo.ComboId\"" }),
            ("Promotions/Index", "Inactivate", new[] { "name=\"promocionId\"", "name=\"motivo\"" }),
            ("Promotions/Segments", "SetSegment", new[] { "name=\"usuarioId\"", "name=\"segmento\"" }) })
        {
            var view = Read($"Proyecto_Final/Views/{route}.cshtml");
            var form = Regex.Match(view, $"<form asp-action=\"{action}\".*?</form>", RegexOptions.Singleline).Value;
            Assert.Contains("method=\"post\"", form);
            Assert.Contains("data-djj-confirm=", form);
            Assert.Contains("AntiForgeryToken", form);
            foreach (var field in fields) Assert.Contains(field, form);
            Assert.DoesNotContain("onclick=", view);
        }
    }

    [Fact]
    public void Controllers_PreserveWriteAuthorizationAndAntiforgery()
    {
        Assert.Equal("PROMOCIONES_GESTIONAR", typeof(PromotionsController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        Assert.Equal("COMBOS_VER", typeof(CombosController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        foreach (var controller in new[] { typeof(CombosController), typeof(PromotionsController) })
            foreach (var method in controller.GetMethods().Where(method => method.IsDefined(typeof(HttpPostAttribute))))
                Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        foreach (var method in typeof(CombosController).GetMethods().Where(method => method.Name is "Create" or "ToggleStatus"))
            Assert.Equal("COMBOS_GESTIONAR", method.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        var index = Read("Proyecto_Final/Views/Combos/Index.cshtml");
        Assert.Contains("if (canManage)", index);
        Assert.Contains("Contains(\"COMBOS_GESTIONAR\")", index);
        var layout = Read("Proyecto_Final/Views/Shared/_WorkspaceLayout.cshtml");
        Assert.Contains("Can(\"PROMOCIONES_GESTIONAR\")", layout);
        Assert.Contains("Can(\"COMBOS_VER\")", layout);
    }

    private static string Read(string path)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return File.ReadAllText(Path.Combine(directory?.FullName ?? throw new DirectoryNotFoundException(), path));
    }
}
