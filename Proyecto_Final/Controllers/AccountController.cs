using Proyecto_Final.Services.ChatV2;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    public class AccountController : Controller
    {
        private readonly AccountApiService _accountApiService;
        private readonly AdminDbService _adminDbService;
        private readonly IWorkspaceResolver _workspaceResolver;
        private readonly ILogger<AccountController> _logger;
        private readonly IOriginalLoginService _originalLogins;
        private readonly ChatV2Continuity? _chatContinuity;

        public AccountController(
            AccountApiService accountApiService,
            AdminDbService adminDbService,
            IWorkspaceResolver workspaceResolver,
            ILogger<AccountController> logger,
            IOriginalLoginService originalLogins,
            ChatV2Continuity? chatContinuity = null)
        {
            _accountApiService = accountApiService;
            _adminDbService = adminDbService;
            _workspaceResolver = workspaceResolver;
            _logger = logger;
            _originalLogins = originalLogins;
            _chatContinuity = chatContinuity;
        }

        [HttpGet]
        public async Task<IActionResult> Login(string? returnUrl = null)
        {
            if (!string.IsNullOrWhiteSpace(HttpContext.Session.GetString("UserEmail")))
            {
                return await RedirectAfterLoginAsync(returnUrl, HttpContext.Session.GetString("UserRole"));
            }

            ViewBag.ReturnUrl = SafeLocalReturnUrl(returnUrl);

            return View(new Proyecto_Final.Models.LoginViewModel
            {
                Email = string.Empty,
                Password = string.Empty
            });
        }

        [HttpGet]
        [SessionAuthorize]
        public IActionResult AccesoDenegado() => AuthorizationResults.AccessDenied();

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("authentication")]
        public async Task<IActionResult> Login(Proyecto_Final.Models.LoginViewModel model, string? returnUrl = null)
        {
            ViewBag.ReturnUrl = SafeLocalReturnUrl(returnUrl);
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            try
            {
                var response = await _accountApiService.LoginAsync(model);

                if (response == null || !response.Success || response.UserId is not > 0 || response.ProfileId is not > 0)
                {
                    ModelState.AddModelError(string.Empty, response?.Message ?? "No fue posible iniciar sesión.");
                    return View(model);
                }

                if (!Guid.TryParse(response.SecurityStamp, out var stamp) || stamp == Guid.Empty)
                    throw new InvalidOperationException("No se acreditó el contexto de autenticación.");
                // A successful account switch retires the previous login before
                // installing a new server-issued identity; it never adopts it.
                if (OriginalLoginSession.Read(HttpContext.Session) is { } previous)
                {
                    await _originalLogins.RevokeAsync(previous, HttpContext.RequestAborted);
                    _chatContinuity?.Purge(previous.LoginId);
                }
                var nonce = OriginalLoginSession.NewNonce();
                var login = await _originalLogins.CreateAsync(response.UserId.Value, response.ProfileId.Value,
                    stamp, OriginalLoginSession.Binding(HttpContext.Session.Id, nonce), HttpContext.RequestAborted);
                HttpContext.Session.Clear();
                HttpContext.Session.SetInt32("UserId", response.UserId ?? 0);
                HttpContext.Session.SetInt32("ProfileId", response.ProfileId!.Value);
                HttpContext.Session.SetString("UserEmail", response.Email ?? string.Empty);
                HttpContext.Session.SetString("UserFullName", response.FullName ?? string.Empty);
                HttpContext.Session.SetString("UserRole", response.Role ?? string.Empty);
                HttpContext.Session.SetString("SecurityStamp", response.SecurityStamp ?? string.Empty);
                OriginalLoginSession.Store(HttpContext.Session, login, nonce);

                TempData["LoginSuccess"] = $"Bienvenido, {response.FullName}.";
                return await RedirectAfterLoginAsync(returnUrl, response.Role);
            }
            catch (Exception exception)
            {
                _logger.LogError("Falló el inicio de sesión. Tipo {ExceptionType}; código SQL {SqlCode}.",
                    exception.GetType().Name, (exception as Microsoft.Data.SqlClient.SqlException)?.Number);
                ModelState.AddModelError(string.Empty, "No fue posible iniciar sesión en este momento. Intentá nuevamente.");
                return View(model);
            }
        }

        [HttpGet]
        public IActionResult Register()
        {
            if (!string.IsNullOrWhiteSpace(HttpContext.Session.GetString("UserEmail")))
            {
                return RedirectToAction("Index", "Home");
            }

            return View("Registro", new Proyecto_Final.Models.RegistroViewModel
            {
                FullName = string.Empty,
                Email = string.Empty,
                Password = string.Empty,
                ConfirmPassword = string.Empty
            });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Register(Proyecto_Final.Models.RegistroViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View("Registro", model);
            }

            try
            {
                var response = await _accountApiService.RegisterAsync(model);

                if (response == null || !response.Success)
                {
                    ModelState.AddModelError(string.Empty, response?.Message ?? "No fue posible completar el registro.");
                    return View("Registro", model);
                }

                await RegistrarAuditoriaAsync(
                    null,
                    model.FullName,
                    model.Email,
                    "Cliente",
                    "Registro",
                    "Usuarios",
                    $"Se registró una nueva cuenta de cliente para el correo {model.Email}.");

                TempData["SuccessMessage"] = "Tu cuenta fue creada correctamente. Ahora puedes iniciar sesión.";
                return RedirectToAction(nameof(Login));
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "No fue posible completar el registro en este momento. Intentá nuevamente.");
                return View("Registro", model);
            }
        }

        [HttpGet]
        public IActionResult ForgotPassword()
        {
            return View(new Proyecto_Final.Models.ForgotPasswordViewModel
            {
                Email = string.Empty
            });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("password-recovery")]
        public async Task<IActionResult> ForgotPassword(Proyecto_Final.Models.ForgotPasswordViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            try
            {
                var response = await _accountApiService.ForgotPasswordAsync(model);

                if (response == null || !response.Success)
                {
                    ModelState.AddModelError(string.Empty, response?.Message ?? "No fue posible procesar la solicitud.");
                    return View(model);
                }

                await RegistrarAuditoriaAsync(
                    null,
                    "Usuario no autenticado",
                    model.Email,
                    "No disponible",
                    "Recuperación de contraseña",
                    "Autenticación",
                    $"Se solicitó recuperación de contraseña para el correo {model.Email}.");

                TempData["SuccessMessage"] = response.Message ?? "Se procesó la recuperación de contraseña correctamente.";
                return RedirectToAction(nameof(Login));
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "No fue posible procesar la solicitud en este momento. Intentá nuevamente.");
                return View(model);
            }
        }

        [HttpGet]
        public IActionResult ResetPassword(string token, string email)
        {
            var model = new Proyecto_Final.Models.ResetPasswordViewModel
            {
                Token = token ?? string.Empty,
                Password = string.Empty,
                ConfirmPassword = string.Empty
            };

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("password-recovery")]
        public async Task<IActionResult> ResetPassword(Proyecto_Final.Models.ResetPasswordViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            try
            {
                var response = await _accountApiService.ResetPasswordAsync(model);

                if (response == null || !response.Success)
                {
                    ModelState.AddModelError(string.Empty, response?.Message ?? "No fue posible restablecer la contraseña.");
                    return View(model);
                }

                await RegistrarAuditoriaAsync(
                    null,
                    "Usuario no autenticado",
                    "No disponible",
                    "No disponible",
                    "Cambio de contraseña",
                    "Autenticación",
                    "Se restableció una contraseña mediante token de recuperación.");

                TempData["SuccessMessage"] = response.Message ?? "La contraseña se restableció correctamente.";
                return RedirectToAction(nameof(Login));
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "No fue posible restablecer la contraseña en este momento. Intentá nuevamente.");
                return View(model);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            try
            {
                if (OriginalLoginSession.Read(HttpContext.Session) is { } login)
                    await _originalLogins.RevokeAsync(login, HttpContext.RequestAborted);
            }
            catch (Exception exception)
            {
                _logger.LogError("No fue posible acreditar la revocación del login. Tipo {ExceptionType}; código SQL {SqlCode}.",
                    exception.GetType().Name, (exception as Microsoft.Data.SqlClient.SqlException)?.Number);
                return StatusCode(StatusCodes.Status503ServiceUnavailable,
                    "La sesión local se cerró, pero no fue posible confirmar su revocación. Intentá nuevamente más tarde.");
            }
            finally
            {
                if (OriginalLoginSession.Read(HttpContext.Session) is { } closedLogin) _chatContinuity?.Purge(closedLogin.LoginId);
                HttpContext.Session.Clear();
            }
            TempData["SuccessMessage"] = "Sesión cerrada correctamente.";
            return RedirectToAction("Index", "Home");
        }

        private async Task RegistrarAuditoriaAsync(int? usuarioId, string? usuarioNombre, string? usuarioCorreo, string? rol, string accion, string modulo, string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                usuarioId,
                usuarioNombre,
                usuarioCorreo,
                rol,
                accion,
                modulo,
                descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }

        private string? SafeLocalReturnUrl(string? returnUrl) => SafeLocalReturnUrl(Url, returnUrl);

        internal static string? SafeLocalReturnUrl(IUrlHelper url, string? returnUrl) =>
            !string.IsNullOrWhiteSpace(returnUrl) && url.IsLocalUrl(returnUrl) ? returnUrl : null;

        private async Task<IActionResult> RedirectAfterLoginAsync(string? returnUrl, string? role)
        {
            var localReturnUrl = SafeLocalReturnUrl(returnUrl);
            if (localReturnUrl is not null)
                return LocalRedirect(localReturnUrl);

            var destination = await _workspaceResolver.ResolveAsync(
                HttpContext.Session.GetInt32("UserId") ?? 0,
                role);
            return RedirectToAction(destination.Action, destination.Controller);
        }
    }
}
