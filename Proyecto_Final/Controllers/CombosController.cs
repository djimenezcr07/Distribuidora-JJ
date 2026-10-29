using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Inventario", "COMBOS_VER")]
public sealed class CombosController : Controller
{
    private readonly IComboDbService _combos;
    private readonly AdminDbService _adminDbService;
    private readonly ILogger<CombosController> _logger;

    public CombosController(
        IComboDbService combos,
        AdminDbService adminDbService,
        ILogger<CombosController> logger)
    {
        _combos = combos;
        _adminDbService = adminDbService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        return View(await _combos.GetAdminCombosAsync(cancellationToken));
    }

    [HttpGet]
    public async Task<IActionResult> Detail(int id, CancellationToken cancellationToken)
    {
        var combo = await _combos.GetDetailAsync(id, cancellationToken);
        return combo is null ? NotFound() : View(combo);
    }

    [HttpGet]
    [AdminAuthorize("Inventario", "COMBOS_GESTIONAR")]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        return View(new ComboFormViewModel
        {
            Productos = await GetProductSelectionListAsync(null, cancellationToken)
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [AdminAuthorize("Inventario", "COMBOS_GESTIONAR")]
    public async Task<IActionResult> Create(ComboFormViewModel model, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            model.Productos = await GetProductSelectionListAsync(model.Productos, cancellationToken);
            return View(model);
        }

        try
        {
            var comboId = await _combos.CreateAsync(model, UserId(), UserName(), cancellationToken);
            TempData["SuccessMessage"] = "Combo creado correctamente y disponible para la tienda.";
            return RedirectToAction(nameof(Detail), new { id = comboId });
        }
        catch (ArgumentException exception)
        {
            _logger.LogWarning(exception, "Se rechazó un combo inválido solicitado por el usuario {UserId}.", UserId());
            ModelState.AddModelError(nameof(model.Productos), "Revise los componentes seleccionados.");
        }
        catch (SqlException exception)
        {
            _logger.LogWarning(exception, "La base rechazó la creación de combo para el usuario {UserId}.", UserId());
            ModelState.AddModelError(string.Empty, "No fue posible crear el combo con los datos indicados.");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Error inesperado al crear un combo para el usuario {UserId}.", UserId());
            ModelState.AddModelError(string.Empty, "Ocurrió un error al crear el combo. Intente nuevamente.");
        }

        model.Productos = await GetProductSelectionListAsync(model.Productos, cancellationToken);
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [AdminAuthorize("Inventario", "COMBOS_GESTIONAR")]
    public async Task<IActionResult> ToggleStatus(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _combos.ToggleStatusAsync(id, UserId(), UserName(), cancellationToken);
            TempData["SuccessMessage"] = "Estado del combo actualizado.";
        }
        catch (SqlException exception)
        {
            _logger.LogWarning(exception, "La base rechazó el cambio de estado del combo {ComboId}.", id);
            TempData["ErrorMessage"] = "No fue posible cambiar el estado del combo.";
        }

        return RedirectToAction(nameof(Index));
    }

    private async Task<List<ComboProductSelectionViewModel>> GetProductSelectionListAsync(
        IReadOnlyCollection<ComboProductSelectionViewModel>? previous,
        CancellationToken cancellationToken)
    {
        var products = await _adminDbService.GetActiveProductsForSelectAsync();
        cancellationToken.ThrowIfCancellationRequested();
        return products.Select(product =>
        {
            var prior = previous?.FirstOrDefault(item => item.ProductoId == product.ProductoId);
            return new ComboProductSelectionViewModel
            {
                ProductoId = product.ProductoId,
                Nombre = product.Nombre,
                StockActual = product.Stock,
                Seleccionado = prior?.Seleccionado ?? false,
                Cantidad = prior?.Cantidad > 0 ? prior.Cantidad : 1
            };
        }).ToList();
    }

    private int UserId() => HttpContext.Session.GetInt32("UserId")!.Value;
    private string UserName() => HttpContext.Session.GetString("UserFullName") ?? "Administrador";
}
