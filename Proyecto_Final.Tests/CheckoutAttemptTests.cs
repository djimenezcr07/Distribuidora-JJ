using Microsoft.AspNetCore.Http;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class CheckoutAttemptTests
{
    [Fact]
    public void Refresh_KeepsUuidAndFrozenPayloadDespiteCartMutations()
    {
        var session = new MemorySession(); var login = Login();
        var draft = CheckoutAttemptState.Get(session, login);
        var request = Request(draft.OperationId);
        var lines = new List<CartItemViewModel> { new() { ProductoId = 2, Cantidad = 3, Precio = 1 } };
        CheckoutAttemptState.Freeze(session, login, request, lines);
        lines[0].Cantidad = 100; request.DireccionEntrega = "Changed";
        var restored = CheckoutAttemptState.Get(session, login);
        Assert.Equal(draft.OperationId, restored.OperationId);
        Assert.Equal(3, restored.Items![0].Cantidad);
        Assert.Equal("Original address", restored.Request!.DireccionEntrega);
        CheckoutAttemptState.NewCart(session);
        Assert.Equal(draft.OperationId, CheckoutAttemptState.Get(session, login).OperationId);
    }

    [Fact]
    public void Retry_PreservesRequestAndRejectsChangedContent()
    {
        var session = new MemorySession(); var login = Login();
        var draft = CheckoutAttemptState.Get(session, login); var request = Request(draft.OperationId);
        var first = CheckoutAttemptState.Freeze(session, login, request, []);
        Assert.Equal(first.OperationId, CheckoutAttemptState.Freeze(session, login, request, []).OperationId);
        request.Observaciones = "Different request";
        Assert.Throws<CheckoutAttemptConflictException>(() => CheckoutAttemptState.Freeze(session, login, request, []));
    }

    [Fact]
    public void SameActor_NewLoginCannotAdoptUuidOrBody()
    {
        var session = new MemorySession(); var login = Login();
        var old = CheckoutAttemptState.Get(session, login);
        CheckoutAttemptState.Freeze(session, login, Request(old.OperationId), []);
        var next = CheckoutAttemptState.Get(session, login with { LoginId = Guid.NewGuid() });
        Assert.NotEqual(old.OperationId, next.OperationId); Assert.Null(next.Request);
        Assert.Throws<CheckoutAttemptConflictException>(() => CheckoutAttemptState.Freeze(session,
            login with { LoginId = next.LoginId }, Request(old.OperationId), []));
    }

    [Fact]
    public void Logout_DoesNotRecoverBodyInAnotherAccount()
    {
        var session = new MemorySession(); var login = Login();
        var old = CheckoutAttemptState.Get(session, login);
        CheckoutAttemptState.Freeze(session, login, Request(old.OperationId), []);
        session.Clear();
        var next = CheckoutAttemptState.Get(session, Login() with { UserId = 3 });
        Assert.Null(next.Request); Assert.NotEqual(old.OperationId, next.OperationId);
    }

    [Fact]
    public void CompletedReceipt_SurvivesRefreshUntilANewCartStarts()
    {
        var session = new MemorySession(); var login = Login();
        var attempt = CheckoutAttemptState.Get(session, login);
        CheckoutAttemptState.Complete(session, attempt);
        Assert.True(CheckoutAttemptState.Get(session, login).Completed);
        CheckoutAttemptState.NewCart(session);
        Assert.NotEqual(attempt.OperationId, CheckoutAttemptState.Get(session, login).OperationId);
    }

    [Fact]
    public void PayloadFingerprint_IgnoresUntrustedPricesButBindsResourceQuantityAndDelivery()
    {
        var request = Request(Guid.NewGuid());
        var lines = new List<CartItemViewModel> { new() { ProductoId = 2, Cantidad = 1, Precio = 10 } };
        var first = CheckoutAttemptState.PayloadHash(request, lines);
        lines[0].Precio = 0.01m;
        Assert.Equal(first, CheckoutAttemptState.PayloadHash(request, lines));
        lines[0].Cantidad = 2;
        Assert.NotEqual(first, CheckoutAttemptState.PayloadHash(request, lines));
        lines[0].Cantidad = 1; request.DireccionEntrega = "Different address";
        Assert.NotEqual(first, CheckoutAttemptState.PayloadHash(request, lines));
    }

    private static OriginalLoginContext Login()
    {
        var issued = DateTime.UtcNow;
        return new(Guid.NewGuid(), 2, 2, Guid.NewGuid(), issued, issued.AddHours(8), new byte[32]);
    }
    private static CheckoutViewModel Request(Guid id) => new() { OperationToken = id, DireccionEntrega = "Original address" };
    private sealed class MemorySession : ISession
    {
        private readonly Dictionary<string, byte[]> _values = [];
        public string Id => "owned-session";
        public bool IsAvailable => true;
        public IEnumerable<string> Keys => _values.Keys;
        public void Clear() => _values.Clear();
        public void Remove(string key) => _values.Remove(key);
        public void Set(string key, byte[] value) => _values[key] = value;
        public bool TryGetValue(string key, [System.Diagnostics.CodeAnalysis.NotNullWhen(true)] out byte[]? value) => _values.TryGetValue(key, out value);
        public Task LoadAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task CommitAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
