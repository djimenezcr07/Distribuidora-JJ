using System.Security.Cryptography;
using System.Text.Json;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services;

public sealed class CheckoutAttemptConflictException(string message) : InvalidOperationException(message) { }

// Private request bodies stay in the existing server session, never browser storage.
public sealed record CheckoutAttemptState(Guid LoginId, Guid OperationId, CheckoutViewModel? Request,
    List<CartItemViewModel>? Items, bool Completed = false)
{
    private const string SessionKey = "Stage2.CheckoutAttempt";

    public static CheckoutAttemptState Get(ISession session, OriginalLoginContext login)
    {
        var raw = session.GetString(SessionKey);
        var state = raw is null ? null : JsonSerializer.Deserialize<CheckoutAttemptState>(raw);
        if (state is not null && state.LoginId == login.LoginId && state.OperationId != Guid.Empty)
            return state;
        state = new(login.LoginId, Guid.NewGuid(), null, null);
        Save(session, state);
        return state;
    }

    public static CheckoutAttemptState Freeze(ISession session, OriginalLoginContext login,
        CheckoutViewModel request, IReadOnlyCollection<CartItemViewModel> items)
    {
        var state = Get(session, login);
        if (request.OperationToken != state.OperationId)
            throw new CheckoutAttemptConflictException("El intento no corresponde a la sesión original.");
        if (state.Request is not null)
        {
            if (!CryptographicOperations.FixedTimeEquals(PayloadHash(state.Request, state.Items!), PayloadHash(request, state.Items!)))
                throw new CheckoutAttemptConflictException("El contenido del intento original cambió.");
            return state;
        }
        // Deep snapshot: later cart refreshes cannot change the pending request.
        var snapshot = JsonSerializer.Deserialize<CheckoutViewModel>(JsonSerializer.Serialize(request))!;
        var lines = JsonSerializer.Deserialize<List<CartItemViewModel>>(JsonSerializer.Serialize(items))!;
        state = state with { Request = snapshot, Items = lines };
        Save(session, state);
        return state;
    }

    public static void Complete(ISession session, CheckoutAttemptState state) => Save(session, state with { Completed = true });

    public static void NewCart(ISession session)
    {
        var raw = session.GetString(SessionKey);
        if (raw is not null && JsonSerializer.Deserialize<CheckoutAttemptState>(raw) is { Completed: true })
            session.Remove(SessionKey);
    }

    public static byte[] PayloadHash(CheckoutViewModel request, IReadOnlyCollection<CartItemViewModel> items) =>
        SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(new
        {
            purpose = "StorefrontCheckout:v1",
            delivery = request.TipoEntrega.Trim(), address = Normalize(request.DireccionEntrega),
            notes = Normalize(request.Observaciones), identification = Normalize(request.Identificacion),
            payment = request.MetodoPago.Trim(), reference = Normalize(request.ReferenciaPago),
            items = StoreCheckoutPayloadBuilder.CreateItemsJson(items.OrderBy(x => x.ItemType, StringComparer.Ordinal)
                .ThenBy(x => x.ProductoId).ThenBy(x => x.ComboId))
        }));

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Save(ISession session, CheckoutAttemptState state) =>
        session.SetString(SessionKey, JsonSerializer.Serialize(state));
}
