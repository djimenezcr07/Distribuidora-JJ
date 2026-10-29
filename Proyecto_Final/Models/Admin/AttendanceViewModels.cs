using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class AttendanceEntryViewModel
{
    public long JornadaId { get; set; }
    public int EmpleadoId { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public decimal HorasOrdinarias { get; set; }
    public decimal HorasExtra { get; set; }
    public decimal HorasAusencia { get; set; }
    public string? Observaciones { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? RespuestaSupervisor { get; set; }
    public string RowVersionBase64 { get; set; } = string.Empty;
}

public sealed class AttendanceFormViewModel : IValidatableObject
{
    public long JornadaId { get; set; }

    [DataType(DataType.Date)]
    [Display(Name = "Fecha de jornada")]
    public DateTime Fecha { get; set; } = DateTime.Today;

    [Range(typeof(decimal), "0", "24")]
    [Display(Name = "Horas ordinarias")]
    public decimal HorasOrdinarias { get; set; }

    [Range(typeof(decimal), "0", "24")]
    [Display(Name = "Horas extra")]
    public decimal HorasExtra { get; set; }

    [Range(typeof(decimal), "0", "24")]
    [Display(Name = "Horas de ausencia")]
    public decimal HorasAusencia { get; set; }

    [StringLength(500)]
    public string? Observaciones { get; set; }

    public Guid IdempotencyKey { get; set; } = Guid.NewGuid();
    public string? RowVersionBase64 { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext) =>
        AttendanceRules.Validate(HorasOrdinarias, HorasExtra, HorasAusencia)
            .Select(message => new ValidationResult(message, [nameof(HorasOrdinarias), nameof(HorasExtra), nameof(HorasAusencia)]));
}

public sealed class AttendanceDecisionViewModel
{
    [Range(1, long.MaxValue)]
    public long JornadaId { get; set; }

    [Required]
    [RegularExpression("Aprobada|Rechazada")]
    public string Decision { get; set; } = string.Empty;

    [StringLength(500)]
    public string? RespuestaSupervisor { get; set; }

    [Required]
    public string RowVersionBase64 { get; set; } = string.Empty;
}

public sealed class MyAttendanceIndexViewModel
{
    public AttendanceFormViewModel Form { get; set; } = new();
    public List<AttendanceEntryViewModel> Jornadas { get; set; } = [];
}

public static class AttendanceRules
{
    public static IReadOnlyList<string> Validate(decimal ordinary, decimal overtime, decimal absence)
    {
        var errors = new List<string>();
        if (ordinary < 0 || overtime < 0 || absence < 0) errors.Add("Las horas no pueden ser negativas.");
        if (ordinary + overtime + absence > 24m) errors.Add("La suma de horas no puede superar 24 para una fecha.");
        if (ordinary + overtime + absence == 0m) errors.Add("Debe registrar al menos una hora ordinaria, extra o de ausencia.");
        return errors;
    }
}
