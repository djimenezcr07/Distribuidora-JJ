using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Seguridad")]
    public class SecurityController : Controller
    {
        [HttpGet]
        [Obsolete("Ruta de compatibilidad. Use Roles/Index.")]
        public IActionResult Roles()
        {
            return RedirectToAction("Index", "Roles");
        }

        [HttpGet]
        [Obsolete("Ruta de compatibilidad. Use Audit/Index.")]
        public IActionResult Auditoria()
        {
            return RedirectToAction("Index", "Audit");
        }

        [HttpGet]
        [Obsolete("Ruta de compatibilidad. Use Roles/Create.")]
        public IActionResult CrearRol()
        {
            return RedirectToAction("Create", "Roles");
        }

        [HttpGet]
        [Obsolete("Ruta de compatibilidad. Use Roles/Edit.")]
        public IActionResult EditarRol(int id)
        {
            return RedirectToAction("Edit", "Roles", new { id });
        }

        [HttpGet]
        [Obsolete("Ruta de compatibilidad. Use Permissions/Edit.")]
        public IActionResult Permisos(int perfilId)
        {
            return RedirectToAction("Edit", "Permissions", new { id = perfilId });
        }

    }
}
