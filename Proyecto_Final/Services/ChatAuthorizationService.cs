namespace Proyecto_Final.Services
{
    public interface IChatAuthorizationService
    {
        Task<bool> CanAccessConversationAsync(int userId, int conversationId);
        Task<bool> CanAccessDepartmentAsync(int userId, string? role, int departmentId);
        Task<bool> CanPostToDepartmentAsync(int userId, string? role, int departmentId);
        Task<bool> CanManageAllDepartmentsAsync(string? role);
    }

    public sealed class ChatAuthorizationService : IChatAuthorizationService
    {
        private readonly IChatDbService _chatDbService;
        private readonly IRolePermissionService _permissionService;

        public ChatAuthorizationService(IChatDbService chatDbService, IRolePermissionService permissionService)
        {
            _chatDbService = chatDbService;
            _permissionService = permissionService;
        }

        public Task<bool> CanAccessConversationAsync(int userId, int conversationId)
        {
            if (userId <= 0 || conversationId <= 0)
            {
                return Task.FromResult(false);
            }

            return _chatDbService.IsConversationMemberAsync(conversationId, userId);
        }

        public async Task<bool> CanAccessDepartmentAsync(int userId, string? role, int departmentId)
        {
            if (userId <= 0 || departmentId <= 0)
            {
                return false;
            }

            return await _chatDbService.IsDepartmentMemberAsync(
                departmentId,
                userId,
                await CanManageAllDepartmentsAsync(role));
        }

        public async Task<bool> CanPostToDepartmentAsync(int userId, string? role, int departmentId)
        {
            if (userId <= 0 || departmentId <= 0)
            {
                return false;
            }

            return await _chatDbService.CanPostToDepartmentAsync(
                departmentId,
                userId,
                await CanManageAllDepartmentsAsync(role));
        }

        public async Task<bool> CanManageAllDepartmentsAsync(string? role) =>
            string.Equals(role, "Administrador", StringComparison.OrdinalIgnoreCase)
            || await _permissionService.HasCodePermissionAsync(role ?? string.Empty, "CHAT_DEPARTAMENTOS_GESTIONAR");
    }
}
