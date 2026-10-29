using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-106 — Liquidación financiera de cobros de ruta (efectivo + comprobantes del chofer).
    [AdminAuthorize("Finanzas", "LIQUIDACION_FINANCIERA")]
    public class FinanceController : Controller
    {
        private readonly LogisticsDbService _logistics;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<FinanceController> _logger;

        public FinanceController(LogisticsDbService logistics, AdminDbService adminDbService, ILogger<FinanceController> logger)
        {
            _logistics = logistics;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado)
        {
            ViewBag.Estado = estado;
            // Rutas despachadas/completadas candidatas a liquidación financiera.
            var rutas = await _logistics.GetRoutesAsync(null, null);
            ViewBag.Rutas = rutas
                .Where(r => r.Estado == "Despachada" || r.Estado == "Completada")
                .ToList();
            var liquidaciones = await _logistics.GetCashSettlementsAsync(estado);
            return View(liquidaciones);
        }

        [HttpGet]
        public async Task<IActionResult> Liquidate(int rutaId)
        {
            var prep = await _logistics.PrepareCashSettlementAsync(rutaId);
            if (prep == null)
            {
                TempData["ErrorMessage"] = "No se encontró la ruta solicitada.";
                return RedirectToAction(nameof(Index));
            }
            if (prep.YaLiquidadaFinanciera)
            {
                TempData["ErrorMessage"] = $"La ruta {prep.RutaCodigo} ya tiene liquidación financiera registrada.";
                return RedirectToAction(nameof(Index));
            }

            ViewBag.Prepare = prep;
            var model = new CashSettlementFormViewModel
            {
                RutaId = prep.RutaId,
                RutaCodigo = prep.RutaCodigo,
                EsperadoEfectivo = prep.EsperadoEfectivo,
                EsperadoOtros = prep.EsperadoOtros,
                MontoEfectivoRecibido = prep.EsperadoEfectivo,
                MontoComprobantes = prep.EsperadoOtros
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Liquidate(CashSettlementFormViewModel model)
        {
            var prep = await _logistics.PrepareCashSettlementAsync(model.RutaId);
            if (prep == null)
            {
                TempData["ErrorMessage"] = "No se encontró la ruta solicitada.";
                return RedirectToAction(nameof(Index));
            }

            if (!ModelState.IsValid)
            {
                ViewBag.Prepare = prep;
                return View(model);
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Cajero";

            // Comprobantes válidos capturados en el formulario.
            var comprobantes = (model.Comprobantes ?? new List<CashSettlementVoucher>())
                .Where(c => c.Monto > 0 && !string.IsNullOrWhiteSpace(c.Tipo))
                .Select(c => new { c.Tipo, c.Referencia, c.Monto });
            var comprobantesJson = comprobantes.Any()
                ? System.Text.Json.JsonSerializer.Serialize(comprobantes)
                : string.Empty;

            try
            {
                var (id, estado, diferencia) = await _logistics.RegisterCashSettlementAsync(model, comprobantesJson, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Liquidar cobros de ruta", "Finanzas",
                    $"Liquidación financiera #{id} de la ruta {model.RutaCodigo}: {estado} (diferencia {diferencia:0.00}).");
                TempData["SuccessMessage"] = $"Liquidación registrada. Resultado: {estado} (diferencia {diferencia:0.00}).";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                ViewBag.Prepare = prep;
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al registrar liquidación financiera.");
                ModelState.AddModelError(string.Empty, "No fue posible registrar la liquidación.");
                ViewBag.Prepare = prep;
                return View(model);
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
