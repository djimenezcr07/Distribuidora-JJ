using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class AssistantPermissionTests
{
    [Fact]
    public async Task ManagerWithoutFinancialPermissions_DoesNotReceiveFinancialCategory()
    {
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.HasCodePermissionAsync("Gerente", It.IsAny<string>()))
            .ReturnsAsync(false);
        permissions.Setup(service => service.HasModulePermissionAsync("Gerente", It.IsAny<string>()))
            .ReturnsAsync(false);
        var service = CreateService(permissions.Object);

        var categories = await service.GetAllowedCategoriesAsync("Gerente");

        Assert.DoesNotContain("financiero", categories);
    }

    [Fact]
    public async Task CustomRoleWithEffectivePermission_ReceivesMappedCategory()
    {
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.HasCodePermissionAsync("Analista", "REPORTES_VENTAS_VER"))
            .ReturnsAsync(true);
        permissions.Setup(service => service.HasCodePermissionAsync("Analista", It.Is<string>(code => code != "REPORTES_VENTAS_VER")))
            .ReturnsAsync(false);
        permissions.Setup(service => service.HasModulePermissionAsync("Analista", It.IsAny<string>()))
            .ReturnsAsync(false);
        var service = CreateService(permissions.Object);

        var categories = await service.GetAllowedCategoriesAsync("Analista");

        Assert.Contains("financiero", categories);
    }

    [Fact]
    public async Task Administrator_IsTheOnlyExplicitSuperuserBypass()
    {
        var permissions = new Mock<IRolePermissionService>(MockBehavior.Strict);
        var service = CreateService(permissions.Object);

        var categories = await service.GetAllowedCategoriesAsync("Administrador");

        Assert.Equal(6, categories.Count);
    }

    private static AssistantService CreateService(IRolePermissionService permissions)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = "Server=(localdb)\\MSSQLLocalDB;Database=AssistantTests;Integrated Security=true"
            })
            .Build();

        return new AssistantService(configuration, NullLogger<AssistantService>.Instance, permissions);
    }
}
