using System.Data;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services.ChatV2;

/// <summary>Read-only authority adapter. Requires a separate, narrowly granted server-side provider, not APP credentials.</summary>
public sealed class SqlChatV2CanonicalStateSource(IChatV2CanonicalReadConnections source) : IChatV2CanonicalStateSource
{
    public async ValueTask<ChatV2CanonicalState?> GetAsync(Guid serverSessionId, CancellationToken ct)
    {
        if (serverSessionId == Guid.Empty) return null;
        try
        {
            await using var connection = await source.OpenAsync(ct);
            // Fixed SQL, with parameterized server session. ProofHash is deliberately never selected.
            using var command = new SqlCommand("""
                SELECT u.UsuarioId,u.PerfilId,c.ClienteId,i.Kind,u.Activo UserActive,p.Activo ProfileActive,
                    u.SecurityStamp,s.Stamp SessionStamp,s.SessionId,s.ExpiresUtc,s.Revoked,i.AuthorizationVersion
                FROM ChatCandidate.Sessions s JOIN dbo.Usuarios u ON u.UsuarioId=s.UserId
                JOIN dbo.Perfiles p ON p.PerfilId=u.PerfilId JOIN ChatCandidate.IdentityMap i ON i.UserId=u.UsuarioId
                LEFT JOIN dbo.Clientes c ON c.UsuarioId=u.UsuarioId WHERE s.SessionId=@SessionId;
                SELECT uc.Code FROM ChatCandidate.UserCapabilities uc JOIN ChatCandidate.Sessions s ON s.UserId=uc.UserId
                WHERE s.SessionId=@SessionId AND uc.Enabled=1 ORDER BY uc.Code;
                """, connection);
            command.Parameters.Add("@SessionId",SqlDbType.UniqueIdentifier).Value=serverSessionId;
            using var reader = await command.ExecuteReaderAsync(ct);
            ChatV2Rows.Schema(reader,new("UsuarioId",typeof(int),"int"),new("PerfilId",typeof(int),"int"),new("ClienteId",typeof(int),"int"),
                new("Kind",typeof(string),"char",1),new("UserActive",typeof(bool),"bit"),new("ProfileActive",typeof(bool),"bit"),
                new("SecurityStamp",typeof(Guid),"uniqueidentifier"),new("SessionStamp",typeof(Guid),"uniqueidentifier"),new("SessionId",typeof(Guid),"uniqueidentifier"),
                new("ExpiresUtc",typeof(DateTime),"datetime2"),new("Revoked",typeof(bool),"bit"),new("AuthorizationVersion",typeof(long),"bigint"));
            ChatV2CanonicalState? state=null;
            if(await reader.ReadAsync(ct))
            {
                var kind=ChatV2Rows.Required<string>(reader,3) switch { "I" => ChatV2Kind.Internal, "C" => ChatV2Kind.Client, _=>throw new ChatV2Exception(ChatV2Failure.Contract) };
                state=new(ChatV2Rows.Required<int>(reader,0),ChatV2Rows.Required<int>(reader,1),ChatV2Rows.Optional<int>(reader,2),kind,ChatV2Capabilities.None,
                    ChatV2Rows.Required<bool>(reader,4),ChatV2Rows.Required<bool>(reader,5),ChatV2Rows.Required<Guid>(reader,6),ChatV2Rows.Required<Guid>(reader,7),ChatV2Rows.Required<Guid>(reader,8),
                    new DateTimeOffset(ChatV2Rows.Utc(ChatV2Rows.Required<DateTime>(reader,9))),ChatV2Rows.Required<bool>(reader,10),ChatV2Rows.Required<long>(reader,11));
                if(state.UserId<=0||state.ProfileId<=0||state.ActorEpoch<=0||state.SessionId!=serverSessionId||await reader.ReadAsync(ct))ChatV2Rows.Contract();
            }
            if(!await reader.NextResultAsync(ct))ChatV2Rows.Contract();
            ChatV2Rows.Schema(reader,new ChatV2Rows.Column("Code",typeof(string),"varchar",60));var capabilities=ChatV2Capabilities.None;
            while(await reader.ReadAsync(ct))capabilities|=ChatV2Rows.Required<string>(reader,0) switch
            {
                "CHAT_USAR"=>ChatV2Capabilities.InternalUse,"CHAT_CLIENTE_USAR"=>ChatV2Capabilities.CustomerUse,
                "CHAT_CLIENTES_ATENDER"=>ChatV2Capabilities.AttendCustomers,"CHAT_ATENCION_GESTIONAR"=>ChatV2Capabilities.ManageAttention,"CHAT_DEPARTAMENTOS_GESTIONAR"=>ChatV2Capabilities.ManageDepartments,
                _=>throw new ChatV2Exception(ChatV2Failure.Contract)
            };
            if(await reader.NextResultAsync(ct))ChatV2Rows.Contract();
            return state is null ? null : state with {Capabilities=capabilities};
        }
        catch(SqlException exception){throw ChatV2Errors.FromSql(exception);}
    }
}
