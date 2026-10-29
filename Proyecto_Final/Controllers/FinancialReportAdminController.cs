using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Finanzas")]
    public class FinancialReportAdminController : Controller
    {
        private readonly AdminDbService _adminDbService;

        public FinancialReportAdminController(AdminDbService adminDbService)
        {
            _adminDbService = adminDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(
            DateTime? fechaInicio,
            DateTime? fechaFin)
        {
            var modelo = await _adminDbService
                .GetFinancialReportAsync(fechaInicio, fechaFin);

            return View(modelo);
        }
    }
}