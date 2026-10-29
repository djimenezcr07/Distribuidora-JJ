using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Auditoria")]
    public class AuditController : Controller
    {
        private readonly AdminDbService _adminDbService;

        public AuditController(AdminDbService adminDbService)
        {
            _adminDbService = adminDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? modulo, string? accion, string? buscar)
        {
            var registros = await _adminDbService.GetAuditLogsAsync(modulo, accion, buscar);

            var model = new AuditLogFilterViewModel
            {
                Modulo = modulo,
                Accion = accion,
                Buscar = buscar,
                Registros = registros
            };

            return View(model);
        }
    }
}
