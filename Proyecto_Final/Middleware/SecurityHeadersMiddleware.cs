namespace Proyecto_Final.Middleware
{
    public class SecurityHeadersMiddleware
    {
        private readonly RequestDelegate _next;

        public SecurityHeadersMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            context.Response.OnStarting(() =>
            {
                var headers = context.Response.Headers;

                SetHeaderIfMissing(headers, "X-Content-Type-Options", "nosniff");
                SetHeaderIfMissing(headers, "X-Frame-Options", "DENY");
                SetHeaderIfMissing(headers, "Referrer-Policy", "strict-origin-when-cross-origin");
                SetHeaderIfMissing(headers, "X-XSS-Protection", "0");
                SetHeaderIfMissing(headers, "Permissions-Policy", "camera=(), microphone=(), geolocation=()");
                SetHeaderIfMissing(
                    headers,
                    "Content-Security-Policy",
                    "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'; " +
                    "img-src 'self' data: blob: https://*.tile.openstreetmap.org https://unpkg.com; " +
                    "style-src 'self' 'unsafe-inline' https://unpkg.com https://stackpath.bootstrapcdn.com https://fonts.googleapis.com https://cdnjs.cloudflare.com; " +
                    "script-src 'self' 'unsafe-inline' https://code.jquery.com https://stackpath.bootstrapcdn.com https://unpkg.com; " +
                    "connect-src 'self' ws: wss:; font-src 'self' data: https://fonts.gstatic.com https://cdnjs.cloudflare.com");

                if (ShouldDisableCaching(
                    context.Features.Get<Microsoft.AspNetCore.Http.Features.ISessionFeature>()?.Session?.GetInt32("UserId") is > 0,
                    context.Request.Path))
                {
                    headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0";
                    headers["Pragma"] = "no-cache";
                    headers["Expires"] = "0";
                }

                return Task.CompletedTask;
            });

            await _next(context);
        }

        private static void SetHeaderIfMissing(IHeaderDictionary headers, string name, string value)
        {
            if (!headers.ContainsKey(name))
            {
                headers[name] = value;
            }
        }

        internal static bool ShouldDisableCaching(bool authenticated, PathString path) =>
            authenticated
            || path.StartsWithSegments("/Account")
            || path.StartsWithSegments("/Cart/Checkout")
            || path.StartsWithSegments("/Cart/Confirmation");
    }
}
