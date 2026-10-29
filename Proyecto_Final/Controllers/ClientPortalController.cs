using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [SessionAuthorize("Cliente")]
    public class ClientPortalController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<ClientPortalController> _logger;

        public ClientPortalController(AdminDbService adminDbService, ILogger<ClientPortalController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;

            var cliente = await _adminDbService
                .GetClientDetailAsync(usuarioId);

            if (cliente == null)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar la información del cliente.";

                return RedirectToAction("Index", "Home");
            }

            var model = new ClientPortalIndexViewModel
            {
                Cliente = MapClientSummary(cliente),

                Credito = await TryGetCreditSummaryAsync(usuarioId),

                Pedidos = cliente.Pedidos
                    .Select(MapOrderListItem)
                    .ToList()
            };

            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Statement()
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;

            var cliente = await _adminDbService
                .GetClientDetailAsync(usuarioId);

            if (cliente == null)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el estado de cuenta.";

                return RedirectToAction(nameof(Index));
            }

            var model = new ClientPortalStatementViewModel
            {
                Cliente = MapClientSummary(cliente),

                Credito = await TryGetCreditSummaryAsync(usuarioId),

                Pedidos = cliente.Pedidos
                    .Select(MapOrderListItem)
                    .ToList()
            };

            await RegistrarAuditoriaAsync(
                "Descargar estado de cuenta",
                "Portal cliente",
                $"El cliente {model.Cliente.NombreCompleto} descargó su estado de cuenta."
            );

            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Detail(int id)
        {
            if (id <= 0)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el pedido solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            var pedido = await _adminDbService
                .GetOrderDetailAsync(id);

            if (pedido == null || pedido.UsuarioId != usuarioId)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el pedido solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var hasInvoice = await _adminDbService
                .OrderHasInvoiceAsync(id);

            var model = MapOrderDetail(pedido, hasInvoice);
            var eligibleLines = await _adminDbService.GetWarrantyEligibleLineIdsAsync(id, usuarioId);
            foreach (var line in model.Lineas)
                line.CanRequestWarranty = eligibleLines.Contains(line.PedidoDetalleId);
            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Invoice(int id)
        {
            if (id <= 0)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el comprobante solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            try
            {
                var comprobante = await _adminDbService
                    .GetClientInvoiceByOrderAsync(id, usuarioId);

                if (comprobante == null)
                {
                    TempData["ErrorMessage"] =
                        "No fue posible cargar el comprobante solicitado.";

                    return RedirectToAction(nameof(Index));
                }

                return View(comprobante);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No se pudo cargar el comprobante del portal del cliente.");
                TempData["ErrorMessage"] =
                    "No fue posible cargar el comprobante en este momento. Intente nuevamente.";

                return RedirectToAction(nameof(Index));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Cancel(int id)
        {
            if (id <= 0)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cancelar el pedido solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            try
            {
                var cancelled = await _adminDbService
                    .CancelClientPendingOrderAsync(id, usuarioId);

                if (!cancelled)
                {
                    TempData["ErrorMessage"] =
                        "No fue posible cancelar el pedido solicitado.";

                    return RedirectToAction(
                        nameof(Detail),
                        new { id }
                    );
                }

                await RegistrarAuditoriaAsync(
                    "Cancelar pedido",
                    "Portal cliente",
                    $"El cliente canceló el pedido #{id} desde el portal."
                );

                TempData["SuccessMessage"] =
                    "Pedido cancelado correctamente.";
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No se pudo cancelar un pedido desde el portal del cliente.");
                TempData["ErrorMessage"] =
                    "No fue posible cancelar el pedido en este momento. Intente nuevamente.";
            }

            return RedirectToAction(
                nameof(Detail),
                new { id }
            );
        }

        // Abre el formulario para solicitar una garantía.
        [HttpGet]
        public async Task<IActionResult> Warranty(int id)
        {
            if (id <= 0)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el producto solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            var detalle = await _adminDbService
                .GetOrderDetailLineAsync(id);

            if (detalle == null ||
                detalle.UsuarioId != usuarioId || !detalle.CanRequestWarranty)
            {
                TempData["ErrorMessage"] =
                    "No fue posible cargar el producto solicitado.";

                return RedirectToAction(nameof(Index));
            }

            var model = new WarrantyRequestFormViewModel
            {
                PedidoDetalleId = detalle.PedidoDetalleId,
                PedidoId = detalle.PedidoId,
                Producto = detalle.Producto
            };

            return View(model);
        }

        // Guarda la solicitud de garantía.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Warranty(
            WarrantyRequestFormViewModel model)
        {
            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            /*
             * Se consulta nuevamente el detalle para evitar que
             * el cliente modifique el PedidoDetalleId desde el HTML.
             */
            var detalle = await _adminDbService
                .GetOrderDetailLineAsync(model.PedidoDetalleId);

            if (detalle == null ||
                detalle.UsuarioId != usuarioId || !detalle.CanRequestWarranty)
            {
                TempData["ErrorMessage"] =
                    "El producto seleccionado no pertenece a su cuenta.";

                return RedirectToAction(nameof(Index));
            }

            // Usamos los datos reales de la base de datos.
            model.PedidoDetalleId = detalle.PedidoDetalleId;
            model.PedidoId = detalle.PedidoId;
            model.Producto = detalle.Producto;

            if (!ModelState.IsValid)
            {
                return View(model);
            }

            try
            {
                if (!Guid.TryParse(HttpContext.Session.GetString("SecurityStamp"), out var stamp) || stamp == Guid.Empty)
                    return Unauthorized();
                var creado = await _adminDbService
                    .CreateWarrantyRequestAsync(
                        model.PedidoDetalleId,
                        usuarioId,
                        model.Motivo,
                        model.Descripcion,
                        OriginalLoginSession.ValidatedRequest(HttpContext)
                    );

                if (!creado)
                {
                    ModelState.AddModelError(
                        string.Empty,
                        "No fue posible registrar la solicitud de garantía."
                    );

                    return View(model);
                }

                // Creation and canonical audit are committed together by SQL.

                TempData["SuccessMessage"] =
                    "Solicitud de garantía registrada correctamente.";

                return RedirectToAction(
                    nameof(Detail),
                    new { id = model.PedidoId }
                );
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No se pudo crear la solicitud de garantía del usuario {UserId}.", usuarioId);
                ModelState.AddModelError(
                    string.Empty,
                    "No fue posible registrar la solicitud de garantía en este momento."
                );

                return View(model);
            }
        }

        // Muestra las garantías solicitadas por el cliente.
        [HttpGet]
        public async Task<IActionResult> Warranties()
        {
            var usuarioId =
                HttpContext.Session.GetInt32("UserId") ?? 0;

            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            try
            {
                var solicitudes = await _adminDbService
                    .GetClientWarrantyRequestsAsync(usuarioId);

                return View(solicitudes);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No se pudieron cargar las garantías del usuario {UserId}.", usuarioId);
                TempData["ErrorMessage"] =
                    "No fue posible cargar las solicitudes de garantía.";

                return RedirectToAction(nameof(Index));
            }
        }

        private async Task<ClientPortalCreditSummaryViewModel?>
            TryGetCreditSummaryAsync(int usuarioId)
        {
            try
            {
                var credito = await _adminDbService
                    .GetClientCreditDetailAsync(usuarioId);

                if (credito == null)
                {
                    return null;
                }

                return new ClientPortalCreditSummaryViewModel
                {
                    LimiteCredito = credito.LimiteCredito,
                    CreditoActivo = credito.CreditoActivo,
                    CreditoBloqueado = credito.CreditoBloqueado,
                    DeudaActual = credito.DeudaActual,
                    CreditoDisponible = credito.CreditoDisponible,
                    FechaActualizacion = credito.FechaActualizacion
                };
            }
            catch (InvalidOperationException)
            {
                return null;
            }
        }

        private static ClientPortalSummaryViewModel
            MapClientSummary(ClientDetailViewModel cliente)
        {
            return new ClientPortalSummaryViewModel
            {
                UsuarioId = cliente.UsuarioId,
                NombreCompleto = cliente.NombreCompleto,
                Correo = cliente.Correo,
                Telefono = cliente.Telefono,
                Direccion = cliente.Direccion,
                Activo = cliente.Activo,
                FechaRegistro = cliente.FechaRegistro,
                TotalPedidos = cliente.TotalPedidos,
                TotalComprado = cliente.TotalComprado,
                UltimoPedido = cliente.UltimoPedido
            };
        }

        private static ClientPortalOrderListItemViewModel
            MapOrderListItem(ClientOrderSummaryViewModel pedido)
        {
            return new ClientPortalOrderListItemViewModel
            {
                PedidoId = pedido.PedidoId,
                FechaPedido = pedido.FechaPedido,
                Estado = pedido.Estado,
                TipoEntrega = pedido.TipoEntrega,
                DireccionEntrega = pedido.DireccionEntrega,
                Total = pedido.Total,
                Observaciones = pedido.Observaciones
            };
        }

        private async Task RegistrarAuditoriaAsync(
            string accion,
            string modulo,
            string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                HttpContext.Session.GetInt32("UserId"),
                HttpContext.Session.GetString("UserFullName"),
                HttpContext.Session.GetString("UserEmail"),
                HttpContext.Session.GetString("UserRole"),
                accion,
                modulo,
                descripcion,
                HttpContext.Connection
                    .RemoteIpAddress?
                    .ToString(),
                Request.Headers.UserAgent.ToString()
            );
        }

        private static ClientPortalOrderDetailViewModel
            MapOrderDetail(
                OrderDetailViewModel pedido,
                bool hasInvoice)
        {
            var canCancel =
                string.Equals(
                    pedido.Estado,
                    "Pendiente",
                    StringComparison.OrdinalIgnoreCase
                )
                && !hasInvoice;

            return new ClientPortalOrderDetailViewModel
            {
                PedidoId = pedido.PedidoId,
                FechaPedido = pedido.FechaPedido,
                Estado = pedido.Estado,
                TipoEntrega = pedido.TipoEntrega,
                DireccionEntrega = pedido.DireccionEntrega,
                Total = pedido.Total,
                Observaciones = pedido.Observaciones,
                HasInvoice = hasInvoice,
                CanCancel = canCancel,

                CancelStatusMessage = canCancel
                    ? "Puede cancelar este pedido mientras permanezca pendiente y sin factura asociada."
                    : "Este pedido no permite cancelación desde el portal.",

                Lineas = pedido.Detalles
                    .Select(linea =>
                        new ClientPortalOrderLineViewModel
                        {
                            PedidoDetalleId =
                                linea.PedidoDetalleId,

                            Producto = linea.Producto,
                            Cantidad = linea.Cantidad,
                            PrecioUnitario = linea.PrecioUnitario,
                            Subtotal = linea.Subtotal,
                            IsCombo = linea.IsCombo
                        })
                    .ToList()
            };
        }
    }
}
