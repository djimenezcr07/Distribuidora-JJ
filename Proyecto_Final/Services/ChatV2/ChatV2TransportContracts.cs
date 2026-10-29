using System.Text.Json.Serialization;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

// Server-only transport context. None of these types is a Hub argument or public event payload.
public sealed record ChatV2ConnectionContext(Guid SessionId, int UserId, long ActorEpoch,
    ChatV2Resource? Resource, long ResourceEpoch, DateTimeOffset SessionExpiresUtc);
public sealed record ChatV2ConnectionSnapshot(string ConnectionId, long Generation,
    ChatV2ConnectionContext Context, DateTimeOffset LeaseUntilUtc);
public interface IChatV2ConnectionIdentitySource
{
    ValueTask<ServerChatV2Session> ResolveAsync(Guid serverSessionId, CancellationToken ct);
}
public interface IChatV2ConnectionValidator
{
    ValueTask<ChatV2ConnectionContext> ValidateAsync(Guid serverSessionId, ChatV2Resource? resource, CancellationToken ct);
}
public enum ChatV2SecurityEventKind { User, Session, Department, Member, Assignment }
public sealed record ChatV2SecurityEvent(Guid EventId, ChatV2SecurityEventKind Kind, int? SubjectUser,
    Guid? SubjectSession, int? DepartmentId, int? CaseId, long Epoch);
public sealed record ChatV2SecurityClaim(ChatV2SecurityEvent Event, Guid WorkerId,
    [property: JsonIgnore] Guid ClaimToken, DateTimeOffset LeaseUntilUtc, int Attempts)
{
    public override string ToString() => nameof(ChatV2SecurityClaim);
}
public interface IChatV2DispatcherConnections
{
    ValueTask<SqlConnection> OpenAsync(CancellationToken ct);
}
public interface IChatV2SecurityOutbox
{
    ValueTask<ChatV2SecurityClaim?> ClaimAsync(Guid worker, int leaseSeconds, Guid? eventId, CancellationToken ct);
    ValueTask<bool> ValidateRecipientAsync(ChatV2SecurityClaim claim, ChatV2ConnectionSnapshot recipient, CancellationToken ct);
    ValueTask AckAsync(ChatV2SecurityClaim claim, CancellationToken ct);
}
// Implement this bridge with authenticated server IPC when dispatcher and APP are separate processes.
public interface IChatV2RevocationBridge
{
    ValueTask<IReadOnlyList<ChatV2ConnectionSnapshot>> RefreshAffectedAsync(ChatV2SecurityEvent securityEvent, CancellationToken ct);
    ValueTask NotifyAsync(ChatV2ConnectionSnapshot recipient, DateTimeOffset claimExpiresUtc, CancellationToken ct);
}
public interface IChatV2GenericNotifications
{
    // Only the fixed event name and zero arguments may be emitted.
    ValueTask InvalidateAsync(string serverConnectionId, CancellationToken ct);
}

public sealed class ChatV2ConnectionValidator(IChatV2ConnectionIdentitySource identities,
    IServiceScopeFactory scopes, TimeProvider time) : IChatV2ConnectionValidator
{
    public async ValueTask<ChatV2ConnectionContext> ValidateAsync(Guid sessionId, ChatV2Resource? resource, CancellationToken ct)
    {
        var session = await identities.ResolveAsync(sessionId, ct);
        if (session.Identity.SessionId != sessionId || session.Identity.ExpiresUtc <= time.GetUtcNow())
            throw new ChatV2Exception(ChatV2Failure.Session);
        using var scope = scopes.CreateScope();
        var authorization = scope.ServiceProvider.GetRequiredService<IChatV2Authorization>();
        var repository = scope.ServiceProvider.GetRequiredService<IChatV2Repository>();
        long version = 0;
        if (resource is ChatV2Resource selected)
        {
            selected.Validate(); authorization.RequireDomain(session, selected.Domain);
            version = await repository.MembershipAsync(session, selected, ct);
        }
        else
        {
            // Authenticate in SQL as well as the canonical broker; G alone is not a transport permission.
            var identity = session.Identity;
            var domain = identity.Kind == ChatV2Kind.Client ? ChatV2Domain.Customer :
                (identity.Capabilities & ChatV2Capabilities.InternalUse) != 0 ? ChatV2Domain.Private : ChatV2Domain.Customer;
            authorization.RequireDomain(session, domain);
            await repository.ListOwnAsync(session, domain, ct);
        }
        return new(sessionId, session.Identity.UserId, session.Identity.ActorEpoch, resource, version, session.Identity.ExpiresUtc);
    }
}
