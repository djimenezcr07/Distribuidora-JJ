using System.Globalization;
using System.Text.RegularExpressions;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class AnalyticsPresentationTests
{
    [Theory]
    [InlineData("ManagementDashboard/Index")]
    [InlineData("Kpis/Index")]
    [InlineData("Kpis/Report")]
    [InlineData("SalesReports/Index")]
    [InlineData("SellerPerformance/Index")]
    [InlineData("MyGoal/Index")]
    public void MigratedViews_UseWorkspaceWithoutLegacyDependencies(string path)
    {
        var view = Read("Proyecto_Final", "Views", path + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Contains("<h1>", view);
        Assert.DoesNotMatch("custom-theme|bootstrap|class=\"(?:btn |form-control|container-fluid|row )|fa fa-", view);
        // Every visible field has an explicit associated, nonempty label.
        foreach (Match input in Regex.Matches(view, "<(?:input|select|textarea)[^>]+id=\"([^\"]+)\""))
            Assert.Matches($"<label[^>]*for=\"{Regex.Escape(input.Groups[1].Value)}\"[^>]*>[^<]+</label>", view);
    }

    [Theory]
    [InlineData("SalesReports", "Agrupacion", "Categoria")]
    [InlineData("SellerPerformance", "VendedorUsuarioId", "Orden")]
    public void ReadReports_PreserveFilterParametersOnPrintAndCsv(string family, string first, string second)
    {
        var view = Read("Proyecto_Final", "Views", family, "Index.cshtml");
        foreach (var name in new[] { "Desde", "Hasta", first, second })
        {
            Assert.Contains($"name=\"{name}\"", view);
            foreach (var action in new[] { "Print", "ExportCsv" })
            {
                var link = Regex.Match(view, $"<a asp-action=\"{action}\"[^>]+>").Value;
                Assert.Contains($"asp-route-{name}=", link);
            }
        }
        Assert.Contains("ViewData[\"PrintMode\"]", view);
        Assert.Contains("window.print()", view);
        Assert.Contains("<caption>", view);
        Assert.Contains("_AnalyticsChart", view);
    }

    [Fact]
    public void GoalManagement_PreservesPostContractAndAntiforgery()
    {
        var view = Read("Proyecto_Final", "Views", "Kpis", "Index.cshtml");
        var form = Regex.Match(view, "<form asp-controller=\"Kpis\" asp-action=\"Save\".*?</form>", RegexOptions.Singleline).Value;
        Assert.Contains("method=\"post\"", form);
        Assert.Contains("@Html.AntiForgeryToken()", form);
        foreach (var field in new[] { "Anio", "Mes", "VendedorUsuarioId", "MontoMeta", "Observaciones" })
            Assert.Contains($"name=\"{field}\"", form);
        Assert.Contains("@item.Observaciones", view);
        Assert.Contains("@item.VentasReales", view);
    }

    [Fact]
    public void DashboardAndKpiReport_KeepCriticalDataAndTabularChartEquivalent()
    {
        var dashboard = Read("Proyecto_Final", "Views", "ManagementDashboard", "Index.cshtml");
        foreach (var field in new[] { "VentasPeriodo", "FacturasPeriodo", "PedidosPeriodo", "TicketPromedio", "StockBajo", "ProductosAgotados", "PedidosEnRuta", "CobrosPendientes" })
            Assert.Contains($"Model.{field}", dashboard);
        Assert.Contains("@point.Facturas", dashboard);
        var report = Read("Proyecto_Final", "Views", "Kpis", "Report.cshtml");
        Assert.Contains("item.Clasificacion", report);
        Assert.Contains("item.Facturas", report);
        Assert.Contains("item.PorcentajeCumplimiento.HasValue", report);
        Assert.Contains("<table", report);
        Assert.Contains("_AnalyticsChart", report);
    }

    [Theory]
    [InlineData(0, 100, "0")]
    [InlineData(50, 200, "25")]
    [InlineData(200, 100, "100")]
    [InlineData(10, 0, "0")]
    [InlineData(-10, 100, "0")]
    public void ChartWidths_HandleZeroAndOverflowUsingInvariantCss(decimal value, decimal max, string expected)
    {
        var original = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("es-ES");
            Assert.Equal(expected, AnalyticsChartViewModel.Width(value, max));
            Assert.Equal("33.3333", AnalyticsChartViewModel.Width(1m, 3m));
        }
        finally { CultureInfo.CurrentCulture = original; }
    }

    [Fact]
    public void ChartScale_IncludesTargetsAndPreservesFullSourceValues()
    {
        var chart = new AnalyticsChartViewModel { Rows = [new("A", 150m, 100m), new("B", 0m, 300m)] };
        Assert.Equal(300m, chart.Maximum);
        Assert.Equal("50", AnalyticsChartViewModel.Width(chart.Rows[0].Value, chart.Maximum));
        Assert.Equal(150m, chart.Rows[0].Value);
        Assert.Equal(0m, new AnalyticsChartViewModel().Maximum);
        var partial = Read("Proyecto_Final", "Views", "Shared", "_AnalyticsChart.cshtml");
        Assert.Contains("@row.Label", partial);
        Assert.DoesNotContain("Html.Raw", partial);
        Assert.Contains("@row.Value.ToString", partial);
        Assert.Contains("row.Target.HasValue", partial);
        Assert.Contains("Model.Rows.Count == 0", partial);
    }

    [Fact]
    public void MyGoal_RetainsPersonalOwnershipAndUndefinedGoalState()
    {
        var controller = Read("Proyecto_Final", "Controllers", "MyGoalController.cs");
        Assert.Contains("Session.GetInt32(\"UserId\")", controller);
        Assert.Contains("GetMiProgresoAsync(vendedorId", controller);
        var view = Read("Proyecto_Final", "Views", "MyGoal", "Index.cshtml");
        Assert.Contains("Model.SinMetaDefinida", view);
        Assert.Contains("Model.MontoPendiente", view);
        Assert.Contains("Model.VentasReales", view);
        Assert.Contains("Model.PorcentajeCumplimiento", view);
        Assert.DoesNotContain("VendedorUsuarioId", view);
        Assert.DoesNotContain("Model.Items", view);
    }

    private static string Read(params string[] parts)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "Proyecto_Final.slnx"))) dir = dir.Parent;
        return File.ReadAllText(Path.Combine([dir?.FullName ?? throw new DirectoryNotFoundException(), .. parts]));
    }
}
