using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Reportes", "REPORTES_VENDEDORES_VER")]
public sealed class SellerPerformanceController : Controller
{
    private readonly ReportsDbService _reports;

    public SellerPerformanceController(ReportsDbService reports) => _reports = reports;

    [HttpGet]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Index([FromQuery] SellerPerformanceFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return View(new SellerPerformanceViewModel { Filtro = filter });
        return View(await _reports.GetSellerPerformanceAsync(filter, cancellationToken));
    }

    [HttpGet]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Print([FromQuery] SellerPerformanceFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest();
        ViewData["PrintMode"] = true;
        return View("Index", await _reports.GetSellerPerformanceAsync(filter, cancellationToken));
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> ExportCsv([FromQuery] SellerPerformanceFilterViewModel filter, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest();
        var report = await _reports.GetSellerPerformanceAsync(filter, cancellationToken);
        var csv = new StringBuilder("Vendedor,Ventas,Pedidos,Facturas,TicketPromedio,ClientesAtendidos,Meta,CumplimientoPorcentual\r\n");
        foreach (var row in report.Filas)
        {
            csv.Append(CsvExportSanitizer.Cell(row.VendedorNombre)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Ventas)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Pedidos)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Facturas)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.TicketPromedio)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.ClientesAtendidos)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.Meta)).Append(',')
                .Append(CsvExportSanitizer.Cell(row.CumplimientoPorcentual)).Append("\r\n");
        }

        return File(new UTF8Encoding(true).GetBytes(csv.ToString()), "text/csv", $"vendedores-{filter.Desde:yyyyMMdd}-{filter.Hasta:yyyyMMdd}.csv");
    }
}
