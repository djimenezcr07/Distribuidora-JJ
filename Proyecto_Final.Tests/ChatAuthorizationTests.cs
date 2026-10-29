using Moq;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class ChatAuthorizationTests
{
    [Fact]
    public async Task ConversationAccess_IsDeniedForNonMember()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.IsConversationMemberAsync(12, 44)).ReturnsAsync(false);
        var authorization = new ChatAuthorizationService(repository.Object, Mock.Of<IRolePermissionService>());

        Assert.False(await authorization.CanAccessConversationAsync(44, 12));
    }

    [Fact]
    public async Task ConversationAccess_IsAllowedForMember()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.IsConversationMemberAsync(12, 44)).ReturnsAsync(true);
        var authorization = new ChatAuthorizationService(repository.Object, Mock.Of<IRolePermissionService>());

        Assert.True(await authorization.CanAccessConversationAsync(44, 12));
    }

    [Fact]
    public async Task DepartmentAccess_UsesExplicitMembershipForEmployee()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.IsDepartmentMemberAsync(3, 8, false)).ReturnsAsync(true);
        var authorization = new ChatAuthorizationService(repository.Object, Mock.Of<IRolePermissionService>());

        Assert.True(await authorization.CanAccessDepartmentAsync(8, "Empleado", 3));
        repository.Verify(service => service.IsDepartmentMemberAsync(3, 8, false), Times.Once);
    }

    [Fact]
    public async Task DepartmentPost_PassesAdministrativeScopeForConfiguredPermission()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.CanPostToDepartmentAsync(5, 1, true)).ReturnsAsync(true);
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.HasCodePermissionAsync("Delegado", "CHAT_DEPARTAMENTOS_GESTIONAR")).ReturnsAsync(true);
        var authorization = new ChatAuthorizationService(repository.Object, permissions.Object);

        Assert.True(await authorization.CanPostToDepartmentAsync(1, "Delegado", 5));
        repository.Verify(service => service.CanPostToDepartmentAsync(5, 1, true), Times.Once);
    }

    [Fact]
    public void MessagePolicy_RejectsEmptyAndOversizedContent()
    {
        Assert.False(ChatMessagePolicy.TryNormalize("   ", out _, out _));
        Assert.False(ChatMessagePolicy.TryNormalize(new string('x', 1001), out _, out _));
    }

    [Fact]
    public void MessagePolicy_PreservesUserTextForSafeTextRendering()
    {
        Assert.True(ChatMessagePolicy.TryNormalize("  <script>alert(1)</script>  ", out var normalized, out _));
        Assert.Equal("<script>alert(1)</script>", normalized);
    }
}
