using System.Security.Cryptography;
using System.Text;

namespace Proyecto_Final.Services.ChatV2;

public sealed record ChatV2CursorState(int Actor,ChatV2Domain Domain,int Resource,long After,long Upper,long ActorEpoch,
    long ResourceEpoch,Guid Session,long Issued,long Expires);
public sealed record ChatV2CursorContext(int Actor,ChatV2Domain Domain,int Resource,long ActorEpoch,long ResourceEpoch,Guid Session,long SessionExpires);
public interface IChatV2CursorKeys { ushort SigningKeyId { get; } bool TryCopyKey(ushort id,out byte[] key); }
public interface IChatV2CursorProtector
{
    string Protect(ChatV2CursorState state);
    bool TryUnprotect(string token,ChatV2CursorContext current,out ChatV2CursorState? state);
}

/// <summary>Ephemeral key ring. Future hosting must supply custody, rotation and distribution; no configuration is read here.</summary>
public sealed class EphemeralChatV2CursorKeys : IChatV2CursorKeys,IDisposable
{
    private readonly object _gate=new();private readonly Dictionary<ushort,byte[]> _keys=[];private readonly HashSet<ushort> _revoked=[];
    private ushort _active;private bool _disposed;
    public ushort SigningKeyId {get{lock(_gate)return _active;}}
    public void Rotate(ushort id){lock(_gate){ObjectDisposedException.ThrowIf(_disposed,this);if(id==0||_keys.ContainsKey(id))throw new ArgumentException("Invalid key identifier.",nameof(id));_keys[id]=RandomNumberGenerator.GetBytes(32);_active=id;}}
    public void Revoke(ushort id){lock(_gate)_revoked.Add(id);}
    public bool TryCopyKey(ushort id,out byte[] key){lock(_gate){key=[];if(_disposed||_revoked.Contains(id)||!_keys.TryGetValue(id,out var stored))return false;key=stored.ToArray();return true;}}
    public void Dispose(){lock(_gate){foreach(var key in _keys.Values)CryptographicOperations.ZeroMemory(key);_keys.Clear();_disposed=true;}}
}

public sealed class HmacChatV2CursorProtector(IChatV2CursorKeys keys,TimeProvider time) : IChatV2CursorProtector
{
    private const int PayloadLength=84,TokenLength=116;
    private static readonly byte[] Purpose=Encoding.ASCII.GetBytes("JJCHCUR1");
    private static bool Canonical(ChatV2CursorState state)=>state.Actor>0&&state.Resource>0&&Enum.IsDefined(state.Domain)
        &&state.Session!=Guid.Empty&&state.After>=0&&state.Upper>=state.After&&state.ActorEpoch>0&&state.ResourceEpoch>=0
        &&state.Issued>=0&&state.Expires>state.Issued&&state.Expires-state.Issued<=300;
    private static string Encode(byte[] bytes)=>Convert.ToBase64String(bytes).TrimEnd('=').Replace('+','-').Replace('/','_');
    public string Protect(ChatV2CursorState state)
    {
        var now=time.GetUtcNow().ToUnixTimeSeconds();var keyId=keys.SigningKeyId;
        if(!Canonical(state)||state.Issued>now||state.Expires<=now||!keys.TryCopyKey(keyId,out var key))throw new ChatV2Exception(ChatV2Failure.Contract);
        try
        {
            using var stream=new MemoryStream();using(var writer=new BinaryWriter(stream,Encoding.UTF8,true))
            {writer.Write(Purpose);writer.Write((byte)1);writer.Write(keyId);writer.Write((byte)state.Domain);writer.Write(state.Actor);writer.Write(state.Resource);
                writer.Write(state.After);writer.Write(state.Upper);writer.Write(state.ActorEpoch);writer.Write(state.ResourceEpoch);writer.Write(state.Session.ToByteArray());writer.Write(state.Issued);writer.Write(state.Expires);}
            var payload=stream.ToArray();return Encode([..payload,..HMACSHA256.HashData(key,payload)]);
        }
        finally{CryptographicOperations.ZeroMemory(key);}
    }
    public bool TryUnprotect(string token,ChatV2CursorContext context,out ChatV2CursorState? state)
    {
        state=null;if(token is null||token.Length!=155||token.Any(c=>!char.IsAsciiLetterOrDigit(c)&&c!='-'&&c!='_'))return false;
        byte[] bytes;try{bytes=Convert.FromBase64String(token.Replace('-','+').Replace('_','/')+"=");}catch(FormatException){return false;}
        if(bytes.Length!=TokenLength||Encode(bytes)!=token||!bytes.AsSpan(0,8).SequenceEqual(Purpose)||bytes[8]!=1)return false;
        using var stream=new MemoryStream(bytes,0,PayloadLength,false);using var reader=new BinaryReader(stream);
        reader.ReadBytes(9);var keyId=reader.ReadUInt16();if(!keys.TryCopyKey(keyId,out var key))return false;
        try{if(!CryptographicOperations.FixedTimeEquals(HMACSHA256.HashData(key,bytes.AsSpan(0,PayloadLength)),bytes.AsSpan(PayloadLength,32)))return false;}
        finally{CryptographicOperations.ZeroMemory(key);}
        var candidate=new ChatV2CursorState(0,(ChatV2Domain)reader.ReadByte(),0,0,0,0,0,Guid.Empty,0,0);
        candidate=candidate with {Actor=reader.ReadInt32(),Resource=reader.ReadInt32(),After=reader.ReadInt64(),Upper=reader.ReadInt64(),ActorEpoch=reader.ReadInt64(),ResourceEpoch=reader.ReadInt64(),Session=new Guid(reader.ReadBytes(16)),Issued=reader.ReadInt64(),Expires=reader.ReadInt64()};
        var now=time.GetUtcNow().ToUnixTimeSeconds();
        if(!Canonical(candidate)||candidate.Issued>now||candidate.Expires<=now||candidate.Expires>context.SessionExpires
            ||candidate.Actor!=context.Actor||candidate.Domain!=context.Domain||candidate.Resource!=context.Resource
            ||candidate.ActorEpoch!=context.ActorEpoch||candidate.ResourceEpoch!=context.ResourceEpoch||candidate.Session!=context.Session)return false;
        state=candidate;return true;
    }
}
