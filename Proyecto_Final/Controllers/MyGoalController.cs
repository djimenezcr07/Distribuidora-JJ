using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-212 — Panel de progreso en tiempo real del vendedor sobre su propia meta.
    [AdminAuthorize("Metas y KPIs", "METAS_PROPIAS_VER")]
    public class MyGoalController : Controller
    {
        private readonly KpiDbService _kpis;
        private readonly BusinessClock _clock;

        public MyGoalController(KpiDbService kpis, BusinessClock clock)
        {
            _kpis = kpis;
            _clock = clock;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var vendedorId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var hoy = _clock.LocalNow;

            var model = await _kpis.GetMiProgresoAsync(vendedorId, hoy.Year, hoy.Month);
            return View(model);
        }
    }
}
