using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers.Admin
{
    [AdminAuthorize("Garantias", "GARANTIAS_GESTIONAR", false)]
    public sealed class WarrantyRequestsAdminController : Controller
    {
        private static readonly HashSet<string> AllowedStatuses = new(StringComparer.OrdinalIgnoreCase)
        {
            "En revisión",
            "Aprobada",
            "Rechazada"
        };

        private readonly AdminDbService _adminDbService;
        private readonly ILogger<WarrantyRequestsAdminController> _logger;

        public WarrantyRequestsAdminController(
            AdminDbService adminDbService,
            ILogger<WarrantyRequestsAdminController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index() =>
            View(await _adminDbService.GetWarrantyRequestsAsync());

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateStatus(int garantiaId, string estado, string? resolucion)
        {
            estado = estado?.Trim() ?? string.Empty;
            if (garantiaId <= 0 || !AllowedStatuses.Contains(estado))
            {
                TempData["ErrorMessage"] = "La actualización de garantía no es válida.";
                return RedirectToAction(nameof(Index));
            }

            if ((estado == "Aprobada" || estado == "Rechazada") && string.IsNullOrWhiteSpace(resolucion))
            {
                TempData["ErrorMessage"] = "Debe indicar la resolución de la garantía.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                if (!Guid.TryParse(HttpContext.Session.GetString("SecurityStamp"), out var stamp) || stamp == Guid.Empty)
                    return Unauthorized();
                var userId = HttpContext.Session.GetInt32("UserId") ?? 0;
                await _adminDbService.UpdateWarrantyStatusAsync(
                    garantiaId,
                    estado,
                    resolucion,
                    userId,
                    HttpContext.Session.GetString("UserFullName") ?? string.Empty,
                    OriginalLoginSession.ValidatedRequest(HttpContext));
                TempData["SuccessMessage"] = "La garantía se actualizó correctamente.";
            }
            catch (SqlException exception) when (exception.Number >= 50000)
            {
                _logger.LogWarning(exception, "Actualización rechazada para la garantía {WarrantyId}.", garantiaId);
                TempData["ErrorMessage"] = "No fue posible aplicar el estado solicitado a la garantía.";
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al actualizar la garantía {WarrantyId}.", garantiaId);
                TempData["ErrorMessage"] = "No fue posible actualizar la garantía.";
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
