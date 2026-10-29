using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class ExpenseFilterViewModel
{
    public string? Search { get; set; }
    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public int? DepartmentId { get; set; }
    public int? CategoryId { get; set; }
    public string? Status { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed class OperatingExpenseFormViewModel
{
    public int ExpenseId { get; set; }

    [DataType(DataType.Date)]
    public DateTime ExpenseDate { get; set; } = DateTime.Today;

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione un departamento.")]
    public int DepartmentId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione una categoría.")]
    public int CategoryId { get; set; }

    [StringLength(180)]
    public string? SupplierName { get; set; }

    [Required]
    [StringLength(80)]
    public string DocumentNumber { get; set; } = string.Empty;

    [Required]
    [StringLength(40)]
    public string DocumentType { get; set; } = "Factura";

    [Required]
    [StringLength(500)]
    public string Description { get; set; } = string.Empty;

    [Range(typeof(decimal), "0.01", "999999999999.99")]
    public decimal Subtotal { get; set; }

    [Range(typeof(decimal), "0", "999999999999.99")]
    public decimal Tax { get; set; }

    [Required]
    [StringLength(40)]
    public string PaymentMethod { get; set; } = "Transferencia";

    public Guid OperationToken { get; set; } = Guid.NewGuid();
    public IFormFile? Receipt { get; set; }
    public decimal Total => ExpenseRules.CalculateTotal(Subtotal, Tax);
}

public sealed class OperatingExpenseListItemViewModel
{
    public int ExpenseId { get; set; }
    public DateTime ExpenseDate { get; set; }
    public string DepartmentName { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;
    public string? SupplierName { get; set; }
    public string DocumentNumber { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Subtotal { get; set; }
    public decimal Tax { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
    public bool HasReceipt { get; set; }
    public decimal BudgetAmount { get; set; }
    public decimal RealSpent { get; set; }
    public decimal CommittedSpent { get; set; }
    public decimal ExecutionPercent { get; set; }
    public string ConsumptionLevel { get; set; } = string.Empty;
}

public sealed class OperatingExpenseDetailsViewModel
{
    public OperatingExpenseListItemViewModel Expense { get; set; } = new();
    public string DocumentType { get; set; } = string.Empty;
    public string PaymentMethod { get; set; } = string.Empty;
    public string Currency { get; set; } = "CRC";
    public string? CancellationReason { get; set; }
    public string? ReceiptOriginalName { get; set; }
    public IReadOnlyList<BudgetAuditViewModel> Audit { get; set; } = Array.Empty<BudgetAuditViewModel>();
}

public sealed class ExpensesDashboardViewModel
{
    public ExpenseFilterViewModel Filter { get; set; } = new();
    public OperatingExpenseFormViewModel NewExpense { get; set; } = new();
    public PagedResult<OperatingExpenseListItemViewModel> Expenses { get; set; } = new();
    public IReadOnlyList<SelectOptionViewModel> Departments { get; set; } = Array.Empty<SelectOptionViewModel>();
    public IReadOnlyList<SelectOptionViewModel> Categories { get; set; } = Array.Empty<SelectOptionViewModel>();
    public decimal RegisteredTotal { get; set; }
    public decimal ApprovedTotal { get; set; }
    public decimal PaidTotal { get; set; }
    public decimal PendingTotal { get; set; }
    public decimal AvailableBudget { get; set; }
}

public sealed record ExpenseCreationResult(int ExpenseId, bool Duplicate, string ConsumptionLevel, decimal ExecutionPercent);

public static class ExpenseRules
{
    public static decimal CalculateTotal(decimal subtotal, decimal tax)
    {
        if (subtotal < 0 || tax < 0) throw new ArgumentOutOfRangeException(nameof(subtotal));
        return decimal.Round(subtotal + tax, 2, MidpointRounding.AwayFromZero);
    }

    public static bool IsValidDate(DateTime date, DateTime businessDate) =>
        date.Date <= businessDate.Date && date.Date >= businessDate.Date.AddYears(-2);

    public static bool CanEdit(string? status) => string.Equals(status, "Registrado", StringComparison.OrdinalIgnoreCase);

    public static bool ConsumesBudget(string? status) =>
        string.Equals(status, "Aprobado", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(status, "Pagado", StringComparison.OrdinalIgnoreCase);

    public static string ConsumptionLevel(decimal percent) => percent switch
    {
        >= 100m => "Excedido",
        >= 90m => "Crítico",
        >= 80m => "Advertencia",
        _ => "Normal"
    };
}
