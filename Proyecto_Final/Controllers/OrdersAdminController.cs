using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Pedidos")]
    public class OrdersAdminController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<OrdersAdminController> _logger;

        public OrdersAdminController(AdminDbService adminDbService, ILogger<OrdersAdminController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado)
        {
            ViewBag.Estado = estado;

            var pedidos = await _adminDbService.GetOrdersAsync(estado);
            return View(pedidos);
        }

        [HttpGet]
        public async Task<IActionResult> Detail(int id)
        {
            var pedido = await _adminDbService.GetOrderDetailAsync(id);

            if (pedido == null)
            {
                TempData["ErrorMessage"] = "No se encontró el pedido solicitado.";
                return RedirectToAction(nameof(Index));
            }

            pedido.FacturaId = await _adminDbService.GetInvoiceIdByOrderAsync(id);
            pedido.HasInvoice = pedido.FacturaId.HasValue;

            return View(pedido);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Pedidos", "PEDIDOS_CAMBIAR_ESTADO", false)]
        public async Task<IActionResult> UpdateStatus(int pedidoId, string nuevoEstado)
        {
            if (pedidoId <= 0 || string.IsNullOrWhiteSpace(nuevoEstado))
            {
                TempData["ErrorMessage"] = "La solicitud para actualizar el estado no es válida.";
                return RedirectToAction(nameof(Index));
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                await _adminDbService.UpdateOrderStatusAsync(pedidoId, nuevoEstado.Trim(), usuarioId, usuarioNombre, OriginalLoginSession.ValidatedRequest(HttpContext));

                // The SQL workflow commits the state and canonical audit together.

                TempData["SuccessMessage"] = "Estado del pedido actualizado correctamente.";
            }
            catch (Exception exception)
            {
                _logger.LogWarning("Operación rechazada. Tipo {ExceptionType}; código SQL {SqlError}.", exception.GetType().Name, exception is Microsoft.Data.SqlClient.SqlException sql ? sql.Number : (int?)null);
                TempData["ErrorMessage"] = "No fue posible actualizar el estado del pedido en este momento. Intente nuevamente.";
            }

            return RedirectToAction(nameof(Detail), new { id = pedidoId });
        }

    }
}
