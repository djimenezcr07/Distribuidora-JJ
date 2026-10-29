using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Hubs;
using Proyecto_Final.Models.Chat;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class ChatPresentationStateTests
{
    [Fact]
    public async Task DepartmentLoadFailure_HasExplicitErrorWithoutExposingException()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.GetDepartmentsForAdministrationAsync()).ThrowsAsync(new Exception("private detail"));
        var controller = Create(repository.Object);
        var result = Assert.IsType<ViewResult>(await controller.Index());
        Assert.Empty(Assert.IsAssignableFrom<IReadOnlyList<ChatDepartmentAdminViewModel>>(result.Model));
        var message = Assert.IsType<string>(controller.ViewData["LoadError"]);
        Assert.DoesNotContain("private detail", message);
        repository.Verify(service => service.GetUsersAsync(It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public async Task SuccessfulEmptyDepartmentList_IsNotALoadError()
    {
        var repository = new Mock<IChatDbService>();
        repository.Setup(service => service.GetDepartmentsForAdministrationAsync()).ReturnsAsync([]);
        repository.Setup(service => service.GetUsersAsync(It.IsAny<int>())).ReturnsAsync([]);
        var controller = Create(repository.Object);
        var result = Assert.IsType<ViewResult>(await controller.Index());
        Assert.Empty(Assert.IsAssignableFrom<IReadOnlyList<ChatDepartmentAdminViewModel>>(result.Model));
        Assert.Null(controller.ViewData["LoadError"]);
    }

    private static ChatController Create(IChatDbService repository) => new(repository,
        Mock.Of<IChatAuthorizationService>(), Mock.Of<IHubContext<ChatHub>>(), NullLogger<ChatController>.Instance)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { Session = Mock.Of<ISession>() } }
    };
}
