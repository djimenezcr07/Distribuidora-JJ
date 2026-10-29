using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Admin")]
    public class AdminController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<AdminController> _logger;

        public AdminController(
            AdminDbService adminDbService,
            ILogger<AdminController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            try
            {
                return View(await _adminDbService.GetDashboardSummaryAsync());
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No fue posible cargar el tablero administrativo.");
                TempData["ErrorMessage"] = "No fue posible cargar todos los datos del tablero. Puede utilizar los accesos rápidos mientras se restablece la información.";
                return View(new DashboardSummaryViewModel());
            }
        }
    }
}
