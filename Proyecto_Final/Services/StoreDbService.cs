using System.Data;
using System.Data.Common;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services;

public sealed class StoreDbService
{
    private readonly string _connectionString;

    public StoreDbService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la configuración de base de datos.");
    }

    public async Task<StoreProductViewModel?> GetStoreProductByIdAsync(
        int productId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Store_GetProductById", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@ProductoId", SqlDbType.Int).Value = productId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new StoreProductViewModel
        {
            ProductoId = reader.GetInt32(0),
            Nombre = reader.GetString(1),
            Categoria = reader.GetString(2),
            Descripcion = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
            Precio = reader.GetDecimal(4),
            Stock = reader.GetInt32(5),
            ImagenUrl = reader.IsDBNull(6) ? "~/img/whisky-premium.webp" : reader.GetString(6)
        };
    }

    public async Task<OrderCreationResult> CreateOrderWithPromotionsAsync(
        int userId,
        CheckoutViewModel checkout,
        IReadOnlyCollection<CartItemViewModel> items,
        OriginalLoginContext originalLogin,
        CancellationToken cancellationToken = default)
    {
        if (!originalLogin.HasCanonicalLifetime || originalLogin.UserId != userId)
            throw new UnauthorizedAccessException("El checkout no corresponde al login original.");
        if (items.Count == 0)
        {
            throw new InvalidOperationException("El carrito está vacío.");
        }

        if (checkout.OperationToken == Guid.Empty)
        {
            throw new ArgumentException("El intento de checkout no tiene un identificador válido.", nameof(checkout));
        }

        var payloadHash = CheckoutAttemptState.PayloadHash(checkout, items);
        // Ownership commits independently of business success, so a failed/unknown
        // result never allows another login to adopt the UUID.
        await ClaimCheckoutIntentAsync(originalLogin, checkout.OperationToken, payloadHash, cancellationToken);
        var itemsJson = StoreCheckoutPayloadBuilder.CreateItemsJson(items);

        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Stage2_CreateOrderAmountsV2_1", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@TipoEntrega", SqlDbType.NVarChar, 100).Value = checkout.TipoEntrega;
        command.Parameters.Add("@DireccionEntrega", SqlDbType.NVarChar, 500).Value = DbValue(checkout.DireccionEntrega);
        command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 500).Value = DbValue(checkout.Observaciones);
        command.Parameters.Add("@IdentificacionCliente", SqlDbType.NVarChar, 100).Value = DbValue(checkout.Identificacion);
        command.Parameters.Add("@ItemsJson", SqlDbType.NVarChar, -1).Value = itemsJson;
        command.Parameters.Add("@MetodoPago", SqlDbType.NVarChar, 40).Value = checkout.MetodoPago.Trim();
        command.Parameters.Add("@ReferenciaPago", SqlDbType.NVarChar, 80).Value = DbValue(checkout.ReferenciaPago);
        command.Parameters.Add("@TokenOperacion", SqlDbType.UniqueIdentifier).Value = checkout.OperationToken;
        command.Parameters.Add("@OriginalLoginId", SqlDbType.UniqueIdentifier).Value = originalLogin.LoginId;

        return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, userId, null, async () =>
        {
        await using (var claim = CheckoutClaimCommand(connection, originalLogin, checkout.OperationToken, payloadHash))
        {
            claim.Transaction = command.Transaction;
            await claim.ExecuteNonQueryAsync(cancellationToken);
        }
        bool replay;
        await using (var lookup = new SqlCommand("SELECT COUNT(*) FROM dbo.CheckoutOperaciones WHERE UsuarioId=@Actor AND TokenOperacion=@Token;", connection, command.Transaction))
        {
            lookup.Parameters.Add("@Actor", SqlDbType.Int).Value = userId;
            lookup.Parameters.Add("@Token", SqlDbType.UniqueIdentifier).Value = checkout.OperationToken;
            replay = (int)(await lookup.ExecuteScalarAsync(cancellationToken))! > 0;
        }
        DateTime evaluationDate;
        await using (var date = new SqlCommand("SELECT CONVERT(date,SYSDATETIME());", connection, command.Transaction))
            evaluationDate = (DateTime)(await date.ExecuteScalarAsync(cancellationToken))!;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("La base de datos no devolvió el pedido creado.");
        }

        var result = new OrderCreationResult
        {
            IsReplay = replay,
            PedidoId = reader.GetInt32(reader.GetOrdinal("PedidoId")),
            Total = reader.GetDecimal(reader.GetOrdinal("Total"))
        };
        var amountsVersion = reader.GetInt32(reader.GetOrdinal("ContractVersion"));

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var productOrdinal = reader.GetOrdinal("ProductoId");
                var comboOrdinal = reader.GetOrdinal("ComboId");
                var imageOrdinal = reader.GetOrdinal("ImagenUrl");
                var price = reader.GetDecimal(reader.GetOrdinal("PrecioUnitario"));
                var quantity = reader.GetInt32(reader.GetOrdinal("Cantidad"));
                var discount = reader.GetDecimal(reader.GetOrdinal("MontoDescuento"));
                result.Items.Add(new CartItemViewModel
                {
                    ItemType = reader.GetString(reader.GetOrdinal("TipoItem")),
                    ProductoId = reader.IsDBNull(productOrdinal) ? 0 : reader.GetInt32(productOrdinal),
                    ComboId = reader.IsDBNull(comboOrdinal) ? null : reader.GetInt32(comboOrdinal),
                    Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                    Categoria = reader.GetString(reader.GetOrdinal("Categoria")),
                    Descripcion = ReadNullableString(reader, "Descripcion"),
                    Precio = price,
                    Cantidad = quantity,
                    ImagenUrl = reader.IsDBNull(imageOrdinal) ? "~/img/OFER-Combo.webp" : reader.GetString(imageOrdinal),
                    MontoDescuento = discount,
                    SubtotalAntesDescuento = price * quantity + (amountsVersion == 2 ? 0 : discount)
                });
            }
        }

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                result.Gifts.Add(new CartItemViewModel
                {
                    ItemType = CartItemTypes.Product,
                    ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                    Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                    Cantidad = reader.GetInt32(reader.GetOrdinal("Cantidad")),
                    Precio = 0m,
                    EsRegalo = true,
                    PromocionNombre = reader.GetString(reader.GetOrdinal("PromocionNombre"))
                });
            }
        }

        await reader.DisposeAsync();
        if (amountsVersion == 2)
        {
            await using var amounts = new SqlCommand("""
                SELECT Bruto,Descuento,Neto,Impuesto,TotalFinal FROM dbo.Stage2OrderAmounts WHERE PedidoId=@Order;
                SELECT a.LineKind,COALESCE(a.ProductoId,c.ComboId),a.Cantidad,a.PrecioBruto,a.Bruto,a.Descuento,a.Neto
                FROM dbo.Stage2OrderAmountLines a LEFT JOIN dbo.PedidoCombos c
                  ON a.LineKind=N'Combo' AND c.PedidoComboId=a.LineId AND c.PedidoId=a.PedidoId
                WHERE a.PedidoId=@Order;
                """, connection, command.Transaction);
            amounts.Parameters.Add("@Order", SqlDbType.Int).Value = result.PedidoId;
            await using var persisted = await amounts.ExecuteReaderAsync(cancellationToken);
            if (!await persisted.ReadAsync(cancellationToken)) throw new CheckoutPricingMismatchException();
            result.Amounts = new(persisted.GetDecimal(0), persisted.GetDecimal(1), persisted.GetDecimal(2), persisted.GetDecimal(3), persisted.GetDecimal(4));
            if (!await persisted.NextResultAsync(cancellationToken)) throw new CheckoutPricingMismatchException();
            var lineCount = 0;
            while (await persisted.ReadAsync(cancellationToken))
            {
                var kind = persisted.GetString(0);
                var id = persisted.GetInt32(1);
                var line = result.Items.SingleOrDefault(x => x.ItemType == kind
                    && (kind == CartItemTypes.Combo ? x.ComboId == id : x.ProductoId == id));
                if (line is null || line.Cantidad != persisted.GetInt32(2)) throw new CheckoutPricingMismatchException();
                line.Precio = persisted.GetDecimal(3);
                line.SubtotalAntesDescuento = persisted.GetDecimal(4);
                line.MontoDescuento = persisted.GetDecimal(5);
                if (line.SubtotalConDescuento != persisted.GetDecimal(6)) throw new CheckoutPricingMismatchException();
                lineCount++;
            }
            if (lineCount != result.Items.Count) throw new CheckoutPricingMismatchException();
            if (result.Amounts.Net != result.Total || result.Items.Sum(x => x.SubtotalConDescuento) != result.Total
                || result.Amounts.Gross - result.Amounts.Discount != result.Amounts.Net
                || result.Amounts.Tax != Math.Round(result.Total * 0.13m, 2, MidpointRounding.AwayFromZero)
                || result.Amounts.FinalTotal != result.Amounts.Net + result.Amounts.Tax)
                throw new CheckoutPricingMismatchException();
        }
        if (!replay)
            await CheckoutPricingGuard.ValidateAsync(connection, command.Transaction!, userId, evaluationDate, result, cancellationToken);
        return result;
        }, cancellationToken);
    }

    private async Task ClaimCheckoutIntentAsync(OriginalLoginContext login, Guid operationId, byte[] hash, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = CheckoutClaimCommand(connection, login, operationId, hash);
        await OriginalLoginTransaction.ExecuteAsync(connection, command, login, login.UserId, null, async () =>
        {
            await command.ExecuteNonQueryAsync(cancellationToken);
            return 0;
        }, cancellationToken);
    }

    private static SqlCommand CheckoutClaimCommand(SqlConnection connection, OriginalLoginContext login, Guid operationId, byte[] hash)
    {
        var command = OriginalLoginService.ContextCommand(connection, "dbo.sp_Stage2_ClaimCheckoutIntent", login);
        command.Parameters.Add("@OperationId", SqlDbType.UniqueIdentifier).Value = operationId;
        command.Parameters.Add("@PayloadHash", SqlDbType.Binary, 32).Value = hash;
        return command;
    }
    public async Task<string> GetUserSegmentAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        if (userId <= 0)
        {
            return "Minorista";
        }

        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Cliente_GetSegmento", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await ReadUserSegmentAsync(reader, cancellationToken);
    }

    internal static async Task<string> ReadUserSegmentAsync(DbDataReader reader, CancellationToken cancellationToken = default)
    {
        if (!await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("No se pudo acreditar el cliente.");
        var ordinal = reader.GetOrdinal("SegmentoCliente");
        if (reader.IsDBNull(ordinal) || reader.GetValue(ordinal) is not string segment
            || segment is not ("Minorista" or "Mayorista") || await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("No se pudo acreditar el segmento del cliente.");
        return segment;
    }

    private static object DbValue(string? value) =>
        string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();

    private static string? ReadNullableString(SqlDataReader reader, string column)
    {
        var ordinal = reader.GetOrdinal(column);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }
}
