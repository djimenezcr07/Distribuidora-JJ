using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Tests;

public sealed class ProductImageLifecycleSecurityTests
{
    [Fact]
    public void PublicImageEndpoint_IsReadOnlyAndAnonymous()
    {
        Assert.NotEmpty(typeof(ProductImagesController).GetCustomAttributes(typeof(AllowAnonymousAttribute),true));
        var methods=typeof(ProductImagesController).GetMethods().Where(method=>method.DeclaringType==typeof(ProductImagesController)).ToArray();
        Assert.Single(methods);
        Assert.NotEmpty(methods[0].GetCustomAttributes(typeof(HttpGetAttribute),true));
    }

    [Theory]
    [InlineData("Create","INVENTARIO_CREAR")]
    [InlineData("Edit","INVENTARIO_EDITAR")]
    [InlineData("RemoveImage","INVENTARIO_EDITAR")]
    [InlineData("DeletePermanent","INVENTARIO_ELIMINAR")]
    public void ImageMutations_RequireExactPermissionAndAntiforgery(string method,string permission)
    {
        var action=typeof(InventoryController).GetMethods().Single(candidate=>candidate.Name==method&&candidate.GetCustomAttributes(typeof(HttpPostAttribute),true).Any());
        var authorization=Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(action.GetCustomAttributes(typeof(AdminAuthorizeAttribute),true)));
        Assert.Equal(permission,authorization.Arguments![1]);
        Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute),true));
    }
}
