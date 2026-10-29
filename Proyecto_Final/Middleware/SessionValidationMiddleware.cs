using Proyecto_Final.Services;

namespace Proyecto_Final.Middleware;

public sealed class SessionValidationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<SessionValidationMiddleware> _logger;

    public SessionValidationMiddleware(RequestDelegate next, ILogger<SessionValidationMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, IOriginalLoginService originalLogins)
    {
        var userId = context.Session.GetInt32("UserId");
        if (!userId.HasValue || userId.Value <= 0)
        {
            await _next(context);
            return;
        }

        var expectedStamp = context.Session.GetString("SecurityStamp");
        var expectedRole = context.Session.GetString("UserRole");
        var originalLogin = OriginalLoginSession.Read(context.Session);
        UserSessionState? current;

        try
        {
            current = originalLogin is null ? null
                : await originalLogins.ValidateAsync(originalLogin, context.RequestAborted);
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "No fue posible validar la sesión del usuario {UserId}.", userId.Value);
            await RejectAsync(context);
            return;
        }

        if (!IsCurrent(current, expectedRole, expectedStamp, context.Session.GetInt32("ProfileId")))
        {
            _logger.LogInformation("Se revocó una sesión desactualizada del usuario {UserId}.", userId.Value);
            if (context.Request.Path.StartsWithSegments("/Account/Login"))
            {
                context.Session.Clear();
                await _next(context);
                return;
            }

            await RejectAsync(context);
            return;
        }

        context.Items[OriginalLoginSession.ValidatedContextItem] = originalLogin;
        await _next(context);
    }

    public static bool IsCurrent(UserSessionState? current, string? expectedRole, string? expectedStamp, int? expectedProfileId = null) =>
        current is { Active: true, ProfileActive: true, ProfileId: > 0 }
        && expectedProfileId is > 0
        && current.ProfileId == expectedProfileId
        && !string.IsNullOrWhiteSpace(expectedStamp)
        && string.Equals(current.Role, expectedRole, StringComparison.OrdinalIgnoreCase)
        && string.Equals(current.SecurityStamp, expectedStamp, StringComparison.OrdinalIgnoreCase);

    private static async Task RejectAsync(HttpContext context)
    {
        context.Session.Clear();

        if (context.Request.Headers.Accept.Any(value => value?.Contains("application/json", StringComparison.OrdinalIgnoreCase) == true)
            || context.Request.Path.StartsWithSegments("/chatHub"))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        var returnUrl = context.Request.PathBase + context.Request.Path + context.Request.QueryString;
        context.Response.Redirect($"/Account/Login?returnUrl={Uri.EscapeDataString(returnUrl)}");
        await Task.CompletedTask;
    }
}
