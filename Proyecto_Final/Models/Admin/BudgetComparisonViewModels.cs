namespace Proyecto_Final.Models.Admin;

public sealed class BudgetComparisonFilterViewModel
{
    public int Year { get; set; } = DateTime.Today.Year;
    public int? DepartmentId { get; set; }
    public int? Month { get; set; }
    public int? CategoryId { get; set; }
    public string? ExpenseStatus { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed class BudgetComparisonSummaryViewModel
{
    public decimal AnnualBudget { get; set; }
    public decimal FilteredBudget { get; set; }
    public decimal RegisteredExpense { get; set; }
    public decimal ApprovedExpense { get; set; }
    public decimal PaidExpense { get; set; }
    public decimal PendingExpense { get; set; }
    public decimal RealExpense { get; set; }
    public decimal Available { get; set; }
    public decimal Variance { get; set; }
    public decimal ExecutionPercent { get; set; }
    public decimal AnnualProjection { get; set; }
    public int ExpenseCount { get; set; }
    public int DepartmentsWithoutBudget { get; set; }
    public int OverBudgetCategories { get; set; }
    public string Level => BudgetComparisonCalculator.Level(ExecutionPercent);
}

public sealed class BudgetComparisonRowViewModel
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Budget { get; set; }
    public decimal Pending { get; set; }
    public decimal Real { get; set; }
    public decimal Available { get; set; }
    public decimal ExecutionPercent { get; set; }
    public string Level => BudgetComparisonCalculator.Level(ExecutionPercent);
}

public sealed class BudgetComparisonMonthlyViewModel
{
    public int Month { get; set; }
    public decimal Budget { get; set; }
    public decimal Pending { get; set; }
    public decimal Real { get; set; }
}

public sealed class BudgetComparisonDashboardViewModel
{
    public BudgetComparisonFilterViewModel Filter { get; set; } = new();
    public BudgetComparisonSummaryViewModel Summary { get; set; } = new();
    public IReadOnlyList<BudgetComparisonRowViewModel> ByDepartment { get; set; } = Array.Empty<BudgetComparisonRowViewModel>();
    public IReadOnlyList<BudgetComparisonRowViewModel> ByCategory { get; set; } = Array.Empty<BudgetComparisonRowViewModel>();
    public IReadOnlyList<BudgetComparisonMonthlyViewModel> Monthly { get; set; } = Array.Empty<BudgetComparisonMonthlyViewModel>();
    public PagedResult<OperatingExpenseListItemViewModel> ExpenseDetail { get; set; } = new();
    public IReadOnlyList<SelectOptionViewModel> Departments { get; set; } = Array.Empty<SelectOptionViewModel>();
    public IReadOnlyList<SelectOptionViewModel> Categories { get; set; } = Array.Empty<SelectOptionViewModel>();
    public DateTime UpdatedUtc { get; set; } = DateTime.UtcNow;
}

public static class BudgetComparisonCalculator
{
    public static decimal Percentage(decimal actual, decimal budget) =>
        budget <= 0 ? 0 : decimal.Round(actual / budget * 100m, 2, MidpointRounding.AwayFromZero);

    public static decimal Projection(decimal accumulated, int elapsedMonths) =>
        elapsedMonths <= 0 ? 0 : decimal.Round(accumulated / elapsedMonths * 12m, 2, MidpointRounding.AwayFromZero);

    public static string Level(decimal percent) => percent switch
    {
        >= 100m => "Excedido",
        >= 90m => "Crítico",
        >= 80m => "Advertencia",
        _ => "Normal"
    };
}

public static class CsvExportSanitizer
{
    public static string Cell(object? value)
    {
        var text = Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture) ?? string.Empty;
        if (text.Length > 0 && "=+-@".Contains(text[0])) text = "'" + text;
        return '"' + text.Replace("\"", "\"\"") + '"';
    }
}
