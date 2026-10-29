using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services;

public sealed class BudgetDbService
{
    private readonly string _connectionString;

    public BudgetDbService(IConfiguration configuration) =>
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");

    public async Task<(IReadOnlyList<SelectOptionViewModel> Departments, IReadOnlyList<SelectOptionViewModel> Categories)> GetOptionsAsync()
    {
        var departments = new List<SelectOptionViewModel>();
        var categories = new List<SelectOptionViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Budget_GetOptions");
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) departments.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) categories.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        return (departments, categories);
    }

    public async Task<PagedResult<BudgetListItemViewModel>> ListAsync(BudgetFilterViewModel filter)
    {
        var page = Math.Max(filter.Page, 1);
        var size = Math.Clamp(filter.PageSize, 1, 100);
        var total = 0;
        var items = new List<BudgetListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Budget_List");
        command.Parameters.Add("@Anio", SqlDbType.Int).Value = Db(filter.Year);
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = Db(filter.DepartmentId);
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = Db(filter.Status);
        command.Parameters.Add("@Pagina", SqlDbType.Int).Value = page;
        command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = size;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            total = reader.GetInt32(reader.GetOrdinal("TotalResultados"));
            items.Add(ReadBudget(reader));
        }
        return new() { Items = items, Page = page, PageSize = size, Total = total };
    }

    public async Task<int> CreateAsync(BudgetCreateViewModel model, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Budget_Create");
        command.Parameters.Add("@Anio", SqlDbType.Int).Value = model.Year;
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = model.DepartmentId;
        command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = model.CategoryId;
        AddMoney(command, "@MontoAnual", model.AnnualAmount);
        command.Parameters.Add("@Notas", SqlDbType.NVarChar, 800).Value = Db(model.Notes);
        AddActor(command, userId, userName);
        await connection.OpenAsync();
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    public async Task<BudgetDetailsViewModel?> GetDetailsAsync(int budgetId)
    {
        if (budgetId <= 0) return null;

        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Budget_GetById");
        command.Parameters.Add("@PresupuestoId", SqlDbType.Int).Value = budgetId;
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;
        var model = new BudgetDetailsViewModel { Budget = ReadBudget(reader) };
        var details = new List<BudgetDetailLineViewModel>();
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync()) details.Add(new()
            {
                BudgetDetailId = reader.GetInt32(0), CategoryId = reader.GetInt32(1), CategoryName = NullableString(reader, 2) ?? "Sin categoría",
                Month = reader.GetInt32(3), AllocatedAmount = reader.GetDecimal(4), Notes = NullableString(reader, 5)
            });
        }
        var audit = new List<BudgetAuditViewModel>();
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync()) audit.Add(new()
            {
                Action = NullableString(reader, 0) ?? "Sin acción", UserName = NullableString(reader, 1) ?? "Usuario no disponible",
                CreatedUtc = reader.GetDateTime(2), Detail = NullableString(reader, 3)
            });
        }
        var categories = new List<SelectOptionViewModel>();
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync()) categories.Add(new() { Id = reader.GetInt32(0), Name = NullableString(reader, 1) ?? "Sin nombre" });
        }
        model.Details = details;
        model.Audit = audit;
        model.Categories = categories;
        return model;
    }

    public Task SaveDetailAsync(BudgetDetailEditViewModel model, int userId, string userName) => ExecuteAsync(
        "dbo.sp_Budget_SaveDetail", model.BudgetId, userId, userName,
        command =>
        {
            command.Parameters.Add("@PresupuestoDetalleId", SqlDbType.Int).Value = model.BudgetDetailId > 0 ? model.BudgetDetailId : DBNull.Value;
            command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = model.CategoryId;
            command.Parameters.Add("@Mes", SqlDbType.TinyInt).Value = model.Month;
            AddMoney(command, "@MontoAsignado", model.AllocatedAmount);
            command.Parameters.Add("@Notas", SqlDbType.NVarChar, 300).Value = Db(model.Notes);
        });

    public Task UpdateDraftAsync(BudgetHeaderEditViewModel model, int userId, string userName) => ExecuteAsync(
        "dbo.sp_Budget_UpdateDraft", model.BudgetId, userId, userName,
        command =>
        {
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = model.Year;
            AddMoney(command, "@MontoAnual", model.AnnualAmount);
            command.Parameters.Add("@Notas", SqlDbType.NVarChar, 800).Value = Db(model.Notes);
        });

    public Task DistributeAsync(int budgetId, int categoryId, int userId, string userName) => ExecuteAsync(
        "dbo.sp_Budget_Distribute", budgetId, userId, userName,
        command => command.Parameters.Add("@CategoriaId", SqlDbType.Int).Value = categoryId);

    public Task TransitionAsync(int budgetId, string action, string? reason, int userId, string userName) => ExecuteAsync(
        "dbo.sp_Budget_Transition", budgetId, userId, userName,
        command =>
        {
            command.Parameters.Add("@Accion", SqlDbType.NVarChar, 20).Value = action;
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 500).Value = Db(reason);
        });

    public async Task<int> CopyAsync(int sourceBudgetId, int targetYear, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Budget_Copy");
        command.Parameters.Add("@PresupuestoOrigenId", SqlDbType.Int).Value = sourceBudgetId;
        command.Parameters.Add("@AnioDestino", SqlDbType.Int).Value = targetYear;
        AddActor(command, userId, userName);
        await connection.OpenAsync();
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private async Task ExecuteAsync(string procedure, int budgetId, int userId, string userName, Action<SqlCommand> configure)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, procedure);
        command.Parameters.Add("@PresupuestoId", SqlDbType.Int).Value = budgetId;
        configure(command);
        AddActor(command, userId, userName);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    private static BudgetListItemViewModel ReadBudget(SqlDataReader reader) => new()
    {
        BudgetId = reader.GetInt32(reader.GetOrdinal("PresupuestoId")), Year = reader.GetInt32(reader.GetOrdinal("Anio")),
        DepartmentId = reader.GetInt32(reader.GetOrdinal("DepartamentoId")), DepartmentName = NullableString(reader, reader.GetOrdinal("Departamento")) ?? "Departamento no disponible",
        Currency = NullableString(reader, reader.GetOrdinal("Moneda")) ?? "CRC", Status = NullableString(reader, reader.GetOrdinal("Estado")) ?? "Borrador",
        Notes = NullableString(reader, reader.GetOrdinal("Notas")), AnnualAmount = reader.GetDecimal(reader.GetOrdinal("MontoAnual")),
        CreatedByName = NullableString(reader, reader.GetOrdinal("CreadoPorNombre")) ?? "Usuario no disponible", CreatedUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
        Active = reader.GetBoolean(reader.GetOrdinal("Activo"))
    };

    private static void AddActor(SqlCommand command, int userId, string userName)
    {
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName;
    }
    private static void AddMoney(SqlCommand command, string name, decimal value)
    {
        var parameter = command.Parameters.Add(name, SqlDbType.Decimal);
        parameter.Precision = 18; parameter.Scale = 2; parameter.Value = value;
    }
    private static object Db(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
    private static object Db(int? value) => value is > 0 ? value.Value : DBNull.Value;
    private static string? NullableString(SqlDataReader reader, int ordinal) => reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    private static SqlCommand Procedure(SqlConnection connection, string name) => new(name, connection) { CommandType = CommandType.StoredProcedure };
}
