using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AdminAuthorize("RRHH", "RRHH_JORNADAS_APROBAR")]
public sealed class AttendanceController : Controller
{
    private readonly IAttendanceService _attendance;
    private readonly ILogger<AttendanceController> _logger;
    private readonly BusinessClock _clock;

    public AttendanceController(IAttendanceService attendance, ILogger<AttendanceController> logger, BusinessClock clock)
    {
        _attendance = attendance; _logger = logger; _clock = clock;
    }

    [HttpGet]
    public async Task<IActionResult> Index(DateTime? desde, DateTime? hasta, CancellationToken cancellationToken)
    {
        var end = (hasta ?? _clock.Today).Date;
        var start = (desde ?? end.AddDays(-30)).Date;
        ViewBag.Desde = start; ViewBag.Hasta = end;
        return View(await _attendance.GetPendingAsync(start, end, cancellationToken));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Decide(AttendanceDecisionViewModel model, DateTime? desde, DateTime? hasta, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) { TempData["ErrorMessage"] = "La decisión no es válida."; return RedirectToAction(nameof(Index), new { desde, hasta }); }
        try
        {
            await _attendance.DecideAsync(model, HttpContext.Session.GetInt32("UserId") ?? 0,
                HttpContext.Session.GetString("UserFullName") ?? "Supervisor", cancellationToken);
            TempData["SuccessMessage"] = "Jornada actualizada correctamente.";
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "No fue posible resolver la jornada {AttendanceId}.", model.JornadaId);
            TempData["ErrorMessage"] = "No fue posible resolver la jornada; recargue la lista.";
        }
        return RedirectToAction(nameof(Index), new { desde, hasta });
    }
}
