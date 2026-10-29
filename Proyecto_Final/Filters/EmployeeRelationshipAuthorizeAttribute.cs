using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Filters;

public sealed class EmployeeRelationshipAuthorizeAttribute : TypeFilterAttribute
{
    public EmployeeRelationshipAuthorizeAttribute() : base(typeof(EmployeeRelationshipAuthorizeFilter))
    {
    }
}

public sealed class EmployeeRelationshipAuthorizeFilter : IAsyncAuthorizationFilter
{
    private readonly AdminDbService _adminDbService;

    public EmployeeRelationshipAuthorizeFilter(AdminDbService adminDbService)
    {
        _adminDbService = adminDbService;
    }

    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var userId = context.HttpContext.Session.GetInt32("UserId");
        if (!userId.HasValue || userId.Value <= 0)
        {
            context.Result = new RedirectToActionResult("Login", "Account", null);
            return;
        }

        if (!await _adminDbService.IsEmployeeUserAsync(userId.Value))
            context.Result = AuthorizationResults.AccessDenied();
    }
}
