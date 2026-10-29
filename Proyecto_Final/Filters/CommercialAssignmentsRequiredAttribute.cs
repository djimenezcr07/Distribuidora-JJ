using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Filters;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class CommercialAssignmentsRequiredAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        try { CommercialAssignmentGuard.RequireAccreditedRelations(); }
        catch (CommercialAssignmentsUnavailableException)
        {
            context.Result = new ViewResult
            {
                ViewName = "~/Views/Shared/CommercialAssignmentsUnavailable.cshtml",
                StatusCode = StatusCodes.Status503ServiceUnavailable
            };
        }
    }
}
