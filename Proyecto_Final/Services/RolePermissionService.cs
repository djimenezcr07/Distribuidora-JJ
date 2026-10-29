namespace Proyecto_Final.Services;

public sealed class RolePermissionService(AdminDbService adminDbService) : IRolePermissionService
{
    public Task<bool> HasModulePermissionAsync(string? roleName, string module) =>
        adminDbService.TienePermisoPorRolAsync(roleName, module);

    public Task<bool> HasCodePermissionAsync(string roleName, string permissionCode) =>
        adminDbService.TienePermisoCodigoPorRolAsync(roleName, permissionCode);

    public Task<HashSet<string>> GetPermissionCodesAsync(string? roleName) =>
        adminDbService.GetPermissionCodesByRoleAsync(roleName);
}
