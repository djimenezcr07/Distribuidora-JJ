using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Creditos")]
    public class AccountsReceivableAdminController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<AccountsReceivableAdminController> _logger;

        public AccountsReceivableAdminController(
            AdminDbService adminDbService,
            ILogger<AccountsReceivableAdminController> logger)
        {
            _adminDbService = adminDbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(
            string? buscar,
            string? estadoCredito)
        {
            ViewBag.Buscar = buscar;
            ViewBag.EstadoCredito = estadoCredito;

            try
            {
                var cuentas = await _adminDbService
                    .GetClientCreditsAsync(buscar, estadoCredito);

                return View(cuentas);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No se pudieron cargar las cuentas por cobrar.");
                TempData["ErrorMessage"] =
                    "No fue posible cargar las cuentas por cobrar.";

                return View(new List<ClientCreditListItemViewModel>());
            }
        }

        [HttpGet]
        public async Task<IActionResult> Detail(int id)
        {
            if (id <= 0)
            {
                TempData["ErrorMessage"] =
                    "La cuenta por cobrar solicitada no es válida.";

                return RedirectToAction(nameof(Index));
            }

            try
            {
                var cuenta = await _adminDbService
                    .GetClientCreditDetailAsync(id);

                if (cuenta == null)
                {
                    TempData["ErrorMessage"] =
                        "No se encontró la cuenta por cobrar solicitada.";

                    return RedirectToAction(nameof(Index));
                }

                return View(cuenta);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No se pudo cargar la cuenta por cobrar {UserId}.", id);
                TempData["ErrorMessage"] =
                    "No fue posible cargar el detalle de la cuenta.";

                return RedirectToAction(nameof(Index));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateSettings(
            [Bind(Prefix = "SettingsForm")]
    ClientCreditSettingsViewModel settingsForm)
        {
            if (settingsForm.UsuarioId <= 0)
            {
                TempData["ErrorMessage"] = "El cliente seleccionado no es válido.";
                return RedirectToAction(nameof(Index));
            }

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise la configuración del crédito.";

                return RedirectToAction(
                    nameof(Detail),
                    new { id = settingsForm.UsuarioId });
            }

            try
            {
                await _adminDbService.UpdateClientCreditSettingsAsync(
                    settingsForm,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName") ?? "Administrador");

                TempData["SuccessMessage"] =
                    "La configuración del crédito se actualizó correctamente.";
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo actualizar la configuración de crédito del usuario {UserId}.", settingsForm.UsuarioId);
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }

            return RedirectToAction(
                nameof(Detail),
                new { id = settingsForm.UsuarioId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RegisterMovement(
            [Bind(Prefix = "MovementForm")]
    ClientCreditMovementFormViewModel movementForm)
        {
            if (movementForm.UsuarioId <= 0)
            {
                TempData["ErrorMessage"] = "El cliente seleccionado no es válido.";
                return RedirectToAction(nameof(Index));
            }

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise los datos del movimiento.";

                return RedirectToAction(
                    nameof(Detail),
                    new { id = movementForm.UsuarioId });
            }

            try
            {
                await _adminDbService.RegisterClientCreditMovementAsync(
                    movementForm,
                    HttpContext.Session.GetInt32("UserId"),
                    HttpContext.Session.GetString("UserFullName") ?? "Administrador");

                TempData["SuccessMessage"] =
                    "El movimiento se registró correctamente.";
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo registrar el movimiento de crédito del usuario {UserId}.", movementForm.UsuarioId);
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }

            return RedirectToAction(
                nameof(Detail),
                new { id = movementForm.UsuarioId });
        }
    }
    }
