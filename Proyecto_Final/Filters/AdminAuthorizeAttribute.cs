using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.Controllers;
using Proyecto_Final.Services;

namespace Proyecto_Final.Filters
{
    public class AdminAuthorizeAttribute : TypeFilterAttribute
    {
        public AdminAuthorizeAttribute(string modulo, string? permisoCodigo = null, bool allowAdministratorBypass = true) : base(typeof(AdminAuthorizeFilter))
        {
            Arguments = new object[] { modulo, permisoCodigo ?? string.Empty, allowAdministratorBypass };
        }
    }

    public class AdminAuthorizeFilter : IAsyncAuthorizationFilter
    {
        private readonly string _modulo;
        private readonly string? _permisoCodigo;
        private readonly IRolePermissionService _permissionService;
        private readonly bool _allowAdministratorBypass;

        public AdminAuthorizeFilter(string modulo, string? permisoCodigo, IRolePermissionService permissionService, bool allowAdministratorBypass = true)
        {
            _modulo = modulo;
            _permisoCodigo = permisoCodigo;
            _permissionService = permissionService;
            _allowAdministratorBypass = allowAdministratorBypass;
        }

        public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
        {
            var userId = context.HttpContext.Session.GetInt32("UserId");
            var userEmail = context.HttpContext.Session.GetString("UserEmail");
            var userRole = context.HttpContext.Session.GetString("UserRole");

            if (!userId.HasValue || userId.Value <= 0 || string.IsNullOrWhiteSpace(userEmail))
            {
                context.Result = new RedirectToActionResult("Login", "Account", null);
                return;
            }

            if (_allowAdministratorBypass && string.Equals(userRole, "Administrador", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            // Una política declarada directamente en la acción reemplaza la política
            // general del controlador. Así, por ejemplo, REPORTE_KPI no requiere además
            // METAS_GESTIONAR. La propia instancia del filtro de acción se evalúa después.
            if (IsOverriddenByActionPolicy(context))
                return;

            var tienePermiso = !_allowAdministratorBypass
                ? !string.IsNullOrWhiteSpace(_permisoCodigo)
                    && (await _permissionService.GetPermissionCodesAsync(userRole)).Contains(_permisoCodigo)
                : string.IsNullOrWhiteSpace(_permisoCodigo)
                ? await _permissionService.HasModulePermissionAsync(userRole, _modulo)
                : await _permissionService.HasCodePermissionAsync(userRole ?? string.Empty, _permisoCodigo);

            if (!tienePermiso)
            {
                context.Result = AuthorizationResults.AccessDenied();
            }
        }

        private bool IsOverriddenByActionPolicy(AuthorizationFilterContext context)
        {
            if (context.ActionDescriptor is not ControllerActionDescriptor descriptor)
                return false;

            var actionPolicies = descriptor.MethodInfo
                .GetCustomAttributes(typeof(AdminAuthorizeAttribute), inherit: true)
                .Cast<AdminAuthorizeAttribute>()
                .ToArray();
            if (actionPolicies.Length == 0)
                return false;

            return actionPolicies.All(policy =>
            {
                var arguments = policy.Arguments ?? [];
                var module = arguments.Length > 0 ? arguments[0]?.ToString() : string.Empty;
                var permission = arguments.Length > 1 ? arguments[1]?.ToString() : string.Empty;
                return !string.Equals(module, _modulo, StringComparison.OrdinalIgnoreCase)
                    || !string.Equals(permission, _permisoCodigo ?? string.Empty, StringComparison.OrdinalIgnoreCase);
            });
        }
    }
}
