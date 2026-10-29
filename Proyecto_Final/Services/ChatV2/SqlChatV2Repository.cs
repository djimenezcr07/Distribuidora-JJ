using System.Data;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

public sealed class SqlChatV2Repository(IChatV2AppConnections connections) : IChatV2Repository
{
    private static SqlCommand Command(SqlConnection connection, string procedure, ServerChatV2Session session)
    {
        var command = new SqlCommand("ChatCandidate." + procedure, connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 15 };
        command.Parameters.Add("@SessionId",SqlDbType.UniqueIdentifier).Value=session.Identity.SessionId;
        command.Parameters.Add("@Proof",SqlDbType.VarBinary,32).Value=session.ProofForInfrastructure.ToArray();
        return command;
    }
    private static void Resource(SqlCommand command, ChatV2Resource resource)
    {
        resource.Validate();command.Parameters.Add("@Domain",SqlDbType.Char,1).Value=ChatV2Rows.SqlDomain(resource.Domain);
        command.Parameters.Add("@Resource",SqlDbType.Int).Value=resource.Id;
    }
    private async ValueTask<T> Read<T>(string procedure, ServerChatV2Session session, bool resource, Action<SqlCommand>? parameters,
        Func<SqlDataReader,CancellationToken,ValueTask<T>> map, CancellationToken ct)
    {
        try
        {
            await using var connection=await connections.OpenAsync(ct);using var command=Command(connection,procedure,session);parameters?.Invoke(command);
            using var reader=await command.ExecuteReaderAsync(ct);var result=await map(reader,ct);
            if(await reader.NextResultAsync(ct))ChatV2Rows.Contract();
            return result;
        }
        catch(SqlException exception){throw ChatV2Errors.FromSql(exception,resource);}
    }
    private async ValueTask Void(string procedure,ServerChatV2Session session,bool resource,Action<SqlCommand>? parameters,CancellationToken ct)
    {
        await Read(procedure,session,resource,parameters,(reader,_)=>
        {if(reader.FieldCount!=0)ChatV2Rows.Contract();return ValueTask.FromResult(true);},ct);
    }
    private async ValueTask<T> Scalar<T>(string procedure,ServerChatV2Session session,bool resource,Action<SqlCommand>? parameters,string column,string sqlType,CancellationToken ct)
    {
        return await Read(procedure,session,resource,parameters,async(reader,token)=>
        {
            ChatV2Rows.Schema(reader,new ChatV2Rows.Column(column,typeof(T),sqlType));
            if(!await reader.ReadAsync(token))ChatV2Rows.Contract();var result=ChatV2Rows.Required<T>(reader,0);
            if(await reader.ReadAsync(token))ChatV2Rows.Contract();return result;
        },ct);
    }
    public ValueTask<IReadOnlyList<ChatV2Contact>> DirectoryAsync(ServerChatV2Session session,CancellationToken ct)=>
        Read<IReadOnlyList<ChatV2Contact>>("Directory",session,false,null,async(reader,token)=>
        {ChatV2Rows.Schema(reader,new ChatV2Rows.Column("UserId",typeof(int),"int"));var rows=new List<ChatV2Contact>();while(await reader.ReadAsync(token)){var id=ChatV2Rows.Required<int>(reader,0);if(id<=0)ChatV2Rows.Contract();rows.Add(new(id));}return rows;},ct);
    public async ValueTask<int> OpenPrivateAsync(ServerChatV2Session session,int otherUser,CancellationToken ct)
    {
        if(otherUser<=0||otherUser==session.Identity.UserId)throw new ChatV2Exception(ChatV2Failure.Validation);
        var result=await Scalar<int>("OpenPrivate",session,false,c=>c.Parameters.Add("@OtherUser",SqlDbType.Int).Value=otherUser,"ResourceId","int",ct);
        if(result<=0)ChatV2Rows.Contract();return result;
    }
    public ValueTask<IReadOnlyList<ChatV2OwnedResource>> ListOwnAsync(ServerChatV2Session session,ChatV2Domain domain,CancellationToken ct)=>
        Read<IReadOnlyList<ChatV2OwnedResource>>("ListOwn",session,false,c=>c.Parameters.Add("@Domain",SqlDbType.Char,1).Value=ChatV2Rows.SqlDomain(domain),async(reader,token)=>
        {
            ChatV2Rows.Schema(reader,new("Domain",typeof(string),"varchar",1),new("ResourceId",typeof(int),"int"),new("AuthorizationVersion",typeof(long),"bigint"));
            var rows=new List<ChatV2OwnedResource>();while(await reader.ReadAsync(token)){var row=new ChatV2OwnedResource(ChatV2Rows.Domain(ChatV2Rows.Required<string>(reader,0)),ChatV2Rows.Required<int>(reader,1),ChatV2Rows.Required<long>(reader,2));if(row.Domain!=domain||row.ResourceId<=0||row.AuthorizationVersion<0)ChatV2Rows.Contract();rows.Add(row);}return rows;
        },ct);
    public async ValueTask<long> MembershipAsync(ServerChatV2Session session,ChatV2Resource resource,CancellationToken ct)
    {var result=await Scalar<long>("Membership",session,true,c=>Resource(c,resource),"AuthorizationVersion","bigint",ct);if(result<0)ChatV2Rows.Contract();return result;}
    public ValueTask<ChatV2History> HistoryAsync(ServerChatV2Session session,ChatV2HistoryQuery query,CancellationToken ct)
    {
        query.Resource.Validate();if(query.Limit is <1 or >100||query.After<0)throw new ChatV2Exception(ChatV2Failure.Validation);
        return Read("HistoryVNext",session,true,c=>
        {
            Resource(c,query.Resource);c.Parameters.Add("@Limit",SqlDbType.Int).Value=query.Limit;c.Parameters.Add("@After",SqlDbType.BigInt).Value=query.After;
            c.Parameters.Add("@Upper",SqlDbType.BigInt).Value=(object?)query.Upper??DBNull.Value;
            c.Parameters.Add("@ExpectedActorEpoch",SqlDbType.BigInt).Value=(object?)query.ActorEpoch??DBNull.Value;
            c.Parameters.Add("@ExpectedResourceEpoch",SqlDbType.BigInt).Value=(object?)query.ResourceEpoch??DBNull.Value;
            c.Parameters.Add("@ExpectedActorId",SqlDbType.Int).Value=(object?)query.Actor??DBNull.Value;
            c.Parameters.Add("@ExpectedDomain",SqlDbType.Char,1).Value=query.Upper is null?DBNull.Value:ChatV2Rows.SqlDomain(query.Resource.Domain);
            c.Parameters.Add("@ExpectedResourceId",SqlDbType.Int).Value=query.Upper is null?DBNull.Value:query.Resource.Id;
        },async(reader,token)=>
        {
            ChatV2Rows.Schema(reader,ChatV2Rows.HistoryColumns);var rows=new List<ChatV2Message>();long sequence=query.After;
            while(await reader.ReadAsync(token)){var row=ChatV2Rows.Message(reader);if(row.StreamSequence<=sequence||rows.Count>=query.Limit)ChatV2Rows.Contract();sequence=row.StreamSequence;rows.Add(row);}
            if(!await reader.NextResultAsync(token))ChatV2Rows.Contract();ChatV2Rows.Schema(reader,ChatV2Rows.ContextColumns);
            if(!await reader.ReadAsync(token))ChatV2Rows.Contract();var context=ChatV2Rows.Context(reader);
            if(await reader.ReadAsync(token)||context.Domain!=query.Resource.Domain||context.ResourceId!=query.Resource.Id
                ||context.NextSequence!=sequence||rows.Any(x=>x.StreamSequence>context.UpperBound)
                ||query.Upper is long upper&&context.UpperBound!=upper)ChatV2Rows.Contract();
            return new ChatV2History(rows,context);
        },ct);
    }
    private ValueTask<ChatV2Receipt> ReceiptRead(string procedure,ServerChatV2Session session,Guid requestId,Action<SqlCommand>? parameters,CancellationToken ct)
    {
        if(requestId==Guid.Empty)throw new ChatV2Exception(ChatV2Failure.Validation);
        return Read(procedure,session,true,c=>{c.Parameters.Add("@RequestId",SqlDbType.UniqueIdentifier).Value=requestId;parameters?.Invoke(c);},async(reader,token)=>
        {ChatV2Rows.Schema(reader,ChatV2Rows.ReceiptColumns);if(!await reader.ReadAsync(token))ChatV2Rows.Contract();var receipt=ChatV2Rows.Receipt(reader);if(receipt.RequestId!=requestId||await reader.ReadAsync(token))ChatV2Rows.Contract();return receipt;},ct);
    }
    public async ValueTask<ChatV2Receipt> SendAsync(ServerChatV2Session session,ChatV2Resource resource,Guid requestId,string content,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(content)||content.Length>1000)throw new ChatV2Exception(ChatV2Failure.Validation);
        var receipt=await ReceiptRead("Send",session,requestId,c=>{Resource(c,resource);c.Parameters.Add("@Content",SqlDbType.NVarChar,-1).Value=content;},ct);
        if(receipt.Domain!=resource.Domain||receipt.ResourceId!=resource.Id||receipt.Content!=content)ChatV2Rows.Contract();return receipt;
    }
    public ValueTask<ChatV2Receipt> ReceiptAsync(ServerChatV2Session session,Guid requestId,CancellationToken ct)=>ReceiptRead("Receipt",session,requestId,null,ct);
    public ValueTask<IReadOnlyList<ChatV2SearchHit>> SearchAsync(ServerChatV2Session session,ChatV2Resource resource,string text,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(text)||text.Length>100)throw new ChatV2Exception(ChatV2Failure.Validation);
        return Read<IReadOnlyList<ChatV2SearchHit>>("Search",session,true,c=>{Resource(c,resource);c.Parameters.Add("@Text",SqlDbType.NVarChar,100).Value=text;},async(reader,token)=>
        {ChatV2Rows.Schema(reader,new("MessageId",typeof(long),"bigint"),new("StreamSequence",typeof(long),"bigint"),new("Content",typeof(string),"nvarchar",1000));var rows=new List<ChatV2SearchHit>();long sequence=0;while(await reader.ReadAsync(token)){var row=new ChatV2SearchHit(ChatV2Rows.Required<long>(reader,0),ChatV2Rows.Required<long>(reader,1),ChatV2Rows.Required<string>(reader,2));if(row.MessageId<=0||row.StreamSequence<=sequence||rows.Count>=100)ChatV2Rows.Contract();sequence=row.StreamSequence;rows.Add(row);}return rows;},ct);
    }
    public ValueTask MarkReadAsync(ServerChatV2Session session,ChatV2Resource resource,long sequence,CancellationToken ct)
    {if(sequence<0)throw new ChatV2Exception(ChatV2Failure.Validation);return Void("MarkRead",session,true,c=>{Resource(c,resource);c.Parameters.Add("@Sequence",SqlDbType.BigInt).Value=sequence;},ct);}
    public async ValueTask<int> CreateCaseAsync(ServerChatV2Session session,CancellationToken ct)
    {var result=await Scalar<int>("CreateCase",session,false,null,"ResourceId","int",ct);if(result<=0)ChatV2Rows.Contract();return result;}
    public ValueTask<IReadOnlyList<ChatV2QueueItem>> QueueAsync(ServerChatV2Session session,CancellationToken ct)=>
        Read<IReadOnlyList<ChatV2QueueItem>>("Queue",session,false,null,async(reader,token)=>
        {ChatV2Rows.Schema(reader,new("CaseId",typeof(int),"int"),new("Assigned",typeof(bool),"bit"),new("AssignmentVersion",typeof(long),"bigint"),new("State",typeof(string),"varchar",20));var rows=new List<ChatV2QueueItem>();while(await reader.ReadAsync(token)){var row=new ChatV2QueueItem(ChatV2Rows.Required<int>(reader,0),ChatV2Rows.Required<bool>(reader,1),ChatV2Rows.Required<long>(reader,2),ChatV2Rows.Required<string>(reader,3));if(row.CaseId<=0||row.AssignmentVersion<0||row.State!="LAB_OPEN")ChatV2Rows.Contract();rows.Add(row);}return rows;},ct);
    public async ValueTask<long> TransferAsync(ServerChatV2Session session,int caseId,int newAgent,long expectedVersion,CancellationToken ct)
    {
        if(caseId<=0||newAgent<=0||expectedVersion<0)throw new ChatV2Exception(ChatV2Failure.Validation);
        var result=await Scalar<long>("Transfer",session,true,c=>{c.Parameters.Add("@CaseId",SqlDbType.Int).Value=caseId;c.Parameters.Add("@NewAgent",SqlDbType.Int).Value=newAgent;c.Parameters.Add("@ExpectedVersion",SqlDbType.BigInt).Value=expectedVersion;},"AssignmentVersion","bigint",ct);
        if(result!=expectedVersion+1)ChatV2Rows.Contract();return result;
    }
    public async ValueTask<int> CreateDepartmentAsync(ServerChatV2Session session,string label,CancellationToken ct)
    {if(string.IsNullOrWhiteSpace(label)||label.Length>120)throw new ChatV2Exception(ChatV2Failure.Validation);var result=await Scalar<int>("CreateDepartment",session,false,c=>c.Parameters.Add("@Label",SqlDbType.NVarChar,120).Value=label,"ResourceId","int",ct);if(result<=0)ChatV2Rows.Contract();return result;}
    public ValueTask SetMemberAsync(ServerChatV2Session session,int departmentId,int userId,bool canRead,bool canPost,CancellationToken ct)
    {if(departmentId<=0||userId<=0||canPost&&!canRead)throw new ChatV2Exception(ChatV2Failure.Validation);return Void("SetMember",session,true,c=>{c.Parameters.Add("@DepartmentId",SqlDbType.Int).Value=departmentId;c.Parameters.Add("@UserId",SqlDbType.Int).Value=userId;c.Parameters.Add("@CanRead",SqlDbType.Bit).Value=canRead;c.Parameters.Add("@CanPost",SqlDbType.Bit).Value=canPost;},ct);}
    public ValueTask SetDepartmentActiveAsync(ServerChatV2Session session,int departmentId,bool active,CancellationToken ct)
    {if(departmentId<=0)throw new ChatV2Exception(ChatV2Failure.Validation);return Void("SetDepartmentActive",session,true,c=>{c.Parameters.Add("@DepartmentId",SqlDbType.Int).Value=departmentId;c.Parameters.Add("@Active",SqlDbType.Bit).Value=active;},ct);}
    public ValueTask LogoutAsync(ServerChatV2Session session,CancellationToken ct)=>Void("Logout",session,false,null,ct);
}
