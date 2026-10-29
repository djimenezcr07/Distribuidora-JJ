using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [SessionAuthorize]
    public class ProfileController : Controller
    {
        private readonly AccountDbService _accountDbService;

        public ProfileController(AccountDbService accountDbService)
        {
            _accountDbService = accountDbService;
        }

        [HttpGet]
        public async Task<IActionResult> Edit()
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId");

            if (usuarioId == null)
            {
                return RedirectToAction("Login", "Account");
            }

            var model = await _accountDbService.GetProfileAsync(usuarioId.Value);
            if (model == null)
            {
                TempData["ErrorMessage"] = "No fue posible cargar la informacion del perfil.";
                return RedirectToAction("Index", "Home");
            }

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(ProfileEditViewModel model)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId");

            if (usuarioId == null)
            {
                return RedirectToAction("Login", "Account");
            }

            model.NombreCompleto = model.NombreCompleto?.Trim() ?? string.Empty;
            model.Correo = model.Correo?.Trim() ?? string.Empty;
            model.Telefono = string.IsNullOrWhiteSpace(model.Telefono) ? null : model.Telefono.Trim();
            model.Direccion = string.IsNullOrWhiteSpace(model.Direccion) ? null : model.Direccion.Trim();

            ModelState.Clear();
            TryValidateModel(model);

            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise los datos ingresados e intente nuevamente.";
                return View(model);
            }

            try
            {
                if (await _accountDbService.EmailExistsForOtherUserAsync(model.Correo, usuarioId.Value))
                {
                    ModelState.AddModelError(nameof(model.Correo), "El correo indicado ya esta en uso.");
                    TempData["ErrorMessage"] = "No fue posible actualizar el perfil con ese correo.";
                    return View(model);
                }

                await _accountDbService.UpdateProfileAsync(usuarioId.Value, model);

                HttpContext.Session.SetString("UserFullName", model.NombreCompleto);
                HttpContext.Session.SetString("UserEmail", model.Correo);

                TempData["SuccessMessage"] = "Perfil actualizado correctamente.";

                return RedirectToAction(nameof(Edit));
            }
            catch (InvalidOperationException ex) when (ex.Message == "DuplicateEmail")
            {
                ModelState.AddModelError(nameof(model.Correo), "El correo indicado ya esta en uso.");
                TempData["ErrorMessage"] = "No fue posible actualizar el perfil con ese correo.";
                return View(model);
            }
            catch (Exception)
            {
                TempData["ErrorMessage"] = "No fue posible actualizar el perfil en este momento. Intente nuevamente.";
                return View(model);
            }
        }
    }
}
