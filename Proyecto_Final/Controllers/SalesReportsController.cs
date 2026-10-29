using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Reportes", "REPORTES_VENTAS_VER")]
public sealed class SalesReportsController : Controller
{
    private readonly ReportsDbService _reports;

    public SalesReportsController(ReportsDbService reports) => _reports = reports;

    [HttpGet]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Index([FromQuery] SalesReportFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return View(new DetailedSalesReportViewModel { Filtro = filter });
        return View(await _reports.GetSalesReportAsync(filter, cancellationToken));
    }

    [HttpGet]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Print([FromQuery] SalesReportFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest();
        ViewData["PrintMode"] = true;
        return View("Index", await _reports.GetSalesReportAsync(filter, cancellationToken));
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> ExportCsv([FromQuery] SalesReportFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest();
        var report = await _reports.GetSalesReportAsync(filter, cancellationToken);
        var csv = new StringBuilder("Grupo,Categoria,Ventas,Facturas,Pedidos,TicketPromedio,Unidades\r\n");
        foreach (var row in report.Filas)
        {
            csv.Append(CsvExportSanitizer.Cell(row.Etiqueta)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Categoria)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.TotalVentas)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Facturas)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Pedidos)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.TicketPromedio)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Unidades)).Append("\r\n");
        }

        return File(new UTF8Encoding(true).GetBytes(csv.ToString()), "text/csv", $"ventas-{filter.Desde:yyyyMMdd}-{filter.Hasta:yyyyMMdd}.csv");
    }
}
