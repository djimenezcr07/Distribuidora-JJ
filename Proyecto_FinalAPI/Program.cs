using Microsoft.AspNetCore.RateLimiting;
using Proyecto_FinalAPI.Middleware;
using Proyecto_FinalAPI.Services;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
StartupConfigurationValidator.Validate(builder.Configuration, builder.Environment);
var companyName = builder.Configuration["Company:BrandName"]!;

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddMemoryCache();
builder.Services.Configure<CompanyOptions>(builder.Configuration.GetSection("Company"));
builder.Services.AddScoped<IAccountApiDbService, AccountApiDbService>();
builder.Services.AddSingleton<IPasswordHashService, PasswordHashService>();
builder.Services.AddScoped<ProductsApiDbService>();
builder.Services.AddScoped<EmailService>();
builder.Services.AddSingleton<LoginAttemptLimiter>();
builder.Services.AddSingleton<PasswordRecoveryAttemptLimiter>();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("authentication", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
    options.AddPolicy("password-recovery", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

var app = builder.Build();

var swaggerEnabled = app.Configuration.GetValue<bool>("Swagger:Enabled");

if (swaggerEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.RoutePrefix = "swagger";
        options.DocumentTitle = $"{companyName} API";
    });
}

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseMiddleware<SecurityHeadersMiddleware>();
app.UseRateLimiter();

app.MapGet("/", () => Results.Ok(new
{
    service = "Proyecto_FinalAPI",
    project = companyName,
    status = "OK",
    health = "/health"
}));

app.MapGet("/health", () => Results.Ok(new
{
    status = "OK",
    service = "Proyecto_FinalAPI",
    build = BuildIdentity.CommitSha
}));

app.MapControllers();
app.Run();
