using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Proyecto_Final.Services.ChatV2;

// Adapted from the SHA-verified Phase B IntentService. Persistence remains an independent authority.
public sealed record ChatV2LiveIdentity(Guid OriginalLoginId, Guid SessionId, int Actor, int Profile,
    ChatV2Kind Kind, Guid SecurityStamp, long ActorEpoch, DateTimeOffset ExpiresUtc, ChatV2Capabilities Capabilities);
public sealed record ChatV2IntentEpochs(long ActorEpoch, long ResourceEpoch, DateTimeOffset ExpiresUtc);
public sealed record ChatV2ContextView(string ContextHandle, bool InternalChat, bool Attention, bool Management);
public sealed record ChatV2IntentInput(string ContextHandle, string Domain, int Resource, Guid RequestId,
    string? Content = null, string? IntentBinding = null);
public sealed record ChatV2BindingView(string IntentBinding, DateTimeOffset ExpiresUtc);
public sealed record ChatV2ResourceAccess(bool CanRead, bool CanSend, long AuthorizationVersion);

/// <summary>The approved broker must implement this port using canonical original-login and transactional SQL contracts.
/// Implementations must not mint a session on GET, substitute a matching actor, or use unrestricted APP credentials.</summary>
public interface IChatV2IntentPersistence
{
    ValueTask<ChatV2LiveIdentity> ResolveAsync(OriginalLoginContext login, CancellationToken ct);
    ValueTask<ChatV2IntentEpochs> PrepareAsync(OriginalLoginContext login, ChatV2LiveIdentity identity,
        ChatV2Resource resource, Guid request, string contentHash, CancellationToken ct);
    ValueTask<ChatV2Receipt> ExecuteAsync(ChatV2BoundIntent intent, string? content, bool receiptOnly, CancellationToken ct);
    ValueTask<IReadOnlyList<ChatV2OwnedResource>> ListAsync(OriginalLoginContext login, ChatV2Domain domain, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    ValueTask<ChatV2ResourceAccess> MembershipAsync(OriginalLoginContext login, ChatV2Resource resource, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    ValueTask<ChatV2HistoryResponse> HistoryAsync(OriginalLoginContext login, ChatV2Resource resource, string? cursor, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    ValueTask<IReadOnlyList<ChatV2QueueItem>> QueueAsync(OriginalLoginContext login, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    ValueTask<long> TransferAsync(OriginalLoginContext login, int caseId, int newAgent, long expectedVersion, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);

}

/// <summary>Server-only captured metadata. No message body is retained in this registry.</summary>
public sealed class ChatV2BoundIntent
{
    [JsonIgnore] public OriginalLoginContext Login { get; }
    [JsonIgnore] public ChatV2LiveIdentity Identity { get; }
    [JsonIgnore] public string Context { get; }
    [JsonIgnore] public ChatV2Resource Resource { get; }
    [JsonIgnore] public Guid Request { get; }
    [JsonIgnore] public string ContentHash { get; }
    [JsonIgnore] public long ResourceEpoch { get; }
    [JsonIgnore] public DateTimeOffset ExpiresUtc { get; }
    internal ChatV2BoundIntent(OriginalLoginContext login, ChatV2LiveIdentity identity, string context,
        ChatV2Resource resource, Guid request, string hash, long resourceEpoch, DateTimeOffset expires)
    {
        Login = login with { BindingHash = login.BindingHash.ToArray() }; Identity = identity; Context = context;
        Resource = resource; Request = request; ContentHash = hash; ResourceEpoch = resourceEpoch; ExpiresUtc = expires;
    }
    public override string ToString() => nameof(ChatV2BoundIntent);
}

/// <summary>Bounded single-host metadata. Durable UUID ownership and epochs MUST be checked inside persistence transactions.</summary>
public sealed class ChatV2Continuity(TimeProvider clock)
{
    private sealed record Context(ChatV2LiveIdentity Identity, byte[] LoginBinding);
    private readonly object _gate = new();
    private readonly Dictionary<string, Context> _contexts = new(StringComparer.Ordinal);
    private readonly Dictionary<string, ChatV2BoundIntent> _bindings = new(StringComparer.Ordinal);
    private static ChatV2Exception Fail(ChatV2Failure kind = ChatV2Failure.Conflict) => new(kind);
    private static string Opaque() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_');
    private static bool Same(ChatV2LiveIdentity a, ChatV2LiveIdentity b) =>
        a.OriginalLoginId == b.OriginalLoginId && a.SessionId == b.SessionId && a.Actor == b.Actor &&
        a.Profile == b.Profile && a.Kind == b.Kind && a.SecurityStamp == b.SecurityStamp && a.ExpiresUtc == b.ExpiresUtc;
    public static string ContentHash(string content)
    {
        if (string.IsNullOrWhiteSpace(content) || content.Length > 1000) throw Fail(ChatV2Failure.Validation);
        for (var i = 0; i < content.Length; i++)
            if (char.IsSurrogate(content[i]) && (!char.IsHighSurrogate(content[i]) ||
                i + 1 == content.Length || !char.IsLowSurrogate(content[++i]))) throw Fail(ChatV2Failure.Validation);
        return Convert.ToHexString(SHA256.HashData(Encoding.Unicode.GetBytes(content)));
    }
    private void Sweep()
    {
        var now = clock.GetUtcNow();
        foreach (var k in _bindings.Where(x => x.Value.ExpiresUtc <= now).Select(x => x.Key).ToArray()) _bindings.Remove(k);
        foreach (var k in _contexts.Where(x => x.Value.Identity.ExpiresUtc <= now).Select(x => x.Key).ToArray()) _contexts.Remove(k);
    }
    private async ValueTask<ChatV2LiveIdentity> Resolve(OriginalLoginContext login, IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        if (!login.HasCanonicalLifetime || login.ExpiresUtc <= clock.GetUtcNow().UtcDateTime) throw Fail(ChatV2Failure.Session);
        var identity = await persistence.ResolveAsync(login, ct);
        if (identity.OriginalLoginId != login.LoginId || identity.Actor != login.UserId || identity.Profile != login.ProfileId ||
            identity.SecurityStamp != login.SecurityStamp || identity.SessionId == Guid.Empty || identity.ActorEpoch <= 0 ||
            !Enum.IsDefined(identity.Kind) || identity.ExpiresUtc <= clock.GetUtcNow() || identity.ExpiresUtc.UtcDateTime > login.ExpiresUtc)
            throw Fail(ChatV2Failure.Session);
        return identity;
    }
    public async ValueTask<ChatV2ContextView> ContextAsync(OriginalLoginContext login, IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        var identity = await Resolve(login, persistence, ct);
        lock (_gate)
        {
            Sweep();
            var old = _contexts.FirstOrDefault(x => Same(x.Value.Identity, identity) &&
                CryptographicOperations.FixedTimeEquals(x.Value.LoginBinding, login.BindingHash.Span));
            var key = old.Key;
            if (key is null)
            {
                if (_contexts.Count >= 1024) throw Fail(ChatV2Failure.Dependency);
                key = Opaque(); _contexts.Add(key, new(identity, login.BindingHash.ToArray()));
            }
            return new(key, identity.Kind == ChatV2Kind.Internal && identity.Capabilities.HasFlag(ChatV2Capabilities.InternalUse),
                identity.Kind == ChatV2Kind.Client && identity.Capabilities.HasFlag(ChatV2Capabilities.CustomerUse) ||
                identity.Kind == ChatV2Kind.Internal && identity.Capabilities.HasFlag(ChatV2Capabilities.AttendCustomers),
                identity.Kind == ChatV2Kind.Internal && identity.Capabilities.HasFlag(ChatV2Capabilities.ManageAttention));
        }
    }
    private static void RequireDomain(ChatV2LiveIdentity identity, string domain)
    {
        var allowed = domain == "C"
            ? identity.Kind == ChatV2Kind.Client && identity.Capabilities.HasFlag(ChatV2Capabilities.CustomerUse) ||
              identity.Kind == ChatV2Kind.Internal && identity.Capabilities.HasFlag(ChatV2Capabilities.AttendCustomers)
            : identity.Kind == ChatV2Kind.Internal && identity.Capabilities.HasFlag(ChatV2Capabilities.InternalUse);
        if (!allowed) throw Fail(ChatV2Failure.Forbidden);
    }
    private async ValueTask<ChatV2LiveIdentity> Validate(OriginalLoginContext login, ChatV2IntentInput input,
        IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        if (input.RequestId == Guid.Empty || input.Domain is not ("P" or "D" or "C") || input.Resource <= 0 ||
            string.IsNullOrEmpty(input.ContextHandle) || input.ContextHandle.Length > 64) throw Fail(ChatV2Failure.Validation);
        var identity = await Resolve(login, persistence, ct);
        RequireDomain(identity, input.Domain);
        lock (_gate)
        {
            Sweep();
            if (!_contexts.TryGetValue(input.ContextHandle, out var context) || !Same(identity, context.Identity) ||
                !CryptographicOperations.FixedTimeEquals(context.LoginBinding, login.BindingHash.Span)) throw Fail();
        }
        return identity;
    }
    public async ValueTask<ChatV2LiveIdentity> ValidateContextAsync(OriginalLoginContext login, string handle,
        IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        var identity = await Resolve(login, persistence, ct);
        lock (_gate)
        {
            Sweep();
            if (string.IsNullOrEmpty(handle) || handle.Length > 64 || !_contexts.TryGetValue(handle, out var context) ||
                !Same(identity, context.Identity) || !CryptographicOperations.FixedTimeEquals(context.LoginBinding, login.BindingHash.Span)) throw Fail();
        }
        return identity;
    }
    private static ChatV2Resource Resource(ChatV2IntentInput input) => new(input.Domain switch
        { "P" => ChatV2Domain.Private, "D" => ChatV2Domain.Department, _ => ChatV2Domain.Customer }, input.Resource);
    public async ValueTask<ChatV2BindingView> PrepareAsync(OriginalLoginContext login, ChatV2IntentInput input,
        IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        var hash = ContentHash(input.Content ?? ""); var identity = await Validate(login, input, persistence, ct);
        var epochs = await persistence.PrepareAsync(login, identity, Resource(input), input.RequestId, hash, ct);
        if (epochs.ActorEpoch != identity.ActorEpoch || epochs.ResourceEpoch < 0 || epochs.ExpiresUtc <= clock.GetUtcNow() ||
            epochs.ExpiresUtc > identity.ExpiresUtc || epochs.ExpiresUtc > clock.GetUtcNow().AddMinutes(15)) throw Fail();
        lock (_gate)
        {
            Sweep();
            var old = _bindings.FirstOrDefault(x => x.Value.Request == input.RequestId && x.Value.Login.LoginId == login.LoginId);
            if (old.Key is not null)
            {
                var prior = old.Value;
                if (!Same(prior.Identity, identity) || prior.Context != input.ContextHandle || prior.Resource != Resource(input) ||
                    prior.ContentHash != hash || prior.Identity.ActorEpoch != epochs.ActorEpoch ||
                    prior.ResourceEpoch != epochs.ResourceEpoch || prior.ExpiresUtc != epochs.ExpiresUtc) throw Fail();
                return new(old.Key, prior.ExpiresUtc);
            }
            if (_bindings.Count >= 8192 || _bindings.Values.Count(x => x.Login.LoginId == login.LoginId) >= 8) throw Fail(ChatV2Failure.Dependency);
            var token = Opaque();
            _bindings.Add(token, new(login, identity, input.ContextHandle, Resource(input), input.RequestId, hash, epochs.ResourceEpoch, epochs.ExpiresUtc));
            return new(token, epochs.ExpiresUtc);
        }
    }
    public async ValueTask<ChatV2Receipt> ExecuteAsync(OriginalLoginContext login, ChatV2IntentInput input, bool receiptOnly,
        IChatV2IntentPersistence persistence, CancellationToken ct)
    {
        var identity = await Validate(login, input, persistence, ct); ChatV2BoundIntent binding;
        lock (_gate)
        {
            Sweep();
            if (input.IntentBinding is null || input.IntentBinding.Length > 64 || !_bindings.TryGetValue(input.IntentBinding, out binding!)) throw Fail();
        }
        if (!Same(identity, binding.Identity) || identity.ActorEpoch != binding.Identity.ActorEpoch ||
            binding.Context != input.ContextHandle || binding.Resource != Resource(input) || binding.Request != input.RequestId ||
            !CryptographicOperations.FixedTimeEquals(binding.Login.BindingHash.Span, login.BindingHash.Span)) throw Fail();
        if (!receiptOnly && ContentHash(input.Content ?? "") != binding.ContentHash) throw Fail();
        // The captured login/epochs reach persistence; no fresh matching actor may replace them after awaiting.
        var result = await persistence.ExecuteAsync(binding, receiptOnly ? null : input.Content, receiptOnly, ct);
        var after = await Resolve(login, persistence, ct);
        if (!Same(after, identity) || after.ActorEpoch != binding.Identity.ActorEpoch) throw Fail();
        if (result.RequestId != binding.Request || result.Domain != binding.Resource.Domain || result.ResourceId != binding.Resource.Id ||
            result.PersistedState != "PERSISTED" || ContentHash(result.Content) != binding.ContentHash) throw Fail(ChatV2Failure.Contract);
        return result;
    }
    public void Purge(Guid loginId)
    {
        lock (_gate)
        {
            foreach (var k in _contexts.Where(x => x.Value.Identity.OriginalLoginId == loginId).Select(x => x.Key).ToArray()) _contexts.Remove(k);
            foreach (var k in _bindings.Where(x => x.Value.Login.LoginId == loginId).Select(x => x.Key).ToArray()) _bindings.Remove(k);
        }
    }
}

/// <summary>No SQL or legacy fallback until restricted broker, original-login link and manifest are accredited.</summary>
public sealed class UnavailableChatV2IntentPersistence : IChatV2IntentPersistence
{
    public ValueTask<ChatV2LiveIdentity> ResolveAsync(OriginalLoginContext login, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    public ValueTask<ChatV2IntentEpochs> PrepareAsync(OriginalLoginContext login, ChatV2LiveIdentity identity, ChatV2Resource resource, Guid request, string contentHash, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
    public ValueTask<ChatV2Receipt> ExecuteAsync(ChatV2BoundIntent intent, string? content, bool receiptOnly, CancellationToken ct) => throw new ChatV2Exception(ChatV2Failure.Dependency);
}
public static class ChatV2ContinuityIntegration
{
    public static IServiceCollection AddChatV2Continuity(this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System); services.TryAddSingleton<ChatV2Continuity>();
        services.TryAddScoped<IChatV2IntentPersistence, UnavailableChatV2IntentPersistence>();
        services.TryAddScoped<ChatV2JsonExceptionFilter>(); services.TryAddScoped<ChatV2OriginalLoginFilter>(); return services;
    }
}

public sealed class ChatV2OriginalLoginFilter(TimeProvider clock) : Microsoft.AspNetCore.Mvc.Filters.IAuthorizationFilter
{
    public void OnAuthorization(Microsoft.AspNetCore.Mvc.Filters.AuthorizationFilterContext context)
    {
        if (context.HttpContext.Items[OriginalLoginSession.ValidatedContextItem] is OriginalLoginContext login &&
            login.HasCanonicalLifetime && login.ExpiresUtc > clock.GetUtcNow().UtcDateTime) return;
        context.ActionDescriptor.RouteValues.TryGetValue("action", out var action);
        context.Result = string.Equals(action, "Index", StringComparison.Ordinal)
            ? new Microsoft.AspNetCore.Mvc.RedirectToActionResult("Login", "Account", new { returnUrl = "/ChatV2" })
            : new Microsoft.AspNetCore.Mvc.UnauthorizedObjectResult(new ChatV2Error("session", context.HttpContext.TraceIdentifier));
    }
}
