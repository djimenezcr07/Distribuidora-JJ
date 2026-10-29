using Microsoft.AspNetCore.SignalR;
using Proyecto_Final.Services;

namespace Proyecto_Final.Hubs
{
    public sealed class ChatHub : Hub
    {
        private readonly IChatAuthorizationService _authorization;
        private readonly ILogger<ChatHub> _logger;

        public ChatHub(IChatAuthorizationService authorization, ILogger<ChatHub> logger)
        {
            _authorization = authorization;
            _logger = logger;
        }

        public override async Task OnConnectedAsync()
        {
            if (CurrentUserId() <= 0)
            {
                Context.Abort();
                return;
            }

            await base.OnConnectedAsync();
        }

        public async Task JoinConversation(int conversationId)
        {
            var userId = CurrentUserId();
            if (!await _authorization.CanAccessConversationAsync(userId, conversationId))
            {
                _logger.LogWarning(
                    "El usuario {UserId} intentó unirse sin autorización a la conversación {ConversationId}.",
                    userId,
                    conversationId);
                throw new HubException("No tiene acceso a la conversación.");
            }

            await Groups.AddToGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));
        }

        public Task LeaveConversation(int conversationId) =>
            Groups.RemoveFromGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));

        public async Task JoinDepartment(int departmentId)
        {
            var userId = CurrentUserId();
            var role = Context.GetHttpContext()?.Session.GetString("UserRole");
            if (!await _authorization.CanAccessDepartmentAsync(userId, role, departmentId))
            {
                _logger.LogWarning(
                    "El usuario {UserId} intentó unirse sin autorización al departamento {DepartmentId}.",
                    userId,
                    departmentId);
                throw new HubException("No tiene acceso al departamento.");
            }

            await Groups.AddToGroupAsync(Context.ConnectionId, DepartmentGroup(departmentId));
        }

        public Task LeaveDepartment(int departmentId) =>
            Groups.RemoveFromGroupAsync(Context.ConnectionId, DepartmentGroup(departmentId));

        public static string ConversationGroup(int conversationId) => $"chat-conversation-{conversationId}";

        public static string DepartmentGroup(int departmentId) => $"chat-department-{departmentId}";

        private int CurrentUserId() =>
            Context.GetHttpContext()?.Session.GetInt32("UserId") ?? 0;
    }
}
