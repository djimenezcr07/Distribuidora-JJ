using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Seguridad")]
    public class RolesController : Controller
    {
        private readonly AdminDbService _adminDbService;

        public RolesController(AdminDbService adminDbService)
        {
            _adminDbService = adminDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? buscar)
        {
            ViewBag.Buscar = buscar;
            var roles = await _adminDbService.GetRolesAsync(buscar);
            return View(roles);
        }

        [HttpGet]
        public IActionResult Create()
        {
            return View(new RoleFormViewModel { Activo = true });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Seguridad", "ROLES_CREAR_EDITAR")]
        public async Task<IActionResult> Create(RoleFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);

            try
            {
                var perfilId = await _adminDbService.CreateRoleAsync(model);

                await RegistrarAuditoriaAsync(
                    "Crear",
                    "Roles",
                    $"Se creó el rol {model.Nombre} con identificador #{perfilId}.");

                TempData["SuccessMessage"] = "Rol creado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (InvalidOperationException)
            {
                ModelState.AddModelError(string.Empty, "No se pudo crear el rol. Revise los datos e intente nuevamente.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Ocurrió un error al crear el rol. Intente nuevamente.");
            }

            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _adminDbService.GetRoleByIdAsync(id);

            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el rol solicitado.";
                return RedirectToAction(nameof(Index));
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Seguridad", "ROLES_CREAR_EDITAR")]
        public async Task<IActionResult> Edit(RoleFormViewModel model)
        {
            if (!ModelState.IsValid) return View(model);

            try
            {
                await _adminDbService.UpdateRoleAsync(model);

                await RegistrarAuditoriaAsync(
                    "Editar",
                    "Roles",
                    $"Se actualizó el rol {model.Nombre}.");

                TempData["SuccessMessage"] = "Rol actualizado correctamente.";
                return RedirectToAction(nameof(Index));
            }
            catch (InvalidOperationException)
            {
                ModelState.AddModelError(string.Empty, "No se pudo actualizar el rol. Revise los datos e intente nuevamente.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Ocurrió un error al actualizar el rol. Intente nuevamente.");
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Seguridad", "ROLES_CREAR_EDITAR")]
        public async Task<IActionResult> ToggleStatus(int perfilId, string? buscar)
        {
            if (perfilId <= 0)
            {
                TempData["ErrorMessage"] = "La solicitud no es válida.";
                return RedirectToAction(nameof(Index), new { buscar });
            }

            try
            {
                var rol = await _adminDbService.GetRoleByIdAsync(perfilId);
                await _adminDbService.ToggleRoleStatusAsync(perfilId);

                await RegistrarAuditoriaAsync(
                    "Activar/Inactivar",
                    "Roles",
                    $"Se cambió el estado del rol #{perfilId} {(rol == null ? string.Empty : rol.Nombre)}.");

                TempData["SuccessMessage"] = "Estado del rol actualizado correctamente.";
            }
            catch (InvalidOperationException)
            {
                TempData["ErrorMessage"] = "No se pudo cambiar el estado del rol.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "Ocurrió un error al cambiar el estado del rol.";
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
                accion,
                modulo,
                descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }
    }
}
