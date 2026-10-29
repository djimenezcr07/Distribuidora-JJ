using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.ModelBinders;

namespace Proyecto_Final.Models.Admin;

public sealed class PayrollRuleViewModel
{
    public int ReglaId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public string TipoCalculo { get; set; } = string.Empty;
    public decimal Valor { get; set; }
    public decimal? Tope { get; set; }
    public DateTime VigenteDesde { get; set; }
    public DateTime? VigenteHasta { get; set; }
    public string Fuente { get; set; } = string.Empty;
}

public sealed class PayrollRuleFormViewModel : IValidatableObject
{
    [Required(ErrorMessage = "El código de la regla es obligatorio.")]
    [StringLength(50, ErrorMessage = "El código no puede superar 50 caracteres.")]
    [RegularExpression("^[A-Z0-9_]+$", ErrorMessage = "Use solo letras mayúsculas, números y guiones bajos en el código.")]
    public string Codigo { get; set; } = string.Empty;

    [Required(ErrorMessage = "El nombre de la regla es obligatorio.")]
    [StringLength(150, ErrorMessage = "El nombre no puede superar 150 caracteres.")]
    public string Nombre { get; set; } = string.Empty;

    [Required]
    [RegularExpression("^(Ingreso|Deduccion)$", ErrorMessage = "El tipo de regla no es válido.")]
    public string Tipo { get; set; } = "Ingreso";

    [Required]
    [RegularExpression("^(MontoFijo|PorcentajeSalario|PorHoraExtra|PorcentajeBruto)$", ErrorMessage = "El tipo de cálculo no es válido.")]
    public string TipoCalculo { get; set; } = "MontoFijo";

    [ModelBinder(BinderType = typeof(FlexibleDecimalModelBinder))]
    [Range(typeof(decimal), "0", "99999999", ErrorMessage = "El valor debe estar entre 0 y 99 999 999.")]
    public decimal Valor { get; set; }

    [ModelBinder(BinderType = typeof(FlexibleDecimalModelBinder))]
    [Range(typeof(decimal), "0", "99999999", ErrorMessage = "El tope debe estar entre 0 y 99 999 999.")]
    public decimal? Tope { get; set; }

    [DataType(DataType.Date)] public DateTime VigenteDesde { get; set; } = DateTime.Today;
    [DataType(DataType.Date)] public DateTime? VigenteHasta { get; set; }

    [Required(ErrorMessage = "Indique la fuente oficial o aprobación responsable.")]
    [StringLength(500, ErrorMessage = "La fuente no puede superar 500 caracteres.")]
    public string Fuente { get; set; } = string.Empty;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (VigenteDesde == default)
        {
            yield return new ValidationResult(
                "Debe indicar la fecha de inicio de vigencia.",
                [nameof(VigenteDesde)]);
        }

        if (VigenteHasta.HasValue && VigenteHasta.Value.Date < VigenteDesde.Date)
        {
            yield return new ValidationResult(
                "La fecha final no puede ser anterior a la fecha de inicio.",
                [nameof(VigenteHasta)]);
        }
    }
}

public sealed class PayrollPeriodFormViewModel : IValidatableObject
{
    [Required]
    [RegularExpression(
        "^(Quincenal|Mensual)$",
        ErrorMessage = "El tipo de período no es válido."
    )]
    public string Tipo { get; set; } = "Quincenal";

    [DataType(DataType.Date)]
    public DateTime Desde { get; set; } = DateTime.Today;

    [DataType(DataType.Date)]
    public DateTime Hasta { get; set; } = DateTime.Today;

    [ModelBinder(BinderType = typeof(FlexibleDecimalModelBinder))]
    public decimal FactorSalario { get; set; }

    [Required(ErrorMessage = "Debe indicar la fuente o aprobación del factor.")]
    [StringLength(
        500,
        ErrorMessage = "La fuente no puede superar 500 caracteres."
    )]
    public string FuenteConfiguracion { get; set; } = string.Empty;

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext
    )
    {
        if (Desde == default)
        {
            yield return new ValidationResult(
                "Debe indicar la fecha de inicio del período.",
                [nameof(Desde)]
            );
        }

        if (Hasta == default)
        {
            yield return new ValidationResult(
                "Debe indicar la fecha final del período.",
                [nameof(Hasta)]
            );
        }

        if (Hasta < Desde)
        {
            yield return new ValidationResult(
                "El final no puede ser anterior al inicio.",
                [nameof(Hasta)]
            );
        }

        if ((Hasta - Desde).TotalDays > 31)
        {
            yield return new ValidationResult(
                "El período no puede superar 31 días.",
                [nameof(Hasta)]
            );
        }

        if (FactorSalario <= 0m || FactorSalario > 1m)
        {
            yield return new ValidationResult(
                "El factor salarial debe ser mayor que 0 y menor o igual que 1.",
                [nameof(FactorSalario)]
            );
        }
    }
}

public sealed class PayrollCalculationRequestViewModel : IValidatableObject
{
    [Range(1, int.MaxValue)] public int PeriodoId { get; set; }
    [Range(1, int.MaxValue)] public int EmpleadoId { get; set; }
    [ModelBinder(BinderType = typeof(FlexibleDecimalModelBinder))]
    [Range(typeof(decimal), "0", "99999999", ErrorMessage = "Las comisiones no pueden ser negativas ni superar 99 999 999.")]
    public decimal Comisiones { get; set; }

    [Required(ErrorMessage = "No se pudo preparar la solicitud de cálculo. Recargue la página e inténtelo de nuevo.")]
    public Guid IdempotencyKey { get; set; } = Guid.NewGuid();

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (IdempotencyKey == Guid.Empty)
        {
            yield return new ValidationResult(
                "No se pudo preparar la solicitud de cálculo. Recargue la página e inténtelo de nuevo.",
                [nameof(IdempotencyKey)]);
        }
    }
}

public sealed class PayrollCalculationInput
{
    public int PeriodoId { get; init; }
    public int EmpleadoId { get; init; }
    public decimal SalarioBase { get; init; }
    public decimal HorasOrdinarias { get; init; }
    public decimal HorasExtra { get; init; }
    public decimal Comisiones { get; init; }
    public decimal FactorSalario { get; init; }
    public string FuenteConfiguracionPeriodo { get; init; } = string.Empty;
    public DateTime FechaCalculo { get; init; }
    public IReadOnlyList<PayrollRuleViewModel> Reglas { get; init; } = [];
}

public sealed record PayrollLine(string Codigo, string Nombre, string Tipo, decimal Monto);

public sealed class PayrollCalculationResult
{
    public decimal SalarioBase { get; init; }
    public decimal HorasOrdinarias { get; init; }
    public decimal HorasExtra { get; init; }
    public decimal Comisiones { get; init; }
    public decimal TotalIngresos { get; init; }
    public decimal TotalDeducciones { get; init; }
    public decimal TotalBruto { get; init; }
    public decimal TotalNeto { get; init; }
    public IReadOnlyList<PayrollLine> Lineas { get; init; } = [];
    public string ReglasSnapshotJson { get; init; } = "[]";
    public byte[] Fingerprint { get; init; } = [];
}

public sealed class PayrollListItemViewModel
{
    public long CalculoId { get; set; }
    public int PeriodoId { get; set; }
    public string Periodo { get; set; } = string.Empty;
    public int EmpleadoId { get; set; }
    public string Empleado { get; set; } = string.Empty;
    public decimal TotalBruto { get; set; }
    public decimal TotalDeducciones { get; set; }
    public decimal TotalNeto { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string RowVersionBase64 { get; set; } = string.Empty;
}

public sealed class PayrollStateChangeViewModel : IValidatableObject
{
    [Range(1, long.MaxValue)] public long CalculoId { get; set; }
    [Required, RegularExpression("^(Aprobada|Pagada|Revertida)$")] public string Estado { get; set; } = string.Empty;
    [StringLength(500)] public string? Motivo { get; set; }

    [Required(ErrorMessage = "La versión del cálculo es obligatoria.")]
    public string RowVersionBase64 { get; set; } = string.Empty;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        var isRowVersionValid = true;

        try
        {
            if (Convert.FromBase64String(RowVersionBase64).Length != 8)
            {
                throw new FormatException();
            }
        }
        catch (FormatException)
        {
            isRowVersionValid = false;
        }

        if (!isRowVersionValid)
        {
            yield return new ValidationResult(
                "La versión del cálculo no es válida. Recargue la página e inténtelo de nuevo.",
                [nameof(RowVersionBase64)]);
        }
    }
}

public sealed class PayrollIndexViewModel
{
    public PayrollPeriodFormViewModel Periodo { get; set; } = new();
    public PayrollRuleFormViewModel Regla { get; set; } = new();
    public PayrollCalculationRequestViewModel Calculo { get; set; } = new();
    public List<PayrollListItemViewModel> Calculos { get; set; } = [];
}

public sealed class PayrollConfigurationException : Exception
{
    public PayrollConfigurationException(string message) : base(message) { }
}

public static class PayrollCalculationPolicy
{
    public static PayrollCalculationResult Calculate(PayrollCalculationInput input)
    {
        ArgumentNullException.ThrowIfNull(input);
        if (input.SalarioBase < 0 || input.HorasOrdinarias < 0 || input.HorasExtra < 0 || input.Comisiones < 0)
            throw new ArgumentOutOfRangeException(nameof(input), "Los importes y horas no pueden ser negativos.");
        var active = input.Reglas.Where(rule => rule.VigenteDesde.Date <= input.FechaCalculo.Date &&
            (!rule.VigenteHasta.HasValue || rule.VigenteHasta.Value.Date >= input.FechaCalculo.Date)).OrderBy(rule => rule.Codigo).ToList();
        if (input.HorasExtra > 0 && !active.Any(rule => rule.Tipo == "Ingreso" && rule.TipoCalculo == "PorHoraExtra"))
            throw new PayrollConfigurationException("Hay horas extra aprobadas, pero no existe una regla vigente para valorarlas.");

        var lines = new List<PayrollLine>();
        foreach (var rule in active.Where(rule => rule.Tipo == "Ingreso"))
        {
            var amount = CalculateRule(rule, input.SalarioBase, input.SalarioBase, input.HorasExtra);
            if (amount > 0) lines.Add(new PayrollLine(rule.Codigo, rule.Nombre, rule.Tipo, amount));
        }
        if (input.Comisiones > 0) lines.Add(new PayrollLine("COMISION_MANUAL", "Comisiones confirmadas", "Ingreso", Round(input.Comisiones)));
        var income = lines.Where(line => line.Tipo == "Ingreso").Sum(line => line.Monto);
        var gross = Round(input.SalarioBase + income);
        foreach (var rule in active.Where(rule => rule.Tipo == "Deduccion"))
        {
            var amount = CalculateRule(rule, input.SalarioBase, gross, input.HorasExtra);
            if (amount > 0) lines.Add(new PayrollLine(rule.Codigo, rule.Nombre, rule.Tipo, amount));
        }
        var deductions = Round(lines.Where(line => line.Tipo == "Deduccion").Sum(line => line.Monto));
        if (deductions > gross) throw new PayrollConfigurationException("Las deducciones configuradas superan el total bruto.");
        var snapshot = JsonSerializer.Serialize(new { input.FactorSalario, input.FuenteConfiguracionPeriodo, Reglas = active });
        var canonical = JsonSerializer.Serialize(new { input.PeriodoId, input.EmpleadoId, input.SalarioBase, input.HorasOrdinarias, input.HorasExtra, input.Comisiones, input.FactorSalario, input.FuenteConfiguracionPeriodo, Lines = lines, Rules = active });
        return new PayrollCalculationResult
        {
            SalarioBase = Round(input.SalarioBase), HorasOrdinarias = input.HorasOrdinarias, HorasExtra = input.HorasExtra,
            Comisiones = Round(input.Comisiones), TotalIngresos = income, TotalDeducciones = deductions,
            TotalBruto = gross, TotalNeto = Round(gross - deductions), Lineas = lines,
            ReglasSnapshotJson = snapshot, Fingerprint = SHA256.HashData(Encoding.UTF8.GetBytes(canonical))
        };
    }

    private static decimal CalculateRule(PayrollRuleViewModel rule, decimal salary, decimal gross, decimal extraHours)
    {
        var amount = rule.TipoCalculo switch
        {
            "MontoFijo" => rule.Valor,
            "PorcentajeSalario" => salary * rule.Valor,
            "PorHoraExtra" => extraHours * rule.Valor,
            "PorcentajeBruto" => gross * rule.Valor,
            _ => throw new PayrollConfigurationException($"Tipo de cálculo no admitido: {rule.TipoCalculo}.")
        };
        if (rule.Tope.HasValue) amount = Math.Min(amount, rule.Tope.Value);
        return Round(amount);
    }

    private static decimal Round(decimal value) => decimal.Round(value, 2, MidpointRounding.AwayFromZero);
}
