namespace Proyecto_Final.Services.ChatV2;

/// <summary>Bounded, single-host send classification lock. SQL remains the persistence/idempotency authority.</summary>
public sealed class ChatV2SendCoordinator
{
    private readonly SemaphoreSlim[] _stripes=Enumerable.Range(0,64).Select(_=>new SemaphoreSlim(1,1)).ToArray();
    public async ValueTask<IDisposable> EnterAsync(int actor,Guid request,CancellationToken ct)
    {var index=(uint)HashCode.Combine(actor,request)%64;var gate=_stripes[index];await gate.WaitAsync(ct);return new Lease(gate);}
    private sealed class Lease(SemaphoreSlim gate):IDisposable
    {private int _released;public void Dispose(){if(Interlocked.Exchange(ref _released,1)==0)gate.Release();}}
}

public sealed class ChatV2MessagingService(IChatV2IdentityContext identities,IChatV2Authorization authorization,
    IChatV2Repository repository,IChatV2CursorProtector cursors,ChatV2SendCoordinator sends,TimeProvider time)
{
    private async ValueTask<ServerChatV2Session> Domain(ChatV2Resource resource,CancellationToken ct)
    {resource.Validate();var session=await identities.ResolveCurrentAsync(ct);authorization.RequireDomain(session,resource.Domain);return session;}
    public async ValueTask<IReadOnlyList<ChatV2Contact>> DirectoryAsync(CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireInternal(session);return await repository.DirectoryAsync(session,ct);}
    public async ValueTask<int> OpenPrivateAsync(int otherUser,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireInternal(session);return await repository.OpenPrivateAsync(session,otherUser,ct);}
    public async ValueTask<IReadOnlyList<ChatV2OwnedResource>> ListOwnAsync(ChatV2Domain domain,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireDomain(session,domain);return await repository.ListOwnAsync(session,domain,ct);}
    public async ValueTask<long> MembershipAsync(ChatV2Resource resource,CancellationToken ct)
    {var session=await Domain(resource,ct);return await repository.MembershipAsync(session,resource,ct);}
    public async ValueTask<ChatV2HistoryResponse> HistoryAsync(ChatV2Resource resource,string? cursor,int limit,CancellationToken ct)
    {
        var session=await Domain(resource,ct);if(limit is <1 or >100)throw new ChatV2Exception(ChatV2Failure.Validation);
        var query=new ChatV2HistoryQuery(resource,limit);
        if(cursor is not null)
        {
            // Check current SQL access before accepting any cursor context or reporting an epoch failure.
            var version=await repository.MembershipAsync(session,resource,ct);var identity=session.Identity;
            var context=new ChatV2CursorContext(identity.UserId,resource.Domain,resource.Id,identity.ActorEpoch,version,identity.SessionId,identity.ExpiresUtc.ToUnixTimeSeconds());
            if(!cursors.TryUnprotect(cursor,context,out var state))throw new ChatV2Exception(ChatV2Failure.Validation);
            query=query with {After=state!.After,Upper=state.Upper,ActorEpoch=state.ActorEpoch,ResourceEpoch=state.ResourceEpoch,Actor=state.Actor};
        }
        var history=await repository.HistoryAsync(session,query,ct);string? next=null;
        if(history.Context.HasMore)
        {
            var now=time.GetUtcNow().ToUnixTimeSeconds();var expiry=Math.Min(now+300,session.Identity.ExpiresUtc.ToUnixTimeSeconds());
            // Context comes from the completed, fully mapped SQL resultsets, not untrusted request fields.
            next=cursors.Protect(new(session.Identity.UserId,resource.Domain,resource.Id,history.Context.NextSequence,history.Context.UpperBound,
                history.Context.ActorAuthorizationVersion,history.Context.ResourceAuthorizationVersion,session.Identity.SessionId,now,expiry));
        }
        return new(history.Messages,next);
    }
    public async ValueTask<ChatV2SendResult> SendAsync(ChatV2Resource resource,Guid request,string content,CancellationToken ct)
    {
        var session=await Domain(resource,ct);
        if(request==Guid.Empty||string.IsNullOrWhiteSpace(content)||content.Length>1000)throw new ChatV2Exception(ChatV2Failure.Validation);
        using var lease=await sends.EnterAsync(session.Identity.UserId,request,ct);ChatV2Receipt? existing=null;
        try{existing=await repository.ReceiptAsync(session,request,ct);}catch(ChatV2Exception exception)when(exception.Failure==ChatV2Failure.Resource){/* Missing or inaccessible receipt: Send rechecks write access in SQL. */}
        if(existing is not null&&(existing.Domain!=resource.Domain||existing.ResourceId!=resource.Id||existing.Content!=content))throw new ChatV2Exception(ChatV2Failure.Conflict);
        // Even identical retries go through Send: a readable receipt must not bypass current write authorization.
        var receipt=await repository.SendAsync(session,resource,request,content,ct);
        return new(receipt,existing is null);
    }
    public async ValueTask<ChatV2Receipt> ReceiptAsync(Guid request,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);return await repository.ReceiptAsync(session,request,ct);}
    public async ValueTask<IReadOnlyList<ChatV2SearchHit>> SearchAsync(ChatV2Resource resource,string text,CancellationToken ct)
    {var session=await Domain(resource,ct);return await repository.SearchAsync(session,resource,text,ct);}
    public async ValueTask MarkReadAsync(ChatV2Resource resource,long sequence,CancellationToken ct)
    {var session=await Domain(resource,ct);await repository.MarkReadAsync(session,resource,sequence,ct);}
    public async ValueTask<int> CreateCaseAsync(CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireCustomerOwner(session);return await repository.CreateCaseAsync(session,ct);}
    public async ValueTask<IReadOnlyList<ChatV2QueueItem>> QueueAsync(CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireAttentionManagement(session);return await repository.QueueAsync(session,ct);}
    public async ValueTask<long> TransferAsync(int caseId,int newAgent,long expectedVersion,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireAttentionManagement(session);if(newAgent==session.Identity.UserId)throw new ChatV2Exception(ChatV2Failure.Forbidden);return await repository.TransferAsync(session,caseId,newAgent,expectedVersion,ct);}
    public async ValueTask<int> CreateDepartmentAsync(string label,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireManagement(session);return await repository.CreateDepartmentAsync(session,label,ct);}
    public async ValueTask SetMemberAsync(int department,int user,bool read,bool post,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireManagement(session);await repository.SetMemberAsync(session,department,user,read,post,ct);}
    public async ValueTask SetDepartmentActiveAsync(int department,bool active,CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);authorization.RequireManagement(session);await repository.SetDepartmentActiveAsync(session,department,active,ct);}
    public async ValueTask LogoutAsync(CancellationToken ct)
    {var session=await identities.ResolveCurrentAsync(ct);await repository.LogoutAsync(session,ct);}
}
