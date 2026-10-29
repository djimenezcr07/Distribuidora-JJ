using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services;

public partial class ExpensesDbService
{
    public async Task<(IReadOnlyList<SelectOptionViewModel> Departments, IReadOnlyList<SelectOptionViewModel> Categories)> GetManagementOptionsAsync()
    {
        var departments = new List<SelectOptionViewModel>();
        var categories = new List<SelectOptionViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_GetOptions");
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) departments.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) categories.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        return (departments, categories);
    }

    public async Task<(PagedResult<OperatingExpenseListItemViewModel> Page, decimal Registered, decimal Approved, decimal Paid, decimal Pending, decimal Available)> ListOperatingAsync(ExpenseFilterViewModel filter)
    {
        var page = Math.Max(filter.Page, 1);
        var size = Math.Clamp(filter.PageSize, 1, 100);
        var total = 0;
        var items = new List<OperatingExpenseListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_List");
        AddExpenseFilters(command, filter);
        command.Parameters.Add("@Pagina", SqlDbType.Int).Value = page;
        command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = size;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            total = reader.GetInt32(reader.GetOrdinal("TotalResultados"));
            items.Add(ReadOperatingExpense(reader));
        }
        decimal registered = 0, approved = 0, paid = 0, pending = 0, available = 0;
        if (await reader.NextResultAsync() && await reader.ReadAsync())
        {
            registered = reader.GetDecimal(0); approved = reader.GetDecimal(1); paid = reader.GetDecimal(2);
            pending = reader.GetDecimal(3); available = reader.GetDecimal(4);
        }
        return (new() { Items = items, Page = page, PageSize = size, Total = total }, registered, approved, paid, pending, available);
    }

    public async Task<OperatingExpenseDetailsViewModel?> GetOperatingDetailsAsync(int expenseId)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_GetById");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;
        var result = new OperatingExpenseDetailsViewModel
        {
            Expense = ReadOperatingExpense(reader),
            DocumentType = reader.GetString(reader.GetOrdinal("TipoDocumento")),
            PaymentMethod = reader.GetString(reader.GetOrdinal("MetodoPago")),
            Currency = reader.GetString(reader.GetOrdinal("Moneda")),
            CancellationReason = ExpenseNullableString(reader, "MotivoCancelacion"),
            ReceiptOriginalName = ExpenseNullableString(reader, "ComprobanteNombreOriginal")
        };
        var audit = new List<BudgetAuditViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) audit.Add(new()
        {
            Action = reader.GetString(0), UserName = reader.GetString(1), CreatedUtc = reader.GetDateTime(2), Detail = reader.IsDBNull(3) ? null : reader.GetString(3)
        });
        result.Audit = audit;
        return result;
    }

    public async Task<OperatingExpenseFormViewModel?> GetOperatingFormAsync(int expenseId)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_GetForEdit");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        if (!await reader.ReadAsync()) return null;
        return new()
        {
            ExpenseId = reader.GetInt32(0), ExpenseDate = reader.GetDateTime(1), DepartmentId = reader.GetInt32(2),
            CategoryId = reader.GetInt32(3), SupplierName = reader.IsDBNull(4) ? null : reader.GetString(4),
            DocumentNumber = reader.GetString(5), DocumentType = reader.GetString(6), Description = reader.GetString(7),
            Subtotal = reader.GetDecimal(8), Tax = reader.GetDecimal(9), PaymentMethod = reader.GetString(10),
            OperationToken = reader.GetGuid(11)
        };
    }

    public async Task<ExpenseCreationResult> CreateOperatingAsync(OperatingExpenseFormViewModel model, StagedPrivateFile? receipt, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_Create");
        AddOperatingForm(command, model);
        AddExpenseFile(command, receipt);
        AddExpenseActor(command, userId, userName);
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        if (!await reader.ReadAsync()) throw new InvalidOperationException("La base de datos no devolvió el gasto creado.");
        return new(reader.GetInt32(0), reader.GetBoolean(1), reader.GetString(2), reader.GetDecimal(3));
    }

    public async Task UpdateOperatingAsync(OperatingExpenseFormViewModel model, StagedPrivateFile? receipt, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_Update");
        AddOperatingForm(command, model);
        AddExpenseFile(command, receipt);
        AddExpenseActor(command, userId, userName);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task MarkReceiptReadyAsync(int expenseId, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_MarkReceiptReady");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        AddExpenseActor(command, userId, userName);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task DeletePendingReceiptAsync(int expenseId, int userId)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_DeletePendingReceipt");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task TransitionOperatingAsync(int expenseId, string action, string? reason, bool overrideBudget, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_Transition");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        command.Parameters.Add("@Accion", SqlDbType.NVarChar, 20).Value = action;
        command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 500).Value = ExpenseDb(reason);
        command.Parameters.Add("@AutorizarExceso", SqlDbType.Bit).Value = overrideBudget;
        AddExpenseActor(command, userId, userName);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task<PrivateFileMetadata?> GetReceiptAsync(int expenseId, int userId, bool canManage)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ExpenseProcedure(connection, "dbo.sp_OperatingExpense_GetReceipt");
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = expenseId;
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@PuedeAdministrar", SqlDbType.Bit).Value = canManage;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        return await reader.ReadAsync() ? new()
        {
            OwnerId = expenseId, StorageArea = "ExpenseReceipts", StorageKey = reader.GetString(0),
            OriginalName = reader.GetString(1), MimeType = reader.GetString(2)
        } : null;
    }

    private static void AddExpenseFilters(SqlCommand command, ExpenseFilterViewModel filter)
    {
        command.Parameters.Add("@Busqueda", SqlDbType.NVarChar, 180).Value = ExpenseDb(filter.Search);
        command.Parameters.Add("@Desde", SqlDbType.Date).Value = filter.From?.Date ?? (object)DBNull.Value;
        command.Parameters.Add("@Hasta", SqlDbType.Date).Value = filter.To?.Date ?? (object)DBNull.Value;
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = filter.DepartmentId is > 0 ? filter.DepartmentId.Value : DBNull.Value;
        command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = filter.CategoryId is > 0 ? filter.CategoryId.Value : DBNull.Value;
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = ExpenseDb(filter.Status);
    }

    private static void AddOperatingForm(SqlCommand command, OperatingExpenseFormViewModel model)
    {
        command.Parameters.Add("@GastoId", SqlDbType.Int).Value = model.ExpenseId > 0 ? model.ExpenseId : DBNull.Value;
        command.Parameters.Add("@FechaGasto", SqlDbType.Date).Value = model.ExpenseDate.Date;
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = DocumentExpirationPolicy.BusinessDate(DateTimeOffset.UtcNow);
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = model.DepartmentId;
        command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = model.CategoryId;
        command.Parameters.Add("@Proveedor", SqlDbType.NVarChar, 180).Value = ExpenseDb(model.SupplierName);
        command.Parameters.Add("@NumeroDocumento", SqlDbType.NVarChar, 80).Value = model.DocumentNumber.Trim();
        command.Parameters.Add("@TipoDocumento", SqlDbType.NVarChar, 40).Value = model.DocumentType.Trim();
        command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value = model.Description.Trim();
        AddExpenseMoney(command, "@Subtotal", model.Subtotal);
        AddExpenseMoney(command, "@Impuesto", model.Tax);
        command.Parameters.Add("@MetodoPago", SqlDbType.NVarChar, 40).Value = model.PaymentMethod.Trim();
        command.Parameters.Add("@TokenOperacion", SqlDbType.UniqueIdentifier).Value = model.OperationToken;
    }

    private static void AddExpenseFile(SqlCommand command, StagedPrivateFile? receipt)
    {
        command.Parameters.Add("@ComprobanteNombreOriginal", SqlDbType.NVarChar, 255).Value = receipt?.OriginalName ?? (object)DBNull.Value;
        command.Parameters.Add("@ComprobanteStorageKey", SqlDbType.NVarChar, 80).Value = receipt?.StorageKey ?? (object)DBNull.Value;
        command.Parameters.Add("@ComprobanteMimeType", SqlDbType.NVarChar, 100).Value = receipt?.ContentType ?? (object)DBNull.Value;
        command.Parameters.Add("@ComprobanteExtension", SqlDbType.NVarChar, 10).Value = receipt?.Extension ?? (object)DBNull.Value;
        command.Parameters.Add("@ComprobanteTamanoBytes", SqlDbType.BigInt).Value = receipt?.Length ?? (object)DBNull.Value;
        command.Parameters.Add("@ComprobanteHashSha256", SqlDbType.Char, 64).Value = receipt?.Sha256 ?? (object)DBNull.Value;
    }

    private static OperatingExpenseListItemViewModel ReadOperatingExpense(SqlDataReader reader) => new()
    {
        ExpenseId = reader.GetInt32(reader.GetOrdinal("GastoId")), ExpenseDate = reader.GetDateTime(reader.GetOrdinal("FechaGasto")),
        DepartmentName = reader.GetString(reader.GetOrdinal("Departamento")), CategoryName = reader.GetString(reader.GetOrdinal("Categoria")),
        SupplierName = ExpenseNullableString(reader, "Proveedor"), DocumentNumber = reader.GetString(reader.GetOrdinal("NumeroDocumento")),
        Description = reader.GetString(reader.GetOrdinal("Descripcion")), Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal")),
        Tax = reader.GetDecimal(reader.GetOrdinal("Impuesto")), Total = reader.GetDecimal(reader.GetOrdinal("Total")),
        Status = reader.GetString(reader.GetOrdinal("Estado")), CreatedByName = reader.GetString(reader.GetOrdinal("CreadoPorNombre")),
        CreatedUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")), HasReceipt = reader.GetBoolean(reader.GetOrdinal("TieneComprobante")),
        BudgetAmount = reader.GetDecimal(reader.GetOrdinal("MontoPresupuesto")), RealSpent = reader.GetDecimal(reader.GetOrdinal("GastoReal")),
        CommittedSpent = reader.GetDecimal(reader.GetOrdinal("GastoComprometido")), ExecutionPercent = reader.GetDecimal(reader.GetOrdinal("PorcentajeEjecucion")),
        ConsumptionLevel = reader.GetString(reader.GetOrdinal("NivelConsumo"))
    };

    private static void AddExpenseActor(SqlCommand command, int userId, string userName)
    {
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName;
    }
    private static void AddExpenseMoney(SqlCommand command, string name, decimal value)
    {
        var parameter = command.Parameters.Add(name, SqlDbType.Decimal); parameter.Precision = 18; parameter.Scale = 2; parameter.Value = value;
    }
    private static object ExpenseDb(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
    private static string? ExpenseNullableString(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name); return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }
    private static SqlCommand ExpenseProcedure(SqlConnection connection, string name) => new(name, connection) { CommandType = CommandType.StoredProcedure };
}
