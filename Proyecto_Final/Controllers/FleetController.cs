using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-152 (kilometraje), CU-153 (mantenimiento), CU-154 (alertas y documentos).
    public class FleetController : Controller
    {
        private readonly FleetDbService _fleet;
        private readonly LogisticsDbService _logistics;
        private readonly AdminDbService _adminDbService;
        private readonly IRolePermissionService _permissionService;
        private readonly ILogger<FleetController> _logger;

        public FleetController(
            FleetDbService fleet,
            LogisticsDbService logistics,
            AdminDbService adminDbService,
            IRolePermissionService permissionService,
            ILogger<FleetController> logger)
        {
            _fleet = fleet;
            _logistics = logistics;
            _adminDbService = adminDbService;
            _permissionService = permissionService;
            _logger = logger;
        }

        // ── CU-152 Kilometraje (chofer + admin) ─────────────
        [HttpGet]
        [AdminAuthorize("Flota", "FLOTA_KILOMETRAJE")]
        public async Task<IActionResult> Mileage()
        {
            await PopulateMileageVehiclesAsync();
            var puedeAdministrar = await CanAdministerMileageAsync();
            int? choferFiltro = puedeAdministrar ? null : HttpContext.Session.GetInt32("UserId");
            var vm = new MileageIndexViewModel
            {
                Jornadas = await _fleet.GetMileageAsync(null, choferFiltro)
            };
            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Flota", "FLOTA_KILOMETRAJE")]
        public async Task<IActionResult> OpenMileage(MileageOpenViewModel nueva)
        {
            var choferId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var choferNombre = HttpContext.Session.GetString("UserFullName") ?? "Chofer";

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise los datos del kilometraje inicial.";
                return RedirectToAction(nameof(Mileage));
            }
            try
            {
                await _fleet.OpenMileageAsync(nueva, choferId, choferNombre);
                TempData["SuccessMessage"] = "Jornada iniciada. Kilometraje inicial registrado.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al abrir kilometraje.");
                TempData["ErrorMessage"] = "No fue posible registrar el kilometraje inicial.";
            }
            return RedirectToAction(nameof(Mileage));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Flota", "FLOTA_KILOMETRAJE")]
        public async Task<IActionResult> CloseMileage(int kilometrajeId, int kmFinal)
        {
            var actorUsuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (actorUsuarioId <= 0)
            {
                return AuthorizationResults.AccessDenied();
            }

            try
            {
                await _fleet.CloseMileageAsync(
                    kilometrajeId,
                    kmFinal,
                    actorUsuarioId,
                    await CanAdministerMileageAsync());
                TempData["SuccessMessage"] = "Jornada cerrada. Kilometraje final registrado.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al cerrar kilometraje.");
                TempData["ErrorMessage"] = "No fue posible registrar el kilometraje final.";
            }
            return RedirectToAction(nameof(Mileage));
        }

        // ── CU-153 Mantenimiento ────────────────────────────
        [HttpGet]
        [AdminAuthorize("Flota", "FLOTA_MANTENIMIENTO")]
        public async Task<IActionResult> Maintenance(string? estado)
        {
            await PopulateVehiclesAsync();
            var vm = new MaintenanceIndexViewModel
            {
                Estado = estado,
                Ordenes = await _fleet.GetMaintenanceAsync(null, estado)
            };
            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Flota", "FLOTA_MANTENIMIENTO")]
        public async Task<IActionResult> CreateMaintenance(MaintenanceFormViewModel nueva)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            if (!ModelState.IsValid)
            {
                await PopulateVehiclesAsync();
                var vm = new MaintenanceIndexViewModel { Nueva = nueva, Ordenes = await _fleet.GetMaintenanceAsync(null, null) };
                return View(nameof(Maintenance), vm);
            }
            try
            {
                await _fleet.CreateMaintenanceAsync(nueva, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Registrar mantenimiento", "Flota",
                    $"Orden {nueva.Tipo} registrada para vehículo #{nueva.VehiculoId}.");
                TempData["SuccessMessage"] = "Orden de mantenimiento registrada.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al registrar mantenimiento.");
                TempData["ErrorMessage"] = "No fue posible registrar la orden de mantenimiento.";
            }
            return RedirectToAction(nameof(Maintenance));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Flota", "FLOTA_MANTENIMIENTO")]
        public async Task<IActionResult> CompleteMaintenance(int ordenId, decimal? costo)
        {
            try
            {
                await _fleet.CompleteMaintenanceAsync(ordenId, DateTime.Today, costo);
                await RegistrarAuditoriaAsync("Completar mantenimiento", "Flota", $"Orden de mantenimiento #{ordenId} marcada como completada.");
                TempData["SuccessMessage"] = "Orden marcada como completada.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al completar mantenimiento.");
                TempData["ErrorMessage"] = "No fue posible completar la orden.";
            }
            return RedirectToAction(nameof(Maintenance));
        }

        // ── CU-154 Alertas y documentos ─────────────────────
        [HttpGet]
        [AdminAuthorize("Flota", "FLOTA_MANTENIMIENTO")]
        public async Task<IActionResult> Alerts(int diasAviso = 15)
        {
            await PopulateVehiclesAsync();
            var vm = new FleetAlertsViewModel
            {
                DiasAviso = diasAviso,
                Alertas = await _fleet.GetAlertsAsync(diasAviso)
            };
            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Flota", "FLOTA_MANTENIMIENTO")]
        public async Task<IActionResult> CreateDocument(VehicleDocumentFormViewModel nuevoDocumento)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise los datos del documento.";
                return RedirectToAction(nameof(Alerts));
            }
            try
            {
                await _fleet.CreateDocumentAsync(nuevoDocumento);
                await RegistrarAuditoriaAsync("Registrar documento", "Flota",
                    $"Documento {nuevoDocumento.Tipo} para vehículo #{nuevoDocumento.VehiculoId} (vence {nuevoDocumento.FechaVencimiento:dd/MM/yyyy}).");
                TempData["SuccessMessage"] = "Documento registrado. Se vigilará su vencimiento.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al registrar documento del vehículo.");
                TempData["ErrorMessage"] = "No fue posible registrar el documento.";
            }
            return RedirectToAction(nameof(Alerts));
        }

        private async Task PopulateVehiclesAsync()
        {
            ViewBag.Vehiculos = await _logistics.GetAvailableVehiclesAsync();
        }

        // Vehículos activos con su odómetro actual (para el kilometraje).
        private async Task PopulateMileageVehiclesAsync()
        {
            var vehiculos = await _logistics.GetVehiclesAsync(null);
            ViewBag.VehiculosKm = vehiculos.Where(v => v.Activo).ToList();
        }

        private async Task<bool> CanAdministerMileageAsync()
        {
            var role = HttpContext.Session.GetString("UserRole") ?? string.Empty;
            return string.Equals(role, "Administrador", StringComparison.OrdinalIgnoreCase)
                || await _permissionService.HasCodePermissionAsync(role, "FLOTA_KILOMETRAJE_ADMIN");
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
