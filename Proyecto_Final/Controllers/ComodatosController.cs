using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Controllers
{
    // CU-162/163/164 — Comodatos: asignación, devolución/retiro y consulta de rentabilidad.
    // Gestión reutiliza el permiso ACTIVOS_GESTIONAR (módulo Activos).
    [AdminAuthorize("Activos", "ACTIVOS_GESTIONAR")]
    public class ComodatosController : Controller
    {
        private readonly FleetDbService _fleet;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<ComodatosController> _logger;

        public ComodatosController(FleetDbService fleet, AdminDbService adminDbService, ILogger<ComodatosController> logger)
        {
            _fleet = fleet;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado, string? buscar)
        {
            ViewBag.Estado = estado;
            ViewBag.Buscar = buscar;
            var comodatos = await _fleet.GetComodatosAsync(estado, buscar);
            return View(comodatos);
        }

        // CU-162 — Asignar
        [HttpGet]
        public async Task<IActionResult> Assign()
        {
            var model = new ComodatoAssignViewModel
            {
                FechaAsignacion = DateTime.Today,
                ActivosDisponibles = await _fleet.GetAvailableAssetsAsync()
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Assign(ComodatoAssignViewModel model)
        {
            model.ClienteIdentificacion = CostaRicanIdentificationAttribute.Normalize(model.ClienteIdentificacion);
            if (!ModelState.IsValid)
            {
                model.ActivosDisponibles = await _fleet.GetAvailableAssetsAsync();
                return View(model);
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                var id = await _fleet.AssignComodatoAsync(model, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Asignar comodato", "Activos",
                    $"Comodato #{id}: activo #{model.ActivoId} asignado a {model.ClienteNombre}.");
                TempData["SuccessMessage"] = "Comodato registrado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                model.ActivosDisponibles = await _fleet.GetAvailableAssetsAsync();
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al asignar comodato.");
                ModelState.AddModelError(string.Empty, "No fue posible registrar el comodato.");
                model.ActivosDisponibles = await _fleet.GetAvailableAssetsAsync();
                return View(model);
            }
        }

        // CU-163 — Devolver / Retirar
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Return(ComodatoReturnViewModel model)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                await _fleet.ReturnComodatoAsync(model, usuarioId, usuarioNombre);
                var destino = model.Destino == "Mantenimiento" ? "enviado a mantenimiento" : "reingresado al inventario";
                await RegistrarAuditoriaAsync("Devolver comodato", "Activos",
                    $"Comodato #{model.ComodatoId} cerrado; equipo {destino}.");
                TempData["SuccessMessage"] = $"Comodato cerrado. Equipo {destino}.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al devolver comodato.");
                TempData["ErrorMessage"] = "No fue posible registrar la devolución.";
            }
            return RedirectToAction(nameof(Index));
        }

        // CU-164 — Rentabilidad (consulta). Auditor/gerente por COMODATOS_CONSULTAR.
        [HttpGet]
        [AdminAuthorize("Activos", "COMODATOS_CONSULTAR")]
        public async Task<IActionResult> Profitability()
        {
            var datos = await _fleet.GetComodatoProfitabilityAsync();
            return View(datos);
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
