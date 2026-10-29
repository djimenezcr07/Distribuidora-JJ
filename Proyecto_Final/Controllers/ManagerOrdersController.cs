using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Pedidos", "PEDIDOS_AUTORIZAR_RECHAZAR", allowAdministratorBypass: false)]
    [CommercialAssignmentsRequired]
    public class ManagerOrdersController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<ManagerOrdersController> _logger;

        public ManagerOrdersController(AdminDbService adminDbService, ILogger<ManagerOrdersController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? buscar)
        {
            ViewBag.Buscar = buscar;
            var pedidos = await _adminDbService.GetRetainedOrdersAsync(buscar);
            return View(pedidos);
        }

        [HttpGet]
        public async Task<IActionResult> Review(int id)
        {
            var pedido = await _adminDbService.GetOrderDetailAsync(id);

            if (pedido == null)
            {
                TempData["ErrorMessage"] = "No se encontró el pedido solicitado.";
                return RedirectToAction(nameof(Index));
            }

            if (pedido.Estado != "Retenido")
            {
                TempData["ErrorMessage"] = "Solo se pueden revisar pedidos en estado Retenido.";
                return RedirectToAction(nameof(Index));
            }

            var vm = new ManagerOrderReviewViewModel
            {
                Pedido       = pedido,
                RechazarForm = new ManagerRejectOrderViewModel { PedidoId = id }
            };

            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Approve(int pedidoId)
        {
            if (pedidoId <= 0)
            {
                TempData["ErrorMessage"] = "La solicitud de aprobación no es válida.";
                return RedirectToAction(nameof(Index));
            }

            var usuarioId     = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Gerente";

            try
            {
                var result = await _adminDbService.ApproveRetainedOrderAsync(pedidoId, usuarioId, usuarioNombre);

                await RegistrarAuditoriaAsync(
                    "Aprobar pedido retenido",
                    "Pedidos",
                    $"{usuarioNombre} aprobó el pedido #{pedidoId}. Factura generada: {result.NumeroFactura}.");

                TempData["Confirm_PedidoId"]      = result.PedidoId;
                TempData["Confirm_NumeroFactura"]  = result.NumeroFactura;
                return RedirectToAction(nameof(ApproveConfirmation));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo aprobar el pedido retenido {OrderId}.", pedidoId);
                TempData["ErrorMessage"] = "No fue posible aprobar el pedido en este momento.";
                return RedirectToAction(nameof(Review), new { id = pedidoId });
            }
        }

        [HttpGet]
        public IActionResult ApproveConfirmation()
        {
            var pedidoId      = TempData["Confirm_PedidoId"]     as int?    ?? 0;
            var numeroFactura = TempData["Confirm_NumeroFactura"] as string  ?? string.Empty;

            if (pedidoId <= 0)
                return RedirectToAction(nameof(Index));

            var vm = new ManagerApproveResultViewModel
            {
                PedidoId      = pedidoId,
                Estado        = "Facturado",
                NumeroFactura = numeroFactura
            };

            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reject([Bind(Prefix = "RechazarForm")] ManagerRejectOrderViewModel model)
        {
            if (!ModelState.IsValid)
            {
                var pedido = await _adminDbService.GetOrderDetailAsync(model.PedidoId);
                if (pedido == null) return RedirectToAction(nameof(Index));

                var vm = new ManagerOrderReviewViewModel { Pedido = pedido, RechazarForm = model };
                return View("Review", vm);
            }

            var usuarioId     = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Gerente";

            try
            {
                await _adminDbService.RejectRetainedOrderAsync(
                    model.PedidoId, model.MotivoRechazo, usuarioId, usuarioNombre);

                await RegistrarAuditoriaAsync(
                    "Rechazar pedido retenido",
                    "Pedidos",
                    $"{usuarioNombre} rechazó el pedido #{model.PedidoId}. Motivo: {model.MotivoRechazo}.");

                TempData["SuccessMessage"] = $"Pedido #{model.PedidoId} rechazado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo rechazar el pedido retenido {OrderId}.", model.PedidoId);
                TempData["ErrorMessage"] = "No fue posible rechazar el pedido en este momento.";
                return RedirectToAction(nameof(Review), new { id = model.PedidoId });
            }
        }

        private async Task RegistrarAuditoriaAsync(string accion, string modulo, string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                HttpContext.Session.GetInt32("UserId"),
                HttpContext.Session.GetString("UserFullName"),
                HttpContext.Session.GetString("UserEmail"),
                HttpContext.Session.GetString("UserRole"),
                accion, modulo, descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }
    }
}
