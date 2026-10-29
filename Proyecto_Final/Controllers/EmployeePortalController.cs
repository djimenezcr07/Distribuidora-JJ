using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [SessionAuthorize]
    [EmployeeRelationshipAuthorize]
    public class EmployeePortalController : Controller
    {
        private readonly IEmployeesService _employeesDbService;
        private readonly AdminDbService _adminDbService;

        public EmployeePortalController(IEmployeesService employeesDbService, AdminDbService adminDbService)
        {
            _employeesDbService = employeesDbService;
            _adminDbService = adminDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            var model = await _employeesDbService.GetEmployeePortalAsync(usuarioId);

            if (model.Perfil == null)
            {
                TempData["ErrorMessage"] = "No se encontró un perfil de empleado asociado a su usuario.";
                return RedirectToAction("Index", "Home");
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RequestTimeOff(EmployeeLeaveRequestFormViewModel model)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            if (model.FechaFin < model.FechaInicio)
            {
                ModelState.AddModelError(nameof(model.FechaFin), "La fecha final no puede ser menor a la fecha inicial.");
            }

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Debe completar correctamente la solicitud de días libres.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                var solicitudId = await _employeesDbService.CreateMyLeaveRequestAsync(usuarioId, model);

                await RegistrarAuditoriaAsync(
                    "Solicitud días libres",
                    "Empleados",
                    $"El usuario #{usuarioId} registró la solicitud de días libres #{solicitudId}.");

                TempData["SuccessMessage"] = "Solicitud enviada correctamente. Quedó pendiente de revisión administrativa.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible registrar la solicitud.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateMyTaskStatus(int tareaId, string estado)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (usuarioId <= 0)
            {
                return RedirectToAction("Login", "Account");
            }

            if (tareaId <= 0 || string.IsNullOrWhiteSpace(estado))
            {
                TempData["ErrorMessage"] = "La solicitud no es válida.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _employeesDbService.UpdateMyTaskStatusAsync(usuarioId, tareaId, estado);

                await RegistrarAuditoriaAsync(
                    "Actualizar mi tarea",
                    "Empleados",
                    $"El usuario #{usuarioId} actualizó la tarea #{tareaId} al estado {estado}.");

                TempData["SuccessMessage"] = "Tarea actualizada correctamente.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible actualizar la tarea.";
            }

            return RedirectToAction(nameof(Index));
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
