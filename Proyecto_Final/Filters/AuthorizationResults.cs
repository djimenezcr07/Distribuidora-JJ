using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Proyecto_Final.Filters;

/// <summary>
/// Creates the single, user-safe response used when an authenticated user is not authorized.
/// </summary>
public static class AuthorizationResults
{
    public static ViewResult AccessDenied() => new()
    {
        ViewName = "~/Views/Account/AccesoDenegado.cshtml",
        StatusCode = StatusCodes.Status403Forbidden
    };
}
