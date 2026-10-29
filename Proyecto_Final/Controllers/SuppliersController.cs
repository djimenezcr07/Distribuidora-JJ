using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

public sealed class SuppliersController : Controller
{
    private readonly IPurchasingService _purchasing;
    private readonly ILogger<SuppliersController> _logger;

    public SuppliersController(IPurchasingService purchasing, ILogger<SuppliersController> logger)
    {
        _purchasing = purchasing;
        _logger = logger;
    }

    [HttpGet]
    [AdminAuthorize("Compras", "PROVEEDORES_VER")]
    public async Task<IActionResult> Index(bool? soloActivos, string? filtro, CancellationToken cancellationToken)
    {
        return View(await BuildIndexAsync(new SupplierFormViewModel(), soloActivos, filtro, cancellationToken));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "PROVEEDORES_GESTIONAR")]
    public async Task<IActionResult> Save(
        SupplierFormViewModel formulario,
        bool? soloActivos,
        string? filtro,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return View("Index", await BuildIndexAsync(formulario, soloActivos, filtro, cancellationToken));
        }

        try
        {
            await _purchasing.SaveSupplierAsync(formulario, CurrentActor(), cancellationToken);
            TempData["SuccessMessage"] = "Proveedor guardado correctamente.";
            return RedirectToAction(nameof(Index));
        }
        catch (PurchasingOperationException ex)
        {
            _logger.LogWarning(ex, "La operación de proveedor {SupplierId} fue rechazada por una regla de negocio.", formulario.ProveedorId);
            ModelState.AddModelError(string.Empty, ex.UserMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No fue posible guardar el proveedor {SupplierId}.", formulario.ProveedorId);
            ModelState.AddModelError(string.Empty, "No fue posible guardar el proveedor.");
        }

        return View("Index", await BuildIndexAsync(formulario, soloActivos, filtro, cancellationToken));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "PROVEEDORES_GESTIONAR")]
    public async Task<IActionResult> ChangeStatus(int proveedorId, bool activo, CancellationToken cancellationToken)
    {
        if (proveedorId <= 0)
        {
            return BadRequest();
        }

        try
        {
            await _purchasing.SetSupplierStatusAsync(proveedorId, activo, CurrentActor(), cancellationToken);
            TempData["SuccessMessage"] = activo ? "Proveedor reactivado." : "Proveedor desactivado.";
        }
        catch (PurchasingOperationException ex)
        {
            _logger.LogWarning(ex, "El cambio de estado del proveedor {SupplierId} fue rechazado.", proveedorId);
            TempData["ErrorMessage"] = ex.UserMessage;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No fue posible cambiar el estado del proveedor {SupplierId}.", proveedorId);
            TempData["ErrorMessage"] = "No fue posible cambiar el estado del proveedor.";
        }

        return RedirectToAction(nameof(Index));
    }

    private async Task<SuppliersIndexViewModel> BuildIndexAsync(
        SupplierFormViewModel form,
        bool? activeOnly,
        string? search,
        CancellationToken cancellationToken) =>
        new()
        {
            Formulario = form,
            SoloActivos = activeOnly,
            Filtro = search,
            Proveedores = await _purchasing.GetSuppliersAsync(activeOnly, search, cancellationToken)
        };

    private PurchasingActor CurrentActor() => new(
        HttpContext.Session.GetInt32("UserId") ?? 0,
        HttpContext.Session.GetString("UserFullName") ?? "Usuario",
        HttpContext.Session.GetString("UserEmail"),
        HttpContext.Session.GetString("UserRole"),
        HttpContext.Connection.RemoteIpAddress?.ToString(),
        Request.Headers.UserAgent.ToString());
}
