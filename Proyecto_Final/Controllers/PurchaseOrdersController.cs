using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

public sealed class PurchaseOrdersController : Controller
{
    private readonly IPurchasingService _purchasing;
    private readonly AdminDbService _admin;
    private readonly ILogger<PurchaseOrdersController> _logger;

    public PurchaseOrdersController(
        IPurchasingService purchasing,
        AdminDbService admin,
        ILogger<PurchaseOrdersController> logger)
    {
        _purchasing = purchasing;
        _admin = admin;
        _logger = logger;
    }

    [HttpGet]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_VER")]
    public async Task<IActionResult> Index(string? estado, int? proveedorId, CancellationToken cancellationToken)
    {
        ViewBag.Estado = estado;
        ViewBag.ProveedorId = proveedorId;
        ViewBag.Proveedores = await _purchasing.GetSuppliersAsync(true, null, cancellationToken);
        var orders = await _purchasing.GetPurchaseOrdersAsync(estado, proveedorId, cancellationToken);
        return View(orders);
    }

    [HttpGet]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_CREAR")]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        var model = new PurchaseOrderFormViewModel();
        await PopulateOptionsAsync(model, cancellationToken);
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequestFormLimits(ValueCountLimit = 512)]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_CREAR")]
    public async Task<IActionResult> Create(PurchaseOrderFormViewModel model, CancellationToken cancellationToken)
    {
        if (model.TokenOperacion == Guid.Empty)
        {
            ModelState.AddModelError(string.Empty, "La solicitud no contiene un token de operación válido.");
        }

        if (!ModelState.IsValid)
        {
            await PopulateOptionsAsync(model, cancellationToken);
            return View(model);
        }

        try
        {
            var orderId = await _purchasing.CreatePurchaseOrderAsync(model, CurrentActor(), cancellationToken);
            TempData["SuccessMessage"] = "Orden de compra creada correctamente.";
            return RedirectToAction(nameof(Detail), new { id = orderId });
        }
        catch (PurchasingOperationException ex)
        {
            _logger.LogWarning(ex, "La creación de la orden de compra fue rechazada por una regla de negocio.");
            ModelState.AddModelError(string.Empty, ex.UserMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No fue posible crear la orden de compra.");
            ModelState.AddModelError(string.Empty, "No fue posible crear la orden de compra.");
        }

        await PopulateOptionsAsync(model, cancellationToken);
        return View(model);
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    [AdminAuthorize("Compras", "COMPRAS_SUGERENCIAS_VER")]
    public async Task<IActionResult> Suggestions(CancellationToken cancellationToken)
    {
        var suggestions = (await _purchasing.GetPurchaseSuggestionsAsync(3, 1, cancellationToken)).ToList();
        var model = new PurchaseOrderFormViewModel { Productos = suggestions };
        await PopulateOptionsAsync(model, cancellationToken);
        ViewData["FromSuggestions"] = true;
        return View("Create", model);
    }

    [HttpGet]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_VER")]
    public async Task<IActionResult> Detail(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return NotFound();
        }

        var detail = await _purchasing.GetPurchaseOrderDetailAsync(id, cancellationToken);
        return detail is null ? NotFound() : View(detail);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_RECIBIR")]
    public async Task<IActionResult> Receive(PurchaseOrderReceiveViewModel model, CancellationToken cancellationToken)
    {
        if (model.TokenOperacion == Guid.Empty)
        {
            ModelState.AddModelError(string.Empty, "Token de recepción inválido.");
        }

        if (!ModelState.IsValid)
        {
            return UnprocessableEntity(new { message = "Los datos de la recepción no son válidos." });
        }

        try
        {
            await _purchasing.ReceivePurchaseOrderLineAsync(model, CurrentActor(), cancellationToken);
            TempData["SuccessMessage"] = "Recepción registrada e inventario actualizado.";
        }
        catch (PurchasingOperationException ex)
        {
            _logger.LogWarning(ex, "La recepción de la orden {PurchaseOrderId} fue rechazada.", model.OrdenCompraId);
            TempData["ErrorMessage"] = ex.UserMessage;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No fue posible recibir la línea {PurchaseOrderLineId}.", model.DetalleOrdenCompraId);
            TempData["ErrorMessage"] = "No fue posible registrar la recepción.";
        }

        return RedirectToAction(nameof(Detail), new { id = model.OrdenCompraId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_CERRAR")]
    public Task<IActionResult> CloseWithDiscrepancy(PurchaseOrderCloseViewModel model, CancellationToken cancellationToken) =>
        CompleteOrderAsync(model, cancel: false, cancellationToken);

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Compras", "COMPRAS_ORDENES_CANCELAR")]
    public Task<IActionResult> Cancel(PurchaseOrderCloseViewModel model, CancellationToken cancellationToken) =>
        CompleteOrderAsync(model, cancel: true, cancellationToken);

    private async Task<IActionResult> CompleteOrderAsync(
        PurchaseOrderCloseViewModel model,
        bool cancel,
        CancellationToken cancellationToken)
    {
        if (model.TokenOperacion == Guid.Empty)
        {
            ModelState.AddModelError(string.Empty, "Token de operación inválido.");
        }

        if (!ModelState.IsValid)
        {
            return UnprocessableEntity(new { message = "Debe indicar un motivo de al menos diez caracteres." });
        }

        try
        {
            if (cancel)
            {
                await _purchasing.CancelPurchaseOrderAsync(model, CurrentActor(), cancellationToken);
            }
            else
            {
                await _purchasing.CloseWithDiscrepancyAsync(model, CurrentActor(), cancellationToken);
            }

            TempData["SuccessMessage"] = cancel
                ? "Orden cancelada sin alterar inventario."
                : "Orden cerrada con faltantes documentados.";
        }
        catch (PurchasingOperationException ex)
        {
            _logger.LogWarning(ex, "La operación sobre la orden {PurchaseOrderId} fue rechazada.", model.OrdenCompraId);
            TempData["ErrorMessage"] = ex.UserMessage;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No fue posible completar la operación sobre la orden {PurchaseOrderId}.", model.OrdenCompraId);
            TempData["ErrorMessage"] = "No fue posible actualizar la orden.";
        }

        return RedirectToAction(nameof(Detail), new { id = model.OrdenCompraId });
    }

    private async Task PopulateOptionsAsync(PurchaseOrderFormViewModel model, CancellationToken cancellationToken)
    {
        model.Proveedores = await _purchasing.GetSuppliersAsync(true, null, cancellationToken);
        var posted = model.Productos
            .Where(product => product.Seleccionado)
            .Where(product => product.ProductoId > 0)
            .GroupBy(product => product.ProductoId)
            .ToDictionary(group => group.Key, group => group.First());
        var products = await _admin.GetActiveProductsForSelectAsync();
        var lastPrices = await _purchasing.GetLastPurchasePricesAsync(cancellationToken);

        var catalog = products.Select(product =>
        {
            return new PurchaseOrderLineSelectionViewModel
            {
                ProductoId = product.ProductoId,
                Nombre = product.Nombre,
                StockActual = product.Stock,
                PrecioTienda = product.Precio,
                UltimoPrecioPagado = lastPrices.TryGetValue(product.ProductoId, out var lastPrice) ? lastPrice : null,
                Cantidad = 1,
                PrecioUnitario = 1m
            };
        }).ToList();

        var catalogById = catalog.ToDictionary(product => product.ProductoId);
        model.Productos = posted.Values
            .Where(product => catalogById.ContainsKey(product.ProductoId))
            .Select(previous =>
            {
                var authoritative = catalogById[previous.ProductoId];
                authoritative.PromedioVentaMensual = previous.PromedioVentaMensual;
                authoritative.DatosInsuficientes = previous.DatosInsuficientes;
                authoritative.Seleccionado = true;
                authoritative.Cantidad = previous.Cantidad;
                authoritative.PrecioUnitario = previous.PrecioUnitario;
                return authoritative;
            })
            .ToList();
        ViewBag.ProductCatalog = catalog;
    }

    private PurchasingActor CurrentActor() => new(
        HttpContext.Session.GetInt32("UserId") ?? 0,
        HttpContext.Session.GetString("UserFullName") ?? "Usuario",
        HttpContext.Session.GetString("UserEmail"),
        HttpContext.Session.GetString("UserRole"),
        HttpContext.Connection.RemoteIpAddress?.ToString(),
        Request.Headers.UserAgent.ToString());
}
