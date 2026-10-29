namespace Proyecto_FinalAPI.Middleware
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
                headers["Cache-Control"] = "no-store";

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
    }
}
