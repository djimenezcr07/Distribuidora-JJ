using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-211/213 — Metas mensuales por vendedor y reporte de cumplimiento de KPIs.
    [AdminAuthorize("Metas y KPIs", "METAS_GESTIONAR")]
    public class KpisController : Controller
    {
        private readonly KpiDbService _kpis;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<KpisController> _logger;
        private readonly BusinessClock _clock;

        public KpisController(KpiDbService kpis, AdminDbService adminDbService, ILogger<KpisController> logger, BusinessClock clock)
        {
            _kpis = kpis;
            _adminDbService = adminDbService;
            _logger = logger;
            _clock = clock;
        }

        // CU-211 — Gestión de metas
        [HttpGet]
        public async Task<IActionResult> Index(int? anio, int? mes)
        {
            var (a, m) = NormalizarPeriodo(anio, mes);
            var model = new MetasIndexViewModel
            {
                Anio = a,
                Mes = m,
                Metas = await _kpis.GetMetasAsync(a, m),
                Vendedores = await _kpis.GetSellerOptionsAsync(),
                Nueva = new MetaFormViewModel { Anio = a, Mes = m }
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(MetaFormViewModel nueva)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revisá los datos de la meta (vendedor, período y monto).";
                return RedirectToAction(nameof(Index), new { anio = nueva.Anio, mes = nueva.Mes });
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Gerente";
            try
            {
                await _kpis.UpsertMetaAsync(nueva, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Definir meta de ventas", "Metas y KPIs",
                    $"Meta de ₡{nueva.MontoMeta:N2} para vendedor #{nueva.VendedorUsuarioId} en {nueva.Mes:00}/{nueva.Anio}.");
                TempData["SuccessMessage"] = "Meta guardada correctamente.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al guardar meta.");
                TempData["ErrorMessage"] = "No fue posible guardar la meta.";
            }
            return RedirectToAction(nameof(Index), new { anio = nueva.Anio, mes = nueva.Mes });
        }

        // CU-213 — Reporte de cumplimiento global de KPIs
        [HttpGet]
        [AdminAuthorize("Metas y KPIs", "REPORTE_KPI")]
        public async Task<IActionResult> Report(int? anio, int? mes)
        {
            var (a, m) = NormalizarPeriodo(anio, mes);
            var model = await _kpis.GetGlobalKpiAsync(a, m);
            return View(model);
        }

        private (int anio, int mes) NormalizarPeriodo(int? anio, int? mes)
        {
            var hoy = _clock.LocalNow;
            var a = anio is >= 2000 and <= 2100 ? anio.Value : hoy.Year;
            var m = mes is >= 1 and <= 12 ? mes.Value : hoy.Month;
            return (a, m);
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
