using System.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Middleware;
using Proyecto_Final.Controllers;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class OriginalLoginTests
{
    [Fact]
    public void StoredLogin_RoundTripsUtcTicksAndDoesNotSlide()
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        var first = OriginalLoginSession.Read(session)!;
        var second = OriginalLoginSession.Read(session)!;
        Assert.Equal(login.IssuedUtc.Ticks, first.IssuedUtc.Ticks);
        Assert.Equal(login.ExpiresUtc.Ticks, second.ExpiresUtc.Ticks);
        Assert.Equal(TimeSpan.FromHours(8), first.ExpiresUtc - first.IssuedUtc);
        Assert.Equal(DateTimeKind.Utc, first.ExpiresUtc.Kind);
        Assert.Equal(login.BindingHash.ToArray(), second.BindingHash.ToArray());
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(1)]
    public void Lifetime_CannotBeShortenedOrExtendedEvenOneTick(long difference)
    {
        var (session, login, nonce) = Context();
        Assert.Throws<InvalidOperationException>(() => OriginalLoginSession.Store(session,
            login with { ExpiresUtc = login.ExpiresUtc.AddTicks(difference) }, nonce));
    }

    [Fact]
    public void Lifetime_RequiresUtcAndDoesNotInventLegacyIdentity()
    {
        var (session, login, nonce) = Context();
        Assert.Null(OriginalLoginSession.Read(session));
        Assert.Throws<InvalidOperationException>(() => OriginalLoginSession.Store(session,
            login with { IssuedUtc = DateTime.SpecifyKind(login.IssuedUtc, DateTimeKind.Unspecified) }, nonce));
    }

    [Fact]
    public void Binding_ChangesWithCookieSessionOrNonce()
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        session.Id = "different-cookie-session";
        var changed = OriginalLoginSession.Read(session)!;
        Assert.Equal(login.LoginId, changed.LoginId);
        Assert.NotEqual(login.BindingHash.ToArray(), changed.BindingHash.ToArray());
        Assert.Throws<InvalidOperationException>(() => OriginalLoginSession.Store(session, login, nonce));
        Assert.NotEqual(OriginalLoginSession.Binding(session.Id, nonce),
            OriginalLoginSession.Binding(session.Id, OriginalLoginSession.NewNonce()));
    }

    [Fact]
    public void Logout_ClearDoesNotRestoreAnOriginalLogin()
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        session.Clear();
        Assert.Null(OriginalLoginSession.Read(session));
    }

    [Fact]
    public void SqlContext_UsesExplicitDateTime2Scale7AndBinaryBinding()
    {
        var (_, login, _) = Context();
        using var connection = new SqlConnection();
        using var command = OriginalLoginService.ContextCommand(connection, "dbo.sp_Stage2_ValidateOriginalLogin", login);
        foreach (var name in new[] { "@IssuedUtc", "@ExpiresUtc" })
        {
            Assert.Equal(SqlDbType.DateTime2, command.Parameters[name].SqlDbType);
            Assert.Equal(7, command.Parameters[name].Scale);
        }
        Assert.Equal(SqlDbType.Binary, command.Parameters["@BindingHash"].SqlDbType);
        Assert.Equal(32, command.Parameters["@BindingHash"].Size);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Middleware_AuthorityDenialOrUnavailableClearsSession(bool unavailable)
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        var http = new DefaultHttpContext { Session = session };
        http.Request.Path = "/ClientPortal";
        http.Request.Headers.Accept = "application/json";
        var authority = new Mock<IOriginalLoginService>();
        if (unavailable) authority.Setup(x => x.ValidateAsync(It.IsAny<OriginalLoginContext>(), It.IsAny<CancellationToken>())).ThrowsAsync(new InvalidOperationException("Unavailable"));
        else authority.Setup(x => x.ValidateAsync(It.IsAny<OriginalLoginContext>(), It.IsAny<CancellationToken>())).ReturnsAsync((UserSessionState?)null);
        var reached = false;
        await new SessionValidationMiddleware(_ => { reached = true; return Task.CompletedTask; }, NullLogger<SessionValidationMiddleware>.Instance)
            .InvokeAsync(http, authority.Object);
        Assert.False(reached);
        Assert.Equal(401, http.Response.StatusCode);
        Assert.Empty(session.Keys);
    }

    [Fact]
    public async Task Middleware_LegacySessionCannotAdoptARecordOrBypassAuthority()
    {
        var (session, _, _) = Context();
        var http = new DefaultHttpContext { Session = session };
        http.Request.Path = "/ClientPortal";
        var authority = new Mock<IOriginalLoginService>(MockBehavior.Strict);
        await new SessionValidationMiddleware(_ => throw new Exception("Should not reach endpoint"), NullLogger<SessionValidationMiddleware>.Instance)
            .InvokeAsync(http, authority.Object);
        Assert.Equal(302, http.Response.StatusCode);
        Assert.Empty(session.Keys);
        authority.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Middleware_ValidatedSnapshotPreservesOriginalExpiry()
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        var http = new DefaultHttpContext { Session = session };
        var authority = new Mock<IOriginalLoginService>();
        authority.Setup(x => x.ValidateAsync(It.IsAny<OriginalLoginContext>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new UserSessionState(true, "Cliente", login.SecurityStamp.ToString("D"), login.ProfileId, true));
        var reached = false;
        await new SessionValidationMiddleware(_ => { reached = true; return Task.CompletedTask; }, NullLogger<SessionValidationMiddleware>.Instance)
            .InvokeAsync(http, authority.Object);
        Assert.True(reached);
        Assert.Equal(login.ExpiresUtc, Assert.IsType<OriginalLoginContext>(http.Items[OriginalLoginSession.ValidatedContextItem]).ExpiresUtc);
        Assert.Equal(login.ExpiresUtc, OriginalLoginSession.Read(session)!.ExpiresUtc);
        authority.Verify(x => x.ValidateAsync(It.IsAny<OriginalLoginContext>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Logout_WhenRevocationIsUnavailableStillClearsLocalSessionAndDoesNotClaimSuccess()
    {
        var (session, login, nonce) = Context();
        OriginalLoginSession.Store(session, login, nonce);
        var authority = new Mock<IOriginalLoginService>();
        authority.Setup(x => x.RevokeAsync(It.IsAny<OriginalLoginContext>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("internal-detail-not-for-browser"));
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["ConnectionStrings:DefaultConnection"] = string.Empty }).Build();
        using var httpClient = new HttpClient();
        var controller = new AccountController(new AccountApiService(httpClient),
            new AdminDbService(configuration, new PasswordHashService()), new Mock<IWorkspaceResolver>().Object,
            NullLogger<AccountController>.Instance, authority.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { Session = session } }
        };
        var result = Assert.IsType<ObjectResult>(await controller.Logout());
        Assert.Equal(503, result.StatusCode);
        Assert.DoesNotContain("internal-detail", Assert.IsType<string>(result.Value));
        Assert.Empty(session.Keys);
    }

    private static (MemorySession Session, OriginalLoginContext Login, string Nonce) Context()
    {
        var session = new MemorySession();
        var stamp = Guid.NewGuid();
        session.SetInt32("UserId", 21); session.SetInt32("ProfileId", 2);
        session.SetString("SecurityStamp", stamp.ToString("D")); session.SetString("UserRole", "Cliente");
        var nonce = OriginalLoginSession.NewNonce();
        var issued = new DateTime(2026, 10, 14, 12, 0, 0, DateTimeKind.Utc).AddTicks(1234567);
        return (session, new OriginalLoginContext(Guid.NewGuid(), 21, 2, stamp, issued, issued.AddHours(8),
            OriginalLoginSession.Binding(session.Id, nonce)), nonce);
    }

    private sealed class MemorySession : ISession
    {
        private readonly Dictionary<string, byte[]> _values = new();
        public string Id { get; set; } = "original-cookie-session";
        public bool IsAvailable => true;
        public IEnumerable<string> Keys => _values.Keys;
        public void Clear() => _values.Clear();
        public Task CommitAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task LoadAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public void Remove(string key) => _values.Remove(key);
        public void Set(string key, byte[] value) => _values[key] = value;
        public bool TryGetValue(string key, out byte[] value) => _values.TryGetValue(key, out value!);
    }
}
