using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Filters;

// Resource existence and department relationships are not disclosed by denial.
public sealed class DocumentAccessExceptionFilterAttribute : ExceptionFilterAttribute
{
    public override void OnException(ExceptionContext context)
    {
        if (context.Exception is SqlException { Number: 57401 or 57402 })
        {
            context.Result = new NotFoundResult();
            context.ExceptionHandled = true;
        }
        else if (context.Exception is UnauthorizedAccessException)
        {
            context.Result = new UnauthorizedResult();
            context.ExceptionHandled = true;
        }
    }
}
