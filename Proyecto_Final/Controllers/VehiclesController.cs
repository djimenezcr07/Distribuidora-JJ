using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-081 — gestión de la flota de vehículos de reparto.
    [AdminAuthorize("Rutas", "RUTAS_GESTIONAR")]
    public class VehiclesController : Controller
    {
        private readonly LogisticsDbService _logistics;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<VehiclesController> _logger;

        public VehiclesController(LogisticsDbService logistics, AdminDbService adminDbService, ILogger<VehiclesController> logger)
        {
            _logistics = logistics;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? buscar)
        {
            ViewBag.Buscar = buscar;
            var vehiculos = await _logistics.GetVehiclesAsync(buscar);
            return View(vehiculos);
        }

        [HttpGet]
        public IActionResult Create() => View(new VehicleFormViewModel { Activo = true });

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(VehicleFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);

            try
            {
                await _logistics.CreateVehicleAsync(model);
                await RegistrarAuditoriaAsync("Crear", "Rutas", $"Se registró el vehículo {model.Placa}.");
                TempData["SuccessMessage"] = "Vehículo registrado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al crear vehículo.");
                ModelState.AddModelError(string.Empty, "No fue posible registrar el vehículo.");
                return View(model);
            }
        }

        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _logistics.GetVehicleByIdAsync(id);
            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el vehículo solicitado.";
                return RedirectToAction(nameof(Index));
            }
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(VehicleFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);

            try
            {
                await _logistics.UpdateVehicleAsync(model);
                await RegistrarAuditoriaAsync("Editar", "Rutas", $"Se actualizó el vehículo {model.Placa}.");
                TempData["SuccessMessage"] = "Vehículo actualizado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al actualizar vehículo.");
                ModelState.AddModelError(string.Empty, "No fue posible actualizar el vehículo.");
                return View(model);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleStatus(int vehiculoId, string? buscar)
        {
            try
            {
                var activo = await _logistics.ToggleVehicleStatusAsync(vehiculoId);
                await RegistrarAuditoriaAsync(activo ? "Activar" : "Inactivar", "Rutas",
                    activo ? $"Se reactivó el vehículo #{vehiculoId}." : $"Se inactivó el vehículo #{vehiculoId}.");
                TempData["SuccessMessage"] = activo ? "Vehículo reactivado." : "Vehículo inactivado.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al cambiar estado del vehículo.");
                TempData["ErrorMessage"] = "No fue posible cambiar el estado del vehículo.";
            }
            return RedirectToAction(nameof(Index), new { buscar });
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
