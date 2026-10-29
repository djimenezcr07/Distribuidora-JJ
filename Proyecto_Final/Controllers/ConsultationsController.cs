using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Consultas", "CONSULTAS_VER")]
    public class ConsultationsController : Controller
    {
        private readonly AdminDbService _adminDbService;

        public ConsultationsController(AdminDbService adminDbService)
        {
            _adminDbService = adminDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado, string? buscar)
        {
            var consultas = await _adminDbService.GetConsultationsAsync(estado, buscar);

            var model = new ConsultationFilterViewModel
            {
                Estado = estado,
                Buscar = buscar,
                Consultas = consultas
            };

            return View(model);
        }

        [HttpGet]
        public async Task<IActionResult> Details(int id)
        {
            var consulta = await _adminDbService.GetConsultationByIdAsync(id);

            if (consulta == null)
            {
                TempData["ErrorMessage"] = "No se encontró la consulta solicitada.";
                return RedirectToAction(nameof(Index));
            }

            return View(consulta);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Consultas", "CONSULTAS_ATENDER")]
        public async Task<IActionResult> UpdateStatus(ConsultationUpdateStatusViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revisá el estado y la observación ingresada.";
                return RedirectToAction(nameof(Details), new { id = model.ConsultaId });
            }

            try
            {
                await _adminDbService.UpdateConsultationStatusAsync(
                    model.ConsultaId,
                    model.Estado,
                    model.RespuestaInterna,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName"));

                await RegistrarAuditoriaAsync(
                    "Actualizar consulta",
                    "Consultas",
                    $"Se actualizó la consulta #{model.ConsultaId} al estado {model.Estado}.");

                TempData["SuccessMessage"] = "Consulta actualizada correctamente.";
            }
            catch (InvalidOperationException)
            {
                TempData["ErrorMessage"] = "No se pudo actualizar la consulta.";
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "Ocurrió un error al actualizar la consulta.";
            }

            return RedirectToAction(nameof(Details), new { id = model.ConsultaId });
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
