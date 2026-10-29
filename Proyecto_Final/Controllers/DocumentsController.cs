using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[SessionAuthorize]
[DocumentAccessExceptionFilter]
public sealed class DocumentsController : Controller
{
    private static readonly string[] AllowedStatuses = ["Vigente", "Suspendido", "Archivado"];
    private readonly IDocumentManagementDbService _documents;
    private readonly IPrivateFileStorageService _storage;
    private readonly IDocumentAlertService _alerts;
    private readonly AdminDbService _admin;
    private readonly ILogger<DocumentsController> _logger;

    public DocumentsController(IDocumentManagementDbService documents, IPrivateFileStorageService storage,
        IDocumentAlertService alerts, AdminDbService admin, ILogger<DocumentsController> logger)
    {
        _documents = documents; _storage = storage; _alerts = alerts; _admin = admin; _logger = logger;
    }

    public override void OnActionExecuted(ActionExecutedContext context)
    {
        // Successful views contain only data authorized by the owner-scoped SQL service.
        ViewData["DocumentOwnerScope"] = context.Exception is null && context.Result is ViewResult
            && HttpContext.Items[OriginalLoginSession.ValidatedContextItem] is OriginalLoginContext { HasCanonicalLifetime: true };
        base.OnActionExecuted(context);
    }

    [HttpGet]
    public async Task<IActionResult> Index([FromQuery] DocumentFilterViewModel filter)
    {
        var businessDate = _alerts.CurrentBusinessDate();
        var options = await _documents.GetOptionsAsync();
        var summary = await _documents.GetSummaryAsync(businessDate, _alerts.DefaultWarningDays);
        return View(new DocumentIndexViewModel
        {
            Filter = filter, Documents = await _documents.ListAsync(filter, businessDate, _alerts.DefaultWarningDays),
            Types = options.Types, Departments = options.Departments,
            CurrentCount = summary.Current, WarningCount = summary.Warning, ExpiredCount = summary.Expired, NoExpirationCount = summary.NoExpiration
        });
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id)
    {
        if (id <= 0) return NotFound();
        var model = await _documents.GetDetailsAsync(id, _alerts.CurrentBusinessDate(), _alerts.DefaultWarningDays);
        return model is null ? NotFound() : View(model);
    }

    [HttpGet]
    public async Task<IActionResult> Detail(int id)
    {
        if (id <= 0) return NotFound();
        var model = await _documents.GetDetailsAsync(id, _alerts.CurrentBusinessDate(), _alerts.DefaultWarningDays);
        return model is null ? NotFound() : View("Details", model);
    }

    [HttpGet]
    public async Task<IActionResult> History(int id)
    {
        if (id <= 0) return NotFound();
        var model = await _documents.GetDetailsAsync(id, _alerts.CurrentBusinessDate(), _alerts.DefaultWarningDays);
        if (model is null) return NotFound();
        ViewData["FocusHistory"] = true;
        return View("Details", model);
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        await LoadOptionsAsync();
        return View(new DocumentFormViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("private-file-upload")]
    public async Task<IActionResult> Create(DocumentFormViewModel model, CancellationToken cancellationToken)
    {
        ValidateDocument(model, requireFile: true);
        if (!ModelState.IsValid) { await LoadOptionsAsync(); return InvalidDocumentForm(model); }
        StagedPrivateFile? staged = null;
        var documentId = 0;
        var committed = false;
        var ready = false;
        try
        {
            staged = await _storage.StageAsync(model.File, PrivateStorageArea.Documents, cancellationToken)
                ?? throw new PrivateFileValidationException("Seleccione un archivo.");
            documentId = await _documents.CreatePendingAsync(model, staged, UserId(), UserName());
            await _storage.CommitAsync(staged, cancellationToken);
            committed = true;
            await _documents.MarkDocumentReadyAsync(documentId, UserId(), UserName());
            ready = true;
            TempData["SuccessMessage"] = "Documento almacenado de forma privada.";
            return RedirectToAction(nameof(Details), new { id = documentId });
        }
        catch (PrivateFileValidationException exception)
        {
            ModelState.AddModelError(nameof(model.File), exception.Message);
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "No se pudo crear el documento privado.");
            ModelState.AddModelError(string.Empty, "No fue posible guardar el documento.");
        }
        if (staged is not null && !ready)
        {
            if (committed) await _storage.DeleteCommittedAsync(PrivateStorageArea.Documents, staged.StorageKey);
            else await _storage.DeleteStageAsync(staged);
        }
        if (documentId > 0 && !ready) await TryDeletePendingAsync(documentId);
        await LoadOptionsAsync();
        return InvalidDocumentForm(model);
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var model = await _documents.GetFormAsync(id);
        if (model is null) return NotFound();
        await LoadOptionsAsync();
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(DocumentFormViewModel model)
    {
        ValidateDocument(model, requireFile: false);
        if (!ModelState.IsValid) { await LoadOptionsAsync(); return InvalidDocumentForm(model); }
        try
        {
            await _documents.UpdateMetadataAsync(model, UserId(), UserName());
            TempData["SuccessMessage"] = "Documento actualizado.";
            return RedirectToAction(nameof(Details), new { id = model.DocumentId });
        }
        catch (Exception exception)
        {
            HandleDatabaseError(exception, "actualizar el documento");
            await LoadOptionsAsync();
            return InvalidDocumentForm(model);
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("private-file-upload")]
    public async Task<IActionResult> ReplaceFile(int id, IFormFile? file, CancellationToken cancellationToken)
    {
        StagedPrivateFile? staged = null;
        var versionId = 0;
        var committed = false;
        var ready = false;
        try
        {
            staged = await _storage.StageAsync(file, PrivateStorageArea.Documents, cancellationToken)
                ?? throw new PrivateFileValidationException("Seleccione un archivo.");
            versionId = await _documents.ReplaceFilePendingAsync(id, staged, UserId(), UserName());
            await _storage.CommitAsync(staged, cancellationToken);
            committed = true;
            await _documents.MarkVersionReadyAsync(id, versionId, UserId(), UserName());
            ready = true;
            TempData["SuccessMessage"] = "Nueva versión almacenada.";
        }
        catch (PrivateFileValidationException exception) { TempData["ErrorMessage"] = exception.Message; }
        catch (Exception exception)
        {
            _logger.LogError(exception, "No se pudo reemplazar el archivo del documento {DocumentId}.", id);
            TempData["ErrorMessage"] = "No fue posible reemplazar el archivo.";
        }
        if (versionId > 0 && !ready) await TryDeletePendingVersionAsync(id, versionId);
        if (staged is not null && !ready)
        {
            if (committed) await _storage.DeleteCommittedAsync(PrivateStorageArea.Documents, staged.StorageKey);
            else await _storage.DeleteStageAsync(staged);
        }
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet]
    [EnableRateLimiting("sensitive-read")]
    public async Task<IActionResult> Download(int id, int? versionId, CancellationToken cancellationToken)
    {
        var metadata = await _documents.GetAuthorizedFileAsync(id, versionId, UserId(), await CanManageAsync());
        if (metadata is null) return NotFound();
        var stream = await _storage.OpenReadAsync(PrivateStorageArea.Documents, metadata.StorageKey, cancellationToken);
        if (stream is null) { _logger.LogWarning("Archivo privado ausente para documento {DocumentId}.", id); return NotFound(); }
        Response.Headers.CacheControl = "private, no-store, max-age=0";
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        Response.Headers.ContentDisposition = $"attachment; filename*=UTF-8''{Uri.EscapeDataString(metadata.OriginalName)}";
        return File(stream, metadata.MimeType);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SetActive(int id, bool active)
    {
        try
        {
            await _documents.SetActiveAsync(id, active, UserId(), UserName());
            TempData["SuccessMessage"] = active ? "Documento reactivado." : "Documento desactivado sin borrar su historial.";
        }
        catch (Exception exception) { HandleDatabaseError(exception, "cambiar el estado del documento"); }
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet]
    public async Task<IActionResult> Alerts([FromQuery] DocumentAlertFilterViewModel filter)
    {
        var date = _alerts.CurrentBusinessDate();
        var options = await _documents.GetOptionsAsync();
        var summary = await _documents.GetAlertSummaryAsync(date);
        return View(new DocumentAlertsIndexViewModel
        {
            Filter = filter, Alerts = await _documents.ListAlertsAsync(filter, date), Departments = options.Departments,
            ActiveCount = summary.Active, ExpiredCount = summary.Expired
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("document-alert-generation")]
    public async Task<IActionResult> GenerateAlerts(CancellationToken cancellationToken)
    {
        try
        {
            var count = await _alerts.GenerateAsync(UserId(), cancellationToken);
            TempData["SuccessMessage"] = $"Proceso completado: {count} alerta(s) nueva(s) o pendiente(s) de notificación.";
        }
        catch (Exception exception) { HandleDatabaseError(exception, "generar alertas"); }
        return RedirectToAction(nameof(Alerts));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> MarkAlertHandled(int id)
    {
        try { await _documents.MarkAlertHandledAsync(id, UserId()); TempData["SuccessMessage"] = "Alerta marcada como atendida."; }
        catch (Exception exception) { HandleDatabaseError(exception, "atender la alerta"); }
        return RedirectToAction(nameof(Alerts));
    }

    private void ValidateDocument(DocumentFormViewModel model, bool requireFile)
    {
        if (requireFile && (model.File is null || model.File.Length == 0)) ModelState.AddModelError(nameof(model.File), "Seleccione un archivo.");
        if (!AllowedStatuses.Contains(model.Status)) ModelState.AddModelError(nameof(model.Status), "El estado no es válido.");
        if (!model.DoesNotExpire && !model.ExpirationDate.HasValue) ModelState.AddModelError(nameof(model.ExpirationDate), "Indique la fecha de vencimiento o marque que no vence.");
        if (model.IssueDate.HasValue && model.ExpirationDate.HasValue && model.ExpirationDate.Value.Date < model.IssueDate.Value.Date)
            ModelState.AddModelError(nameof(model.ExpirationDate), "La fecha de vencimiento no puede ser anterior a la emisión.");
    }

    private async Task LoadOptionsAsync()
    {
        var options = await _documents.GetOptionsAsync(); ViewBag.Types = options.Types; ViewBag.Departments = options.Departments;
    }
    private int UserId() => HttpContext.Session.GetInt32("UserId") ?? 0;
    private string UserName() => HttpContext.Session.GetString("UserFullName") ?? "Usuario";
    private static Task<bool> CanManageAsync() => Task.FromResult(false); // A caller flag never grants ownership.
    private Task AuditAsync(string action, string detail) => _admin.CreateAuditLogAsync(UserId(), UserName(),
        HttpContext.Session.GetString("UserEmail"), HttpContext.Session.GetString("UserRole"), action, "Documentos", detail,
        HttpContext.Connection.RemoteIpAddress?.ToString(), Request.Headers.UserAgent.ToString());
    private async Task TryDeletePendingAsync(int id) { try { await _documents.DeletePendingDocumentAsync(id, UserId()); } catch (Exception ex) { _logger.LogWarning(ex, "No se pudo compensar documento pendiente {DocumentId}.", id); } }
    private async Task TryDeletePendingVersionAsync(int id, int versionId) { try { await _documents.DeletePendingVersionAsync(id, versionId, UserId()); } catch (Exception ex) { _logger.LogWarning(ex, "No se pudo compensar versión pendiente {VersionId}.", versionId); } }
    private void HandleDatabaseError(Exception exception, string operation)
    {
        if (exception is SqlException sql && sql.Number >= 50000) _logger.LogWarning(exception, "Regla de negocio al {Operation}.", operation);
        else _logger.LogError(exception, "Error al {Operation}.", operation);
        TempData["ErrorMessage"] = $"No fue posible {operation}.";
    }

    private ViewResult InvalidDocumentForm(DocumentFormViewModel model)
    {
        Response.StatusCode = StatusCodes.Status422UnprocessableEntity;
        return View(model);
    }
}
