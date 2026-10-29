using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;
using System.Text;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Presupuestos", "PRESUPUESTOS_COMPARAR")]
public sealed class BudgetComparisonController : Controller
{
    private readonly BudgetComparisonDbService _comparison;
    public BudgetComparisonController(BudgetComparisonDbService comparison) => _comparison = comparison;

    [HttpGet]
    public async Task<IActionResult> Index([FromQuery] BudgetComparisonFilterViewModel filter)
    {
        PreventCaching();
        return View(await _comparison.GetDashboardAsync(filter));
    }

    [HttpGet]
    public async Task<IActionResult> Print([FromQuery] BudgetComparisonFilterViewModel filter)
    {
        PreventCaching();
        filter.Page = 1; filter.PageSize = 100;
        return View(await _comparison.GetDashboardAsync(filter));
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    public async Task<IActionResult> ExportCsv([FromQuery] BudgetComparisonFilterViewModel filter)
    {
        PreventCaching();
        filter.Page = 1; filter.PageSize = 100;
        var first = await _comparison.GetDashboardAsync(filter);
        var rows = first.ExpenseDetail.Items.ToList();
        var pages = Math.Min(first.ExpenseDetail.TotalPages, 100);
        for (var page = 2; page <= pages; page++)
        {
            filter.Page = page;
            rows.AddRange((await _comparison.GetDashboardAsync(filter)).ExpenseDetail.Items);
        }

        var csv = new StringBuilder();
        csv.AppendLine("Fecha,Departamento,Categoria,Documento,Proveedor,Descripcion,Estado,Total");
        foreach (var row in rows)
        {
            csv.Append(CsvExportSanitizer.Cell(row.ExpenseDate.ToString("yyyy-MM-dd"))).Append(',')
                .Append(CsvExportSanitizer.Cell(row.DepartmentName)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.CategoryName)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.DocumentNumber)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.SupplierName)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Description)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Status)).Append(',')
                .AppendLine(CsvExportSanitizer.Cell(row.Total));
        }
        return File(new UTF8Encoding(encoderShouldEmitUTF8Identifier: true).GetBytes(csv.ToString()), "text/csv", $"presupuesto-real-{filter.Year}.csv");
    }

    private void PreventCaching()
    {
        Response.Headers.CacheControl = "no-store, no-cache, must-revalidate";
        Response.Headers.Pragma = "no-cache";
    }
}
