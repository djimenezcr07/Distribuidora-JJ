using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[SessionAuthorize]
[EmployeeRelationshipAuthorize]
public sealed class MyAttendanceController : Controller
{
    private readonly IAttendanceService _attendance;
    private readonly ILogger<MyAttendanceController> _logger;
    private readonly BusinessClock _clock;

    public MyAttendanceController(IAttendanceService attendance, ILogger<MyAttendanceController> logger, BusinessClock clock)
    {
        _attendance = attendance; _logger = logger; _clock = clock;
    }

    [HttpGet]
    public async Task<IActionResult> Index(DateTime? desde, DateTime? hasta, CancellationToken cancellationToken)
    {
        var userId = HttpContext.Session.GetInt32("UserId") ?? 0;
        var end = (hasta ?? _clock.Today).Date; var start = (desde ?? end.AddDays(-30)).Date;
        return View(new MyAttendanceIndexViewModel
        {
            Form = new AttendanceFormViewModel { Fecha = _clock.Today },
            Jornadas = await _attendance.GetMineAsync(userId, start, end, cancellationToken)
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Save(AttendanceFormViewModel model, bool submit, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) { TempData["ErrorMessage"] = string.Join(" ", ModelState.Values.SelectMany(x => x.Errors).Select(x => x.ErrorMessage)); return RedirectToAction(nameof(Index)); }
        try
        {
            await _attendance.SaveMineAsync(HttpContext.Session.GetInt32("UserId") ?? 0, model, submit, cancellationToken);
            TempData["SuccessMessage"] = submit ? "Jornada enviada para aprobación." : "Borrador de jornada guardado.";
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "No fue posible guardar la jornada del usuario actual.");
            TempData["ErrorMessage"] = "No fue posible guardar la jornada.";
        }
        return RedirectToAction(nameof(Index));
    }
}
