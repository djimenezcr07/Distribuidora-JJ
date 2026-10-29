using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Tests;

public sealed class SalesReportTests
{
    [Fact]
    public void CalculateAverage_IsPureAndRoundsAwayFromZero()
    {
        Assert.Equal(33.33m, ReportMetrics.CalculateAverage(100m, 3));
        Assert.Equal(0m, ReportMetrics.CalculateAverage(100m, 0));
    }

    [Fact]
    public void SalesFilter_RejectsUnknownGroupingAndExcessiveRange()
    {
        var filter = new SalesReportFilterViewModel
        {
            Desde = new DateTime(2020, 1, 1),
            Hasta = new DateTime(2023, 1, 2),
            Agrupacion = "arbitraria"
        };

        var errors = Validate(filter);
        Assert.Contains(errors, error => error.MemberNames.Contains(nameof(filter.Agrupacion)));
        Assert.Contains(errors, error => error.MemberNames.Contains(nameof(filter.Hasta)));
    }

    [Fact]
    public void SellerFilter_RejectsInvalidSellerAndSort()
    {
        var filter = new SellerPerformanceFilterViewModel { VendedorUsuarioId = 0, Orden = "sql" };
        var errors = Validate(filter);

        Assert.Contains(errors, error => error.MemberNames.Contains(nameof(filter.VendedorUsuarioId)));
        Assert.Contains(errors, error => error.MemberNames.Contains(nameof(filter.Orden)));
    }

    [Theory]
    [InlineData(typeof(SalesReportsController), "REPORTES_VENTAS_VER")]
    [InlineData(typeof(SellerPerformanceController), "REPORTES_VENDEDORES_VER")]
    public void ReportControllers_RequireExactPermission(Type controller, string permission)
    {
        var attribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(
            controller.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)));
        Assert.Equal(permission, attribute.Arguments![1]);
    }

    [Theory]
    [InlineData(typeof(SalesReportsController))]
    [InlineData(typeof(SellerPerformanceController))]
    public void CsvExports_AreRateLimitedAndDisableCaching(Type controller)
    {
        var action = controller.GetMethod("ExportCsv")!;
        Assert.NotEmpty(action.GetCustomAttributes(typeof(EnableRateLimitingAttribute), true));
        var cache = Assert.IsType<ResponseCacheAttribute>(Assert.Single(
            action.GetCustomAttributes(typeof(ResponseCacheAttribute), true)));
        Assert.True(cache.NoStore);
    }

    [Fact]
    public void Migration0015_DeclaresLedgerPermissionsAndProcedures()
    {
        var root = FindRepositoryRoot();
        var migration = File.ReadAllText(Path.Combine(root, "database", "migrations", "0015_sales_and_seller_reports.sql"));
        var verify = File.ReadAllText(Path.Combine(root, "database", "migrations", "0015_sales_and_seller_reports.verify.sql"));

        Assert.Contains("0015_sales_and_seller_reports", migration, StringComparison.Ordinal);
        Assert.Contains("sp_Reportes_VentasDetallado", migration, StringComparison.Ordinal);
        Assert.Contains("sp_Reportes_DesempenoVendedores", migration, StringComparison.Ordinal);
        Assert.Contains("REPORTES_VENTAS_VER", migration, StringComparison.Ordinal);
        Assert.Contains("REPORTES_VENDEDORES_VER", migration, StringComparison.Ordinal);
        Assert.Contains("THROW", verify, StringComparison.Ordinal);
    }

    private static List<ValidationResult> Validate(object model)
    {
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(model, new ValidationContext(model), results, true);
        return results;
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
            directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz de la solución.");
    }
}
