using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Tests;

public sealed class DeliveryBoardTests
{
    [Fact]
    public void Controller_RequiresExactPermissionAndSnapshotAcceptsNoClientResourceId()
    {
        var controllerAttribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(
            typeof(DeliveryBoardController).GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)));
        Assert.Equal("ENTREGAS_TABLERO_VER", controllerAttribute.Arguments![1]);

        var snapshot = typeof(DeliveryBoardController).GetMethod(nameof(DeliveryBoardController.Snapshot))!;
        Assert.DoesNotContain(snapshot.GetParameters(), parameter =>
            parameter.Name!.Contains("id", StringComparison.OrdinalIgnoreCase));
        Assert.NotEmpty(snapshot.GetCustomAttributes(typeof(EnableRateLimitingAttribute), true));
    }
}
