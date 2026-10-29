using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;
using Proyecto_Final.Filters;
using Proyecto_Final.Hubs;
using Proyecto_Final.Models.Chat;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Chat", "CHAT_USAR")]
    public sealed class ChatController : Controller
    {
        private readonly IChatDbService _chat;
        private readonly IChatAuthorizationService _authorization;
        private readonly IHubContext<ChatHub> _hubContext;
        private readonly ILogger<ChatController> _logger;

        public ChatController(
            IChatDbService chat,
            IChatAuthorizationService authorization,
            IHubContext<ChatHub> hubContext,
            ILogger<ChatController> logger)
        {
            _chat = chat;
            _authorization = authorization;
            _hubContext = hubContext;
            _logger = logger;
        }

        [HttpGet]
        [AdminAuthorize("Chat", "CHAT_DEPARTAMENTOS_GESTIONAR")]
        public async Task<IActionResult> Index()
        {
            try
            {
                var departments =
                    await _chat.GetDepartmentsForAdministrationAsync();

                ViewBag.ChatUsers =
                    await _chat.GetUsersAsync(CurrentUserId());

                return View(departments);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No fue posible cargar la administración de departamentos de chat.");
                ViewBag.LoadError = "No fue posible cargar los departamentos en este momento. Inténtelo nuevamente.";
                ViewBag.ChatUsers = Array.Empty<ChatUserViewModel>();
                return View(Array.Empty<ChatDepartmentAdminViewModel>());
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetUsers()
        {
            var userId = CurrentUserId();
            if (userId <= 0)
            {
                return Unauthorized(ChatError("Debe iniciar sesión para utilizar el chat."));
            }

            try
            {
                return Json(new { success = true, users = await _chat.GetUsersAsync(userId) });
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "No se pudo listar usuarios de chat para el usuario {UserId}.", userId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> OpenConversation(int userId)
        {
            var currentUserId = CurrentUserId();
            if (currentUserId <= 0)
            {
                return Unauthorized(ChatError("Debe iniciar sesión para utilizar el chat."));
            }

            if (userId <= 0 || userId == currentUserId)
            {
                return BadRequest(ChatError("El usuario seleccionado no es válido."));
            }

            try
            {
                var conversationId = await _chat.GetOrCreateConversationAsync(currentUserId, userId);
                if (conversationId is not > 0)
                {
                    return BadRequest(ChatError("No puede iniciar una conversación con ese usuario."));
                }

                _logger.LogInformation(
                    "El usuario {UserId} abrió la conversación {ConversationId}.",
                    currentUserId,
                    conversationId);
                return Json(new { success = true, conversationId });
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al abrir una conversación para el usuario {UserId}.", currentUserId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("chat-send")]
        public async Task<IActionResult> SendMessage(int conversationId, string? content)
        {
            var userId = CurrentUserId();
            if (!ChatMessagePolicy.TryNormalize(content, out var normalized, out var validationError))
            {
                return BadRequest(ChatError(validationError));
            }

            if (!await _authorization.CanAccessConversationAsync(userId, conversationId))
            {
                return StatusCode(403, ChatError("No tiene acceso a la conversación."));
            }

            try
            {
                var message = await _chat.SendMessageAsync(conversationId, userId, normalized);
                if (message is null)
                {
                    return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
                }

                await _hubContext.Clients.Group(ChatHub.ConversationGroup(conversationId))
                    .SendAsync("ReceiveMessage", message);
                _logger.LogInformation(
                    "Mensaje {MessageId} enviado por el usuario {UserId} a la conversación {ConversationId}.",
                    message.MensajeId,
                    userId,
                    conversationId);
                return Json(new { success = true, message });
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Error al enviar un mensaje del usuario {UserId} a la conversación {ConversationId}.",
                    userId,
                    conversationId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetMessages(int conversationId, int page = 1, int pageSize = 50)
        {
            var userId = CurrentUserId();
            if (!await _authorization.CanAccessConversationAsync(userId, conversationId))
            {
                return StatusCode(403, ChatError("No tiene acceso a la conversación."));
            }

            try
            {
                var messages = await _chat.GetMessagesAsync(conversationId, userId, page, pageSize);
                return Json(new { success = true, currentUserId = userId, page = Math.Max(page, 1), messages });
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Error al consultar la conversación {ConversationId} para el usuario {UserId}.",
                    conversationId,
                    userId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetDepartments()
        {
            var userId = CurrentUserId();
            try
            {
                var departments = await _chat.GetDepartmentsAsync(
                    userId,
                    await _authorization.CanManageAllDepartmentsAsync(CurrentRole()));
                return Json(new { success = true, departments });
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al listar departamentos del usuario {UserId}.", userId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("chat-send")]
        public async Task<IActionResult> SendDepartmentMessage(int departmentId, string? content)
        {
            var userId = CurrentUserId();
            if (!ChatMessagePolicy.TryNormalize(content, out var normalized, out var validationError))
            {
                return BadRequest(ChatError(validationError));
            }

            if (!await _authorization.CanPostToDepartmentAsync(userId, CurrentRole(), departmentId))
            {
                return StatusCode(403, ChatError("No tiene permiso para publicar en el departamento."));
            }

            try
            {
                var message = await _chat.SendDepartmentMessageAsync(
                    departmentId,
                    userId,
                    normalized,
                    await _authorization.CanManageAllDepartmentsAsync(CurrentRole()));
                if (message is null)
                {
                    return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
                }

                await _hubContext.Clients.Group(ChatHub.DepartmentGroup(departmentId))
                    .SendAsync("ReceiveDepartmentMessage", message);
                _logger.LogInformation(
                    "Mensaje departamental {MessageId} enviado por {UserId} al departamento {DepartmentId}.",
                    message.MensajeId,
                    userId,
                    departmentId);
                return Json(new { success = true, message });
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Error al enviar mensaje departamental del usuario {UserId} al departamento {DepartmentId}.",
                    userId,
                    departmentId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetDepartmentMessages(int departmentId, int page = 1, int pageSize = 50)
        {
            var userId = CurrentUserId();
            if (!await _authorization.CanAccessDepartmentAsync(userId, CurrentRole(), departmentId))
            {
                return StatusCode(403, ChatError("No tiene acceso al departamento."));
            }

            try
            {
                var messages = await _chat.GetDepartmentMessagesAsync(
                    departmentId,
                    userId,
                    await _authorization.CanManageAllDepartmentsAsync(CurrentRole()),
                    page,
                    pageSize);
                return Json(new { success = true, currentUserId = userId, page = Math.Max(page, 1), messages });
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Error al consultar el departamento {DepartmentId} para el usuario {UserId}.",
                    departmentId,
                    userId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("chat-search")]
        public async Task<IActionResult> Search(ChatSearchRequest request)
        {
            var userId = CurrentUserId();
            request.Query = request.Query?.Trim() ?? string.Empty;
            request.Page = Math.Max(request.Page, 1);
            request.PageSize = Math.Clamp(request.PageSize <= 0 ? 25 : request.PageSize, 1, 100);

            if (!ModelState.IsValid || request.Query.Length < 2)
            {
                return BadRequest(ChatError("Escriba al menos dos caracteres para buscar."));
            }

            if (request.ConversationId is > 0 &&
                !await _authorization.CanAccessConversationAsync(userId, request.ConversationId.Value))
            {
                return StatusCode(403, ChatError("No tiene acceso a la conversación indicada."));
            }

            if (request.DepartmentId is > 0 &&
                !await _authorization.CanAccessDepartmentAsync(userId, CurrentRole(), request.DepartmentId.Value))
            {
                return StatusCode(403, ChatError("No tiene acceso al departamento indicado."));
            }

            try
            {
                var results = await _chat.SearchMessagesAsync(
                    userId,
                    await _authorization.CanManageAllDepartmentsAsync(CurrentRole()),
                    request);
                return Json(new
                {
                    success = true,
                    page = request.Page,
                    pageSize = request.PageSize,
                    total = results.FirstOrDefault()?.TotalResults ?? 0,
                    results
                });
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al buscar en el historial autorizado del usuario {UserId}.", userId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, ChatError("El chat no está disponible temporalmente."));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Chat", "CHAT_DEPARTAMENTOS_GESTIONAR")]
        public async Task<IActionResult> CreateDepartment(ChatDepartmentFormViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["ErrorMessage"] = "Revise el nombre y la descripción del departamento.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _chat.CreateDepartmentAsync(model, CurrentUserId());
                TempData["SuccessMessage"] = "Departamento de chat creado.";
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al crear un departamento de chat.");
                TempData["ErrorMessage"] = "No fue posible crear el departamento.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Chat", "CHAT_DEPARTAMENTOS_GESTIONAR")]
        public async Task<IActionResult> UpdateDepartment(ChatDepartmentFormViewModel model)
        {
            if (!ModelState.IsValid || model.DepartmentId <= 0)
            {
                TempData["ErrorMessage"] = "Los datos del departamento no son válidos.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _chat.UpdateDepartmentAsync(model, CurrentUserId());
                TempData["SuccessMessage"] = "Departamento actualizado.";
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al actualizar el departamento {DepartmentId}.", model.DepartmentId);
                TempData["ErrorMessage"] = "No fue posible actualizar el departamento.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Chat", "CHAT_DEPARTAMENTOS_GESTIONAR")]
        public async Task<IActionResult> AddMember(int departmentId, int userId, bool canPost = true)
        {
            if (departmentId <= 0 || userId <= 0)
            {
                TempData["ErrorMessage"] = "El departamento o usuario no es válido.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _chat.AddDepartmentMemberAsync(departmentId, userId, canPost, CurrentUserId());
                TempData["SuccessMessage"] = "Miembro agregado o actualizado.";
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al agregar el usuario {UserId} al departamento {DepartmentId}.", userId, departmentId);
                TempData["ErrorMessage"] = "No fue posible agregar el miembro.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Chat", "CHAT_DEPARTAMENTOS_GESTIONAR")]
        public async Task<IActionResult> RemoveMember(int departmentId, int userId)
        {
            if (departmentId <= 0 || userId <= 0)
            {
                TempData["ErrorMessage"] = "El departamento o usuario no es válido.";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _chat.RemoveDepartmentMemberAsync(departmentId, userId, CurrentUserId());
                TempData["SuccessMessage"] = "Miembro retirado.";
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al retirar el usuario {UserId} del departamento {DepartmentId}.", userId, departmentId);
                TempData["ErrorMessage"] = "No fue posible retirar el miembro.";
            }

            return RedirectToAction(nameof(Index));
        }

        private int CurrentUserId() => HttpContext.Session.GetInt32("UserId") ?? 0;
        private string? CurrentRole() => HttpContext.Session.GetString("UserRole");

        private static object ChatError(string message) => new { success = false, message };

    }
}
