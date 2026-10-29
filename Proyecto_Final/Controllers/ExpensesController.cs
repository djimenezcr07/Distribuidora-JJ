using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Gastos", "GASTOS_VER")]
public sealed class ExpensesController : Controller
{
    private readonly ExpensesDbService _expenses;
    private readonly IPrivateFileStorageService _storage;
    private readonly AdminDbService _admin;
    private readonly ILogger<ExpensesController> _logger;
    private readonly BusinessClock _clock;

    public ExpensesController(ExpensesDbService expenses, IPrivateFileStorageService storage, AdminDbService admin, ILogger<ExpensesController> logger, BusinessClock clock)
    { _expenses = expenses; _storage = storage; _admin = admin; _logger = logger; _clock = clock; }

    [HttpGet]
    public async Task<IActionResult> Index([FromQuery] ExpenseFilterViewModel filter)
    {
        var options = await _expenses.GetManagementOptionsAsync();
        var result = await _expenses.ListOperatingAsync(filter);
        return View(new ExpensesDashboardViewModel
        {
            Filter = filter, Expenses = result.Page, Departments = options.Departments, Categories = options.Categories,
            RegisteredTotal = result.Registered, ApprovedTotal = result.Approved, PaidTotal = result.Paid,
            PendingTotal = result.Pending, AvailableBudget = result.Available,
            NewExpense = new() { ExpenseDate = _clock.Today, OperationToken = Guid.NewGuid() }
        });
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id)
    {
        if (id <= 0) return NotFound();
        try
        {
            var model = await _expenses.GetOperatingDetailsAsync(id);
            return model is null ? NotFound() : View(model);
        }
        catch (SqlException exception) when (exception.Number < 50000)
        {
            return ServiceUnavailable(exception, id);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Detail(int id)
    {
        if (id <= 0) return NotFound();
        try
        {
            var model = await _expenses.GetOperatingDetailsAsync(id);
            return model is null ? NotFound() : View("Details", model);
        }
        catch (SqlException exception) when (exception.Number < 50000)
        {
            return ServiceUnavailable(exception, id);
        }
    }

    [HttpGet]
    [AdminAuthorize("Gastos", "GASTOS_REGISTRAR")]
    public async Task<IActionResult> Create()
    {
        await LoadOptionsAsync();
        return View(new OperatingExpenseFormViewModel
        {
            ExpenseDate = _clock.Today,
            OperationToken = Guid.NewGuid()
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("private-file-upload")]
    [AdminAuthorize("Gastos", "GASTOS_REGISTRAR")]
    public async Task<IActionResult> Create(OperatingExpenseFormViewModel model, CancellationToken cancellationToken)
    {
        ValidateExpense(model);
        if (!ModelState.IsValid) { await LoadOptionsAsync(); return InvalidExpenseForm(model); }
        StagedPrivateFile? staged = null;
        var expenseId = 0;
        var committed = false;
        var ready = false;
        try
        {
            staged = await _storage.StageAsync(model.Receipt, PrivateStorageArea.ExpenseReceipts, cancellationToken);
            var result = await _expenses.CreateOperatingAsync(model, staged, UserId(), UserName());
            expenseId = result.ExpenseId;
            if (result.Duplicate)
            {
                if (staged is not null) await _storage.DeleteStageAsync(staged);
                TempData["SuccessMessage"] = $"La operación ya estaba registrada como gasto #{expenseId}; no se duplicó.";
                return RedirectToAction(nameof(Details), new { id = expenseId });
            }
            if (staged is not null)
            {
                await _storage.CommitAsync(staged, cancellationToken); committed = true;
                await _expenses.MarkReceiptReadyAsync(expenseId, UserId(), UserName());
                ready = true;
            }
            await AuditAsync("REGISTRAR_GASTO", $"Gasto #{expenseId}, total {model.Total:N2}, nivel {result.ConsumptionLevel} ({result.ExecutionPercent:N2}%).");
            TempData["SuccessMessage"] = result.ConsumptionLevel == "Normal"
                ? "Gasto registrado." : $"Gasto registrado. Nivel presupuestario: {result.ConsumptionLevel} ({result.ExecutionPercent:N2}%).";
            return RedirectToAction(nameof(Details), new { id = expenseId });
        }
        catch (PrivateFileValidationException exception) { TempData["ErrorMessage"] = exception.Message; }
        catch (Exception exception) { Handle(exception, "registrar el gasto"); }
        if (staged is not null && !ready)
        {
            if (committed) await _storage.DeleteCommittedAsync(PrivateStorageArea.ExpenseReceipts, staged.StorageKey);
            else await _storage.DeleteStageAsync(staged);
        }
        if (staged is not null && expenseId > 0 && !ready) await TryClearPendingReceiptAsync(expenseId);
        await LoadOptionsAsync();
        return InvalidExpenseForm(model);
    }

    [HttpGet]
    [AdminAuthorize("Gastos", "GASTOS_EDITAR")]
    public async Task<IActionResult> Edit(int id)
    {
        var model = await _expenses.GetOperatingFormAsync(id);
        if (model is null) return NotFound();
        await LoadOptionsAsync();
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("private-file-upload")]
    [AdminAuthorize("Gastos", "GASTOS_EDITAR")]
    public async Task<IActionResult> Edit(OperatingExpenseFormViewModel model, CancellationToken cancellationToken)
    {
        ValidateExpense(model);
        if (model.Receipt is not null && model.Receipt.Length > 0)
            ModelState.AddModelError(nameof(model.Receipt), "El comprobante original se conserva; cree una corrección auditada si necesita reemplazarlo.");
        if (!ModelState.IsValid) { await LoadOptionsAsync(); return InvalidExpenseForm(model); }
        StagedPrivateFile? staged = null;
        var committed = false;
        var ready = false;
        try
        {
            staged = await _storage.StageAsync(model.Receipt, PrivateStorageArea.ExpenseReceipts, cancellationToken);
            await _expenses.UpdateOperatingAsync(model, staged, UserId(), UserName());
            if (staged is not null)
            {
                await _storage.CommitAsync(staged, cancellationToken); committed = true;
                await _expenses.MarkReceiptReadyAsync(model.ExpenseId, UserId(), UserName());
                ready = true;
            }
            await AuditAsync("EDITAR_GASTO", $"Gasto #{model.ExpenseId} actualizado; total {model.Total:N2}.");
            TempData["SuccessMessage"] = "Gasto actualizado.";
            return RedirectToAction(nameof(Details), new { id = model.ExpenseId });
        }
        catch (PrivateFileValidationException exception) { ModelState.AddModelError(nameof(model.Receipt), exception.Message); }
        catch (Exception exception) { Handle(exception, "actualizar el gasto"); }
        if (staged is not null && !ready)
        {
            if (committed) await _storage.DeleteCommittedAsync(PrivateStorageArea.ExpenseReceipts, staged.StorageKey);
            else await _storage.DeleteStageAsync(staged);
        }
        if (staged is not null && !ready) await TryClearPendingReceiptAsync(model.ExpenseId);
        await LoadOptionsAsync();
        return InvalidExpenseForm(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Gastos", "GASTOS_APROBAR")]
    public async Task<IActionResult> Approve(int id, bool overrideBudget)
    {
        if (overrideBudget && !await HasPermissionAsync("GASTOS_EXCEDER_PRESUPUESTO"))
        { TempData["ErrorMessage"] = "No cuenta con permiso para autorizar un exceso presupuestario."; return RedirectToAction(nameof(Details), new { id }); }
        return await Transition(id, "Aprobar", null, overrideBudget, "Gasto aprobado.");
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Gastos", "GASTOS_APROBAR")]
    public Task<IActionResult> Reject(int id, string reason) => Transition(id, "Rechazar", reason, false, "Gasto rechazado.");

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Gastos", "GASTOS_PAGAR")]
    public Task<IActionResult> Pay(int id) => Transition(id, "Pagar", null, false, "Gasto marcado como pagado.");

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("finance-write")]
    [AdminAuthorize("Gastos", "GASTOS_ANULAR")]
    public Task<IActionResult> Cancel(int id, string reason) => Transition(id, "Anular", reason, false, "Gasto anulado; ya no afecta el presupuesto.");

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    public async Task<IActionResult> Receipt(int id, CancellationToken cancellationToken)
    {
        var metadata = await _expenses.GetReceiptAsync(id, UserId(), await HasPermissionAsync("GASTOS_VER"));
        if (metadata is null) return NotFound();
        var stream = await _storage.OpenReadAsync(PrivateStorageArea.ExpenseReceipts, metadata.StorageKey, cancellationToken);
        if (stream is null) { _logger.LogWarning("Comprobante privado ausente para gasto {ExpenseId}.", id); return NotFound(); }
        Response.Headers.ContentDisposition = $"attachment; filename*=UTF-8''{Uri.EscapeDataString(metadata.OriginalName)}";
        return File(stream, metadata.MimeType);
    }

    // Compatibilidad temporal: las cuentas mensuales legadas quedan sólo para consulta durante la migración.
    [HttpGet]
    [AdminAuthorize("Gastos", "GASTOS_LEGADO_VER")]
    public async Task<IActionResult> Accounts() => View(new AccountsViewModel { Cuentas = await _expenses.GetAccountsAsync(), Nueva = new() });

    private async Task<IActionResult> Transition(int id, string action, string? reason, bool overrideBudget, string success)
    {
        try
        {
            await _expenses.TransitionOperatingAsync(id, action, reason, overrideBudget, UserId(), UserName());
            await AuditAsync($"{action.ToUpperInvariant()}_GASTO", $"Gasto #{id}. Motivo: {reason ?? "N/A"}. Exceso autorizado: {overrideBudget}.");
            TempData["SuccessMessage"] = success;
        }
        catch (Exception exception) { Handle(exception, $"{action.ToLowerInvariant()} el gasto"); }
        return RedirectToAction(nameof(Details), new { id });
    }

    private void ValidateExpense(OperatingExpenseFormViewModel model)
    {
        var businessDate = DocumentExpirationPolicy.BusinessDate(DateTimeOffset.UtcNow);
        if (!ExpenseRules.IsValidDate(model.ExpenseDate, businessDate)) ModelState.AddModelError(nameof(model.ExpenseDate), "La fecha no puede ser futura ni tener más de dos años.");
        if (model.OperationToken == Guid.Empty) ModelState.AddModelError(nameof(model.OperationToken), "El token de operación no es válido.");
    }
    private async Task LoadOptionsAsync() { var options = await _expenses.GetManagementOptionsAsync(); ViewBag.Departments = options.Departments; ViewBag.Categories = options.Categories; }
    private int UserId() => HttpContext.Session.GetInt32("UserId") ?? 0;
    private string UserName() => HttpContext.Session.GetString("UserFullName") ?? "Usuario";
    private async Task<bool> HasPermissionAsync(string code) => string.Equals(HttpContext.Session.GetString("UserRole"), "Administrador", StringComparison.OrdinalIgnoreCase)
        || await _admin.TienePermisoCodigoPorRolAsync(HttpContext.Session.GetString("UserRole") ?? string.Empty, code);
    private Task AuditAsync(string action, string detail) => _admin.CreateAuditLogAsync(UserId(), UserName(), HttpContext.Session.GetString("UserEmail"),
        HttpContext.Session.GetString("UserRole"), action, "Gastos", detail, HttpContext.Connection.RemoteIpAddress?.ToString(), Request.Headers.UserAgent.ToString());
    private async Task TryClearPendingReceiptAsync(int id) { try { await _expenses.DeletePendingReceiptAsync(id, UserId()); } catch (Exception ex) { _logger.LogWarning(ex, "No se pudo compensar comprobante pendiente del gasto {ExpenseId}.", id); } }
    private void Handle(Exception exception, string operation)
    {
        if (exception is SqlException sql && sql.Number >= 50000) _logger.LogWarning(exception, "Regla de negocio al {Operation}.", operation);
        else _logger.LogError(exception, "Error al {Operation}.", operation);
        TempData["ErrorMessage"] = $"No fue posible {operation}.";
    }

    private ViewResult InvalidExpenseForm(OperatingExpenseFormViewModel model)
    {
        Response.StatusCode = StatusCodes.Status422UnprocessableEntity;
        return View(model);
    }

    private ViewResult ServiceUnavailable(SqlException exception, int expenseId)
    {
        var traceId = HttpContext.TraceIdentifier;
        _logger.LogError(exception, "Falla SQL controlada al consultar gasto {ExpenseId}. TraceId {TraceId}", expenseId, traceId);
        Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
        ViewData["TraceId"] = traceId;
        return View("ServiceUnavailable");
    }
}
