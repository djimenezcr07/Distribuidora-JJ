using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Controllers
{
    public class CartController : Controller
    {
        private const string CartSessionKey = "CartItems";
        private static readonly HashSet<string> PaymentMethods = new(StringComparer.OrdinalIgnoreCase)
        {
            "Efectivo contra entrega",
            "SINPE Móvil simulado",
            "Tarjeta demo",
            "Transferencia simulada"
        };

        private readonly StoreDbService _storeDbService;
        private readonly EmailService _emailService;
        private readonly PromotionsDbService _promotions;
        private readonly IComboDbService _combos;
        private readonly ICrossSellService _crossSell;
        private readonly ILogger<CartController> _logger;

        public CartController(
            StoreDbService storeDbService,
            EmailService emailService,
            PromotionsDbService promotions,
            IComboDbService combos,
            ICrossSellService crossSell,
            ILogger<CartController> logger)
        {
            _storeDbService = storeDbService;
            _emailService = emailService;
            _promotions = promotions;
            _combos = combos;
            _crossSell = crossSell;
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            return View(await BuildCartViewModelAsync());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Add(int productoId, int cantidad = 1)
        {
            var product = await _storeDbService.GetStoreProductByIdAsync(productoId);
            if (product is null)
            {
                return NotFound();
            }
            if (product.Stock <= 0)
            {
                TempData["ErrorMessage"] = $"{product.Nombre} está agotado y no se agregó al carrito.";
                return RedirectToAction(nameof(Index));
            }

            CheckoutAttemptState.NewCart(HttpContext.Session);
            var items = GetCartItems();
            var item = items.FirstOrDefault(x => x.ProductoId == productoId);
            if (item is null)
            {
                items.Add(new CartItemViewModel
                {
                    ItemType = CartItemTypes.Product,
                    ProductoId = product.ProductoId,
                    Nombre = product.Nombre,
                    Categoria = product.Categoria,
                    Descripcion = product.Descripcion,
                    Precio = product.Precio,
                    StockDisponible = product.Stock,
                    Cantidad = CartQuantity.ClampToAvailableStock(cantidad, product.Stock),
                    ImagenUrl = product.ImagenUrl
                });
            }
            else
            {
                item.StockDisponible = product.Stock;
                item.Precio = product.Precio;
                item.Cantidad = CartQuantity.ClampToAvailableStock(item.Cantidad + Math.Max(cantidad, 1), product.Stock);
            }

            SaveCartItems(items);
            TempData["LoginSuccess"] = $"{product.Nombre} fue agregado al carrito.";
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AddCombo(int comboId, int cantidad = 1, CancellationToken cancellationToken = default)
        {
            var combo = await _combos.GetStoreComboAsync(comboId, cancellationToken);
            if (combo is null)
            {
                return NotFound();
            }
            if (!combo.Disponible)
            {
                return UnprocessableEntity(new { message = "El combo no está disponible en este momento." });
            }

            CheckoutAttemptState.NewCart(HttpContext.Session);
            var items = GetCartItems();
            var item = items.FirstOrDefault(candidate =>
                candidate.ItemType == CartItemTypes.Combo && candidate.ComboId == comboId);
            if (item is null)
            {
                items.Add(new CartItemViewModel
                {
                    ItemType = CartItemTypes.Combo,
                    ComboId = combo.ComboId,
                    Nombre = combo.Nombre,
                    Categoria = "Combo",
                    Descripcion = combo.Descripcion,
                    Precio = combo.Precio,
                    StockDisponible = combo.StockDisponible,
                    Cantidad = Math.Min(Math.Max(cantidad, 1), combo.StockDisponible),
                    ImagenUrl = combo.ImagenUrl
                });
            }
            else
            {
                item.StockDisponible = combo.StockDisponible;
                item.Precio = combo.Precio;
                item.Cantidad = Math.Min(item.Cantidad + Math.Max(cantidad, 1), combo.StockDisponible);
            }

            SaveCartItems(items);
            TempData["LoginSuccess"] = $"{combo.Nombre} fue agregado al carrito.";
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Update(
            int productoId,
            int cantidad,
            string? itemType = null,
            int? comboId = null,
            CancellationToken cancellationToken = default)
        {
            var items = GetCartItems();
            var isCombo = string.Equals(itemType, CartItemTypes.Combo, StringComparison.Ordinal);
            var item = items.FirstOrDefault(candidate => isCombo
                ? candidate.ItemType == CartItemTypes.Combo && candidate.ComboId == comboId
                : candidate.ItemType != CartItemTypes.Combo && candidate.ProductoId == productoId);
            if (item is null)
                return RedirectToAction(nameof(Index));

            if (cantidad <= 0)
            {
                items.Remove(item);
            }
            else
            {
                if (isCombo)
                {
                    var combo = comboId.HasValue
                        ? await _combos.GetStoreComboAsync(comboId.Value, cancellationToken)
                        : null;
                    if (combo is null || !combo.Disponible)
                    {
                        items.Remove(item);
                        TempData["ErrorMessage"] = "Un combo del carrito ya no está disponible.";
                    }
                    else
                    {
                        item.StockDisponible = combo.StockDisponible;
                        item.Precio = combo.Precio;
                        item.Cantidad = Math.Min(cantidad, combo.StockDisponible);
                    }
                }
                else
                {
                    var product = await _storeDbService.GetStoreProductByIdAsync(productoId, cancellationToken);
                    if (product is null)
                    {
                        items.Remove(item);
                        TempData["LoginSuccess"] = "Un producto del carrito ya no está disponible.";
                    }
                    else
                    {
                        if (product.Stock <= 0)
                        {
                            items.Remove(item);
                            TempData["ErrorMessage"] = $"{product.Nombre} está agotado y se retiró del carrito.";
                        }
                        else
                        {
                            item.StockDisponible = product.Stock;
                            item.Precio = product.Precio;
                            item.Cantidad = CartQuantity.ClampToAvailableStock(cantidad, product.Stock);
                        }
                    }
                }
            }

            SaveCartItems(items);
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Remove(int productoId, string? itemType = null, int? comboId = null)
        {
            var items = GetCartItems();
            var isCombo = string.Equals(itemType, CartItemTypes.Combo, StringComparison.Ordinal);
            items.RemoveAll(candidate => isCombo
                ? candidate.ItemType == CartItemTypes.Combo && candidate.ComboId == comboId
                : candidate.ItemType != CartItemTypes.Combo && candidate.ProductoId == productoId);
            SaveCartItems(items);
            return RedirectToAction(nameof(Index));
        }

        [HttpGet]
        public async Task<IActionResult> Checkout()
        {
            if (!IsLoggedIn())
            {
                TempData["LoginSuccess"] = "Debes iniciar sesión para finalizar la compra.";
                return RedirectToAction("Login", "Account", new { returnUrl = Url.Action(nameof(Checkout), "Cart") });
            }

            var original = OriginalLoginSession.ValidatedRequest(HttpContext);
            var attempt = CheckoutAttemptState.Get(HttpContext.Session, original);
            if (attempt.Request is not null)
            {
                ViewData["CheckoutRecovery"] = true;
                return View(attempt.Request);
            }
            var cart = await BuildCartViewModelAsync();
            if (cart.Items.Count == 0)
            {
                TempData["LoginSuccess"] = "Tu carrito está vacío.";
                return RedirectToAction(nameof(Index));
            }

            var model = new CheckoutViewModel
            {
                OperationToken = attempt.OperationId,
                Cart = cart,
                CorreoElectronico = HttpContext.Session.GetString("UserEmail"),
                TipoEntrega = "Envío a domicilio",
                MetodoPago = "Efectivo contra entrega"
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Checkout(CheckoutViewModel model)
        {
            if (!IsLoggedIn())
                return RedirectToAction("Login", "Account", new { returnUrl = Url.Action(nameof(Checkout), "Cart") });
            var original = OriginalLoginSession.ValidatedRequest(HttpContext);
            var attempt = CheckoutAttemptState.Get(HttpContext.Session, original);
            model.Cart = attempt.Request?.Cart ?? await BuildCartViewModelAsync();
            model.TipoEntrega = "Envío a domicilio";
            model.Identificacion = CostaRicanIdentificationAttribute.Normalize(model.Identificacion);

            model.MetodoPago = string.IsNullOrWhiteSpace(model.MetodoPago)
                ? "Efectivo contra entrega"
                : model.MetodoPago.Trim();

            model.ReferenciaPago = string.IsNullOrWhiteSpace(model.ReferenciaPago)
                ? null
                : model.ReferenciaPago.Trim();

            if (!IsLoggedIn())
            {
                TempData["LoginSuccess"] =
                    "Debes iniciar sesión para finalizar la compra.";

                return RedirectToAction(
                    "Login",
                    "Account",
                    new
                    {
                        returnUrl = Url.Action(nameof(Checkout), "Cart")
                    });
            }

            if (model.Cart.Items.Count == 0)
            {
                TempData["LoginSuccess"] = "Tu carrito está vacío.";
                return RedirectToAction(nameof(Index));
            }

            if (string.IsNullOrWhiteSpace(model.Provincia))
            {
                ModelState.AddModelError(
                    nameof(model.Provincia),
                    "La provincia es obligatoria.");
            }

            if (string.IsNullOrWhiteSpace(model.Canton))
            {
                ModelState.AddModelError(
                    nameof(model.Canton),
                    "El cantón es obligatorio.");
            }

            if (string.IsNullOrWhiteSpace(model.Distrito))
            {
                ModelState.AddModelError(
                    nameof(model.Distrito),
                    "El distrito es obligatorio.");
            }

            if (string.IsNullOrWhiteSpace(model.DireccionDetalle))
            {
                ModelState.AddModelError(
                    nameof(model.DireccionDetalle),
                    "La dirección es obligatoria.");
            }

            if (string.IsNullOrWhiteSpace(model.Identificacion))
            {
                ModelState.AddModelError(
                    nameof(model.Identificacion),
                    "La identificación es obligatoria.");
            }

            if (!PaymentMethods.Contains(model.MetodoPago))
            {
                ModelState.AddModelError(
                    nameof(model.MetodoPago),
                    "Seleccione un método de pago válido.");
            }

            model.CorreoElectronico = HttpContext.Session.GetString("UserEmail");

            if (string.IsNullOrWhiteSpace(model.CorreoElectronico))
            {
                ModelState.AddModelError(
                    nameof(model.CorreoElectronico),
                    "No se encontró un correo electrónico para enviar el comprobante.");
            }

            model.DireccionEntrega =
                $"{model.Pais}, {model.Provincia}, {model.Canton}, " +
                $"{model.Distrito}. {model.DireccionDetalle}";

            if (model.OperationToken == Guid.Empty)
            {
                ModelState.AddModelError(string.Empty, "El intento de compra expiró. Recargue el checkout e intente nuevamente.");
            }

            if (!ModelState.IsValid)
            {
                return InvalidCheckout(model);
            }

            try
            {
                var usuarioId =
                    HttpContext.Session.GetInt32("UserId") ?? 0;

                var frozen = CheckoutAttemptState.Freeze(HttpContext.Session, original, model, model.Cart.Items);
                var order = await _storeDbService.CreateOrderWithPromotionsAsync(
                    usuarioId,
                    model,
                    frozen.Items!,
                    original,
                    HttpContext.RequestAborted);

                var confirmedItems = order.Items.Concat(order.Gifts).ToList();

                var confirmacion = new OrderConfirmationViewModel
                {
                    OwnerLoginId = original.LoginId,
                    OwnerUserId = original.UserId,
                    PedidoId = order.PedidoId,
                    TipoEntrega = model.TipoEntrega,
                    DireccionEntrega = model.DireccionEntrega,
                    Total = order.Total,
                    Amounts = order.Amounts,
                    Items = confirmedItems
                };

                var destinatario =
                    model.CorreoElectronico
                    ?? HttpContext.Session.GetString("UserEmail")
                    ?? string.Empty;

                var cliente =
                    HttpContext.Session.GetString("UserFullName")
                    ?? "Cliente";

                if (!order.IsReplay)
                {
                try
                {
                    _emailService.SendOrderReceipt(
                        destinatario,
                        cliente,
                        order.PedidoId,
                        model,
                        confirmedItems,
                        order.Total,
                        confirmedItems.Sum(item => item.MontoDescuento));
                }
                catch (Exception exception)
                {
                    // El pedido ya fue confirmado de forma atómica en SQL. SMTP es un efecto
                    // secundario y no debe convertir una compra confirmada en un aparente fallo.
                    _logger.LogWarning(exception, "No fue posible enviar el comprobante del pedido {PedidoId}.", order.PedidoId);
                    TempData["ErrorMessage"] = "El pedido fue confirmado, pero no fue posible enviar el comprobante por correo.";
                }

                }
                CheckoutAttemptState.Complete(HttpContext.Session, frozen);
                HttpContext.Session.Remove(CartSessionKey);

                TempData["OrderConfirmation"] =
                    JsonSerializer.Serialize(confirmacion);

                TempData["LoginSuccess"] =
                    $"Pedido #{order.PedidoId} creado correctamente.";

                return RedirectToAction(nameof(Confirmation));
            }
            catch (CheckoutPricingMismatchException)
            {
                ModelState.AddModelError(string.Empty, "No se confirmó la compra porque el cálculo de precios requiere reconciliación. No se descontaron existencias.");
                return InvalidCheckout(model);
            }
            catch (CommercialAssignmentsUnavailableException)
            {
                ModelState.AddModelError(string.Empty, "Este importe requiere aprobación supervisora. Esa operación no está habilitada; no se registró la compra.");
                return InvalidCheckout(model);
            }
            catch (CheckoutAttemptConflictException)
            {
                ModelState.AddModelError(string.Empty, "Hay un intento pendiente con otros datos. Volvé a abrir el checkout para recuperar el original.");
                return InvalidCheckout(model);
            }
            catch (SqlException ex)                when (ex.Number is 51106 or 51107 or 53101 or 54615 or 54616)
            {
                _logger.LogWarning(ex, "El checkout fue rechazado por falta de inventario para el usuario {UserId}.", HttpContext.Session.GetInt32("UserId"));
                ModelState.AddModelError(
                    string.Empty,
                    "No hay stock suficiente para completar el pedido. " +
                    "Revise el carrito e intente nuevamente.");

                return InvalidCheckout(model);
            }
            catch (Exception exception)
            {
                return ServiceUnavailable(exception);
            }
        }

        [HttpGet]
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public IActionResult Confirmation()
        {
            if (TempData["OrderConfirmation"] is not string raw || string.IsNullOrWhiteSpace(raw))
                return RedirectToAction(nameof(Index));

            OrderConfirmationViewModel? model;
            try { model = JsonSerializer.Deserialize<OrderConfirmationViewModel>(raw); }
            catch (JsonException) { return RedirectToAction(nameof(Index)); }
            if (model is null || model.PedidoId <= 0
                || HttpContext.Items[OriginalLoginSession.ValidatedContextItem] is not OriginalLoginContext login
                || !login.HasCanonicalLifetime || model.OwnerLoginId != login.LoginId || model.OwnerUserId != login.UserId)
                return RedirectToAction(nameof(Index));
            return View(model);
        }

        private bool IsLoggedIn() => !string.IsNullOrWhiteSpace(HttpContext.Session.GetString("UserEmail"));

        private ViewResult InvalidCheckout(CheckoutViewModel model)
        {
            Response.StatusCode = StatusCodes.Status422UnprocessableEntity;
            return View(model);
        }

        private ViewResult ServiceUnavailable(Exception exception)
        {
            var traceId = HttpContext.TraceIdentifier;
            _logger.LogError(exception, "Falla técnica durante checkout para usuario {UserId}. TraceId {TraceId}", HttpContext.Session.GetInt32("UserId"), traceId);
            Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            ViewData["TraceId"] = traceId;
            return View("ServiceUnavailable");
        }

        // CU-173 — arma el carrito y aplica automáticamente las promociones vigentes.
        private async Task<CartViewModel> BuildCartViewModelAsync()
        {
            var items = await RefreshCartItemsAsync(GetCartItems());
            SaveCartItems(items);
            var cart = new CartViewModel { Items = items };
            if (items.Count == 0) return cart;

            // Mejor esfuerzo: si el motor de promociones falla, se muestra el carrito sin promociones.
            try
            {
                var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
                var segmento = await _storeDbService.GetUserSegmentAsync(usuarioId, HttpContext.RequestAborted);
                var snapshot = await _promotions.GetActivePromotionSnapshotAsync(segmento, HttpContext.RequestAborted);
                var resultado = PromotionEngine.Apply(
                    cart.Items.Where(item => item.ItemType == CartItemTypes.Product).ToList(),
                    snapshot.Promotions, segmento, snapshot.EvaluationDate);
                cart.Regalias = resultado.Gifts;
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No fue posible calcular las promociones para presentar el carrito.");
                foreach (var it in cart.Items) { it.MontoDescuento = 0; it.PromocionNombre = null; }
                cart.Regalias.Clear();
            }

            try
            {
                var productIds = cart.Items
                    .Where(item => item.ItemType == CartItemTypes.Product && item.ProductoId > 0)
                    .Select(item => item.ProductoId)
                    .ToHashSet();
                cart.Recomendaciones = await _crossSell.GetSuggestionsAsync(
                    HttpContext.Session.GetInt32("UserId"), productIds, HttpContext.RequestAborted);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No fue posible calcular recomendaciones de venta cruzada.");
                cart.Recomendaciones = [];
            }
            return cart;
        }

        private async Task<List<CartItemViewModel>> RefreshCartItemsAsync(List<CartItemViewModel> items)
        {
            var refreshed = new List<CartItemViewModel>();
            foreach (var item in items.Where(item => item.Cantidad > 0))
            {
                if (item.ItemType == CartItemTypes.Combo && item.ComboId.HasValue)
                {
                    var combo = await _combos.GetStoreComboAsync(item.ComboId.Value, HttpContext.RequestAborted);
                    if (combo is null || !combo.Disponible)
                    {
                        continue;
                    }

                    refreshed.Add(new CartItemViewModel
                    {
                        ItemType = CartItemTypes.Combo,
                        ComboId = combo.ComboId,
                        Nombre = combo.Nombre,
                        Categoria = "Combo",
                        Descripcion = combo.Descripcion,
                        Precio = combo.Precio,
                        StockDisponible = combo.StockDisponible,
                        Cantidad = Math.Min(item.Cantidad, combo.StockDisponible),
                        ImagenUrl = combo.ImagenUrl
                    });
                    continue;
                }

                if (item.ProductoId <= 0)
                {
                    continue;
                }

                var product = await _storeDbService.GetStoreProductByIdAsync(item.ProductoId, HttpContext.RequestAborted);
                if (product is null || product.Stock <= 0) continue;
                refreshed.Add(new CartItemViewModel
                {
                    ItemType = CartItemTypes.Product,
                    ProductoId = product.ProductoId,
                    Nombre = product.Nombre,
                    Categoria = product.Categoria,
                    Descripcion = product.Descripcion,
                    Precio = product.Precio,
                    StockDisponible = product.Stock,
                    Cantidad = Math.Min(item.Cantidad, product.Stock),
                    ImagenUrl = product.ImagenUrl
                });
            }
            return refreshed;
        }

        private List<CartItemViewModel> GetCartItems()
        {
            var json = HttpContext.Session.GetString(CartSessionKey);
            if (string.IsNullOrWhiteSpace(json))
                return new List<CartItemViewModel>();

            return JsonSerializer.Deserialize<List<CartItemViewModel>>(json) ?? new List<CartItemViewModel>();
        }

        private void SaveCartItems(List<CartItemViewModel> items)
        {
            HttpContext.Session.SetString(CartSessionKey, JsonSerializer.Serialize(items));
        }
    }

    internal static class CartQuantity
    {
        internal static int ClampToAvailableStock(int requested, int availableStock) =>
            availableStock <= 0 ? 0 : Math.Min(Math.Max(requested, 1), availableStock);
    }
}

