using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class BudgetFilterViewModel
{
    public int? Year { get; set; }
    public int? DepartmentId { get; set; }
    public string? Status { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed class BudgetListItemViewModel
{
    public int BudgetId { get; set; }
    public int Year { get; set; }
    public int DepartmentId { get; set; }
    public string DepartmentName { get; set; } = string.Empty;
    public string Currency { get; set; } = "CRC";
    public string Status { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public decimal AnnualAmount { get; set; }
    public string CreatedByName { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
    public bool Active { get; set; }
}

public sealed class BudgetCreateViewModel
{
    [Range(2000, 2100, ErrorMessage = "El año debe estar entre 2000 y 2100.")]
    public int Year { get; set; } = DateTime.Today.Year;

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione un departamento.")]
    public int DepartmentId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione una categoría inicial.")]
    public int CategoryId { get; set; }

    [Range(typeof(decimal), "0.01", "999999999999.99", ErrorMessage = "El monto anual debe ser mayor que cero.")]
    public decimal AnnualAmount { get; set; }

    [StringLength(800)]
    public string? Notes { get; set; }
}

public sealed class BudgetDetailLineViewModel
{
    public int BudgetDetailId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public int Month { get; set; }
    public decimal AllocatedAmount { get; set; }
    public string? Notes { get; set; }
}

public sealed class BudgetHeaderEditViewModel
{
    public int BudgetId { get; set; }

    [Range(2000, 2100)]
    public int Year { get; set; }

    [Range(typeof(decimal), "0.01", "999999999999.99")]
    public decimal AnnualAmount { get; set; }

    [StringLength(800)]
    public string? Notes { get; set; }
}

public sealed class BudgetDetailEditViewModel
{
    public int BudgetId { get; set; }
    public int BudgetDetailId { get; set; }

    [Range(1, int.MaxValue)]
    public int CategoryId { get; set; }

    [Range(1, 12)]
    public int Month { get; set; }

    [Range(typeof(decimal), "0", "999999999999.99")]
    public decimal AllocatedAmount { get; set; }

    [StringLength(300)]
    public string? Notes { get; set; }
}

public sealed class BudgetAuditViewModel
{
    public string Action { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
    public string? Detail { get; set; }
}

public sealed class BudgetDetailsViewModel
{
    public BudgetListItemViewModel Budget { get; set; } = new();
    public IReadOnlyList<BudgetDetailLineViewModel> Details { get; set; } = Array.Empty<BudgetDetailLineViewModel>();
    public IReadOnlyList<BudgetAuditViewModel> Audit { get; set; } = Array.Empty<BudgetAuditViewModel>();
    public IReadOnlyList<SelectOptionViewModel> Categories { get; set; } = Array.Empty<SelectOptionViewModel>();
    public bool CanEdit => BudgetRules.CanEdit(Budget.Status);
}

public sealed class BudgetsIndexViewModel
{
    public BudgetFilterViewModel Filter { get; set; } = new();
    public PagedResult<BudgetListItemViewModel> Budgets { get; set; } = new();
    public BudgetCreateViewModel NewBudget { get; set; } = new();
    public IReadOnlyList<SelectOptionViewModel> Departments { get; set; } = Array.Empty<SelectOptionViewModel>();
    public IReadOnlyList<SelectOptionViewModel> Categories { get; set; } = Array.Empty<SelectOptionViewModel>();
}

public static class BudgetRules
{
    public static bool IsValidYear(int year) => year is >= 2000 and <= 2100;

    public static bool CanEdit(string? status) =>
        string.Equals(status, "Borrador", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(status, "Rechazado", StringComparison.OrdinalIgnoreCase);

    public static bool CanApprove(string? status, int creatorId, int approverId) =>
        string.Equals(status, "Presentado", StringComparison.OrdinalIgnoreCase) &&
        creatorId > 0 && approverId > 0 && creatorId != approverId;

    public static IReadOnlyList<decimal> DistributeAnnual(decimal annualAmount)
    {
        if (annualAmount <= 0) throw new ArgumentOutOfRangeException(nameof(annualAmount));
        var regular = Math.Round(annualAmount / 12m, 2, MidpointRounding.AwayFromZero);
        var result = Enumerable.Repeat(regular, 11).ToList();
        result.Add(annualAmount - result.Sum());
        return result;
    }

    public static bool HasConsistentTotal(IEnumerable<decimal> details, decimal expected) =>
        details.All(value => value >= 0) && details.Sum() == expected;
}
