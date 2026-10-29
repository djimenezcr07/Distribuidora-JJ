using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class CheckoutConfirmationOwnershipTests
{
    [Theory]
    [InlineData(false, false, true)]
    [InlineData(true, false, false)]
    [InlineData(false, true, false)]
    public void ReceiptBelongsToTheExactOriginalLogin(bool newSession, bool differentActor, bool allowed)
    {
        var now = DateTime.UtcNow;
        var login = new OriginalLoginContext(Guid.NewGuid(), 7, 2, Guid.NewGuid(), now, now.AddHours(8), Enumerable.Repeat((byte)1, 32).ToArray());
        var context = new DefaultHttpContext();
        context.Items[OriginalLoginSession.ValidatedContextItem] = login;
        var controller = Controller(context);
        controller.TempData["OrderConfirmation"] = JsonSerializer.Serialize(new OrderConfirmationViewModel
        {
            PedidoId = 11, OwnerLoginId = newSession ? Guid.NewGuid() : login.LoginId,
            OwnerUserId = differentActor ? 8 : login.UserId,
            Amounts = new(.45m, .05m, .40m, .05m, .45m)
        });
        var result = controller.Confirmation();
        if (allowed) Assert.Equal(.40m, Assert.IsType<OrderConfirmationViewModel>(Assert.IsType<ViewResult>(result).Model).Amounts!.Net);
        else Assert.IsType<RedirectToActionResult>(result);
    }

    [Theory]
    [InlineData("{invalid")]
    [InlineData("{\"PedidoId\":11,\"Total\":123}")]
    public void AnonymousOrUnboundReceiptNeverRendersPrivateContent(string raw)
    {
        var controller = Controller(new DefaultHttpContext());
        controller.TempData["OrderConfirmation"] = raw;
        Assert.IsType<RedirectToActionResult>(controller.Confirmation());
    }

    private static CartController Controller(DefaultHttpContext context) => new(null!, null!, null!, null!, null!, NullLogger<CartController>.Instance)
    {
        ControllerContext = new() { HttpContext = context },
        TempData = new TempDataDictionary(context, Mock.Of<ITempDataProvider>())
    };
}
