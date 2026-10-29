using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services;

public interface ICrossSellService
{
    Task<IReadOnlyList<CrossSellSuggestion>> GetSuggestionsAsync(
        int? userId,
        IReadOnlySet<int> cartProductIds,
        CancellationToken cancellationToken = default);
}

public sealed class CrossSellDbService : ICrossSellService
{
    private readonly string _connectionString;

    public CrossSellDbService(IConfiguration configuration) =>
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró DefaultConnection.");

    public async Task<IReadOnlyList<CrossSellSuggestion>> GetSuggestionsAsync(
        int? userId,
        IReadOnlySet<int> cartProductIds,
        CancellationToken cancellationToken = default)
    {
        if (cartProductIds.Count == 0) return [];
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Ventas_CrossSellSuggestions", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId is > 0 ? userId.Value : DBNull.Value;
        command.Parameters.Add("@CartProductIds", SqlDbType.NVarChar, -1).Value = string.Join(',', cartProductIds.Order());
        command.Parameters.Add("@CandidateLimit", SqlDbType.Int).Value = 24;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var candidates = new List<CrossSellCandidate>();
        while (await reader.ReadAsync(cancellationToken))
        {
            candidates.Add(new CrossSellCandidate(
                reader.GetInt32(reader.GetOrdinal("ProductoId")),
                reader.GetString(reader.GetOrdinal("Nombre")),
                reader.GetString(reader.GetOrdinal("Categoria")),
                reader.GetDecimal(reader.GetOrdinal("Precio")),
                reader.GetInt32(reader.GetOrdinal("Stock")),
                reader.GetString(reader.GetOrdinal("ImagenUrl")),
                reader.GetBoolean(reader.GetOrdinal("Activo")),
                reader.GetInt32(reader.GetOrdinal("Support")),
                reader.GetInt32(reader.GetOrdinal("ClientSupport")),
                reader.GetBoolean(reader.GetOrdinal("CategoryMatch")),
                reader.GetInt32(reader.GetOrdinal("Popularity"))));
        }
        return CrossSellPolicy.Select(candidates, cartProductIds);
    }
}
