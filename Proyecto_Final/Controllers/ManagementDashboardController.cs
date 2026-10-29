using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-131 — Tablero gerencial de indicadores. Accesible a Administrador y Gerente
    // mediante el permiso REPORTES_DASHBOARD. No modifica el dashboard admin existente.
    [AdminAuthorize("Reportes", "REPORTES_DASHBOARD")]
    public class ManagementDashboardController : Controller
    {
        private readonly ReportsDbService _reports;
        private readonly BusinessClock _clock;

        public ManagementDashboardController(ReportsDbService reports, BusinessClock clock)
        {
            _reports = reports;
            _clock = clock;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? rango, DateTime? desde, DateTime? hasta)
        {
            var hoy = _clock.Today;
            DateTime rangoDesde, rangoHasta;
            string rangoNormalizado;

            if (desde.HasValue && hasta.HasValue)
            {
                rangoDesde = desde.Value.Date;
                rangoHasta = hasta.Value.Date;
                rangoNormalizado = "personalizado";
            }
            else
            {
                rangoNormalizado = (rango ?? "hoy").ToLowerInvariant();
                switch (rangoNormalizado)
                {
                    case "semana":
                        rangoDesde = hoy.AddDays(-6);
                        rangoHasta = hoy;
                        break;
                    case "mes":
                        rangoDesde = new DateTime(hoy.Year, hoy.Month, 1);
                        rangoHasta = hoy;
                        break;
                    case "hoy":
                    default:
                        rangoNormalizado = "hoy";
                        rangoDesde = hoy;
                        rangoHasta = hoy;
                        break;
                }
            }

            if (rangoDesde > rangoHasta)
                (rangoDesde, rangoHasta) = (rangoHasta, rangoDesde);

            var model = await _reports.GetDashboardAsync(rangoDesde, rangoHasta, rangoNormalizado);
            return View(model);
        }
    }
}
