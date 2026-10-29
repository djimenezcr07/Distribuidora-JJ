using Microsoft.AspNetCore.Mvc;
using System.Data;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Empleados")]
    public class EmployeesController : Controller
    {
        private readonly IEmployeesService _employeesDbService;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<EmployeesController> _logger;

        public EmployeesController(IEmployeesService employeesDbService, AdminDbService adminDbService, ILogger<EmployeesController> logger)
        {
            _employeesDbService = employeesDbService;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        [AdminAuthorize("Empleados", "EMPLEADOS_VER")]
        public async Task<IActionResult> Index(string? buscar, string? estado)
        {
            var model = new EmployeeFilterViewModel
            {
                Buscar = buscar,
                Estado = estado,
                Empleados = await _employeesDbService.GetEmployeesAsync(buscar, estado)
            };

            return View(model);
        }

        [HttpGet]
        [AdminAuthorize("Empleados", "EMPLEADOS_CREAR")]
        public async Task<IActionResult> Create()
        {
            var model = new EmployeeFormViewModel
            {
                Activo = true,
                FechaContratacion = DateTime.Today,
                RolesDisponibles = await _employeesDbService.GetEmployeeRoleSelectListAsync()
            };

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Empleados", "EMPLEADOS_CREAR")]
        public async Task<IActionResult> Create(EmployeeFormViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.Contrasena))
            {
                ModelState.AddModelError(nameof(model.Contrasena), "La contraseña es obligatoria para crear el empleado.");
            }

            if (model.Salario < 0)
            {
                ModelState.AddModelError(nameof(model.Salario), "El salario no puede ser negativo.");
            }

            if (!ModelState.IsValid)
            {
                model.RolesDisponibles = await _employeesDbService.GetEmployeeRoleSelectListAsync(model.PerfilId);
                return View(model);
            }

            try
            {
                var empleadoId = await _employeesDbService.CreateEmployeeAsync(
                    model,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Crear",
                    "Empleados",
                    $"Se registró el empleado {model.NombreCompleto} con identificador #{empleadoId}.");

                TempData["SuccessMessage"] = "Empleado registrado correctamente.";
                return RedirectToAction(nameof(Details), new { id = empleadoId });
            }
            catch (InvalidOperationException)
            {
                ModelState.AddModelError(string.Empty, "No se pudo registrar el empleado. Revise los datos e intente nuevamente.");
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No fue posible registrar el empleado.");
                ModelState.AddModelError(string.Empty, "Ocurrio un error al registrar el empleado. Intente nuevamente.");
            }

            model.RolesDisponibles = await _employeesDbService.GetEmployeeRoleSelectListAsync(model.PerfilId);
            return View(model);
        }

        [HttpGet]
        [AdminAuthorize("Empleados", "EMPLEADOS_EDITAR")]
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _employeesDbService.GetEmployeeFormByIdAsync(id);

            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el empleado solicitado.";
                return RedirectToAction(nameof(Index));
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Empleados", "EMPLEADOS_EDITAR")]
        public async Task<IActionResult> Edit(EmployeeFormViewModel model)
        {
            if (string.IsNullOrWhiteSpace(model.RowVersionBase64))
            {
                ModelState.AddModelError(nameof(model.RowVersionBase64), "La versión del expediente es obligatoria para editar.");
            }

            if (model.Salario < 0)
            {
                ModelState.AddModelError(nameof(model.Salario), "El salario no puede ser negativo.");
            }

            if (!ModelState.IsValid)
            {
                model.RolesDisponibles = await _employeesDbService.GetEmployeeRoleSelectListAsync(model.PerfilId);
                return View(model);
            }

            try
            {
                await _employeesDbService.UpdateEmployeeAsync(
                    model,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Editar",
                    "Empleados",
                    $"Se actualizó la información laboral del empleado {model.NombreCompleto}.");

                TempData["SuccessMessage"] = "Empleado actualizado correctamente.";
                return RedirectToAction(nameof(Details), new { id = model.EmpleadoId });
            }
            catch (DBConcurrencyException exception)
            {
                _logger.LogWarning(exception, "Conflicto de concurrencia al actualizar el empleado {EmployeeId}.", model.EmpleadoId);
                ModelState.AddModelError(string.Empty, "El expediente cambió mientras lo editaba. Recargue la página e intente nuevamente.");
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No fue posible actualizar el empleado {EmployeeId}.", model.EmpleadoId);
                ModelState.AddModelError(string.Empty, "Ocurrio un error al actualizar el empleado. Intente nuevamente.");
            }

            model.RolesDisponibles = await _employeesDbService.GetEmployeeRoleSelectListAsync(model.PerfilId);
            return View(model);
        }

        [HttpGet]
        [AdminAuthorize("Empleados", "EMPLEADOS_VER")]
        public async Task<IActionResult> Details(int id)
        {
            var model = await _employeesDbService.GetEmployeeDetailAsync(id);

            if (model == null)
            {
                TempData["ErrorMessage"] = "No se encontró el empleado solicitado.";
                return RedirectToAction(nameof(Index));
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Empleados", "EMPLEADOS_EDITAR")]
        public async Task<IActionResult> ToggleStatus(int empleadoId, string? buscar, string? estado)
        {
            if (empleadoId <= 0)
            {
                TempData["ErrorMessage"] = "La solicitud no es válida.";
                return RedirectToAction(nameof(Index), new { buscar, estado });
            }

            try
            {
                var nuevoEstado = await _employeesDbService.ToggleEmployeeStatusAsync(empleadoId);

                await RegistrarAuditoriaAsync(
                    nuevoEstado ? "Activar" : "Inactivar",
                    "Empleados",
                    $"Se cambió el estado del empleado #{empleadoId}. Nuevo estado: {(nuevoEstado ? "Activo" : "Inactivo")}.");

                TempData["SuccessMessage"] = nuevoEstado
                    ? "Empleado reactivado correctamente."
                    : "Empleado inactivado correctamente.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "Ocurrió un error al cambiar el estado del empleado.";
            }

            return RedirectToAction(nameof(Index), new { buscar, estado });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateTask(EmployeeTaskFormViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Debe completar correctamente los datos de la tarea.";
                return RedirectToAction(nameof(Details), new { id = model.EmpleadoId });
            }

            try
            {
                var tareaId = await _employeesDbService.CreateEmployeeTaskAsync(
                    model,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Asignar tarea",
                    "Empleados",
                    $"Se asignó la tarea #{tareaId} al empleado #{model.EmpleadoId}.");

                TempData["SuccessMessage"] = "Tarea asignada correctamente.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible asignar la tarea.";
            }

            return RedirectToAction(nameof(Details), new { id = model.EmpleadoId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateTaskStatus(EmployeeTaskStatusViewModel model)
        {
            if (model.TareaId <= 0 || model.EmpleadoId <= 0 || string.IsNullOrWhiteSpace(model.Estado))
            {
                TempData["ErrorMessage"] = "La solicitud no es válida.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _employeesDbService.UpdateEmployeeTaskStatusAsync(model.TareaId, model.Estado);

                await RegistrarAuditoriaAsync(
                    "Actualizar tarea",
                    "Empleados",
                    $"Se actualizó la tarea #{model.TareaId} al estado {model.Estado}.");

                TempData["SuccessMessage"] = "Estado de la tarea actualizado.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible actualizar la tarea.";
            }

            return RedirectToAction(nameof(Details), new { id = model.EmpleadoId });
        }

        [HttpGet]
        public async Task<IActionResult> LeaveRequests(string? estado)
        {
            ViewBag.Estado = estado;
            var requests = await _employeesDbService.GetEmployeeLeaveRequestsAsync(estado);
            return View(requests);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateLeaveRequest(EmployeeLeaveRequestDecisionViewModel model, string? estadoFiltro)
        {
            if (model.SolicitudId <= 0 || string.IsNullOrWhiteSpace(model.Estado))
            {
                TempData["ErrorMessage"] = "La solicitud no es válida.";
                return RedirectToAction(nameof(LeaveRequests), new { estado = estadoFiltro });
            }

            try
            {
                await _employeesDbService.UpdateEmployeeLeaveRequestStatusAsync(
                    model,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Resolver solicitud",
                    "Empleados",
                    $"Se actualizó la solicitud de días libres #{model.SolicitudId} al estado {model.Estado}.");

                TempData["SuccessMessage"] = "Solicitud actualizada correctamente.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible actualizar la solicitud.";
            }

            return RedirectToAction(nameof(LeaveRequests), new { estado = estadoFiltro });
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
