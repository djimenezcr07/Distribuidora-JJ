using Proyecto_Final.Services.ChatV2;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Middleware;
using Proyecto_Final.Services;
using Proyecto_Final.Hubs;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
StartupConfigurationValidator.Validate(builder.Configuration, builder.Environment);

// MVC
builder.Services.AddControllersWithViews();
builder.Services.AddSignalR();
builder.Services.AddAntiforgery(options => options.HeaderName = "X-CSRF-TOKEN");
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

    options.AddPolicy("public-contact", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("chat-send", httpContext =>
        RateLimitPartition.GetTokenBucketLimiter(
            GetUserPartition(httpContext),
            _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit = 30,
                TokensPerPeriod = 30,
                ReplenishmentPeriod = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("chat-search", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("assistant", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("evidence-upload", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("private-file-upload", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 12,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("document-alert-generation", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 3,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("finance-write", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("sensitive-read", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            GetUserPartition(httpContext),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

// Session compartida: memoria solo para desarrollo local; Redis es obligatorio en producción.
if (builder.Environment.IsProduction())
{
    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = builder.Configuration.GetConnectionString("DistributedCache");
        options.InstanceName = "DistribuidoraJJ:";
    });
}
else
{
    builder.Services.AddDistributedMemoryCache();
}
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(45);
    options.Cookie.Name = ".DistribuidoraJJ.Session";
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = builder.Environment.IsDevelopment()
        ? CookieSecurePolicy.SameAsRequest
        : CookieSecurePolicy.Always;
});

// Servicios propios
builder.Services.AddScoped<AdminDbService>();
builder.Services.AddScoped<IRolePermissionService, RolePermissionService>();
builder.Services.AddScoped<IEmployeeRelationshipService, EmployeeRelationshipService>();
builder.Services.AddScoped<IWorkspaceResolver, WorkspaceResolver>();
builder.Services.AddScoped<IUserSessionValidationService, UserSessionValidationService>();
builder.Services.AddScoped<IOriginalLoginService, OriginalLoginService>();
builder.Services.AddSingleton<IPasswordHashService, PasswordHashService>();
builder.Services.AddScoped<IEmployeesService, EmployeesDbService>();
builder.Services.AddScoped<IAttendanceService, AttendanceDbService>();
builder.Services.AddScoped<IPayrollService, PayrollDbService>();
builder.Services.AddScoped<IPaySlipService, PaySlipDbService>();
builder.Services.AddScoped<IPaySlipEmailSender, SmtpPaySlipEmailSender>();
builder.Services.AddScoped<IPaySlipDeliveryCoordinator, PaySlipDeliveryCoordinator>();
builder.Services.AddScoped<StoreDbService>();
builder.Services.AddScoped<AccountDbService>();
builder.Services.AddScoped<EmailService>();
builder.Services.AddScoped<LogisticsDbService>();
builder.Services.AddScoped<ReportsDbService>();
builder.Services.AddScoped<WarehouseDbService>();
builder.Services.AddScoped<FleetDbService>();
builder.Services.AddScoped<PromotionsDbService>();
builder.Services.AddScoped<ReclamosDbService>();
builder.Services.AddScoped<KpiDbService>();
builder.Services.AddScoped<ExpensesDbService>();
builder.Services.AddScoped<BudgetDbService>();
builder.Services.AddScoped<BudgetComparisonDbService>();
builder.Services.AddScoped<IComboDbService, ComboDbService>();
builder.Services.AddScoped<IInventoryTransformationService, InventoryTransformationDbService>();
builder.Services.AddScoped<IInventoryIntelligenceService, InventoryIntelligenceDbService>();
builder.Services.AddScoped<IPurchasingService, PurchasingDbService>();
builder.Services.AddScoped<ICrossSellService, CrossSellDbService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IDocumentManagementDbService, DocumentManagementDbService>();
builder.Services.AddScoped<IDocumentAlertService, DocumentAlertService>();
builder.Services.AddScoped<IDocumentAlertEmailSender, SmtpDocumentAlertEmailSender>();
builder.Services.AddScoped<AssistantService>();
builder.Services.AddScoped<IChatDbService, ChatDbService>();
builder.Services.AddScoped<IChatAuthorizationService, ChatAuthorizationService>();
builder.Services.AddChatV2Continuity();
builder.Services.AddSingleton<IEvidenceStorageService, FileEvidenceStorageService>();
builder.Services.AddSingleton<IPrivateFileStorageService, PrivateFileStorageService>();
builder.Services.AddSingleton<IProductImageStorageService, ProductImageStorageService>();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<BusinessClock>();
builder.Services.Configure<CompanyOptions>(builder.Configuration.GetSection("Company"));

// HttpClient para consumir la API de autenticación
builder.Services.AddHttpClient<AccountApiService>(client =>
{
    var baseUrl = builder.Configuration["ApiSettings:BaseUrl"];

    if (string.IsNullOrWhiteSpace(baseUrl))
    {
        throw new InvalidOperationException("No se encontró la configuración ApiSettings:BaseUrl en appsettings.json.");
    }
    client.BaseAddress = new Uri(baseUrl);
});

var app = builder.Build();

// Valida la ruta y crea la estructura privada al iniciar, no en la primera carga.
_ = app.Services.GetRequiredService<IPrivateFileStorageService>();

// Pipeline
app.UseExceptionHandler("/Home/Error");
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseMiddleware<SecurityHeadersMiddleware>();

app.UseStaticFiles();

app.UseRouting();

app.UseSession();
app.UseMiddleware<SessionValidationMiddleware>();
app.UseRateLimiter();

app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new
{
    status = "OK",
    service = "Proyecto_Final",
    build = BuildIdentity.CommitSha
}));

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<ChatHub>("/chatHub");

app.Run();

static string GetUserPartition(HttpContext httpContext)
{
    var userId = httpContext.Session.GetInt32("UserId");
    return userId.HasValue && userId.Value > 0
        ? $"user:{userId.Value}"
        : $"ip:{httpContext.Connection.RemoteIpAddress}";
}
