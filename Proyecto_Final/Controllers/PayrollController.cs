using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("Planilla", "PLANILLA_VER")]
public sealed class PayrollController : Controller
{
    private readonly IPayrollService _payroll; private readonly ILogger<PayrollController> _logger;
    public PayrollController(IPayrollService payroll, ILogger<PayrollController> logger){_payroll=payroll;_logger=logger;}

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        try
        {
            return View(new PayrollIndexViewModel
            {
                Calculos = await _payroll.ListAsync(cancellationToken)
            });
        }
        catch (Exception exception)
        {
            return ServiceUnavailable(exception, "cargar los cálculos de planilla");
        }
    }

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_CONFIGURAR")]
    public async Task<IActionResult> ConfigureRule(PayrollRuleFormViewModel model,CancellationToken cancellationToken)=>await ExecuteAsync(model,()=>_payroll.SaveRuleAsync(model,UserId(),UserName(),cancellationToken),"Regla versionada guardada.");

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_GESTIONAR")]
    public async Task<IActionResult> CreatePeriod(PayrollPeriodFormViewModel model,CancellationToken cancellationToken)=>await ExecuteAsync(model,()=>_payroll.CreatePeriodAsync(model,UserId(),UserName(),cancellationToken),"Periodo creado.");

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_CALCULAR")]
    public async Task<IActionResult> Calculate(PayrollCalculationRequestViewModel model,CancellationToken cancellationToken)=>await ExecuteAsync(model,()=>_payroll.CalculateAsync(model,UserId(),UserName(),cancellationToken),"Planilla calculada de forma idempotente.");

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_APROBAR")]
    public Task<IActionResult> Approve(PayrollStateChangeViewModel model,CancellationToken cancellationToken)=>ChangeStateAsync(model,"Aprobada",cancellationToken);

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_PAGAR")]
    public Task<IActionResult> Pay(PayrollStateChangeViewModel model,CancellationToken cancellationToken)=>ChangeStateAsync(model,"Pagada",cancellationToken);

    [HttpPost,ValidateAntiForgeryToken,AdminAuthorize("Planilla","PLANILLA_REVERTIR")]
    public Task<IActionResult> Revert(PayrollStateChangeViewModel model,CancellationToken cancellationToken)=>ChangeStateAsync(model,"Revertida",cancellationToken);

    private Task<IActionResult> ChangeStateAsync(
    PayrollStateChangeViewModel model,
    string state,
    CancellationToken cancellationToken)
    {
        // El estado no debe venir controlado por el navegador.
        // Cada acción determina el estado permitido desde el servidor.
        model.Estado = state;

        // El model binder registra un error porque el formulario no envía Estado.
        // Se elimina únicamente ese error y se conserva el resto de validaciones.
        ModelState.Remove(nameof(PayrollStateChangeViewModel.Estado));

        return ExecuteAsync(
            model,
            () => _payroll.ChangeStateAsync(
                model,
                UserId(),
                UserName(),
                cancellationToken
            ),
            "Estado de planilla actualizado."
        );
    }

    private async Task<IActionResult> ExecuteAsync(object model,Func<Task> action,string success)
    {
        if (!ModelState.IsValid)
        {
            var errors = ModelState
                .Where(item => item.Value is { Errors.Count: > 0 })
                .SelectMany(item => item.Value!.Errors.Select(error =>
                {
                    var message = !string.IsNullOrWhiteSpace(error.ErrorMessage)
                        ? error.ErrorMessage
                        : "El valor recibido tiene un formato inválido.";

                    var field = string.IsNullOrWhiteSpace(item.Key)
                        ? "Formulario"
                        : item.Key;

                    return $"{field}: {message}";
                }))
                .ToArray();

            var detail = errors.Length > 0
                ? string.Join(" | ", errors)
                : "Error de validación no identificado.";

            _logger.LogWarning(
                "Solicitud de planilla inválida: {ValidationErrors}",
                detail
            );

            return UnprocessableEntity(new { message = $"La solicitud no es válida: {detail}" });
        }
        try {await action();TempData["SuccessMessage"]=success;}
        catch(SqlException exception) when(exception.Number>=50000)
        {
            _logger.LogWarning(exception,"Regla de planilla rechazada. TraceId {TraceId}",HttpContext.TraceIdentifier);
            return UnprocessableEntity(new { message = "La operación de planilla no es válida para el estado actual." });
        }
        catch(Exception exception){return ServiceUnavailable(exception,"procesar la operación de planilla");}
        return RedirectToAction(nameof(Index));
    }
    private int UserId()=>HttpContext.Session.GetInt32("UserId")??0; private string UserName()=>HttpContext.Session.GetString("UserFullName")??"Usuario";
    private ViewResult ServiceUnavailable(Exception exception,string operation)
    {
        var traceId=HttpContext.TraceIdentifier;
        _logger.LogError(exception,"Falla técnica al {Operation}. TraceId {TraceId}",operation,traceId);
        Response.StatusCode=StatusCodes.Status503ServiceUnavailable;
        ViewData["TraceId"]=traceId;
        return View("ServiceUnavailable");
    }
}
