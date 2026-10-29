using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Proyecto_Final.Filters
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public class SessionAuthorizeAttribute : Attribute, IAuthorizationFilter
    {
        private readonly string[] _allowedRoles;

        public SessionAuthorizeAttribute(params string[] allowedRoles)
        {
            _allowedRoles = allowedRoles ?? Array.Empty<string>();
        }

        public void OnAuthorization(AuthorizationFilterContext context)
        {
            var session = context.HttpContext.Session;
            var userId = session.GetInt32("UserId");
            var userEmail = session.GetString("UserEmail");
            var userRole = session.GetString("UserRole");

            if (!userId.HasValue || userId.Value <= 0 || string.IsNullOrWhiteSpace(userEmail))
            {
                context.Result = new RedirectToActionResult("Login", "Account", null);
                return;
            }

            if (_allowedRoles.Length == 0)
            {
                return;
            }

            var roleAllowed = _allowedRoles.Any(role =>
                string.Equals(role, userRole, StringComparison.OrdinalIgnoreCase));

            if (!roleAllowed)
            {
                context.Result = AuthorizationResults.AccessDenied();
            }
        }
    }
}
