using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Controllers.Admin;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Tests;

public sealed class ControllerSecurityTests
{
    [Theory]
    [InlineData(typeof(ClientPortalController))]
    [InlineData(typeof(DriverDeliveriesController))]
    [InlineData(typeof(AssistantController))]
    public void ProtectedControllers_HaveSessionAuthorization(Type controllerType)
    {
        Assert.NotNull(controllerType.GetCustomAttributes(typeof(SessionAuthorizeAttribute), true).SingleOrDefault());
    }

    [Fact]
    public void WarrantyAdministration_HasAdministrativeAuthorization()
    {
        Assert.NotNull(typeof(WarrantyRequestsAdminController)
            .GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)
            .SingleOrDefault());
    }

    [Theory]
    [InlineData(typeof(ChatController), "SendMessage")]
    [InlineData(typeof(ChatController), "SendDepartmentMessage")]
    [InlineData(typeof(AssistantController), "Ask")]
    [InlineData(typeof(DriverDeliveriesController), "RegisterEvidence")]
    [InlineData(typeof(WarrantyRequestsAdminController), "UpdateStatus")]
    public void MutatingActions_RequireAntiforgery(Type controllerType, string methodName)
    {
        var method = controllerType.GetMethod(methodName);
        Assert.NotNull(method);
        Assert.NotNull(method!.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true).SingleOrDefault());
    }
}
