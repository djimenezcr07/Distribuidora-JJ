using System.Data;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

public enum ChatV2Failure { Session, Forbidden, Resource, Validation, Conflict, Dependency, Contract }
public sealed class ChatV2Exception(ChatV2Failure failure) : Exception("Chat operation failed.")
{
    public ChatV2Failure Failure { get; } = failure;
}
public sealed record ChatV2Error(string Code, string CorrelationId);
public static class ChatV2Errors
{
    public static int Status(ChatV2Failure failure) => failure switch
    {
        ChatV2Failure.Session => 401, ChatV2Failure.Forbidden => 403, ChatV2Failure.Resource => 404,
        ChatV2Failure.Validation => 400, ChatV2Failure.Conflict => 409, _ => 503
    };
    public static ChatV2Exception FromSql(SqlException exception, bool resource = false, bool issuer = false) => new(
        exception.Number switch { 51001 => issuer ? ChatV2Failure.Session : resource ? ChatV2Failure.Resource : ChatV2Failure.Forbidden,
            51002 => ChatV2Failure.Validation, 51003 => ChatV2Failure.Conflict, _ => ChatV2Failure.Dependency });
}

public sealed class ChatV2Authorization(TimeProvider time) : IChatV2Authorization, IChatV2CapabilityQuery
{
    public bool Has(ChatV2Identity identity, ChatV2Capabilities capability) => (identity.Capabilities & capability) == capability;
    private void Current(ServerChatV2Session session) { if (session.Identity.ExpiresUtc <= time.GetUtcNow()) throw new ChatV2Exception(ChatV2Failure.Session); }
    public void RequireInternal(ServerChatV2Session session) { Current(session); if (session.Identity.Kind != ChatV2Kind.Internal || !Has(session.Identity, ChatV2Capabilities.InternalUse)) throw new ChatV2Exception(ChatV2Failure.Forbidden); }
    public void RequireCustomerOwner(ServerChatV2Session session) { Current(session); if (session.Identity.Kind != ChatV2Kind.Client || !Has(session.Identity, ChatV2Capabilities.CustomerUse)) throw new ChatV2Exception(ChatV2Failure.Forbidden); }
    public void RequireManagement(ServerChatV2Session session) { Current(session); if (session.Identity.Kind != ChatV2Kind.Internal || !Has(session.Identity, ChatV2Capabilities.ManageDepartments)) throw new ChatV2Exception(ChatV2Failure.Forbidden); }
    public void RequireAttentionManagement(ServerChatV2Session session) { Current(session); if (session.Identity.Kind != ChatV2Kind.Internal || !Has(session.Identity, ChatV2Capabilities.ManageAttention)) throw new ChatV2Exception(ChatV2Failure.Forbidden); }
    public void RequireDomain(ServerChatV2Session session, ChatV2Domain domain)
    {
        Current(session);
        if (!Enum.IsDefined(domain)) throw new ChatV2Exception(ChatV2Failure.Validation);
        if (domain != ChatV2Domain.Customer) { RequireInternal(session); return; }
        var identity = session.Identity;
        if (!(identity.Kind == ChatV2Kind.Client && Has(identity, ChatV2Capabilities.CustomerUse))
            && !(identity.Kind == ChatV2Kind.Internal && Has(identity, ChatV2Capabilities.AttendCustomers))) throw new ChatV2Exception(ChatV2Failure.Forbidden);
    }
}

/// <summary>Must be hosted in the authentication authority. Never register this component or its factory in the APP container.</summary>
public sealed class SqlChatV2SessionRegistry(IChatV2IssuerConnections issuer, IChatV2CanonicalStateSource canonical, TimeProvider time) : IChatV2SessionRegistry
{
    public async ValueTask<ServerChatV2Session> RegisterAsync(TrustedChatV2Login login, TimeSpan lifetime, CancellationToken ct)
    {
        var now = time.GetUtcNow();
        if (login.UserId <= 0 || login.ProfileId <= 0 || login.ExpectedStamp == Guid.Empty || !Enum.IsDefined(login.Kind)
            || lifetime <= TimeSpan.Zero || login.AuthenticatedUntilUtc <= now) throw new ChatV2Exception(ChatV2Failure.Session);
        var expires = now.Add(lifetime); if (expires > login.AuthenticatedUntilUtc) expires = login.AuthenticatedUntilUtc;
        var sessionId = Guid.NewGuid(); var proof = RandomNumberGenerator.GetBytes(32);
        try
        {
            await using var connection = await issuer.OpenAsync(ct);
            using var command = new SqlCommand("ChatCandidate.RegisterSession", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@UserId", SqlDbType.Int).Value = login.UserId;
            command.Parameters.Add("@SessionId", SqlDbType.UniqueIdentifier).Value = sessionId;
            command.Parameters.Add("@ProofHash", SqlDbType.Binary, 32).Value = SHA256.HashData(proof);
            ChatV2SqlParameters.AddUtc(command.Parameters, "@ExpiresUtc", expires);
            command.Parameters.Add("@ExpectedStamp", SqlDbType.UniqueIdentifier).Value = login.ExpectedStamp;
            ChatV2SqlParameters.AddUtc(command.Parameters, "@AuthenticatedUntilUtc", login.AuthenticatedUntilUtc);
            await command.ExecuteNonQueryAsync(ct);
            var state = await canonical.GetAsync(sessionId, ct);
            if (state is null || state.UserId != login.UserId || state.ProfileId != login.ProfileId || state.Kind != login.Kind
                || !state.UserActive || !state.ProfileActive || state.Revoked || state.CurrentStamp != login.ExpectedStamp || state.SessionStamp != login.ExpectedStamp)
            {
                await RevokeAsync(sessionId, ct); throw new ChatV2Exception(ChatV2Failure.Session);
            }
            return new ServerChatV2Session(ChatV2IdentityResolver.Identity(state), proof);
        }
        catch (SqlException exception) { throw ChatV2Errors.FromSql(exception, issuer: true); }
        finally { CryptographicOperations.ZeroMemory(proof); }
    }
    public async ValueTask RevokeAsync(Guid serverSessionId, CancellationToken ct)
    {
        if (serverSessionId == Guid.Empty) throw new ChatV2Exception(ChatV2Failure.Session);
        try
        {
            await using var connection = await issuer.OpenAsync(ct);
            using var command = new SqlCommand("ChatCandidate.RevokeSession", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@SessionId", SqlDbType.UniqueIdentifier).Value = serverSessionId;
            command.Parameters.Add("@Reason", SqlDbType.VarChar, 20).Value = "LOGOUT";
            await command.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException exception) { throw ChatV2Errors.FromSql(exception, issuer: true); }
    }
}

public sealed class ChatV2IdentityResolver(IChatV2CanonicalStateSource source, TimeProvider time)
{
    public async ValueTask<ChatV2Identity> ResolveAsync(ServerChatV2Session serverSession, CancellationToken ct)
    {
        var state = await source.GetAsync(serverSession.Identity.SessionId, ct);
        if (state is null || !state.UserActive || !state.ProfileActive || state.Revoked || state.ExpiresUtc <= time.GetUtcNow()
            || state.SessionStamp != state.CurrentStamp || state.UserId != serverSession.Identity.UserId
            || state.ProfileId != serverSession.Identity.ProfileId || state.Kind != serverSession.Identity.Kind
            || state.SessionStamp != serverSession.Identity.SecurityStamp)
            throw new ChatV2Exception(ChatV2Failure.Session);
        return Identity(state);
    }
    internal static ChatV2Identity Identity(ChatV2CanonicalState state) => new(state.UserId, state.ProfileId, state.ClientId,
        state.Kind, state.Capabilities, state.CurrentStamp, state.ActorEpoch, state.SessionId, state.ExpiresUtc);
}
