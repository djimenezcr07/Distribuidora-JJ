using System.Collections.Concurrent;

namespace Proyecto_Final.Services.ChatV2;

/// <summary>Single-host registry. Memory never grants SQL access. Revoked entries cannot be revived.</summary>
public sealed class ChatV2ConnectionRegistry(IChatV2ConnectionValidator validator, TimeProvider time,
    IChatV2GenericNotifications notifications) : IChatV2ConnectionRegistry, IChatV2RevocationBridge
{
    private sealed class Entry(Guid session, Action abort)
    {
        internal readonly object Gate = new();
        internal readonly Guid Session = session;
        internal readonly Action Abort = abort;
        internal long Generation;
        internal bool Revoked;
        internal ChatV2ConnectionContext? Context;
        internal DateTimeOffset Until;
    }
    private readonly ConcurrentDictionary<string, Entry> _entries = new(StringComparer.Ordinal);
    private readonly object _registration = new();
    private static readonly TimeSpan Lease = TimeSpan.FromSeconds(10);

    public async ValueTask RegisterAsync(string connectionId, Guid serverSessionId, Action abort, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(connectionId) || serverSessionId == Guid.Empty) throw new ChatV2Exception(ChatV2Failure.Session);
        var entry = new Entry(serverSessionId, abort);
        lock (_registration)
        {
            if (_entries.Count >= 1024 || _entries.Values.Count(x => x.Session == serverSessionId) >= 8
                || !_entries.TryAdd(connectionId, entry)) throw new ChatV2Exception(ChatV2Failure.Dependency);
        }
        await Validate(connectionId, entry, null, ct);
    }
    private static void Revoke(Entry entry)
    {
        bool abort;
        lock (entry.Gate) { abort = !entry.Revoked; entry.Revoked = true; entry.Generation++; entry.Context = null; entry.Until = default; }
        if (abort) entry.Abort();
    }
    private async ValueTask<ChatV2ConnectionSnapshot> Validate(string id, Entry entry, ChatV2Resource? resource, CancellationToken ct)
    {
        long generation;
        lock (entry.Gate)
        {
            if (entry.Revoked) throw new ChatV2Exception(ChatV2Failure.Session);
            generation = ++entry.Generation;
        }
        ChatV2ConnectionContext context;
        try { context = await validator.ValidateAsync(entry.Session, resource, ct); }
        catch { Revoke(entry); throw; }
        if (context.SessionId != entry.Session || context.SessionExpiresUtc <= time.GetUtcNow())
        { Revoke(entry); throw new ChatV2Exception(ChatV2Failure.Session); }
        lock (entry.Gate)
        {
            // A disconnect/revocation/newer validation wins over a late asynchronous answer.
            if (entry.Revoked || entry.Generation != generation || context.SessionId != entry.Session
                || context.SessionExpiresUtc <= time.GetUtcNow()) throw new ChatV2Exception(ChatV2Failure.Session);
            entry.Context = context; entry.Until = Min(time.GetUtcNow() + Lease, context.SessionExpiresUtc);
            return new(id, generation, context, entry.Until);
        }
    }
    private static DateTimeOffset Min(DateTimeOffset a, DateTimeOffset b) => a < b ? a : b;
    private Entry Current(string id) => _entries.TryGetValue(id, out var entry) ? entry : throw new ChatV2Exception(ChatV2Failure.Session);
    public ValueTask SubscribeAsync(string connectionId, ChatV2Resource resource, CancellationToken ct)
        => Ignore(Validate(connectionId, Current(connectionId), resource, ct));
    public ValueTask UnsubscribeAsync(string connectionId, CancellationToken ct)
        => Ignore(Validate(connectionId, Current(connectionId), null, ct));
    private static async ValueTask Ignore(ValueTask<ChatV2ConnectionSnapshot> task) => await task;
    public async ValueTask RevalidateConnectionAsync(string serverConnectionId, CancellationToken ct)
    {
        var entry = Current(serverConnectionId); ChatV2Resource? resource;
        lock (entry.Gate) resource = entry.Context?.Resource;
        await Validate(serverConnectionId, entry, resource, ct);
    }
    public ValueTask RevokeSessionConnectionsAsync(Guid serverSessionId, CancellationToken ct)
    { foreach (var entry in _entries.Values.Where(x => x.Session == serverSessionId)) Revoke(entry); return ValueTask.CompletedTask; }
    public void Disconnect(string connectionId)
    { if (_entries.TryRemove(connectionId, out var entry)) Revoke(entry); }
    public async ValueTask SweepAsync(CancellationToken ct)
    {
        foreach (var pair in _entries.ToArray())
        {
            try { await RevalidateConnectionAsync(pair.Key, ct); }
            catch (Exception) when (!ct.IsCancellationRequested) { /* Fail-closed entry already revoked. */ }
        }
    }
    private static bool Affected(ChatV2SecurityEvent change, ChatV2ConnectionContext context) => change.Kind switch
    {
        ChatV2SecurityEventKind.User => context.UserId == change.SubjectUser,
        ChatV2SecurityEventKind.Session => context.SessionId == change.SubjectSession,
        ChatV2SecurityEventKind.Department => context.Resource == new ChatV2Resource(ChatV2Domain.Department, change.DepartmentId ?? 0),
        ChatV2SecurityEventKind.Member => context.UserId == change.SubjectUser && context.Resource == new ChatV2Resource(ChatV2Domain.Department, change.DepartmentId ?? 0),
        ChatV2SecurityEventKind.Assignment => context.Resource == new ChatV2Resource(ChatV2Domain.Customer, change.CaseId ?? 0),
        _ => false
    };
    public async ValueTask<IReadOnlyList<ChatV2ConnectionSnapshot>> RefreshAffectedAsync(ChatV2SecurityEvent change, CancellationToken ct)
    {
        var valid = new List<ChatV2ConnectionSnapshot>();
        foreach (var pair in _entries.ToArray())
        {
            ChatV2ConnectionContext? context;
            lock (pair.Value.Gate) context = pair.Value.Context;
            if (context is null || !Affected(change, context)) continue;
            try { valid.Add(await Validate(pair.Key, pair.Value, context.Resource, ct)); }
            catch (ChatV2Exception error) when (error.Failure is ChatV2Failure.Session or ChatV2Failure.Forbidden or ChatV2Failure.Resource) { }
            // Dependency failure must leave the durable event unacknowledged.
        }
        return valid;
    }
    public async ValueTask NotifyAsync(ChatV2ConnectionSnapshot recipient, DateTimeOffset claimExpiresUtc, CancellationToken ct)
    {
        if (!_entries.TryGetValue(recipient.ConnectionId, out var entry)) return;
        lock (entry.Gate)
        {
            if (entry.Revoked || entry.Generation != recipient.Generation || entry.Context != recipient.Context
                || entry.Until <= time.GetUtcNow() || claimExpiresUtc <= time.GetUtcNow()) return;
        }
        var current = await Validate(recipient.ConnectionId, entry, recipient.Context.Resource, ct);
        if (current.Context != recipient.Context) return;
        // The fixed, zero-argument notice conveys no authority. SQL and send are separate operations.
        // A packet already queued cannot be recalled by a later invalidation.
        lock (entry.Gate)
        {
            if (entry.Revoked || entry.Generation != current.Generation || entry.Until <= time.GetUtcNow()
                || claimExpiresUtc <= time.GetUtcNow()) return;
        }
        await notifications.InvalidateAsync(recipient.ConnectionId, ct);
    }
}
