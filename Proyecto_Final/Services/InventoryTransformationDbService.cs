using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

public interface IInventoryTransformationService
{
    Task<StockTransformationResultViewModel> TransformAsync(
        StockTransformationFormViewModel model,
        int userId,
        string userName,
        CancellationToken cancellationToken = default);
}

public sealed class InventoryTransformationDbService : IInventoryTransformationService
{
    private readonly string _connectionString;

    public InventoryTransformationDbService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la configuración de base de datos.");
    }

    public async Task<StockTransformationResultViewModel> TransformAsync(
        StockTransformationFormViewModel model,
        int userId,
        string userName,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Inventory_TransformStockAtomic", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@ProductoOrigenId", SqlDbType.Int).Value = model.ProductoOrigenId;
        command.Parameters.Add("@CantidadOrigen", SqlDbType.Int).Value = model.CantidadOrigen;
        command.Parameters.Add("@ProductoDestinoId", SqlDbType.Int).Value = model.ProductoDestinoId;
        command.Parameters.Add("@CantidadDestino", SqlDbType.Int).Value = model.CantidadDestino;
        command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 300).Value =
            string.IsNullOrWhiteSpace(model.Motivo) ? DBNull.Value : model.Motivo.Trim();
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName.Trim();

        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("La operación no devolvió un resultado.");
        }

        return new StockTransformationResultViewModel
        {
            Reference = reader.GetGuid(reader.GetOrdinal("ReferenciaTransformacion")),
            SourceProductId = reader.GetInt32(reader.GetOrdinal("ProductoOrigenId")),
            SourceProductName = reader.GetString(reader.GetOrdinal("ProductoOrigenNombre")),
            SourceStockBefore = reader.GetInt32(reader.GetOrdinal("StockOrigenAnterior")),
            SourceStockAfter = reader.GetInt32(reader.GetOrdinal("StockOrigenNuevo")),
            DestinationProductId = reader.GetInt32(reader.GetOrdinal("ProductoDestinoId")),
            DestinationProductName = reader.GetString(reader.GetOrdinal("ProductoDestinoNombre")),
            DestinationStockBefore = reader.GetInt32(reader.GetOrdinal("StockDestinoAnterior")),
            DestinationStockAfter = reader.GetInt32(reader.GetOrdinal("StockDestinoNuevo"))
        };
    }
}
