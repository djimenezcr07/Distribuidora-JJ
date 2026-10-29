using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-161 — Registro y administración de activos de la empresa (neveras, exhibidores).
    [AdminAuthorize("Activos", "ACTIVOS_GESTIONAR")]
    public class AssetsController : Controller
    {
        private readonly FleetDbService _fleet;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<AssetsController> _logger;

        public AssetsController(FleetDbService fleet, AdminDbService adminDbService, ILogger<AssetsController> logger)
        {
            _fleet = fleet;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? buscar, string? estado)
        {
            ViewBag.Buscar = buscar;
            ViewBag.Estado = estado;
            var activos = await _fleet.GetAssetsAsync(buscar, estado);
            return View(activos);
        }

        [HttpGet]
        public IActionResult Create() => View(new AssetFormViewModel { Estado = "Disponible", Tipo = "Nevera" });

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(AssetFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);
            try
            {
                await _fleet.CreateAssetAsync(model);
                await RegistrarAuditoriaAsync("Crear activo", "Activos", $"Se registró el activo {model.CodigoActivo} ({model.Nombre}).");
                TempData["SuccessMessage"] = "Activo registrado correctamente.";
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
                _logger.LogError(ex, "Error al crear activo.");
                ModelState.AddModelError(string.Empty, "No fue posible registrar el activo.");
                return View(model);
            }
        }

        [HttpGet]
        public async Task<IActionResult> Details(int id)
        {
            var activo = await _fleet.GetAssetByIdAsync(id);
            if (activo == null)
            {
                TempData["ErrorMessage"] = "No se encontró el activo solicitado.";
                return RedirectToAction(nameof(Index));
            }
            var model = new AssetDetailViewModel
            {
                Activo = activo,
                Historial = await _fleet.GetAssetComodatoHistoryAsync(id)
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                await _fleet.DeleteAssetAsync(id);
                await RegistrarAuditoriaAsync("Eliminar activo", "Activos", $"Se dio de baja el activo #{id}.");
                TempData["SuccessMessage"] = "Activo eliminado (dado de baja) correctamente.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al eliminar activo.");
                TempData["ErrorMessage"] = "No fue posible eliminar el activo.";
            }
            return RedirectToAction(nameof(Index));
        }

        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _fleet.GetAssetByIdAsync(id);
            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el activo solicitado.";
                return RedirectToAction(nameof(Index));
            }
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(AssetFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);
            try
            {
                await _fleet.UpdateAssetAsync(model);
                await RegistrarAuditoriaAsync("Editar activo", "Activos", $"Se actualizó el activo {model.CodigoActivo}.");
                TempData["SuccessMessage"] = "Activo actualizado correctamente.";
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
                _logger.LogError(ex, "Error al actualizar activo.");
                ModelState.AddModelError(string.Empty, "No fue posible actualizar el activo.");
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
