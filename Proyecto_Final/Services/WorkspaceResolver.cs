namespace Proyecto_Final.Services;

public sealed record WorkspaceDestination(string Action, string Controller);

public interface IEmployeeRelationshipService
{
    Task<bool> IsEmployeeAsync(int userId);
}

public sealed class EmployeeRelationshipService(AdminDbService adminDbService) : IEmployeeRelationshipService
{
    public Task<bool> IsEmployeeAsync(int userId) => adminDbService.IsEmployeeUserAsync(userId);
}

public interface IWorkspaceResolver
{
    Task<WorkspaceDestination> ResolveAsync(int userId, string? roleName);
}

public sealed class WorkspaceResolver(
    IRolePermissionService permissionService,
    IEmployeeRelationshipService employeeRelationship) : IWorkspaceResolver
{
    private static readonly WorkspaceDestination Home = new("Index", "Home");

    public async Task<WorkspaceDestination> ResolveAsync(int userId, string? roleName)
    {
        var role = roleName?.Trim() ?? string.Empty;
        if (string.Equals(role, "Administrador", StringComparison.OrdinalIgnoreCase))
            return new("Index", "Admin");
        if (string.Equals(role, "Cliente", StringComparison.OrdinalIgnoreCase))
            return Home;

        var permissions = await permissionService.GetPermissionCodesAsync(role);
        if (permissions.Contains("VENTA_MOVIL_CREAR")) return new("Index", "SellerOrders");
        if (string.Equals(role, "Chofer", StringComparison.OrdinalIgnoreCase)) return new("Index", "DriverDeliveries");
        if (permissions.Contains("INVENTARIO_VER")) return new("Index", "Inventory");
        if (permissions.Contains("COMPRAS_ORDENES_VER")) return new("Index", "PurchaseOrders");
        if (permissions.Contains("REPORTES_DASHBOARD")) return new("Index", "ManagementDashboard");
        if (permissions.Contains("LIQUIDACION_FINANCIERA")) return new("Index", "Finance");
        if (permissions.Contains("EMPLEADOS_VER")) return new("Index", "Employees");
        if (permissions.Contains("CONSULTAS_VER")) return new("Index", "Consultations");

        if (await permissionService.HasModulePermissionAsync(role, "Facturacion")) return new("Index", "Billing");
        if (await permissionService.HasModulePermissionAsync(role, "Creditos")) return new("Index", "AccountsReceivableAdmin");
        if (await permissionService.HasModulePermissionAsync(role, "Auditoria")) return new("Index", "Audit");
        if (await permissionService.HasModulePermissionAsync(role, "Pedidos")) return new("Index", "OrdersAdmin");
        if (userId > 0 && await employeeRelationship.IsEmployeeAsync(userId)) return new("Index", "EmployeePortal");

        return Home;
    }
}
