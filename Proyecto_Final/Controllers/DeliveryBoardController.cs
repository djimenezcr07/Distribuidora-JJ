using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Entregas", "ENTREGAS_TABLERO_VER", allowAdministratorBypass: false)]
public sealed class DeliveryBoardController : Controller
{
    private readonly LogisticsDbService _logistics;

    public DeliveryBoardController(LogisticsDbService logistics)
    {
        _logistics = logistics;
    }

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken) =>
        View(await BuildSnapshotAsync(cancellationToken));

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Snapshot(CancellationToken cancellationToken) =>
        Json(await BuildSnapshotAsync(cancellationToken));

    private async Task<DeliveryBoardViewModel> BuildSnapshotAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var routes = await _logistics.GetRoutesAsync(null, null);
        var rows = routes
            .OrderBy(route => route.Estado is "Despachada" or "Planificada" ? 0 : 1)
            .ThenByDescending(route => route.FechaDespacho ?? route.FechaCreacion)
            .Select(route => new DeliveryBoardRowViewModel
            {
                RutaId = route.RutaId,
                Codigo = route.Codigo,
                Zona = route.Zona,
                Estado = route.Estado,
                Chofer = route.Chofer,
                VehiculoPlaca = route.VehiculoPlaca,
                TotalPedidos = route.TotalPedidos,
                Entregados = route.Entregados,
                Fallidos = route.Fallidos,
                Pendientes = route.Pendientes,
                FechaDespacho = route.FechaDespacho
            })
            .ToArray();

        return new DeliveryBoardViewModel
        {
            GeneradoUtc = DateTimeOffset.UtcNow,
            RutasActivas = rows.Count(route => route.Estado is "Despachada" or "Planificada"),
            EntregasPendientes = rows.Sum(route => route.Pendientes),
            EntregasCompletadas = rows.Sum(route => route.Entregados),
            EntregasFallidas = rows.Sum(route => route.Fallidos),
            Rutas = rows
        };
    }
}
