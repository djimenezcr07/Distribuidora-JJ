using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

public interface IComboDbService
{
    Task<IReadOnlyList<ComboListItemViewModel>> GetAdminCombosAsync(CancellationToken cancellationToken = default);
    Task<ComboDetailViewModel?> GetDetailAsync(int comboId, CancellationToken cancellationToken = default);
    Task<int> CreateAsync(ComboFormViewModel model, int userId, string userName, CancellationToken cancellationToken = default);
    Task ToggleStatusAsync(int comboId, int userId, string userName, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StoreComboViewModel>> GetStoreCombosAsync(string? search, CancellationToken cancellationToken = default);
    Task<StoreComboViewModel?> GetStoreComboAsync(int comboId, CancellationToken cancellationToken = default);
}

public sealed class ComboDbService : IComboDbService
{
    private readonly string _connectionString;

    public ComboDbService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la configuración de base de datos.");
    }

    public async Task<IReadOnlyList<ComboListItemViewModel>> GetAdminCombosAsync(
        CancellationToken cancellationToken = default)
    {
        var result = new List<ComboListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Admin_GetCombos", connection);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new ComboListItemViewModel
            {
                ComboId = reader.GetInt32(reader.GetOrdinal("ComboId")),
                Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                Descripcion = ReadNullableString(reader, "Descripcion"),
                Precio = reader.GetDecimal(reader.GetOrdinal("Precio")),
                Activo = reader.GetBoolean(reader.GetOrdinal("Activo")),
                FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
                RegistradoPorNombre = reader.GetString(reader.GetOrdinal("RegistradoPorNombre")),
                CantidadProductos = reader.GetInt32(reader.GetOrdinal("CantidadProductos")),
                StockDisponibleCombo = reader.GetInt32(reader.GetOrdinal("StockDisponibleCombo")),
                EstadoDisponibilidad = reader.GetString(reader.GetOrdinal("EstadoDisponibilidad"))
            });
        }

        return result;
    }

    public async Task<ComboDetailViewModel?> GetDetailAsync(
        int comboId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Admin_GetComboDetail", connection);
        command.Parameters.Add("@ComboId", SqlDbType.Int).Value = comboId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var model = new ComboDetailViewModel
        {
            ComboId = reader.GetInt32(reader.GetOrdinal("ComboId")),
            Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
            Descripcion = ReadNullableString(reader, "Descripcion"),
            Precio = reader.GetDecimal(reader.GetOrdinal("Precio")),
            Activo = reader.GetBoolean(reader.GetOrdinal("Activo")),
            RegistradoPorNombre = reader.GetString(reader.GetOrdinal("RegistradoPorNombre")),
            FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
            StockDisponibleCombo = reader.GetInt32(reader.GetOrdinal("StockDisponibleCombo")),
            EstadoDisponibilidad = reader.GetString(reader.GetOrdinal("EstadoDisponibilidad"))
        };

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                model.Componentes.Add(new ComboDetailLineViewModel
                {
                    ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                    ProductoNombre = reader.GetString(reader.GetOrdinal("ProductoNombre")),
                    Cantidad = reader.GetInt32(reader.GetOrdinal("Cantidad")),
                    StockDisponible = reader.GetInt32(reader.GetOrdinal("StockDisponible")),
                    ProductoActivo = reader.GetBoolean(reader.GetOrdinal("ProductoActivo"))
                });
            }
        }

        return model;
    }

    public async Task<int> CreateAsync(
        ComboFormViewModel model,
        int userId,
        string userName,
        CancellationToken cancellationToken = default)
    {
        var components = model.Productos
            .Where(product => product.Seleccionado)
            .GroupBy(product => product.ProductoId)
            .Select(group => new
            {
                productoId = group.Key,
                cantidad = group.Sum(product => product.Cantidad)
            })
            .ToArray();

        if (components.Length == 0 || components.Any(component => component.productoId <= 0 || component.cantidad <= 0))
        {
            throw new ArgumentException("El combo no contiene componentes válidos.", nameof(model));
        }

        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Admin_CreateCombo", connection);
        command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = model.Nombre.Trim();
        command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value =
            string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
        var price = command.Parameters.Add("@Precio", SqlDbType.Decimal);
        price.Precision = 18;
        price.Scale = 2;
        price.Value = model.Precio;
        command.Parameters.Add("@ComponentesJson", SqlDbType.NVarChar, -1).Value = JsonSerializer.Serialize(components);
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName.Trim();
        var output = command.Parameters.Add("@NuevoComboId", SqlDbType.Int);
        output.Direction = ParameterDirection.Output;

        await connection.OpenAsync(cancellationToken);
        await command.ExecuteNonQueryAsync(cancellationToken);
        return output.Value is int comboId && comboId > 0
            ? comboId
            : throw new InvalidOperationException("La base de datos no devolvió el combo creado.");
    }

    public async Task ToggleStatusAsync(
        int comboId,
        int userId,
        string userName,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Admin_ToggleComboStatus", connection);
        command.Parameters.Add("@ComboId", SqlDbType.Int).Value = comboId;
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName.Trim();
        await connection.OpenAsync(cancellationToken);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<StoreComboViewModel>> GetStoreCombosAsync(
        string? search,
        CancellationToken cancellationToken = default)
    {
        var result = new List<StoreComboViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Store_GetActiveCombos", connection);
        command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value =
            string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(MapStoreCombo(reader));
        }

        return result;
    }

    public async Task<StoreComboViewModel?> GetStoreComboAsync(
        int comboId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = StoredProcedure("dbo.sp_Store_GetComboById", connection);
        command.Parameters.Add("@ComboId", SqlDbType.Int).Value = comboId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? MapStoreCombo(reader) : null;
    }

    private static StoreComboViewModel MapStoreCombo(SqlDataReader reader) => new()
    {
        ComboId = reader.GetInt32(reader.GetOrdinal("ComboId")),
        Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
        Descripcion = ReadNullableString(reader, "Descripcion") ?? string.Empty,
        Precio = reader.GetDecimal(reader.GetOrdinal("Precio")),
        StockDisponible = reader.GetInt32(reader.GetOrdinal("StockDisponibleCombo")),
        CantidadProductos = reader.GetInt32(reader.GetOrdinal("CantidadProductos")),
        ComponentesValidos = reader.GetBoolean(reader.GetOrdinal("ComponentesValidos")),
        ComponentesResumen = ReadNullableString(reader, "ComponentesResumen") ?? string.Empty
    };

    private static SqlCommand StoredProcedure(string name, SqlConnection connection) => new(name, connection)
    {
        CommandType = CommandType.StoredProcedure
    };

    private static string? ReadNullableString(SqlDataReader reader, string column)
    {
        var ordinal = reader.GetOrdinal(column);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }
}
