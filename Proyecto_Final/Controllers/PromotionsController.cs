using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-171/172/174 — Gestión de promociones y segmentos de cliente.
    [AdminAuthorize("Promociones", "PROMOCIONES_GESTIONAR")]
    public class PromotionsController : Controller
    {
        private readonly PromotionsDbService _promos;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<PromotionsController> _logger;

        public PromotionsController(PromotionsDbService promos, AdminDbService adminDbService, ILogger<PromotionsController> logger)
        {
            _promos = promos;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado, string? buscar)
        {
            ViewBag.Estado = estado;
            ViewBag.Buscar = buscar;
            var promociones = await _promos.GetPromotionsAsync(estado, buscar);
            return View(promociones);
        }

        // CU-171/172 — Crear
        [HttpGet]
        public async Task<IActionResult> Create()
        {
            var model = new PromotionFormViewModel { Productos = await _promos.GetProductOptionsAsync() };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(PromotionFormViewModel model)
        {
            NormalizeByType(model);
            if (!ModelState.IsValid)
            {
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                var id = await _promos.CreatePromotionAsync(model, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Crear promoción", "Promociones", $"Promoción #{id} '{model.Nombre}' ({model.Tipo}).");
                TempData["SuccessMessage"] = "Promoción creada correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al crear promoción.");
                ModelState.AddModelError(string.Empty, "No fue posible crear la promoción.");
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }
        }

        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _promos.GetPromotionByIdAsync(id);
            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró la promoción.";
                return RedirectToAction(nameof(Index));
            }
            model.Productos = await _promos.GetProductOptionsAsync();
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(PromotionFormViewModel model)
        {
            NormalizeByType(model);
            if (!ModelState.IsValid)
            {
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }
            try
            {
                await _promos.UpdatePromotionAsync(model);
                await RegistrarAuditoriaAsync("Editar promoción", "Promociones", $"Promoción #{model.PromocionId} actualizada.");
                TempData["SuccessMessage"] = "Promoción actualizada correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al actualizar promoción.");
                ModelState.AddModelError(string.Empty, "No fue posible actualizar la promoción.");
                model.Productos = await _promos.GetProductOptionsAsync();
                return View(model);
            }
        }

        // CU-174 — Inactivar
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Inactivate(int promocionId, string? motivo)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                await _promos.InactivatePromotionAsync(promocionId, motivo, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Inactivar promoción", "Promociones", $"Promoción #{promocionId} inactivada. Motivo: {motivo}");
                TempData["SuccessMessage"] = "Promoción inactivada.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al inactivar promoción.");
                TempData["ErrorMessage"] = "No fue posible inactivar la promoción.";
            }
            return RedirectToAction(nameof(Index));
        }

        // CU-172 — Segmentos de cliente
        [HttpGet]
        public async Task<IActionResult> Segments(string? buscar)
        {
            ViewBag.Buscar = buscar;
            var clientes = await _promos.GetClientSegmentsAsync(buscar);
            return View(clientes);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SetSegment(int usuarioId, string segmento)
        {
            try
            {
                await _promos.SetClientSegmentAsync(usuarioId, segmento);
                await RegistrarAuditoriaAsync("Cambiar segmento de cliente", "Promociones",
                    $"Cliente #{usuarioId} marcado como {segmento}.");
                TempData["SuccessMessage"] = "Segmento actualizado.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al cambiar segmento de cliente.");
                TempData["ErrorMessage"] = "No fue posible actualizar el segmento.";
            }
            return RedirectToAction(nameof(Segments), new { buscar = (string?)null });
        }

        // Deja consistentes los campos según el tipo (evita validaciones cruzadas).
        private void NormalizeByType(PromotionFormViewModel model)
        {
            if (model.Tipo == "DescuentoPorcentual")
            {
                model.ProductoRegaloId = null;
                model.CantidadRegalo = null;
                ModelState.Remove(nameof(model.ProductoRegaloId));
                ModelState.Remove(nameof(model.CantidadRegalo));
                if (!model.PorcentajeDescuento.HasValue)
                    ModelState.AddModelError(nameof(model.PorcentajeDescuento), "Indique el porcentaje de descuento.");
            }
            else if (model.Tipo == "RegaliaPorVolumen")
            {
                model.PorcentajeDescuento = null;
                ModelState.Remove(nameof(model.PorcentajeDescuento));
                if (!model.ProductoRegaloId.HasValue)
                    ModelState.AddModelError(nameof(model.ProductoRegaloId), "Seleccione el producto de regalía.");
                if (!model.CantidadRegalo.HasValue)
                    ModelState.AddModelError(nameof(model.CantidadRegalo), "Indique la cantidad de regalía.");
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
