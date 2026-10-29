using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Inventario", "INVENTARIO_INTELIGENCIA_VER")]
public sealed class InventoryIntelligenceController : Controller
{
    private readonly IInventoryIntelligenceService _intelligence;
    private readonly ILogger<InventoryIntelligenceController> _logger;

    public InventoryIntelligenceController(
        IInventoryIntelligenceService intelligence,
        ILogger<InventoryIntelligenceController> logger)
    {
        _intelligence = intelligence;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> Index(
        [FromQuery] InventoryIntelligenceFilterViewModel filter,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return View(new InventoryIntelligenceViewModel { Filter = filter });
        }

        try
        {
            return View(await _intelligence.GetAsync(filter, cancellationToken));
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "No fue posible consultar inteligencia de inventario.");
            ModelState.AddModelError(string.Empty, "No fue posible cargar los indicadores en este momento.");
            return View(new InventoryIntelligenceViewModel { Filter = filter });
        }
    }
}
