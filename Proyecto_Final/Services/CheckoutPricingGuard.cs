using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services;

public sealed class CheckoutPricingMismatchException() : InvalidOperationException(
    "El contrato persistido no coincide con PromotionEngine; no se confirma el pedido.") { }

internal static class CheckoutPricingGuard
{
    // Validate the existing SQL calculation with the real engine, under the locks
    // acquired by SQL0012 and the original-login transaction. Never repair a price
    // or publish a quote on behalf of an absent pricing authority.
    internal static async Task ValidateAsync(SqlConnection connection, SqlTransaction transaction,
        int userId, DateTime evaluationDate, OrderCreationResult order, CancellationToken cancellationToken)
    {
        var items = new List<CartItemViewModel>();
        var consumed = new Dictionary<int, int>();
        await using (var command = new SqlCommand("""
            SELECT d.ProductoId,d.Cantidad,p.Precio FROM dbo.PedidoDetalle d
            JOIN dbo.Productos p ON p.ProductoId=d.ProductoId
            WHERE d.PedidoId=@Order AND d.PedidoComboId IS NULL AND d.EsRegalo=0;
            SELECT ProductoId,CONVERT(int,SUM(Quantity)) FROM (
                SELECT ProductoId,CONVERT(bigint,Cantidad) AS Quantity FROM dbo.PedidoDetalle
                WHERE PedidoId=@Order AND PedidoComboId IS NULL
                UNION ALL
                SELECT d.ProductoId,CONVERT(bigint,d.CantidadTotal) FROM dbo.PedidoComboDetalle d
                JOIN dbo.PedidoCombos c ON c.PedidoComboId=d.PedidoComboId WHERE c.PedidoId=@Order
            ) q GROUP BY ProductoId;
            """, connection, transaction))
        {
            command.Parameters.Add("@Order", SqlDbType.Int).Value = order.PedidoId;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                items.Add(new() { ProductoId = reader.GetInt32(0), Cantidad = reader.GetInt32(1), Precio = reader.GetDecimal(2) });
            if (!await reader.NextResultAsync(cancellationToken)) throw new CheckoutPricingMismatchException();
            while (await reader.ReadAsync(cancellationToken)) consumed.Add(reader.GetInt32(0), reader.GetInt32(1));
        }
        string segment;
        await using (var command = new SqlCommand("SELECT SegmentoCliente FROM dbo.Usuarios WHERE UsuarioId=@Actor AND Activo=1;", connection, transaction))
        {
            command.Parameters.Add("@Actor", SqlDbType.Int).Value = userId;
            segment = await command.ExecuteScalarAsync(cancellationToken) as string ?? string.Empty;
        }
        if (segment is not ("Minorista" or "Mayorista")) throw new CheckoutPricingMismatchException();
        var promotions = new List<Proyecto_Final.Models.Admin.ActivePromotionViewModel>();
        await using (var command = PromotionsDbService.CreateActivePromotionCommand(connection, segment))
        {
            command.Transaction = transaction;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken) || reader.GetDateTime(0).Date != evaluationDate.Date
                || !await reader.NextResultAsync(cancellationToken)) throw new CheckoutPricingMismatchException();
            while (await reader.ReadAsync(cancellationToken))
            {
                var promotion = PromotionsDbService.ReadActivePromotion(reader);
                if (promotion.ProductoRegaloId is int gift)
                    promotion.ProductoRegaloStock = checked(promotion.ProductoRegaloStock + consumed.GetValueOrDefault(gift));
                promotions.Add(promotion);
            }
        }
        var expected = PromotionEngine.Apply(items, promotions, segment, evaluationDate);
        var actual = new List<(int Promotion, int Product, string Kind, decimal? Discount, int? GiftUnits)>();
        await using (var command = new SqlCommand("""
            SELECT PromocionId,ProductoId,TipoBeneficio,MontoDescontado,UnidadesRegalo
            FROM dbo.PromocionAplicaciones WHERE PedidoId=@Order;
            """, connection, transaction))
        {
            command.Parameters.Add("@Order", SqlDbType.Int).Value = order.PedidoId;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                actual.Add((reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2),
                    reader.IsDBNull(3) ? null : reader.GetDecimal(3), reader.IsDBNull(4) ? null : reader.GetInt32(4)));
        }
        var applied = expected.Applied.Select(p => (Promotion: p.PromocionId, Product: p.ProductoId,
            Kind: p.TipoBeneficio, Discount: p.MontoDescontado, GiftUnits: p.UnidadesRegalo));
        if (!actual.OrderBy(p => p.Promotion).ThenBy(p => p.Product)
            .SequenceEqual(applied.OrderBy(p => p.Promotion).ThenBy(p => p.Product)))
            throw new CheckoutPricingMismatchException();
        var net = items.Sum(p => p.SubtotalConDescuento)
            + order.Items.Where(p => p.ItemType == CartItemTypes.Combo).Sum(p => p.SubtotalConDescuento);
        if (net != order.Total) throw new CheckoutPricingMismatchException();
        var final = net + Math.Round(net * 0.13m, 2, MidpointRounding.AwayFromZero);
        if (final > 2_000_000m) throw new CommercialAssignmentsUnavailableException();
    }
}
