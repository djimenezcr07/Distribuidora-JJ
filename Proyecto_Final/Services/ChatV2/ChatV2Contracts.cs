using System.Text.Json.Serialization;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

public enum ChatV2Kind { Internal, Client }
public enum ChatV2Domain : byte { Private = 1, Department = 2, Customer = 3 }
[Flags]
public enum ChatV2Capabilities { None = 0, InternalUse = 1, CustomerUse = 2, AttendCustomers = 4, ManageDepartments = 8, ManageAttention = 16 }

public readonly record struct ChatV2Resource(ChatV2Domain Domain, int Id)
{
    public void Validate() { if (!Enum.IsDefined(Domain) || Id <= 0) throw new ChatV2Exception(ChatV2Failure.Validation); }
}
public sealed record ChatV2Identity(int UserId, int ProfileId, int? ClientId, ChatV2Kind Kind,
    ChatV2Capabilities Capabilities, [property: JsonIgnore] Guid SecurityStamp,
    long ActorEpoch, Guid SessionId, DateTimeOffset ExpiresUtc);

/// <summary>Infrastructure material obtained from a trusted server session provider, never model-bound.</summary>
[JsonConverter(typeof(ServerChatV2SessionJsonConverter))]
public sealed class ServerChatV2Session
{
    private readonly byte[] _proof;
    [JsonIgnore] public ChatV2Identity Identity { get; }
    [JsonIgnore] public ReadOnlyMemory<byte> ProofForInfrastructure => _proof;
    public ServerChatV2Session(ChatV2Identity identity, ReadOnlySpan<byte> proof)
    {
        if (proof.Length != 32 || identity.UserId <= 0 || identity.ProfileId <= 0 || identity.SessionId == Guid.Empty
            || identity.SecurityStamp == Guid.Empty || identity.ActorEpoch <= 0 || !Enum.IsDefined(identity.Kind))
            throw new ChatV2Exception(ChatV2Failure.Session);
        Identity = identity; _proof = proof.ToArray();
    }
    public override string ToString() => nameof(ServerChatV2Session);
}

/// <summary>Infrastructure credentials cannot be reconstructed by a JSON request or accidentally exported.</summary>
public sealed class ServerChatV2SessionJsonConverter : JsonConverter<ServerChatV2Session>
{
    public override ServerChatV2Session Read(ref System.Text.Json.Utf8JsonReader reader, Type typeToConvert, System.Text.Json.JsonSerializerOptions options)
        => throw new NotSupportedException("Server session material cannot be deserialized from JSON.");
    public override void Write(System.Text.Json.Utf8JsonWriter writer, ServerChatV2Session value, System.Text.Json.JsonSerializerOptions options)
    { writer.WriteStartObject(); writer.WriteEndObject(); }
}

/// <summary>Only an authentication authority may supply this result. A DTO type alone is not proof of provenance.</summary>
public sealed record TrustedChatV2Login(int UserId, int ProfileId, ChatV2Kind Kind,
    Guid ExpectedStamp, DateTimeOffset AuthenticatedUntilUtc);
public sealed record ChatV2CanonicalState(int UserId, int ProfileId, int? ClientId, ChatV2Kind Kind,
    ChatV2Capabilities Capabilities, bool UserActive, bool ProfileActive, Guid CurrentStamp,
    Guid SessionStamp, Guid SessionId, DateTimeOffset ExpiresUtc, bool Revoked, long ActorEpoch);
public interface IChatV2AppConnections { ValueTask<SqlConnection> OpenAsync(CancellationToken cancellationToken); }
public interface IChatV2IssuerConnections { ValueTask<SqlConnection> OpenAsync(CancellationToken cancellationToken); }
public interface IChatV2CanonicalReadConnections { ValueTask<SqlConnection> OpenAsync(CancellationToken cancellationToken); }
public interface IChatV2CanonicalStateSource { ValueTask<ChatV2CanonicalState?> GetAsync(Guid serverSessionId, CancellationToken cancellationToken); }
public interface IChatV2IdentityContext { ValueTask<ServerChatV2Session> ResolveCurrentAsync(CancellationToken cancellationToken); }
public interface IChatV2SessionRegistry
{
    ValueTask<ServerChatV2Session> RegisterAsync(TrustedChatV2Login trustedLogin, TimeSpan lifetime, CancellationToken cancellationToken);
    ValueTask RevokeAsync(Guid serverSessionId, CancellationToken cancellationToken);
}
public interface IChatV2CapabilityQuery { bool Has(ChatV2Identity identity, ChatV2Capabilities capability); }
public interface IChatV2Authorization
{
    void RequireInternal(ServerChatV2Session session);
    void RequireCustomerOwner(ServerChatV2Session session);
    void RequireManagement(ServerChatV2Session session);
    void RequireAttentionManagement(ServerChatV2Session session);
    void RequireDomain(ServerChatV2Session session, ChatV2Domain domain);
}

public sealed record ChatV2Contact(int UserId);
public sealed record ChatV2OwnedResource(ChatV2Domain Domain, int ResourceId, long AuthorizationVersion);
public sealed record ChatV2QueueItem(int CaseId, bool Assigned, long AssignmentVersion, string State);
public sealed record ChatV2Receipt(Guid RequestId, ChatV2Domain Domain, int ResourceId, long MessageId,
    long StreamSequence, DateTime TimestampUtc, string PersistedState, string Content, long AuthorizationVersion);
public sealed record ChatV2Message(long MessageId, long StreamSequence, int Sender, string Content,
    DateTime? OriginalDate, DateTime? TimestampUtc, int? LegacyMessageId, bool? LegacyRead);
public sealed record ChatV2SearchHit(long MessageId, long StreamSequence, string Content);
public sealed record ChatV2HistoryContext(ChatV2Domain Domain, int ResourceId, long NextSequence, long UpperBound,
    bool HasMore, long ActorAuthorizationVersion, long ResourceAuthorizationVersion);
public sealed record ChatV2History(IReadOnlyList<ChatV2Message> Messages, ChatV2HistoryContext Context);
public sealed record ChatV2HistoryQuery(ChatV2Resource Resource, int Limit = 50, long After = 0, long? Upper = null,
    long? ActorEpoch = null, long? ResourceEpoch = null, int? Actor = null);
public sealed record ChatV2HistoryResponse(IReadOnlyList<ChatV2Message> Messages, string? NextCursor);
public sealed record ChatV2SendResult(ChatV2Receipt Receipt, bool Created);

public interface IChatV2Repository
{
    ValueTask<IReadOnlyList<ChatV2Contact>> DirectoryAsync(ServerChatV2Session session, CancellationToken ct);
    ValueTask<int> OpenPrivateAsync(ServerChatV2Session session, int otherUser, CancellationToken ct);
    ValueTask<IReadOnlyList<ChatV2OwnedResource>> ListOwnAsync(ServerChatV2Session session, ChatV2Domain domain, CancellationToken ct);
    ValueTask<long> MembershipAsync(ServerChatV2Session session, ChatV2Resource resource, CancellationToken ct);
    ValueTask<ChatV2History> HistoryAsync(ServerChatV2Session session, ChatV2HistoryQuery query, CancellationToken ct);
    ValueTask<ChatV2Receipt> SendAsync(ServerChatV2Session session, ChatV2Resource resource, Guid requestId, string content, CancellationToken ct);
    ValueTask<ChatV2Receipt> ReceiptAsync(ServerChatV2Session session, Guid requestId, CancellationToken ct);
    ValueTask<IReadOnlyList<ChatV2SearchHit>> SearchAsync(ServerChatV2Session session, ChatV2Resource resource, string text, CancellationToken ct);
    ValueTask MarkReadAsync(ServerChatV2Session session, ChatV2Resource resource, long sequence, CancellationToken ct);
    ValueTask<int> CreateCaseAsync(ServerChatV2Session session, CancellationToken ct);
    ValueTask<IReadOnlyList<ChatV2QueueItem>> QueueAsync(ServerChatV2Session session, CancellationToken ct);
    ValueTask<long> TransferAsync(ServerChatV2Session session, int caseId, int newAgent, long expectedVersion, CancellationToken ct);
    ValueTask<int> CreateDepartmentAsync(ServerChatV2Session session, string label, CancellationToken ct);
    ValueTask SetMemberAsync(ServerChatV2Session session, int departmentId, int userId, bool canRead, bool canPost, CancellationToken ct);
    ValueTask SetDepartmentActiveAsync(ServerChatV2Session session, int departmentId, bool active, CancellationToken ct);
    ValueTask LogoutAsync(ServerChatV2Session session, CancellationToken ct);
}

// Contracts for the next gate only: no Hub, dispatcher, transport or connection registry implementation.
public sealed record ChatV2Invalidation(Guid InternalEventId, string InternalType, long Epoch);
public interface IChatV2InvalidationConsumer { ValueTask ProcessAsync(ChatV2Invalidation invalidation, CancellationToken ct); }
public interface IChatV2ConnectionRegistry
{
    ValueTask RevokeSessionConnectionsAsync(Guid serverSessionId, CancellationToken ct);
    ValueTask RevalidateConnectionAsync(string serverConnectionId, CancellationToken ct);
}
