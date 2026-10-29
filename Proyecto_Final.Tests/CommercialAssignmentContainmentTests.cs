using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class CommercialAssignmentContainmentTests
{
    [Fact]
    public void Action_ExplainsUnavailableDependencyWithoutInvokingTheAction()
    {
        var action = new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor());
        var context = new ActionExecutingContext(action, [], new Dictionary<string, object?>(), new object());
        new CommercialAssignmentsRequiredAttribute().OnActionExecuting(context);
        var result = Assert.IsType<ViewResult>(context.Result);
        Assert.Equal(503, result.StatusCode);
        Assert.Equal("~/Views/Shared/CommercialAssignmentsUnavailable.cshtml", result.ViewName);
    }

    [Fact]
    public async Task Service_CannotUseLegacySqlToManufactureMissingAssignments()
    {
        // An invalid connection proves these failures occur before any SQL opening.
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:DefaultConnection"] = "not a valid SQL connection string" }).Build();
        var service = new AdminDbService(configuration, new PasswordHashService());
        await Assert.ThrowsAsync<CommercialAssignmentsUnavailableException>(() =>
            service.CreateSellerOrderAsync(new SellerOrderCreateViewModel(), 1, "Administrator"));
        await Assert.ThrowsAsync<CommercialAssignmentsUnavailableException>(() => service.GetSellerOrderClientsAsync());
        await Assert.ThrowsAsync<CommercialAssignmentsUnavailableException>(() => service.GetRetainedOrdersAsync(null));
        await Assert.ThrowsAsync<CommercialAssignmentsUnavailableException>(() => service.ApproveRetainedOrderAsync(1, 1, "Administrator"));
        await Assert.ThrowsAsync<CommercialAssignmentsUnavailableException>(() => service.RejectRetainedOrderAsync(1, "fixture", 1, "Administrator"));
    }
}
