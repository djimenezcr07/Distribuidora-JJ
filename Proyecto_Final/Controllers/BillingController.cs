using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;
using Microsoft.Extensions.Options;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Facturacion")]
    public class BillingController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly EmailService _emailService;
        private readonly CompanyOptions _company;
        private readonly ILogger<BillingController> _logger;

        public BillingController(AdminDbService adminDbService, EmailService emailService, IOptions<CompanyOptions> company, ILogger<BillingController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
            _emailService = emailService;
            _company = company.Value;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var model = await _adminDbService.GetSalesReportAsync();
            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Detail(int id)
        {
            var factura = await _adminDbService.GetInvoiceDetailAsync(id);

            if (factura == null)
            {
                TempData["ErrorMessage"] = "No se encontro la factura solicitada.";
                return RedirectToAction(nameof(Index));
            }

            return View(factura);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Facturacion", "FACTURACION_GENERAR", false)]
        public async Task<IActionResult> GenerateFromOrder(int pedidoId)
        {
            if (pedidoId <= 0)
            {
                TempData["ErrorMessage"] = "No fue posible generar la factura del pedido solicitado.";
                return RedirectToAction("Index", "OrdersAdmin");
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                var result = await _adminDbService.GenerateInvoiceFromOrderAsync(pedidoId, usuarioId, usuarioNombre, OriginalLoginSession.ValidatedRequest(HttpContext));

                // The SQL workflow commits invoice, states and canonical audit together.

                TempData["SuccessMessage"] = $"Factura {result.NumeroFactura} generada correctamente.";
                await EnviarComprobantePorCorreoAsync(result.FacturaId);
                return RedirectToAction(nameof(Detail), new { id = result.FacturaId });
            }
            catch (Exception exception)
            {
                _logger.LogWarning("Operación rechazada. Tipo {ExceptionType}; código SQL {SqlError}.", exception.GetType().Name, exception is Microsoft.Data.SqlClient.SqlException sql ? sql.Number : (int?)null);
                TempData["ErrorMessage"] = "No fue posible generar la factura del pedido. Verifique que no este cancelado ni facturado previamente.";
                return RedirectToAction("Detail", "OrdersAdmin", new { id = pedidoId });
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Facturacion", "FACTURACION_GENERAR", false)]
        public async Task<IActionResult> ResendEmail(int id)
        {
            var enviado = await EnviarComprobantePorCorreoAsync(id);

            TempData[enviado ? "SuccessMessage" : "ErrorMessage"] = enviado
                ? "Comprobante reenviado correctamente al correo del cliente."
                : "No fue posible reenviar el comprobante. Intente nuevamente.";

            return RedirectToAction(nameof(Detail), new { id });
        }

        // Envia el comprobante por correo; no interrumpe el flujo si el envio falla (CU-092).
        private async Task<bool> EnviarComprobantePorCorreoAsync(int facturaId)
        {
            try
            {
                var factura = await _adminDbService.GetInvoiceDetailAsync(facturaId);
                if (factura == null || string.IsNullOrWhiteSpace(factura.Correo))
                {
                    return false;
                }

                var contenido = EmailTemplateBuilder.BuildInvoiceEmail(
                    factura.Cliente,
                    factura.NumeroFactura,
                    factura.PedidoId,
                    factura.FechaFactura,
                    factura.Total,
                    _company);

                _emailService.SendEmail(factura.Correo, $"Comprobante {factura.NumeroFactura}", contenido);

                await RegistrarAuditoriaAsync(
                    "Enviar comprobante por correo",
                    "Facturacion",
                    $"Se envio el comprobante {factura.NumeroFactura} al correo {factura.Correo}.");

                return true;
            }
            catch (Exception exception)
            {
                _logger.LogWarning("Operación rechazada. Tipo {ExceptionType}; código SQL {SqlError}.", exception.GetType().Name, exception is Microsoft.Data.SqlClient.SqlException sql ? sql.Number : (int?)null);
                TempData["ErrorMessage"] = "La factura se genero correctamente, pero no fue posible enviar el comprobante por correo.";
                return false;
            }
        }

        private async Task RegistrarAuditoriaAsync(string accion, string modulo, string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                HttpContext.Session.GetInt32("UserId"),
                HttpContext.Session.GetString("UserFullName"),
                HttpContext.Session.GetString("UserEmail"),
                HttpContext.Session.GetString("UserRole"),
                accion,
                modulo,
                descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }
    }
}
