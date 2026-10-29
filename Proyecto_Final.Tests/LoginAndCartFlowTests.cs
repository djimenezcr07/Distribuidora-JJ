using Microsoft.AspNetCore.Mvc;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class LoginAndCartFlowTests
{
    [Fact]
    public async Task Administrator_DefaultLanding_IsAdministrativeWorkspace()
    {
        var destination = await CreateResolver([]).ResolveAsync(42, "Administrador");

        Assert.Equal("Admin", destination.Controller);
        Assert.Equal("Index", destination.Action);
    }

    [Theory]
    [InlineData("Cliente", null, "Home")]
    [InlineData("Vendedor", "VENTA_MOVIL_CREAR", "SellerOrders")]
    [InlineData("Chofer", null, "DriverDeliveries")]
    [InlineData("Compras", "COMPRAS_ORDENES_VER", "PurchaseOrders")]
    [InlineData("Gerente", "REPORTES_DASHBOARD", "ManagementDashboard")]
    [InlineData("Supervisor", "EMPLEADOS_VER", "Employees")]
    [InlineData("Rol Personalizado", "LIQUIDACION_FINANCIERA", "Finance")]
    public async Task CriticalProfiles_ResolveAuthorizedWorkspace(string role, string? permission, string expectedController)
    {
        var destination = await CreateResolver(permission is null ? [] : [permission]).ResolveAsync(42, role);

        Assert.Equal(expectedController, destination.Controller);
        Assert.Equal("Index", destination.Action);
    }

    [Fact]
    public async Task RoleWithoutSpecializedWorkspace_FallsBackToHome()
    {
        var destination = await CreateResolver([]).ResolveAsync(42, "Rol sin permisos");
        Assert.Equal("Home", destination.Controller);
    }

    [Fact]
    public async Task GenericEmployee_WithRelationship_UsesEmployeePortal()
    {
        var destination = await CreateResolver([], isEmployee: true).ResolveAsync(42, "Empleado");
        Assert.Equal("EmployeePortal", destination.Controller);
    }

    [Theory]
    [InlineData("Facturador", "Facturacion", "Billing")]
    [InlineData("Crédito y Cobro", "Creditos", "AccountsReceivableAdmin")]
    [InlineData("Auditor Interno", "Auditoria", "Audit")]
    public async Task OperationalProfiles_UseExistingModuleWorkspace(string role, string module, string expectedController)
    {
        var destination = await CreateResolver([], module: module).ResolveAsync(42, role);
        Assert.Equal(expectedController, destination.Controller);
    }

    [Theory]
    [InlineData(1, 0, 0)]
    [InlineData(5, -1, 0)]
    [InlineData(0, 8, 1)]
    [InlineData(10, 8, 8)]
    [InlineData(3, 8, 3)]
    public void CartQuantity_NeverCreatesValidQuantityWithoutStock(int requested, int stock, int expected) =>
        Assert.Equal(expected, CartQuantity.ClampToAvailableStock(requested, stock));

    [Fact]
    public void ExplicitLocalReturnUrl_IsAccepted()
    {
        var url = new Mock<IUrlHelper>();
        url.Setup(helper => helper.IsLocalUrl("/Cart/Checkout")).Returns(true);

        Assert.Equal("/Cart/Checkout", AccountController.SafeLocalReturnUrl(url.Object, "/Cart/Checkout"));
    }

    [Fact]
    public void ExternalReturnUrl_IsRejected()
    {
        var malicious = "https://attacker.example/phishing";
        var url = new Mock<IUrlHelper>();
        url.Setup(helper => helper.IsLocalUrl(malicious)).Returns(false);

        Assert.Null(AccountController.SafeLocalReturnUrl(url.Object, malicious));
    }

    private static WorkspaceResolver CreateResolver(IEnumerable<string> codes, bool isEmployee = false, string? module = null)
    {
        var permissionSet = new HashSet<string>(codes, StringComparer.OrdinalIgnoreCase);
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.GetPermissionCodesAsync(It.IsAny<string?>())).ReturnsAsync(permissionSet);
        permissions.Setup(service => service.HasModulePermissionAsync(It.IsAny<string?>(), It.IsAny<string>()))
            .ReturnsAsync((string? _, string requestedModule) => string.Equals(module, requestedModule, StringComparison.OrdinalIgnoreCase));
        var relationship = new Mock<IEmployeeRelationshipService>();
        relationship.Setup(service => service.IsEmployeeAsync(It.IsAny<int>())).ReturnsAsync(isEmployee);
        return new WorkspaceResolver(permissions.Object, relationship.Object);
    }
}
