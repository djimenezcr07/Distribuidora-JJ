using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Moq;
using Proyecto_Final.Services.ChatV2;
using Xunit;

namespace Proyecto_Final.Tests;

public sealed class ChatV2SecurityAndContractsTests
{
    private sealed class Clock : TimeProvider { public DateTimeOffset Now=DateTimeOffset.FromUnixTimeSeconds(2_000_000_000); public override DateTimeOffset GetUtcNow()=>Now; }
    private static ServerChatV2Session Session(ChatV2Kind kind,ChatV2Capabilities caps,Clock clock)=>new(new(101,7,kind==ChatV2Kind.Client?9001:null,kind,caps,Guid.NewGuid(),5,Guid.NewGuid(),clock.Now.AddHours(1)),RandomNumberGenerator.GetBytes(32));
    [Theory]
    [InlineData(ChatV2Capabilities.InternalUse)]
    [InlineData(ChatV2Capabilities.ManageDepartments)]
    [InlineData(ChatV2Capabilities.AttendCustomers)]
    [InlineData(ChatV2Capabilities.InternalUse|ChatV2Capabilities.ManageDepartments|ChatV2Capabilities.AttendCustomers)]
    public void ClientCapabilitiesNeverChangeCanonicalKind(ChatV2Capabilities accidental)
    {
        var clock=new Clock();var session=Session(ChatV2Kind.Client,accidental|ChatV2Capabilities.CustomerUse,clock);var auth=new ChatV2Authorization(clock);
        Assert.Equal(ChatV2Failure.Forbidden,Assert.Throws<ChatV2Exception>(()=>auth.RequireInternal(session)).Failure);
        Assert.Equal(ChatV2Failure.Forbidden,Assert.Throws<ChatV2Exception>(()=>auth.RequireManagement(session)).Failure);
        auth.RequireDomain(session,ChatV2Domain.Customer);Assert.NotEqual(session.Identity.UserId,session.Identity.ClientId);
    }
    [Fact] public void InternalWithAccidentalCIsNotClientOwner(){var clock=new Clock();var session=Session(ChatV2Kind.Internal,ChatV2Capabilities.CustomerUse,clock);Assert.Throws<ChatV2Exception>(()=>new ChatV2Authorization(clock).RequireCustomerOwner(session));}
    [Fact] public void AgentWithoutUCanOnlyUseAttention(){var clock=new Clock();var session=Session(ChatV2Kind.Internal,ChatV2Capabilities.AttendCustomers,clock);var auth=new ChatV2Authorization(clock);auth.RequireDomain(session,ChatV2Domain.Customer);Assert.Throws<ChatV2Exception>(()=>auth.RequireDomain(session,ChatV2Domain.Private));}
    [Fact] public void InfrastructureProofIsNeverSerializedOrPrinted(){var session=Session(ChatV2Kind.Internal,ChatV2Capabilities.InternalUse,new Clock());Assert.Equal("{}",JsonSerializer.Serialize(session));Assert.Equal("ServerChatV2Session",session.ToString());}
    [Theory] [InlineData(0)] [InlineData(31)] [InlineData(33)] public void ProofLengthIsStrict(int length)=>Assert.Throws<ChatV2Exception>(()=>new ServerChatV2Session(Session(ChatV2Kind.Internal,ChatV2Capabilities.InternalUse,new Clock()).Identity,new byte[length]));
    [Fact] public async Task ResolverUsesCurrentCanonicalStateAndPreservesIdentityKind()
    {
        var clock=new Clock();var session=Session(ChatV2Kind.Client,ChatV2Capabilities.CustomerUse,clock);var state=new ChatV2CanonicalState(101,7,9001,ChatV2Kind.Client,ChatV2Capabilities.CustomerUse|ChatV2Capabilities.InternalUse,true,true,session.Identity.SecurityStamp,session.Identity.SecurityStamp,session.Identity.SessionId,session.Identity.ExpiresUtc,false,9);
        var source=new Mock<IChatV2CanonicalStateSource>();source.Setup(x=>x.GetAsync(session.Identity.SessionId,It.IsAny<CancellationToken>())).ReturnsAsync(state);
        var current=await new ChatV2IdentityResolver(source.Object,clock).ResolveAsync(session,default);Assert.Equal(9,current.ActorEpoch);Assert.Equal(ChatV2Kind.Client,current.Kind);Assert.Equal(9001,current.ClientId);
    }
    [Theory] [InlineData("user")] [InlineData("profile")] [InlineData("revoked")] [InlineData("stamp")] [InlineData("kind")] [InlineData("profileId")] [InlineData("expires")]
    public async Task ResolverFailsClosedOnChangedCanonicalState(string change)
    {
        var clock=new Clock();var session=Session(ChatV2Kind.Internal,ChatV2Capabilities.InternalUse,clock);var state=new ChatV2CanonicalState(101,7,null,ChatV2Kind.Internal,ChatV2Capabilities.InternalUse,true,true,session.Identity.SecurityStamp,session.Identity.SecurityStamp,session.Identity.SessionId,session.Identity.ExpiresUtc,false,5);
        state=change switch{"user"=>state with{UserActive=false},"profile"=>state with{ProfileActive=false},"revoked"=>state with{Revoked=true},"stamp"=>state with{CurrentStamp=Guid.NewGuid()},"kind"=>state with{Kind=ChatV2Kind.Client},"profileId"=>state with{ProfileId=8},_=>state with{ExpiresUtc=clock.Now}};
        var source=new Mock<IChatV2CanonicalStateSource>();source.Setup(x=>x.GetAsync(It.IsAny<Guid>(),It.IsAny<CancellationToken>())).ReturnsAsync(state);
        Assert.Equal(ChatV2Failure.Session,(await Assert.ThrowsAsync<ChatV2Exception>(async()=>await new ChatV2IdentityResolver(source.Object,clock).ResolveAsync(session,default))).Failure);
    }
    private static ChatV2CursorState State(Clock clock)=>new(101,ChatV2Domain.Private,3,2,8,5,7,Guid.NewGuid(),clock.Now.ToUnixTimeSeconds(),clock.Now.AddMinutes(2).ToUnixTimeSeconds());
    private static ChatV2CursorContext Context(ChatV2CursorState state)=>new(state.Actor,state.Domain,state.Resource,state.ActorEpoch,state.ResourceEpoch,state.Session,state.Expires+1);
    [Fact] public void CursorRoundTripAndRotation(){var clock=new Clock();using var keys=new EphemeralChatV2CursorKeys();keys.Rotate(10);var protector=new HmacChatV2CursorProtector(keys,clock);var state=State(clock);var token=protector.Protect(state);keys.Rotate(11);Assert.True(protector.TryUnprotect(token,Context(state),out var actual));Assert.Equal(state,actual);keys.Revoke(10);Assert.False(protector.TryUnprotect(token,Context(state),out _));}
    [Theory] [InlineData("actor")] [InlineData("domain")] [InlineData("resource")] [InlineData("actorEpoch")] [InlineData("resourceEpoch")] [InlineData("session")] [InlineData("sessionExpiry")]
    public void CursorIsBoundToEveryCurrentContextField(string change)
    {
        var clock=new Clock();using var keys=new EphemeralChatV2CursorKeys();keys.Rotate(1);var protector=new HmacChatV2CursorProtector(keys,clock);var state=State(clock);var context=Context(state);
        context=change switch{"actor"=>context with{Actor=102},"domain"=>context with{Domain=ChatV2Domain.Customer},"resource"=>context with{Resource=4},"actorEpoch"=>context with{ActorEpoch=6},"resourceEpoch"=>context with{ResourceEpoch=8},"session"=>context with{Session=Guid.NewGuid()},_=>context with{SessionExpires=state.Expires-1}};
        Assert.False(protector.TryUnprotect(protector.Protect(state),context,out _));
    }
    [Theory] [InlineData("tag")] [InlineData("truncated")] [InlineData("padding")] [InlineData("unicode")] [InlineData("oversized")] [InlineData("expired")]
    public void CursorRejectsMalformedEncodingTamperingAndExpiry(string change)
    {
        var clock=new Clock();using var keys=new EphemeralChatV2CursorKeys();keys.Rotate(1);var protector=new HmacChatV2CursorProtector(keys,clock);var state=State(clock);var token=protector.Protect(state);
        token=change switch{"tag"=>token[..^2]+(token[^2]=='a'?'b':'a')+token[^1],"truncated"=>token[..^1],"padding"=>token+"=","unicode"=>"ñ"+token[1..],"oversized"=>token+new string('a',5000),_=>token};if(change=="expired")clock.Now=clock.Now.AddMinutes(3);
        Assert.False(protector.TryUnprotect(token,Context(state),out _));
    }
    [Theory] [InlineData(0)] [InlineData(8)] [InlineData(11)] [InlineData(12)] [InlineData(16)] [InlineData(20)] [InlineData(28)] [InlineData(36)] [InlineData(44)] [InlineData(52)] [InlineData(68)] [InlineData(76)]
    public void AuthenticatedMalformedCursorPayloadsStillFailValidation(int offset)
    {
        var clock=new Clock();using var keys=new EphemeralChatV2CursorKeys();keys.Rotate(1);var protector=new HmacChatV2CursorProtector(keys,clock);var state=State(clock);var bytes=Convert.FromBase64String(protector.Protect(state).Replace('-','+').Replace('_','/')+"=");
        if(offset==28)BitConverter.GetBytes(-1L).CopyTo(bytes,offset);else if(offset==76)BitConverter.GetBytes(state.Issued).CopyTo(bytes,offset);else bytes[offset]^=0x40;
        Assert.True(keys.TryCopyKey(1,out var key));try{HMACSHA256.HashData(key,bytes.AsSpan(0,84)).CopyTo(bytes,84);}finally{CryptographicOperations.ZeroMemory(key);}var token=Convert.ToBase64String(bytes).TrimEnd('=').Replace('+','-').Replace('/','_');Assert.False(protector.TryUnprotect(token,Context(state),out _));
    }
    [Fact] public void UnknownKeyIsRejected(){var clock=new Clock();using var keys=new EphemeralChatV2CursorKeys();keys.Rotate(1);var protector=new HmacChatV2CursorProtector(keys,clock);var state=State(clock);var token=protector.Protect(state);using var otherKeys=new EphemeralChatV2CursorKeys();otherKeys.Rotate(2);Assert.False(new HmacChatV2CursorProtector(otherKeys,clock).TryUnprotect(token,Context(state),out _));}
    [Fact] public void BrowserCannotDeserializeServerSession()=>Assert.Throws<NotSupportedException>(()=>JsonSerializer.Deserialize<ServerChatV2Session>("{}"));
    private static DataTable ReceiptTable()
    {var table=new DataTable();foreach(var column in ChatV2Rows.ReceiptColumns)table.Columns.Add(column.Name,column.ClrType);table.Rows.Add(Guid.NewGuid(),"P",3,3_000_000_001L,3_000_000_002L,new DateTime(2026,10,11),"PERSISTED","Synthetic",3_000_000_003L);return table;}
    [Fact] public void ReceiptMapsBigintAndUtcWithoutDowncasting(){using var reader=ReceiptTable().CreateDataReader();ChatV2Rows.Schema(reader,ChatV2Rows.ReceiptColumns);Assert.True(reader.Read());var receipt=ChatV2Rows.Receipt(reader);Assert.Equal(3_000_000_001L,receipt.MessageId);Assert.Equal(3_000_000_003L,receipt.AuthorizationVersion);Assert.Equal(DateTimeKind.Utc,receipt.TimestampUtc.Kind);}
    [Theory] [InlineData(0)] [InlineData(1)] [InlineData(2)] [InlineData(3)] [InlineData(4)] [InlineData(5)] [InlineData(6)] [InlineData(7)] [InlineData(8)]
    public void ReceiptRequiredNullNeverBecomesDefault(int ordinal){var table=ReceiptTable();table.Rows[0][ordinal]=DBNull.Value;using var reader=table.CreateDataReader();reader.Read();Assert.Equal(ChatV2Failure.Contract,Assert.Throws<ChatV2Exception>(()=>ChatV2Rows.Receipt(reader)).Failure);}
    [Theory] [InlineData("missing")] [InlineData("extra")] [InlineData("name")] [InlineData("type")]
    public void ShapeMismatchFailsClosed(string change){var table=ReceiptTable();if(change=="missing")table.Columns.RemoveAt(8);if(change=="extra")table.Columns.Add("Signature",typeof(byte[]));if(change=="name")table.Columns[0].ColumnName="Wrong";if(change=="type"){table=new DataTable();foreach(var c in ChatV2Rows.ReceiptColumns)table.Columns.Add(c.Name,c.Name=="MessageId"?typeof(int):c.ClrType);}using var reader=table.CreateDataReader();Assert.Throws<ChatV2Exception>(()=>ChatV2Rows.Schema(reader,ChatV2Rows.ReceiptColumns));}
    [Fact] public void HistoryPreservesLegacyDateNullUtcAndFalseRead()
    {var table=new DataTable();foreach(var c in ChatV2Rows.HistoryColumns)table.Columns.Add(c.Name,c.ClrType);table.Rows.Add(1L,1L,101,"Synthetic",new DateTime(2020,1,1),DBNull.Value,1,false);using var reader=table.CreateDataReader();reader.Read();var message=ChatV2Rows.Message(reader);Assert.Equal(DateTimeKind.Unspecified,message.OriginalDate!.Value.Kind);Assert.Null(message.TimestampUtc);Assert.False(message.LegacyRead);}
    [Fact] public async Task SendCoordinatorSerializesSameRequestAndIsBounded()
    {var coordinator=new ChatV2SendCoordinator();var id=Guid.NewGuid();using var first=await coordinator.EnterAsync(1,id,default);var second=coordinator.EnterAsync(1,id,default).AsTask();Assert.False(second.IsCompleted);first.Dispose();using var lease=await second.WaitAsync(TimeSpan.FromSeconds(2));}
    [Theory] [InlineData(ChatV2Failure.Session,401)] [InlineData(ChatV2Failure.Forbidden,403)] [InlineData(ChatV2Failure.Resource,404)] [InlineData(ChatV2Failure.Validation,400)] [InlineData(ChatV2Failure.Conflict,409)] [InlineData(ChatV2Failure.Dependency,503)] [InlineData(ChatV2Failure.Contract,503)]
    public void ErrorContractHasNoSqlOrProof(ChatV2Failure failure,int status){Assert.Equal(status,ChatV2Errors.Status(failure));Assert.Equal("Chat operation failed.",new ChatV2Exception(failure).Message);}
}
