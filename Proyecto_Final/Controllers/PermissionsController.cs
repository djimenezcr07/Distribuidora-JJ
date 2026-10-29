using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Seguridad")]
    public class PermissionsController : Controller
    {
        private readonly AdminDbService _adminDbService;

        public PermissionsController(AdminDbService adminDbService)
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
        public async Task<IActionResult> Edit(int id)
        {
            try
            {
                var model = await _adminDbService.GetRolePermissionAssignmentAsync(id);

                if (model == null)
                {
                    TempData["ErrorMessage"] = "No se encontró el rol solicitado.";
                    return RedirectToAction(nameof(Index));
                }

                return View(model);
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "Ocurrió un error al cargar los permisos del rol.";
                return RedirectToAction(nameof(Index));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Seguridad", "PERMISOS_ASIGNAR")]
        public async Task<IActionResult> Edit(int perfilId, List<int>? permisosSeleccionados)
        {
            var model = await _adminDbService.GetRolePermissionAssignmentAsync(perfilId);

            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el rol solicitado.";
                return RedirectToAction(nameof(Index));
            }

            if (model.EsAdministrador)
            {
                TempData["ErrorMessage"] = "El rol Administrador mantiene todos los permisos por seguridad.";
                return RedirectToAction(nameof(Edit), new { id = perfilId });
            }

            try
            {
                permisosSeleccionados ??= new List<int>();

                await _adminDbService.UpdateRolePermissionsAsync(
                    perfilId,
                    permisosSeleccionados,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Asignar permisos",
                    "Permisos",
                    $"Se actualizaron {permisosSeleccionados.Count} permiso(s) para el rol {model.RolNombre}.");

                TempData["SuccessMessage"] = "Permisos actualizados correctamente.";
                return RedirectToAction(nameof(Edit), new { id = perfilId });
            }
            catch (InvalidOperationException)
            {
                TempData["ErrorMessage"] = "No se pudieron actualizar los permisos.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "Ocurrió un error al actualizar los permisos.";
            }

            return RedirectToAction(nameof(Edit), new { id = perfilId });
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
