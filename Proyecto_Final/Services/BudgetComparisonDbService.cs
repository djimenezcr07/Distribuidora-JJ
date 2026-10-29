using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services;

public sealed class BudgetComparisonDbService
{
    private readonly string _connectionString;
    private readonly BusinessClock _clock;
    public BudgetComparisonDbService(IConfiguration configuration, BusinessClock clock)
    {
        _clock = clock;
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
    }

    public async Task<BudgetComparisonDashboardViewModel> GetDashboardAsync(BudgetComparisonFilterViewModel filter)
    {
        filter.Year = filter.Year is >= 2000 and <= 2100 ? filter.Year : _clock.Today.Year;
        filter.Page = Math.Max(filter.Page, 1);
        filter.PageSize = Math.Clamp(filter.PageSize, 1, 100);
        var model = new BudgetComparisonDashboardViewModel { Filter = filter, UpdatedUtc = _clock.UtcNow.UtcDateTime };
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_BudgetComparison_Dashboard");
        AddFilters(command, filter);
        command.Parameters.Add("@Pagina", SqlDbType.Int).Value = filter.Page;
        command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = filter.PageSize;
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = _clock.Today;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync()) model.Summary = new()
        {
            AnnualBudget = reader.GetDecimal(0), FilteredBudget = reader.GetDecimal(1), RegisteredExpense = reader.GetDecimal(2),
            ApprovedExpense = reader.GetDecimal(3), PaidExpense = reader.GetDecimal(4), PendingExpense = reader.GetDecimal(5),
            RealExpense = reader.GetDecimal(6), Available = reader.GetDecimal(7), Variance = reader.GetDecimal(8),
            ExecutionPercent = reader.GetDecimal(9), AnnualProjection = reader.GetDecimal(10), ExpenseCount = reader.GetInt32(11),
            DepartmentsWithoutBudget = reader.GetInt32(12), OverBudgetCategories = reader.GetInt32(13)
        };
        model.ByDepartment = await ReadRowsAsync(reader);
        model.ByCategory = await ReadRowsAsync(reader);
        var monthly = new List<BudgetComparisonMonthlyViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) monthly.Add(new() { Month = reader.GetInt32(0), Budget = reader.GetDecimal(1), Pending = reader.GetDecimal(2), Real = reader.GetDecimal(3) });
        model.Monthly = monthly;
        var expenses = new List<OperatingExpenseListItemViewModel>();
        var total = 0;
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            total = reader.GetInt32(reader.GetOrdinal("TotalResultados"));
            expenses.Add(ReadExpense(reader));
        }
        model.ExpenseDetail = new() { Items = expenses, Page = filter.Page, PageSize = filter.PageSize, Total = total };
        var departments = new List<SelectOptionViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) departments.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        model.Departments = departments;
        var categories = new List<SelectOptionViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) categories.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        model.Categories = categories;
        return model;
    }

    private static async Task<IReadOnlyList<BudgetComparisonRowViewModel>> ReadRowsAsync(SqlDataReader reader)
    {
        var rows = new List<BudgetComparisonRowViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) rows.Add(new()
        {
            Id = reader.GetInt32(0), Name = reader.GetString(1), Budget = reader.GetDecimal(2), Pending = reader.GetDecimal(3),
            Real = reader.GetDecimal(4), Available = reader.GetDecimal(5), ExecutionPercent = reader.GetDecimal(6)
        });
        return rows;
    }

    private static void AddFilters(SqlCommand command, BudgetComparisonFilterViewModel filter)
    {
        command.Parameters.Add("@Anio", SqlDbType.Int).Value = filter.Year;
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = filter.DepartmentId is > 0 ? filter.DepartmentId.Value : DBNull.Value;
        command.Parameters.Add("@Mes", SqlDbType.Int).Value = filter.Month is >= 1 and <= 12 ? filter.Month.Value : DBNull.Value;
        command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = filter.CategoryId is > 0 ? filter.CategoryId.Value : DBNull.Value;
        command.Parameters.Add("@EstadoGasto", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(filter.ExpenseStatus) ? DBNull.Value : filter.ExpenseStatus.Trim();
    }

    private static OperatingExpenseListItemViewModel ReadExpense(SqlDataReader reader) => new()
    {
        ExpenseId = reader.GetInt32(reader.GetOrdinal("GastoId")), ExpenseDate = reader.GetDateTime(reader.GetOrdinal("FechaGasto")),
        DepartmentName = reader.GetString(reader.GetOrdinal("Departamento")), CategoryName = reader.GetString(reader.GetOrdinal("Categoria")),
        SupplierName = NullableString(reader, "Proveedor"), DocumentNumber = reader.GetString(reader.GetOrdinal("NumeroDocumento")),
        Description = reader.GetString(reader.GetOrdinal("Descripcion")), Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
        Tax = reader.GetDecimal(reader.GetOrdinal("Impuesto")), Total = reader.GetDecimal(reader.GetOrdinal("Total")),
        Status = reader.GetString(reader.GetOrdinal("Estado")), CreatedByName = reader.GetString(reader.GetOrdinal("CreadoPorNombre")),
        CreatedUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")), HasReceipt = reader.GetBoolean(reader.GetOrdinal("TieneComprobante")),
        BudgetAmount = reader.GetDecimal(reader.GetOrdinal("MontoPresupuesto")), RealSpent = reader.GetDecimal(reader.GetOrdinal("GastoReal")),
        CommittedSpent = reader.GetDecimal(reader.GetOrdinal("GastoComprometido")), ExecutionPercent = reader.GetDecimal(reader.GetOrdinal("PorcentajeEjecucion")),
        ConsumptionLevel = reader.GetString(reader.GetOrdinal("NivelConsumo"))
    };

    private static string? NullableString(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name); return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }
    private static SqlCommand Procedure(SqlConnection connection, string name) => new(name, connection) { CommandType = CommandType.StoredProcedure };
}
