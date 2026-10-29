using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class LogisticsPresentationTests
{
    [Theory]
    [InlineData("Fleet/Alerts")]
    [InlineData("Fleet/Maintenance")]
    [InlineData("RoutesAdmin/Index")]
    [InlineData("RoutesAdmin/Create")]
    [InlineData("RoutesAdmin/Detail")]
    [InlineData("RoutesAdmin/Evidences")]
    [InlineData("DeliveryBoard/Index")]
    public void LogisticsViewsPreserveAccessibleWorkspaceAndPostContracts(string path)
    {
        var view = Read("Views/" + path + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Single(Regex.Matches(view, "<h1>"));
        Assert.DoesNotMatch("bootstrap|custom-theme|fa fa-|data-toggle=|class=\"(?:btn |form-control|container-fluid|row )", view);
        Assert.Contains("_LogisticsNavigation", view);
        foreach (Match form in Regex.Matches(view, "<form[^>]*method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(view, "<table.*?</table>", RegexOptions.Singleline))
        { Assert.Contains("<caption", table.Value); Assert.Contains("scope=\"col\"", table.Value); }
    }

    [Theory]
    [InlineData("Planificada", "warning")]
    [InlineData("Despachada", "info")]
    [InlineData("Completada", "success")]
    [InlineData("Cancelada", "danger")]
    [InlineData("Estado futuro", "neutral")]
    [InlineData(null, "neutral")]
    public void RouteStatesKeepExplicitSemantics(string? value, string tone) => Assert.Equal(tone, LogisticsStatusPresentation.RouteTone(value));

    [Theory]
    [InlineData("Pendiente", "warning")]
    [InlineData("EnRuta", "info")]
    [InlineData("Entregado", "success")]
    [InlineData("Fallido", "danger")]
    [InlineData("Futuro", "neutral")]
    public void DeliveryStatesKeepExplicitSemantics(string value, string tone) => Assert.Equal(tone, LogisticsStatusPresentation.DeliveryTone(value));

    [Fact]
    public void MaintenanceAndAlertsNeverInventSeverity()
    {
        Assert.Equal("info", LogisticsStatusPresentation.MaintenanceTone("EnProceso"));
        Assert.Equal("neutral", LogisticsStatusPresentation.MaintenanceTone("Otro"));
        Assert.Equal("danger", LogisticsStatusPresentation.AlertTone("Vencido"));
        Assert.Equal("warning", LogisticsStatusPresentation.AlertTone("PorVencer"));
        Assert.Equal("neutral", LogisticsStatusPresentation.AlertTone("Otro"));
        var view = Read("Views/Fleet/Alerts.cshtml");
        Assert.Contains("a.Fecha", view);
        Assert.Contains(": a.Severidad;", view);
        Assert.Contains("name=\"diasAviso\"", view);
    }

    [Fact]
    public void MaintenancePreservesCostDatesWorkshopAndBinding()
    {
        var view = Read("Views/Fleet/Maintenance.cshtml");
        foreach (var field in new[] { "VehiculoId", "Tipo", "Descripcion", "Taller", "Costo", "Estado", "FechaProgramada", "KilometrajeProximo" })
        { Assert.Contains($"asp-for=\"Nueva.{field}\"", view); Assert.Contains($"asp-validation-for=\"Nueva.{field}\"", view); }
        foreach (var field in new[] { "FechaProgramada", "FechaRealizada", "KilometrajeProximo", "FechaRegistro", "RegistradoPorNombre" }) Assert.Contains("o." + field, view);
        Assert.Contains("name=\"ordenId\"", view);
        Assert.Contains("data-djj-confirm=", view);
        Assert.Contains(">Completar</button>", view);
    }

    [Fact]
    public void RouteCreateRetainsFieldsSelectionsAndResourceConstraints()
    {
        var view = Read("Views/RoutesAdmin/Create.cshtml");
        foreach (var field in new[] { "Zona", "ChoferUsuarioId", "VehiculoId", "Observaciones" })
        { Assert.Contains($"asp-for=\"{field}\"", view); Assert.Contains($"asp-validation-for=\"{field}\"", view); }
        Assert.Contains("name=\"PedidosSeleccionados\"", view);
        Assert.Contains("checked=\"@Model.PedidosSeleccionados.Contains(p.PedidoId)\"", view);
        Assert.Contains("disabled=\"@(!Model.HayRecursos)\"", view);
        Assert.Contains("asp-validation-summary=\"All\"", view);
    }

    [Fact]
    public void RouteDetailRetainsEveryMutationContractAndKeyboardMapAlternative()
    {
        var view = Read("Views/RoutesAdmin/Detail.cshtml");
        foreach (var action in new[] { "Sequence", "Dispatch", "Cancel", "Recalculate", "RemoveOrder", "AddOrder", "SaveSequence" }) Assert.Contains($"asp-action=\"{action}\"", view);
        Assert.DoesNotContain("asp-action=\"Liquidate\"", view);
        Assert.Contains("Liquidación y devoluciones bloqueadas", view);
        foreach (var name in new[] { "rutaId", "pedidoId", "motivo", "motivoFallo", "excluirRutaPedidoId", "rutaPedidoId", "secuencia", "lat", "lng" }) Assert.Contains($"name=\"{name}\"", view);
        Assert.Contains("data-djj-toggle=\"cancelBox\"", view);
        Assert.Contains("id=\"cancelBox\" hidden", view);
        Assert.Contains("min=\"-90\" max=\"90\"", view);
        Assert.Contains("min=\"-180\" max=\"180\"", view);
        Assert.Contains("c.FechaCierre", view);
        Assert.Contains("p.FechaEntrega", view);
        Assert.Contains("p.MotivoFallo", view);
        Assert.Contains("p.TotalEvidencias", view);
    }

    [Fact]
    public void EvidenceNeverRendersStorageKeysOrBypassesAuthorizedEndpoint()
    {
        var view = Read("Views/RoutesAdmin/Evidences.cshtml");
        Assert.DoesNotMatch("StorageKey|ArchivoUrl|StorageStatus|wwwroot|App_Data", view);
        Assert.Contains("asp-controller=\"DeliveryEvidence\" asp-action=\"View\"", view);
        Assert.Contains("data-djj-evidence", view);
        Assert.Contains("Vista previa no disponible", view);
        Assert.Contains("image/jpeg", view);
        Assert.Contains("RegistradoPorNombre", view);
    }

    [Fact]
    public void NavigationUsesActualCapabilitiesIncludingBoardDetailLinks()
    {
        var navigation = Read("Views/Shared/_LogisticsNavigation.cshtml");
        foreach (var code in new[] { "FLOTA_MANTENIMIENTO", "RUTAS_GESTIONAR", "ENTREGAS_TABLERO_VER" }) Assert.Contains($"Can(\"{code}\")", navigation);
        Assert.Contains("@if (canRoutes)", Read("Views/DeliveryBoard/Index.cshtml"));
        AssertCapability(typeof(RoutesAdminController), "RUTAS_GESTIONAR");
        AssertCapability(typeof(DeliveryBoardController), "ENTREGAS_TABLERO_VER");
        foreach (var name in new[] { "Create", "Sequence", "Dispatch", "Liquidate", "Cancel", "Recalculate", "RemoveOrder", "AddOrder", "SaveSequence" })
        {
            var method = typeof(RoutesAdminController).GetMethods().Single(m => m.Name == name && m.GetCustomAttribute<HttpPostAttribute>() is not null);
            Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        }
    }

    private static void AssertCapability(Type type, string code) => Assert.Equal(code, type.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
    private static string Read(string path)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "Proyecto_Final.slnx"))) dir = dir.Parent;
        return File.ReadAllText(Path.Combine(dir?.FullName ?? throw new DirectoryNotFoundException(), "Proyecto_Final", path));
    }
}
