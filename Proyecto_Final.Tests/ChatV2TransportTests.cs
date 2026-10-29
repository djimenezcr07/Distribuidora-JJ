using Moq;
using Proyecto_Final.Services.ChatV2;
using Xunit;

namespace Proyecto_Final.Tests;

public sealed class ChatV2TransportTests
{
    private sealed class Clock : TimeProvider
    { public DateTimeOffset Now = DateTimeOffset.UtcNow; public override DateTimeOffset GetUtcNow() => Now; }
    private static ChatV2ConnectionContext Context(Guid session, DateTimeOffset expires)
        => new(session, 42, 1, null, 0, expires);
    private static ChatV2SecurityEvent Change() => new(Guid.NewGuid(), ChatV2SecurityEventKind.User, 42, null, null, null, 2);

    [Fact]
    public async Task RevocationAbortsBothSocketsButKeepsAnotherSession()
    {
        var clock = new Clock(); var first = Guid.NewGuid(); var second = Guid.NewGuid(); var aborts = new List<string>();
        var validator = new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x => x.ValidateAsync(It.IsAny<Guid>(), It.IsAny<ChatV2Resource?>(), It.IsAny<CancellationToken>()))
            .Returns((Guid id, ChatV2Resource? resource, CancellationToken _) => ValueTask.FromResult(Context(id, clock.Now.AddMinutes(5)) with { Resource = resource }));
        var registry = new ChatV2ConnectionRegistry(validator.Object, clock, Mock.Of<IChatV2GenericNotifications>());
        await registry.RegisterAsync("a", first, () => aborts.Add("a"), default);
        await registry.RegisterAsync("b", first, () => aborts.Add("b"), default);
        await registry.RegisterAsync("c", second, () => aborts.Add("c"), default);
        await registry.RevokeSessionConnectionsAsync(first, default);
        await registry.RevokeSessionConnectionsAsync(first, default);
        Assert.Equal(new[] { "a", "b" }, aborts.Order());
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await registry.RevalidateConnectionAsync("a", default));
        await registry.RevalidateConnectionAsync("c", default);
    }
    [Fact]
    public async Task LateValidationCannotReviveRevokedGeneration()
    {
        var clock = new Clock(); var session = Guid.NewGuid(); var ready = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously); var calls = 0; var aborted = false;
        var validator = new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x => x.ValidateAsync(session, It.IsAny<ChatV2Resource?>(), It.IsAny<CancellationToken>()))
            .Returns(async (Guid id, ChatV2Resource? resource, CancellationToken _) =>
            { if (Interlocked.Increment(ref calls) == 2) { ready.SetResult(); await release.Task; } return Context(id, clock.Now.AddMinutes(5)) with { Resource = resource }; });
        var notifications = new Mock<IChatV2GenericNotifications>();
        var registry = new ChatV2ConnectionRegistry(validator.Object, clock, notifications.Object);
        await registry.RegisterAsync("a", session, () => aborted = true, default);
        var pending = registry.SubscribeAsync("a", new(ChatV2Domain.Private, 3), default).AsTask();
        await ready.Task.WaitAsync(TimeSpan.FromSeconds(2));
        await registry.RevokeSessionConnectionsAsync(session, default); release.SetResult();
        await Assert.ThrowsAsync<ChatV2Exception>(() => pending); Assert.True(aborted);
        Assert.Empty(await registry.RefreshAffectedAsync(Change(), default));
        notifications.Verify(x => x.InvalidateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }
    [Theory]
    [InlineData(ChatV2Failure.Session)] [InlineData(ChatV2Failure.Forbidden)]
    [InlineData(ChatV2Failure.Resource)] [InlineData(ChatV2Failure.Dependency)]
    public async Task SensitiveRevalidationFailsClosed(ChatV2Failure failure)
    {
        var clock = new Clock(); var session = Guid.NewGuid(); var aborted = false;
        var validator = new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x => x.ValidateAsync(session, null, It.IsAny<CancellationToken>())).ReturnsAsync(Context(session, clock.Now.AddMinutes(5)));
        var registry = new ChatV2ConnectionRegistry(validator.Object, clock, Mock.Of<IChatV2GenericNotifications>());
        await registry.RegisterAsync("a", session, () => aborted = true, default);
        validator.Setup(x => x.ValidateAsync(session, null, It.IsAny<CancellationToken>())).ThrowsAsync(new ChatV2Exception(failure));
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await registry.RevalidateConnectionAsync("a", default)); Assert.True(aborted);
    }
    [Fact]
    public async Task LeaseCannotOutliveSessionOrAllowExpiredNotice()
    {
        var clock = new Clock(); var session = Guid.NewGuid(); var resource = new ChatV2Resource(ChatV2Domain.Private, 1);
        var validator = new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x => x.ValidateAsync(session, It.IsAny<ChatV2Resource?>(), It.IsAny<CancellationToken>()))
            .Returns((Guid id, ChatV2Resource? selected, CancellationToken _) => ValueTask.FromResult(Context(id, clock.Now.AddSeconds(2)) with { Resource = selected }));
        var notices = new Mock<IChatV2GenericNotifications>(); var registry = new ChatV2ConnectionRegistry(validator.Object, clock, notices.Object);
        await registry.RegisterAsync("a", session, () => { }, default); await registry.SubscribeAsync("a", resource, default);
        var snapshot = Assert.Single(await registry.RefreshAffectedAsync(Change(), default));
        Assert.Equal(clock.Now.AddSeconds(2), snapshot.LeaseUntilUtc);
        clock.Now += TimeSpan.FromSeconds(3); await registry.NotifyAsync(snapshot, clock.Now.AddSeconds(10), default);
        notices.Verify(x => x.InvalidateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }
    [Fact]
    public async Task DisconnectDropsObsoleteSubscription()
    {
        var clock = new Clock(); var session = Guid.NewGuid(); var validator = new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x => x.ValidateAsync(session, null, It.IsAny<CancellationToken>())).ReturnsAsync(Context(session, clock.Now.AddMinutes(5)));
        var registry = new ChatV2ConnectionRegistry(validator.Object, clock, Mock.Of<IChatV2GenericNotifications>());
        await registry.RegisterAsync("a", session, () => { }, default); registry.Disconnect("a");
        Assert.Empty(await registry.RefreshAffectedAsync(Change(), default));
        await Assert.ThrowsAsync<ChatV2Exception>(async () => await registry.RevalidateConnectionAsync("a", default));
    }
    [Fact]
    public async Task ExpiredClaimDoesNotEmitOrAcknowledge()
    {
        var clock = new Clock(); var claim = new ChatV2SecurityClaim(Change(), Guid.NewGuid(), Guid.NewGuid(), clock.Now.AddSeconds(-1), 1);
        var outbox = new Mock<IChatV2SecurityOutbox>(); var bridge = new Mock<IChatV2RevocationBridge>();
        outbox.Setup(x => x.ClaimAsync(claim.WorkerId, 30, null, It.IsAny<CancellationToken>())).ReturnsAsync(claim);
        bridge.Setup(x => x.RefreshAffectedAsync(claim.Event, It.IsAny<CancellationToken>())).ReturnsAsync(new[] {
            new ChatV2ConnectionSnapshot("a", 1, Context(Guid.NewGuid(), clock.Now.AddMinutes(5)) with { Resource = new(ChatV2Domain.Private, 1) }, clock.Now.AddSeconds(10)) });
        var worker = new ChatV2SecurityOutboxDispatcher(outbox.Object, bridge.Object, clock);
        Assert.Equal(ChatV2DispatchOutcome.Retry, await worker.DispatchOneAsync(claim.WorkerId, null, default));
        outbox.Verify(x => x.AckAsync(It.IsAny<ChatV2SecurityClaim>(), It.IsAny<CancellationToken>()), Times.Never);
        bridge.Verify(x => x.NotifyAsync(It.IsAny<ChatV2ConnectionSnapshot>(), It.IsAny<DateTimeOffset>(), It.IsAny<CancellationToken>()), Times.Never);
    }
    [Fact]
    public async Task InvalidExpiredServerValidationAbortsInsteadOfRenewingLease()
    {
        var clock=new Clock();var session=Guid.NewGuid();bool aborted=false;
        var validator=new Mock<IChatV2ConnectionValidator>();
        validator.Setup(x=>x.ValidateAsync(session,null,It.IsAny<CancellationToken>())).ReturnsAsync(Context(session,clock.Now.AddSeconds(-1)));
        var registry=new ChatV2ConnectionRegistry(validator.Object,clock,Mock.Of<IChatV2GenericNotifications>());
        await Assert.ThrowsAsync<ChatV2Exception>(async()=>await registry.RegisterAsync("a",session,()=>aborted=true,default));
        Assert.True(aborted);Assert.Empty(await registry.RefreshAffectedAsync(Change(),default));
    }
    [Fact]
    public async Task FailedBridgeLeavesDurableClaimForRetry()
    {
        var clock = new Clock(); var claim = new ChatV2SecurityClaim(Change(), Guid.NewGuid(), Guid.NewGuid(), clock.Now.AddSeconds(10), 1);
        var outbox = new Mock<IChatV2SecurityOutbox>(); var bridge = new Mock<IChatV2RevocationBridge>();
        outbox.Setup(x => x.ClaimAsync(claim.WorkerId, 30, null, It.IsAny<CancellationToken>())).ReturnsAsync(claim);
        bridge.Setup(x => x.RefreshAffectedAsync(claim.Event, It.IsAny<CancellationToken>())).ThrowsAsync(new ChatV2Exception(ChatV2Failure.Dependency));
        Assert.Equal(ChatV2DispatchOutcome.Retry, await new ChatV2SecurityOutboxDispatcher(outbox.Object, bridge.Object, clock).DispatchOneAsync(claim.WorkerId, null, default));
        outbox.Verify(x => x.AckAsync(It.IsAny<ChatV2SecurityClaim>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}
