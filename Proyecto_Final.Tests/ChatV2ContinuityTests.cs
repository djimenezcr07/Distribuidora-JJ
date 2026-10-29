using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Services;
using Proyecto_Final.Services.ChatV2;

namespace Proyecto_Final.Tests;

// Deterministic model only: these tests do not certify SQL durability, locks or HTTP authentication.
public sealed class ChatV2ContinuityTests
{
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }
    private sealed class DurableModel(Clock clock) : IChatV2IntentPersistence
    {
        private sealed record Owner(Guid Login, Guid Session, int Actor, string Hash, ChatV2Resource Resource, long ActorEpoch, long ResourceEpoch, DateTimeOffset Until);
        private readonly Dictionary<Guid, Owner> _owners = [];
        private readonly Dictionary<Guid, ChatV2Receipt> _receipts = [];
        public bool Revoked, LoseResponse, Access = true;
        public bool WrongOriginalLogin;
        public ChatV2Kind Kind = ChatV2Kind.Internal;
        public ChatV2Capabilities Caps = ChatV2Capabilities.InternalUse;
        public long ActorEpoch = 1, ResourceEpoch = 1;
        public int Effects, Calls;
        public ChatV2BoundIntent? Captured;
        public ValueTask<ChatV2LiveIdentity> ResolveAsync(OriginalLoginContext login, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested(); if (Revoked) throw new ChatV2Exception(ChatV2Failure.Session);
            return ValueTask.FromResult(new ChatV2LiveIdentity(WrongOriginalLogin ? Guid.NewGuid() : login.LoginId,
                login.LoginId, login.UserId, login.ProfileId, Kind, login.SecurityStamp, ActorEpoch, new(login.ExpiresUtc), Caps));
        }
        public ValueTask<ChatV2IntentEpochs> PrepareAsync(OriginalLoginContext login, ChatV2LiveIdentity identity,
            ChatV2Resource resource, Guid request, string hash, CancellationToken ct)
        {
            if (!Access) throw new ChatV2Exception(ChatV2Failure.Forbidden);
            if (!_owners.TryGetValue(request, out var owner))
            {
                owner = new(login.LoginId, identity.SessionId, identity.Actor, hash, resource, ActorEpoch, ResourceEpoch, clock.Now.AddMinutes(15));
                _owners.Add(request, owner);
            }
            if (owner.Login != login.LoginId || owner.Session != identity.SessionId || owner.Actor != identity.Actor || owner.Hash != hash ||
                owner.Resource != resource || owner.ActorEpoch != ActorEpoch || owner.ResourceEpoch != ResourceEpoch || owner.Until <= clock.Now)
                throw new ChatV2Exception(ChatV2Failure.Conflict);
            return ValueTask.FromResult(new ChatV2IntentEpochs(owner.ActorEpoch, owner.ResourceEpoch, owner.Until));
        }
        public ValueTask<ChatV2Receipt> ExecuteAsync(ChatV2BoundIntent intent, string? content, bool receiptOnly, CancellationToken ct)
        {
            Calls++; Captured = intent;
            if (!Access) throw new ChatV2Exception(receiptOnly ? ChatV2Failure.Resource : ChatV2Failure.Forbidden);
            var owner = _owners[intent.Request];
            if (owner.ActorEpoch != ActorEpoch || owner.ResourceEpoch != ResourceEpoch || owner.Until <= clock.Now)
                throw new ChatV2Exception(ChatV2Failure.Conflict);
            if (!_receipts.TryGetValue(intent.Request, out var receipt))
            {
                if (receiptOnly) throw new ChatV2Exception(ChatV2Failure.Resource);
                receipt = new(intent.Request, intent.Resource.Domain, intent.Resource.Id, 9_007_199_254_740_993L, 9_007_199_254_740_995L,
                    clock.Now.UtcDateTime, "PERSISTED", content!, ResourceEpoch);
                _receipts.Add(intent.Request, receipt); Effects++;
            }
            if (LoseResponse) { LoseResponse = false; throw new IOException("Synthetic response loss after modeled commit"); }
            return ValueTask.FromResult(receipt);
        }
    }
    private static OriginalLoginContext Login(Clock clock, int actor = 101) => new(Guid.NewGuid(), actor, 7, Guid.NewGuid(),
        clock.Now.UtcDateTime, clock.Now.AddHours(8).UtcDateTime, RandomNumberGenerator.GetBytes(32));
    private sealed record Fixture(Clock Clock, OriginalLoginContext Login, DurableModel Backend, ChatV2Continuity Continuity,
        ChatV2IntentInput Input);
    private static async Task<Fixture> Setup()
    {
        var clock = new Clock(); var login = Login(clock); var backend = new DurableModel(clock); var continuity = new ChatV2Continuity(clock);
        var context = await continuity.ContextAsync(login, backend, default);
        return new(clock, login, backend, continuity, new(context.ContextHandle, "P", 7, Guid.NewGuid(), " exact ñ <script> "));
    }
    private static async Task<ChatV2IntentInput> Prepared(Fixture f) => f.Input with
        { IntentBinding = (await f.Continuity.PrepareAsync(f.Login, f.Input, f.Backend, default)).IntentBinding };
    [Fact] public async Task SameOriginalSessionHasStableOpaqueContextAndStableBinding()
    {
        var f = await Setup(); var next = await f.Continuity.ContextAsync(f.Login, f.Backend, default);
        Assert.Equal(f.Input.ContextHandle, next.ContextHandle); Assert.Equal(43, next.ContextHandle.Length);
        Assert.DoesNotContain(f.Login.LoginId.ToString(), JsonSerializer.Serialize(next));
        var first = await Prepared(f); var repeated = await Prepared(f); Assert.Equal(first.IntentBinding, repeated.IntentBinding);
    }
    [Fact] public async Task SameAccountNewLoginCannotAdoptOriginalUuidEvenWithFreshContext()
    {
        var f = await Setup(); await Prepared(f); var second = Login(f.Clock) with { SecurityStamp = f.Login.SecurityStamp };
        var context = await f.Continuity.ContextAsync(second, f.Backend, default);
        Assert.NotEqual(f.Input.ContextHandle, context.ContextHandle);
        var error = await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.PrepareAsync(second,
            f.Input with { ContextHandle = context.ContextHandle }, f.Backend, default));
        Assert.Equal(ChatV2Failure.Conflict, error.Failure); Assert.Equal(0, f.Backend.Effects);
    }
    [Fact] public async Task OtherAccountCannotUseOriginalContext()
    {
        var f = await Setup(); var input = await Prepared(f);
        Assert.Equal(ChatV2Failure.Conflict, (await Assert.ThrowsAsync<ChatV2Exception>(async () =>
            await f.Continuity.ExecuteAsync(Login(f.Clock, 102), input, false, f.Backend, default))).Failure);
        Assert.Equal(0, f.Backend.Calls);
    }
    [Fact] public async Task RevokeRegrantEpochCannotResurrectPreparedIntent()
    {
        var f = await Setup(); var input = await Prepared(f); f.Backend.ActorEpoch += 2;
        Assert.Equal(ChatV2Failure.Conflict, (await Assert.ThrowsAsync<ChatV2Exception>(async () =>
            await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default))).Failure);
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await Prepared(f)); Assert.Equal(0, f.Backend.Effects);
    }
    [Fact] public async Task LostResponseRecoversExactReceiptAndRetryDoesNotDuplicateModeledEffects()
    {
        var f = await Setup(); var input = await Prepared(f); f.Backend.LoseResponse = true;
        await Assert.ThrowsAsync<IOException>(async () => await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default));
        var receipt = await f.Continuity.ExecuteAsync(f.Login, input with { Content = null }, true, f.Backend, default);
        var retry = await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default);
        Assert.Equal(receipt.MessageId, retry.MessageId); Assert.Equal(1, f.Backend.Effects);
        Assert.Equal(f.Input.Content, receipt.Content); Assert.Equal(f.Login.LoginId, f.Backend.Captured!.Login.LoginId);
        Assert.Equal("{}", JsonSerializer.Serialize(f.Backend.Captured));
    }
    [Theory] [InlineData("body")] [InlineData("resource")] [InlineData("domain")] [InlineData("binding")]
    public async Task ChangedIntentNeverReachesExecution(string change)
    {
        var f = await Setup(); var input = await Prepared(f);
        input = change switch { "body" => input with { Content = "changed" }, "resource" => input with { Resource = 8 },
            "domain" => input with { Domain = "D" }, _ => input with { IntentBinding = "unknown" } };
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default));
        Assert.Equal(0, f.Backend.Calls);
    }
    [Fact] public async Task ExpiredIntentWithActiveEightHourLoginCannotBeRenewedInModel()
    {
        var f = await Setup(); var input = await Prepared(f); f.Clock.Now = f.Clock.Now.AddMinutes(16);
        Assert.True(f.Login.ExpiresUtc > f.Clock.Now.UtcDateTime);
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default));
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await Prepared(f)); Assert.Equal(0, f.Backend.Effects);
    }
    [Fact] public async Task PurgeInvalidatesMemoryReferencesWithoutDeletingDurableReceipt()
    {
        var f = await Setup(); var input = await Prepared(f);
        await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default); f.Continuity.Purge(f.Login.LoginId);
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.ExecuteAsync(f.Login, input, true, f.Backend, default));
        Assert.Equal(1, f.Backend.Effects);
    }
    [Fact] public async Task OriginalBindingCannotBeReplacedBySameIds()
    {
        var f = await Setup(); var input = await Prepared(f); var forged = f.Login with { BindingHash = RandomNumberGenerator.GetBytes(32) };
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.ExecuteAsync(forged, input, false, f.Backend, default));
        Assert.Equal(0, f.Backend.Calls);
    }
    [Fact] public async Task BackendMustAccreditOriginalLoginNotOnlyMatchingActor()
    {
        var f = await Setup(); f.Backend.WrongOriginalLogin = true;
        Assert.Equal(ChatV2Failure.Session, (await Assert.ThrowsAsync<ChatV2Exception>(async () =>
            await f.Continuity.ContextAsync(f.Login, f.Backend, default))).Failure);
    }
    [Fact] public async Task RevokedLoginIsDeniedBeforeReceipt()
    {
        var f = await Setup(); var input = await Prepared(f); f.Backend.Revoked = true;
        Assert.Equal(ChatV2Failure.Session, (await Assert.ThrowsAsync<ChatV2Exception>(async () =>
            await f.Continuity.ExecuteAsync(f.Login, input, true, f.Backend, default))).Failure); Assert.Equal(0, f.Backend.Calls);
    }
    [Fact] public async Task ReceiptAfterTransferKeepsOpaque404()
    {
        var f = await Setup(); var input = await Prepared(f); await f.Continuity.ExecuteAsync(f.Login, input, false, f.Backend, default);
        f.Backend.Access = false;
        var failure = await Assert.ThrowsAsync<ChatV2Exception>(async () => await f.Continuity.ExecuteAsync(f.Login, input, true, f.Backend, default));
        Assert.Equal(404, ChatV2Errors.Status(failure.Failure));
    }
    [Fact] public async Task DefaultCompositionFailsClosedWithoutSqlOrLegacyFallback()
    {
        var clock = new Clock(); var services = new ServiceCollection(); services.AddSingleton<TimeProvider>(clock); services.AddChatV2Continuity();
        using var provider = services.BuildServiceProvider(); using var scope = provider.CreateScope();
        var backend = scope.ServiceProvider.GetRequiredService<IChatV2IntentPersistence>(); Assert.IsType<UnavailableChatV2IntentPersistence>(backend);
        Assert.Equal(ChatV2Failure.Dependency, (await Assert.ThrowsAsync<ChatV2Exception>(async () =>
            await provider.GetRequiredService<ChatV2Continuity>().ContextAsync(Login(clock), backend, default))).Failure);
    }
    [Fact] public void EveryNewPostUsesAntiforgeryAndWholeControllerDisablesCaching()
    {
        var type = typeof(ChatV2Controller); var posts = type.GetMethods().Where(x => x.GetCustomAttribute<HttpPostAttribute>() is not null).ToArray();
        Assert.Equal(4, posts.Length); foreach (var method in posts) Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        Assert.True(type.GetCustomAttribute<ResponseCacheAttribute>()!.NoStore);
    }
    [Theory] [InlineData(0xD800)] [InlineData(0xDC00)]
    public void IllFormedUnicodeIsRejected(int codeUnit) => Assert.Throws<ChatV2Exception>(() => ChatV2Continuity.ContentHash(new string((char)codeUnit, 1)));
    [Fact] public void EmptyContentIsRejected() => Assert.Throws<ChatV2Exception>(() => ChatV2Continuity.ContentHash(" "));
    [Fact] public void ContentFingerprintIsExactUtf16LittleEndianWithoutNormalization()
    {
        const string body = " exact ñ 😀 "; Assert.Equal(Convert.ToHexString(SHA256.HashData(System.Text.Encoding.Unicode.GetBytes(body))), ChatV2Continuity.ContentHash(body));
        Assert.NotEqual(ChatV2Continuity.ContentHash(body), ChatV2Continuity.ContentHash(body.Trim()));
    }
    [Fact] public async Task DepartmentManagementCannotAuthorizeAttentionQueue()
    {
        var f = await Setup(); var session = new ServerChatV2Session(new(f.Login.UserId, f.Login.ProfileId, null, ChatV2Kind.Internal,
            ChatV2Capabilities.ManageDepartments, f.Login.SecurityStamp, 1, f.Login.LoginId, new(f.Login.ExpiresUtc)), RandomNumberGenerator.GetBytes(32));
        var identities = new Mock<IChatV2IdentityContext>(); identities.Setup(x => x.ResolveCurrentAsync(default)).ReturnsAsync(session);
        var repository = new Mock<IChatV2Repository>(MockBehavior.Strict);
        var service = new ChatV2MessagingService(identities.Object, new ChatV2Authorization(f.Clock), repository.Object,
            Mock.Of<IChatV2CursorProtector>(), new ChatV2SendCoordinator(), f.Clock);
        Assert.Equal(ChatV2Failure.Forbidden, (await Assert.ThrowsAsync<ChatV2Exception>(async () => await service.QueueAsync(default))).Failure);
        Assert.Equal(ChatV2Failure.Forbidden, (await Assert.ThrowsAsync<ChatV2Exception>(async () => await service.TransferAsync(1, 102, 0, default))).Failure);
        repository.VerifyNoOtherCalls();
    }
    [Fact] public void TemporalParametersPreserveUtcTicksAndExplicitScaleWithoutSqlConnection()
    {
        using var command = new Microsoft.Data.SqlClient.SqlCommand();
        var instant = new DateTimeOffset(2030, 1, 1, 12, 0, 0, TimeSpan.FromHours(-6)).AddTicks(1234567);
        var parameter = ChatV2SqlParameters.AddUtc(command.Parameters, "@ExpiresUtc", instant);
        Assert.Equal(System.Data.SqlDbType.DateTime2, parameter.SqlDbType); Assert.Equal((byte)7, parameter.Scale);
        var value = Assert.IsType<DateTime>(parameter.Value); Assert.Equal(DateTimeKind.Utc, value.Kind); Assert.Equal(instant.UtcTicks, value.Ticks);
    }
    [Fact] public async Task AttentionManagerHasNoImplicitBodyAccess()
    {
        var f = await Setup(); f.Backend.Caps = ChatV2Capabilities.ManageAttention;
        var context = await f.Continuity.ContextAsync(f.Login, f.Backend, default); Assert.True(context.Management); Assert.False(context.InternalChat); Assert.False(context.Attention);
        Assert.Equal(ChatV2Failure.Forbidden, (await Assert.ThrowsAsync<ChatV2Exception>(async () => await Prepared(f))).Failure);
    }
}
