using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

public sealed record PurchasingActor(
    int UserId,
    string UserName,
    string? UserEmail,
    string? Role,
    string? IpAddress,
    string? UserAgent);

public sealed class PurchasingOperationException : Exception
{
    public PurchasingOperationException(string userMessage, Exception? innerException = null)
        : base("La operación de compras fue rechazada.", innerException)
    {
        UserMessage = userMessage;
    }

    public string UserMessage { get; }
}

public interface IPurchasingService
{
    Task<IReadOnlyList<SupplierListItemViewModel>> GetSuppliersAsync(bool? activeOnly, string? search, CancellationToken cancellationToken = default);
    Task<int> SaveSupplierAsync(SupplierFormViewModel model, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task SetSupplierStatusAsync(int supplierId, bool active, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PurchaseOrderListItemViewModel>> GetPurchaseOrdersAsync(string? status, int? supplierId, CancellationToken cancellationToken = default);
    Task<PurchaseOrderDetailViewModel?> GetPurchaseOrderDetailAsync(int purchaseOrderId, CancellationToken cancellationToken = default);
    Task<int> CreatePurchaseOrderAsync(PurchaseOrderFormViewModel model, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task ReceivePurchaseOrderLineAsync(PurchaseOrderReceiveViewModel model, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task CloseWithDiscrepancyAsync(PurchaseOrderCloseViewModel model, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task CancelPurchaseOrderAsync(PurchaseOrderCloseViewModel model, PurchasingActor actor, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PurchaseOrderLineSelectionViewModel>> GetPurchaseSuggestionsAsync(int recentMonths, int coverageMonths, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PriceHistoryLineViewModel>> GetPriceHistoryAsync(int productId, CancellationToken cancellationToken = default);
    Task<IReadOnlyDictionary<int, decimal>> GetLastPurchasePricesAsync(CancellationToken cancellationToken = default);
}

public sealed class PurchasingDbService : IPurchasingService
{
    private readonly string _connectionString;

    public PurchasingDbService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la configuración de base de datos.");
    }

    public async Task<IReadOnlyList<SupplierListItemViewModel>> GetSuppliersAsync(
        bool? activeOnly,
        string? search,
        CancellationToken cancellationToken = default)
    {
        var suppliers = new List<SupplierListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Compras_ListarProveedores", connection);
        command.Parameters.Add("@SoloActivos", SqlDbType.Bit).Value = DbValue(activeOnly);
        command.Parameters.Add("@Filtro", SqlDbType.NVarChar, 100).Value = DbText(search);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            suppliers.Add(new SupplierListItemViewModel
            {
                ProveedorId = reader.GetInt32(reader.GetOrdinal("ProveedorId")),
                Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                Contacto = NullableString(reader, "Contacto"),
                Telefono = NullableString(reader, "Telefono"),
                Email = NullableString(reader, "Email"),
                Activo = reader.GetBoolean(reader.GetOrdinal("Activo")),
                FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
                FechaActualizacionUtc = NullableDateTime(reader, "FechaActualizacionUtc")
            });
        }

        return suppliers;
    }

    public async Task<int> SaveSupplierAsync(
        SupplierFormViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = Procedure("dbo.sp_Compras_GuardarProveedor", connection);
            command.Parameters.Add("@ProveedorId", SqlDbType.Int).Value = model.ProveedorId == 0 ? DBNull.Value : model.ProveedorId;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = model.Nombre.Trim();
            command.Parameters.Add("@Contacto", SqlDbType.NVarChar, 150).Value = DbText(model.Contacto);
            command.Parameters.Add("@Telefono", SqlDbType.NVarChar, 30).Value = DbText(model.Telefono);
            command.Parameters.Add("@Email", SqlDbType.NVarChar, 150).Value = DbText(model.Email);
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
            AddActorParameters(command, actor);
            await connection.OpenAsync(cancellationToken);
            return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        }
        catch (SqlException ex) when (IsPurchasingError(ex))
        {
            throw Translate(ex);
        }
    }

    public async Task SetSupplierStatusAsync(
        int supplierId,
        bool active,
        PurchasingActor actor,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = Procedure("dbo.sp_Compras_CambiarEstadoProveedor", connection);
            command.Parameters.Add("@ProveedorId", SqlDbType.Int).Value = supplierId;
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = active;
            AddActorParameters(command, actor);
            await connection.OpenAsync(cancellationToken);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (IsPurchasingError(ex))
        {
            throw Translate(ex);
        }
    }

    public async Task<IReadOnlyList<PurchaseOrderListItemViewModel>> GetPurchaseOrdersAsync(
        string? status,
        int? supplierId,
        CancellationToken cancellationToken = default)
    {
        var orders = new List<PurchaseOrderListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Compras_ListarOrdenes", connection);
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = DbText(status);
        command.Parameters.Add("@ProveedorId", SqlDbType.Int).Value = DbValue(supplierId);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            orders.Add(new PurchaseOrderListItemViewModel
            {
                OrdenCompraId = reader.GetInt32(reader.GetOrdinal("OrdenCompraId")),
                ProveedorId = reader.GetInt32(reader.GetOrdinal("ProveedorId")),
                ProveedorNombre = reader.GetString(reader.GetOrdinal("ProveedorNombre")),
                Estado = reader.GetString(reader.GetOrdinal("Estado")),
                Notas = NullableString(reader, "Notas"),
                FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
                FechaRecepcionUtc = NullableDateTime(reader, "FechaRecepcionUtc"),
                FechaCierreUtc = NullableDateTime(reader, "FechaCierreUtc"),
                MontoTotal = reader.GetDecimal(reader.GetOrdinal("MontoTotal")),
                TotalOrdenado = reader.GetInt32(reader.GetOrdinal("TotalOrdenado")),
                TotalRecibido = reader.GetInt32(reader.GetOrdinal("TotalRecibido"))
            });
        }

        return orders;
    }

    public async Task<PurchaseOrderDetailViewModel?> GetPurchaseOrderDetailAsync(
        int purchaseOrderId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Compras_ObtenerOrdenDetalle", connection);
        command.Parameters.Add("@OrdenCompraId", SqlDbType.Int).Value = purchaseOrderId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var order = new PurchaseOrderDetailViewModel
        {
            OrdenCompraId = reader.GetInt32(reader.GetOrdinal("OrdenCompraId")),
            ProveedorId = reader.GetInt32(reader.GetOrdinal("ProveedorId")),
            ProveedorNombre = reader.GetString(reader.GetOrdinal("ProveedorNombre")),
            Estado = reader.GetString(reader.GetOrdinal("Estado")),
            Notas = NullableString(reader, "Notas"),
            MotivoCierre = NullableString(reader, "MotivoCierre"),
            FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc")),
            FechaRecepcionUtc = NullableDateTime(reader, "FechaRecepcionUtc"),
            FechaCierreUtc = NullableDateTime(reader, "FechaCierreUtc")
        };

        var lines = new List<PurchaseOrderDetailLineViewModel>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                lines.Add(new PurchaseOrderDetailLineViewModel
                {
                    DetalleOrdenCompraId = reader.GetInt32(reader.GetOrdinal("DetalleOrdenCompraId")),
                    ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                    ProductoNombre = reader.GetString(reader.GetOrdinal("ProductoNombre")),
                    CantidadOrdenada = reader.GetInt32(reader.GetOrdinal("CantidadOrdenada")),
                    CantidadRecibida = reader.GetInt32(reader.GetOrdinal("CantidadRecibida")),
                    PrecioUnitario = reader.GetDecimal(reader.GetOrdinal("PrecioUnitario"))
                });
            }
        }

        order.Lineas = lines;
        return order;
    }

    public async Task<int> CreatePurchaseOrderAsync(
        PurchaseOrderFormViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken = default)
    {
        var lines = PurchasingPolicy.NormalizeLines(model.Productos);
        if (lines.Count == 0)
        {
            throw new PurchasingOperationException("Debe seleccionar al menos un producto.");
        }

        var canonicalJson = JsonSerializer.Serialize(lines);
        var requestHash = SHA256.HashData(Encoding.UTF8.GetBytes($"{model.ProveedorId}|{model.Notas?.Trim()}|{canonicalJson}"));

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = Procedure("dbo.sp_Compras_CrearOrden", connection);
            command.Parameters.Add("@ProveedorId", SqlDbType.Int).Value = model.ProveedorId;
            command.Parameters.Add("@Notas", SqlDbType.NVarChar, 300).Value = DbText(model.Notas);
            command.Parameters.Add("@TokenOperacion", SqlDbType.UniqueIdentifier).Value = model.TokenOperacion;
            command.Parameters.Add("@SolicitudHash", SqlDbType.Binary, 32).Value = requestHash;
            command.Parameters.Add("@LineasJson", SqlDbType.NVarChar, -1).Value = canonicalJson;
            AddActorParameters(command, actor);
            await connection.OpenAsync(cancellationToken);
            return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        }
        catch (SqlException ex) when (IsPurchasingError(ex))
        {
            throw Translate(ex);
        }
    }

    public Task ReceivePurchaseOrderLineAsync(
        PurchaseOrderReceiveViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken = default) =>
        ExecuteOrderOperationAsync(
            "dbo.sp_Compras_RecibirDetalle",
            model.OrdenCompraId,
            model.TokenOperacion,
            actor,
            command =>
            {
                command.Parameters.Add("@DetalleOrdenCompraId", SqlDbType.Int).Value = model.DetalleOrdenCompraId;
                command.Parameters.Add("@CantidadRecibidaAhora", SqlDbType.Int).Value = model.CantidadRecibidaAhora;
            },
            cancellationToken);

    public Task CloseWithDiscrepancyAsync(
        PurchaseOrderCloseViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken = default) =>
        ExecuteClosureOperationAsync("dbo.sp_Compras_CerrarConDiscrepancia", model, actor, cancellationToken);

    public Task CancelPurchaseOrderAsync(
        PurchaseOrderCloseViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken = default) =>
        ExecuteClosureOperationAsync("dbo.sp_Compras_CancelarOrden", model, actor, cancellationToken);

    public async Task<IReadOnlyList<PurchaseOrderLineSelectionViewModel>> GetPurchaseSuggestionsAsync(
        int recentMonths,
        int coverageMonths,
        CancellationToken cancellationToken = default)
    {
        var suggestions = new List<PurchaseOrderLineSelectionViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Admin_GetPurchaseSuggestions", connection);
        command.Parameters.Add("@MesesRecientes", SqlDbType.Int).Value = recentMonths;
        command.Parameters.Add("@MesesCobertura", SqlDbType.Int).Value = coverageMonths;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var suggested = reader.GetInt32(reader.GetOrdinal("CantidadSugerida"));
            suggestions.Add(new PurchaseOrderLineSelectionViewModel
            {
                ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
                Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                StockActual = reader.GetInt32(reader.GetOrdinal("StockActual")),
                PromedioVentaMensual = reader.GetDecimal(reader.GetOrdinal("PromedioVentaMensual")),
                Cantidad = Math.Max(suggested, 1),
                Seleccionado = suggested > 0,
                PrecioUnitario = 1m,
                DatosInsuficientes = reader.GetBoolean(reader.GetOrdinal("DatosInsuficientes"))
            });
        }

        return suggestions;
    }

    public async Task<IReadOnlyList<PriceHistoryLineViewModel>> GetPriceHistoryAsync(
        int productId,
        CancellationToken cancellationToken = default)
    {
        var history = new List<PriceHistoryLineViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Compras_HistoricoPrecios", connection);
        command.Parameters.Add("@ProductoId", SqlDbType.Int).Value = productId;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            history.Add(new PriceHistoryLineViewModel
            {
                OrdenCompraId = reader.GetInt32(reader.GetOrdinal("OrdenCompraId")),
                ProveedorId = reader.GetInt32(reader.GetOrdinal("ProveedorId")),
                ProveedorNombre = reader.GetString(reader.GetOrdinal("ProveedorNombre")),
                PrecioUnitario = reader.GetDecimal(reader.GetOrdinal("PrecioUnitario")),
                PrecioAnterior = NullableDecimal(reader, "PrecioAnterior"),
                VariacionPorcentual = NullableDecimal(reader, "VariacionPorcentual"),
                Estado = reader.GetString(reader.GetOrdinal("Estado")),
                FechaCreacionUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc"))
            });
        }

        return history;
    }

    public async Task<IReadOnlyDictionary<int, decimal>> GetLastPurchasePricesAsync(
        CancellationToken cancellationToken = default)
    {
        var prices = new Dictionary<int, decimal>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure("dbo.sp_Compras_UltimosPrecios", connection);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            prices[reader.GetInt32(reader.GetOrdinal("ProductoId"))] = reader.GetDecimal(reader.GetOrdinal("UltimoPrecioPagado"));
        }

        return prices;
    }

    private async Task ExecuteClosureOperationAsync(
        string procedure,
        PurchaseOrderCloseViewModel model,
        PurchasingActor actor,
        CancellationToken cancellationToken)
    {
        await ExecuteOrderOperationAsync(
            procedure,
            model.OrdenCompraId,
            model.TokenOperacion,
            actor,
            command => command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 500).Value = model.Motivo.Trim(),
            cancellationToken);
    }

    private async Task ExecuteOrderOperationAsync(
        string procedure,
        int purchaseOrderId,
        Guid operationToken,
        PurchasingActor actor,
        Action<SqlCommand> addParameters,
        CancellationToken cancellationToken)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = Procedure(procedure, connection);
            command.Parameters.Add("@OrdenCompraId", SqlDbType.Int).Value = purchaseOrderId;
            command.Parameters.Add("@TokenOperacion", SqlDbType.UniqueIdentifier).Value = operationToken;
            addParameters(command);
            AddActorParameters(command, actor);
            await connection.OpenAsync(cancellationToken);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (IsPurchasingError(ex))
        {
            throw Translate(ex);
        }
    }

    private static SqlCommand Procedure(string name, SqlConnection connection) =>
        new(name, connection) { CommandType = CommandType.StoredProcedure };

    private static void AddActorParameters(SqlCommand command, PurchasingActor actor)
    {
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = actor.UserId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = actor.UserName.Trim();
        command.Parameters.Add("@UsuarioCorreo", SqlDbType.NVarChar, 150).Value = DbText(actor.UserEmail);
        command.Parameters.Add("@Rol", SqlDbType.NVarChar, 50).Value = DbText(actor.Role);
        command.Parameters.Add("@DireccionIp", SqlDbType.NVarChar, 80).Value = DbText(actor.IpAddress);
        command.Parameters.Add("@UserAgent", SqlDbType.NVarChar, 300).Value = DbText(actor.UserAgent);
    }

    private static bool IsPurchasingError(SqlException exception) => exception.Number is >= 54620 and <= 54689;

    private static PurchasingOperationException Translate(SqlException exception) =>
        new(exception.Number switch
        {
            54620 => "El proveedor indicado no existe.",
            54621 => "Ya existe un proveedor con ese nombre.",
            54622 => "El nombre del proveedor no es válido.",
            54630 => "El proveedor no existe o está inactivo.",
            54631 => "La orden debe contener productos válidos y sin duplicados.",
            54632 => "Uno de los productos no existe o está inactivo.",
            54633 => "El token de la orden ya fue usado con datos diferentes.",
            54640 => "La orden o su línea no existe.",
            54641 => "La orden ya no admite recepciones.",
            54642 => "La cantidad recibida debe ser mayor a cero.",
            54643 => "La recepción no puede exceder la cantidad ordenada.",
            54644 => "El token de recepción ya fue usado con datos diferentes.",
            54645 => "No fue posible actualizar el inventario del producto.",
            54650 => "La orden ya no puede cerrarse con discrepancias.",
            54651 => "Debe indicar un motivo de al menos diez caracteres.",
            54652 => "La orden no tiene cantidades pendientes.",
            54653 => "El token de cierre ya fue usado con datos diferentes.",
            54660 => "Solo se puede cancelar una orden pendiente sin recepciones.",
            54661 => "El token de cancelación ya fue usado con datos diferentes.",
            _ => "La operación de compras fue rechazada por una regla de integridad."
        }, exception);

    private static object DbValue<T>(T? value) where T : struct => value.HasValue ? value.Value : DBNull.Value;
    private static object DbText(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
    private static string? NullableString(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static DateTime? NullableDateTime(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    private static decimal? NullableDecimal(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? null : reader.GetDecimal(ordinal);
    }
}
