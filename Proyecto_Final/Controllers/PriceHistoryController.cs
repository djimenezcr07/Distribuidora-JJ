using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

public sealed class PriceHistoryController : Controller
{
    private readonly IPurchasingService _purchasing;
    private readonly AdminDbService _admin;

    public PriceHistoryController(IPurchasingService purchasing, AdminDbService admin)
    {
        _purchasing = purchasing;
        _admin = admin;
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    [AdminAuthorize("Compras", "COMPRAS_PRECIOS_VER")]
    public async Task<IActionResult> Index(int? productoId, CancellationToken cancellationToken)
    {
        var products = await _admin.GetActiveProductsForSelectAsync();
        var model = new PriceHistoryViewModel { ProductosDisponibles = products };
        if (productoId is > 0)
        {
            model.ProductoId = productoId.Value;
            model.ProductoNombre = products.FirstOrDefault(product => product.ProductoId == productoId.Value)?.Nombre ?? string.Empty;
            model.Historial = await _purchasing.GetPriceHistoryAsync(productoId.Value, cancellationToken);
        }

        return View(model);
    }
}
