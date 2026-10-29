using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

public interface IInventoryIntelligenceService
{
    Task<InventoryIntelligenceViewModel> GetAsync(
        InventoryIntelligenceFilterViewModel filter,
        CancellationToken cancellationToken = default);
}

public sealed class InventoryIntelligenceDbService : IInventoryIntelligenceService
{
    private readonly string _connectionString;

    public InventoryIntelligenceDbService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la configuración de base de datos.");
    }

    public async Task<InventoryIntelligenceViewModel> GetAsync(
        InventoryIntelligenceFilterViewModel filter,
        CancellationToken cancellationToken = default)
    {
        var model = new InventoryIntelligenceViewModel
        {
            Filter = filter,
            GeneratedUtc = DateTime.UtcNow
        };

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await LoadSuggestionsAsync(connection, model, cancellationToken);
        await LoadSlowMovingAsync(connection, model, cancellationToken);
        await LoadSeasonalAsync(connection, model, cancellationToken);
        model.TendenciaEstacional = InventoryIntelligencePolicy.NormalizeTwelveMonths(model.TendenciaEstacional);
        return model;
    }

    private static async Task LoadSuggestionsAsync(
        SqlConnection connection,
        InventoryIntelligenceViewModel model,
        CancellationToken cancellationToken)
    {
        await using var command = Procedure("dbo.sp_Admin_GetPurchaseSuggestions", connection);
        command.Parameters.Add("@MesesRecientes", SqlDbType.Int).Value = model.Filter.RecentMonths;
        command.Parameters.Add("@MesesCobertura", SqlDbType.Int).Value = model.Filter.CoverageMonths;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            model.SugerenciasCompra.Add(new PurchaseSuggestionItem
            {
                ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                StockActual = reader.GetInt32(reader.GetOrdinal("StockActual")),
                StockMinimo = reader.GetInt32(reader.GetOrdinal("StockMinimo")),
                UnidadesVendidasVentana = reader.GetInt32(reader.GetOrdinal("UnidadesVendidasVentana")),
                PromedioVentaMensual = reader.GetDecimal(reader.GetOrdinal("PromedioVentaMensual")),
                MesesCobertura = reader.GetInt32(reader.GetOrdinal("MesesCobertura")),
                CantidadSugerida = reader.GetInt32(reader.GetOrdinal("CantidadSugerida")),
                DatosInsuficientes = reader.GetBoolean(reader.GetOrdinal("DatosInsuficientes"))
            });
        }
    }

    private static async Task LoadSlowMovingAsync(
        SqlConnection connection,
        InventoryIntelligenceViewModel model,
        CancellationToken cancellationToken)
    {
        await using var command = Procedure("dbo.sp_Admin_GetSlowMovingProducts", connection);
        command.Parameters.Add("@VentanaDias", SqlDbType.Int).Value = model.Filter.SlowWindowDays;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var lastSaleOrdinal = reader.GetOrdinal("UltimaVenta");
            model.ProductosEstancados.Add(new SlowMovingProductItem
            {
                ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                Stock = reader.GetInt32(reader.GetOrdinal("Stock")),
                FechaCreacion = reader.GetDateTime(reader.GetOrdinal("FechaCreacion")),
                UltimaVenta = reader.IsDBNull(lastSaleOrdinal) ? null : reader.GetDateTime(lastSaleOrdinal),
                DiasSinMovimiento = reader.GetInt32(reader.GetOrdinal("DiasSinMovimiento")),
                VendidoEnVentana = reader.GetInt32(reader.GetOrdinal("VendidoEnVentana")),
                NivelRiesgo = reader.GetString(reader.GetOrdinal("NivelRiesgo"))
            });
        }
    }

    private static async Task LoadSeasonalAsync(
        SqlConnection connection,
        InventoryIntelligenceViewModel model,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand("""
                SET NOCOUNT ON;
                IF @AnioInicio NOT BETWEEN 2000 AND 2100 OR @AnioFin NOT BETWEEN 2000 AND 2100
                   OR @AnioInicio > @AnioFin OR @AnioFin - @AnioInicio > 9
                    THROW 54542, N'El período estacional no es válido.', 1;

                ;WITH Months AS
                (
                    SELECT number AS NumeroMes,
                           CHOOSE(number, N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
                                  N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre') AS NombreMes
                    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) valuesTable(number)
                ), Sales AS
                (
                    SELECT MONTH(orders.FechaPedido) AS NumeroMes,
                           COALESCE(amount.Neto,CONVERT(DECIMAL(18,2), detail.Cantidad * detail.PrecioUnitario)) AS Total,
                           detail.Cantidad AS Units
                    FROM dbo.PedidoDetalle detail
                    LEFT JOIN dbo.Stage2OrderAmountLines amount ON amount.PedidoId=detail.PedidoId AND amount.LineKind=N'Producto' AND amount.LineId=detail.PedidoDetalleId
                    INNER JOIN dbo.Pedidos orders ON orders.PedidoId = detail.PedidoId
                    WHERE YEAR(orders.FechaPedido) BETWEEN @AnioInicio AND @AnioFin
                      AND orders.Estado NOT IN (N'Cancelado', N'Rechazado')
                      AND detail.PedidoComboId IS NULL
                    UNION ALL
                    SELECT MONTH(orders.FechaPedido), combo.Subtotal, combo.Cantidad
                    FROM dbo.PedidoCombos combo
                    INNER JOIN dbo.Pedidos orders ON orders.PedidoId = combo.PedidoId
                    WHERE YEAR(orders.FechaPedido) BETWEEN @AnioInicio AND @AnioFin
                      AND orders.Estado NOT IN (N'Cancelado', N'Rechazado')
                )
                SELECT months.NumeroMes,
                       months.NombreMes,
                       CONVERT(DECIMAL(18,2), SUM(ISNULL(sales.Total, 0))) AS TotalVendido,
                       CONVERT(INT, SUM(ISNULL(sales.Units, 0))) AS UnidadesVendidas
                FROM Months months
                LEFT JOIN Sales sales ON sales.NumeroMes = months.NumeroMes
                GROUP BY months.NumeroMes, months.NombreMes
                ORDER BY months.NumeroMes;
            """, connection);
        command.Parameters.Add("@AnioInicio", SqlDbType.Int).Value = model.Filter.StartYear;
        command.Parameters.Add("@AnioFin", SqlDbType.Int).Value = model.Filter.EndYear;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            model.TendenciaEstacional.Add(new SeasonalTrendPoint
            {
                NumeroMes = reader.GetInt32(reader.GetOrdinal("NumeroMes")),
                NombreMes = reader.GetString(reader.GetOrdinal("NombreMes")),
                TotalVendido = reader.GetDecimal(reader.GetOrdinal("TotalVendido")),
                UnidadesVendidas = reader.GetInt32(reader.GetOrdinal("UnidadesVendidas"))
            });
        }
    }

    private static SqlCommand Procedure(string name, SqlConnection connection) => new(name, connection)
    {
        CommandType = CommandType.StoredProcedure
    };
}
