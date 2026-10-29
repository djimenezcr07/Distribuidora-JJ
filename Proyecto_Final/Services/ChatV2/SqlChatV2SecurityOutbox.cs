using System.Data;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

/// <summary>Use only in the separate DISPATCHER workload. No content-table query or APP factory.</summary>
public sealed class SqlChatV2SecurityOutbox(IChatV2DispatcherConnections connections) : IChatV2SecurityOutbox
{
    private static SqlCommand Command(SqlConnection connection, string procedure, Guid worker, Guid? eventId = null, Guid? token = null)
    {
        if (worker == Guid.Empty || eventId == Guid.Empty || token == Guid.Empty) throw new ChatV2Exception(ChatV2Failure.Validation);
        var command = new SqlCommand("ChatCandidate." + procedure, connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 15 };
        command.Parameters.Add("@WorkerId", SqlDbType.UniqueIdentifier).Value = worker;
        if (eventId is Guid id) command.Parameters.Add("@EventId", SqlDbType.UniqueIdentifier).Value = id;
        if (token is Guid claim) command.Parameters.Add("@ClaimToken", SqlDbType.UniqueIdentifier).Value = claim;
        return command;
    }
    public async ValueTask<ChatV2SecurityClaim?> ClaimAsync(Guid worker, int leaseSeconds, Guid? eventId, CancellationToken ct)
    {
        if (leaseSeconds is < 1 or > 60) throw new ChatV2Exception(ChatV2Failure.Validation);
        try
        {
            await using var connection = await connections.OpenAsync(ct);
            using var command = Command(connection, "SecurityClaim", worker, eventId);
            command.Parameters.Add("@LeaseSeconds", SqlDbType.Int).Value = leaseSeconds;
            // NULL requests the next pending event, not a browser-selected subject.
            if (eventId is null) command.Parameters.Add("@EventId", SqlDbType.UniqueIdentifier).Value = DBNull.Value;
            using var reader = await command.ExecuteReaderAsync(ct);
            ChatV2Rows.Schema(reader, new("EventId", typeof(Guid), "uniqueidentifier"), new("EventKind", typeof(string), "varchar", 20),
                new("SubjectUser", typeof(int), "int"), new("SubjectSession", typeof(Guid), "uniqueidentifier"),
                new("DepartmentId", typeof(int), "int"), new("CaseId", typeof(int), "int"), new("Epoch", typeof(long), "bigint"),
                new("Attempts", typeof(int), "int"), new("ClaimToken", typeof(Guid), "uniqueidentifier"), new("LeaseUtc", typeof(DateTime), "datetime2"));
            ChatV2SecurityClaim? result = null;
            if (await reader.ReadAsync(ct))
            {
                var kind = ChatV2Rows.Required<string>(reader, 1) switch { "USER" => ChatV2SecurityEventKind.User,
                    "SESSION" => ChatV2SecurityEventKind.Session, "DEPARTMENT" => ChatV2SecurityEventKind.Department,
                    "MEMBER" => ChatV2SecurityEventKind.Member, "ASSIGNMENT" => ChatV2SecurityEventKind.Assignment,
                    _ => throw new ChatV2Exception(ChatV2Failure.Contract) };
                var change = new ChatV2SecurityEvent(ChatV2Rows.Required<Guid>(reader, 0), kind, ChatV2Rows.Optional<int>(reader, 2),
                    ChatV2Rows.Optional<Guid>(reader, 3), ChatV2Rows.Optional<int>(reader, 4), ChatV2Rows.Optional<int>(reader, 5), ChatV2Rows.Required<long>(reader, 6));
                result = new(change, worker, ChatV2Rows.Required<Guid>(reader, 8),
                    new DateTimeOffset(ChatV2Rows.Utc(ChatV2Rows.Required<DateTime>(reader, 9))), ChatV2Rows.Required<int>(reader, 7));
                var shape = kind switch
                {
                    ChatV2SecurityEventKind.User => change.SubjectUser > 0 && change.SubjectSession is null && change.DepartmentId is null && change.CaseId is null,
                    ChatV2SecurityEventKind.Session => change.SubjectUser is null && change.SubjectSession is Guid session && session != Guid.Empty && change.DepartmentId is null && change.CaseId is null,
                    ChatV2SecurityEventKind.Department => change.SubjectUser is null && change.SubjectSession is null && change.DepartmentId > 0 && change.CaseId is null,
                    ChatV2SecurityEventKind.Member => change.SubjectUser > 0 && change.SubjectSession is null && change.DepartmentId > 0 && change.CaseId is null,
                    ChatV2SecurityEventKind.Assignment => change.SubjectUser is null && change.SubjectSession is null && change.DepartmentId is null && change.CaseId > 0,
                    _ => false
                };
                if (!shape || change.EventId == Guid.Empty || change.Epoch < 0 || result.ClaimToken == Guid.Empty || result.Attempts < 1
                    || await reader.ReadAsync(ct)) ChatV2Rows.Contract();
            }
            if (await reader.NextResultAsync(ct)) ChatV2Rows.Contract();
            return result;
        }
        catch (SqlException error) { throw ChatV2Errors.FromSql(error); }
    }
    public async ValueTask<bool> ValidateRecipientAsync(ChatV2SecurityClaim claim, ChatV2ConnectionSnapshot recipient, CancellationToken ct)
    {
        if (recipient.Context.Resource is not ChatV2Resource resource) return false;
        resource.Validate();
        try
        {
            await using var connection = await connections.OpenAsync(ct);
            using var command = Command(connection, "SecurityValidateRecipient", claim.WorkerId, claim.Event.EventId, claim.ClaimToken);
            command.Parameters.Add("@RecipientSessionId", SqlDbType.UniqueIdentifier).Value = recipient.Context.SessionId;
            command.Parameters.Add("@Domain", SqlDbType.Char, 1).Value = ChatV2Rows.SqlDomain(resource.Domain);
            command.Parameters.Add("@Resource", SqlDbType.Int).Value = resource.Id;
            command.Parameters.Add("@ExpectedActorEpoch", SqlDbType.BigInt).Value = recipient.Context.ActorEpoch;
            command.Parameters.Add("@ExpectedResourceEpoch", SqlDbType.BigInt).Value = recipient.Context.ResourceEpoch;
            using var reader = await command.ExecuteReaderAsync(ct);
            ChatV2Rows.Schema(reader, new ChatV2Rows.Column("Authorized", typeof(bool), "bit"));
            if (!await reader.ReadAsync(ct)) ChatV2Rows.Contract();
            var allowed = ChatV2Rows.Required<bool>(reader, 0);
            if (await reader.ReadAsync(ct) || await reader.NextResultAsync(ct)) ChatV2Rows.Contract();
            return allowed;
        }
        catch (SqlException error) { throw ChatV2Errors.FromSql(error); }
    }
    public async ValueTask AckAsync(ChatV2SecurityClaim claim, CancellationToken ct)
    {
        try
        {
            await using var connection = await connections.OpenAsync(ct);
            using var command = Command(connection, "SecurityAck", claim.WorkerId, claim.Event.EventId, claim.ClaimToken);
            using var reader = await command.ExecuteReaderAsync(ct);
            if (reader.FieldCount != 0 || await reader.NextResultAsync(ct)) ChatV2Rows.Contract();
        }
        catch (SqlException error) { throw ChatV2Errors.FromSql(error); }
    }
}

public enum ChatV2DispatchOutcome { Empty, Acknowledged, Retry }
public sealed class ChatV2SecurityOutboxDispatcher(IChatV2SecurityOutbox outbox, IChatV2RevocationBridge bridge, TimeProvider time,
    ILogger<ChatV2SecurityOutboxDispatcher>? logger = null)
{
    public async ValueTask<ChatV2DispatchOutcome> DispatchOneAsync(Guid worker, Guid? eventId, CancellationToken ct)
    {
        var correlation=Guid.NewGuid();var started=time.GetTimestamp();
        try
        {
            var claim = await outbox.ClaimAsync(worker, 30, eventId, ct);
            if (claim is null) return ChatV2DispatchOutcome.Empty;
            var recipients = await bridge.RefreshAffectedAsync(claim.Event, ct);
            foreach (var recipient in recipients)
            {
                if (claim.LeaseUntilUtc <= time.GetUtcNow())
                { logger?.LogWarning("Chat V2 dispatch retry. Category {Category}; Correlation {Correlation}", "lease", Guid.NewGuid()); return ChatV2DispatchOutcome.Retry; }
                if (recipient.Context.Resource is null) continue;
                if (await outbox.ValidateRecipientAsync(claim, recipient, ct))
                    await bridge.NotifyAsync(recipient, claim.LeaseUntilUtc, ct);
                else
                    // SQL changed after APP validation: refresh again; never resurrect a stale generation.
                    await bridge.RefreshAffectedAsync(claim.Event, ct);
            }
            await outbox.AckAsync(claim, ct);
            logger?.LogInformation("Chat V2 dispatch completed. Category {Category}; DurationMs {DurationMs}; Correlation {Correlation}",
                "ack",time.GetElapsedTime(started).TotalMilliseconds,correlation);
            return ChatV2DispatchOutcome.Acknowledged;
        }
        catch (ChatV2Exception error) when (error.Failure is ChatV2Failure.Dependency or ChatV2Failure.Conflict or ChatV2Failure.Session or ChatV2Failure.Forbidden or ChatV2Failure.Resource)
        { logger?.LogWarning("Chat V2 dispatch retry. Category {Category}; Correlation {Correlation}", error.Failure, Guid.NewGuid()); return ChatV2DispatchOutcome.Retry; }
        catch (Exception) when (!ct.IsCancellationRequested)
        { logger?.LogWarning("Chat V2 dispatch retry. Category {Category}; Correlation {Correlation}", "dependency", Guid.NewGuid()); return ChatV2DispatchOutcome.Retry; }
    }
}
