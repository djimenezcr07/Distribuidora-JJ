using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class TransactionalLoginTests
{
    private static OriginalLoginContext Login() => new(Guid.NewGuid(), 15, 2, Guid.NewGuid(),
        new DateTime(2026, 10, 14, 0, 0, 0, DateTimeKind.Utc),
        new DateTime(2026, 10, 14, 8, 0, 0, DateTimeKind.Utc), new byte[32]);

    [Fact]
    public void Request_RequiresTheMiddlewareSnapshot()
    {
        var http = new DefaultHttpContext();
        Assert.Throws<UnauthorizedAccessException>(() => OriginalLoginSession.ValidatedRequest(http));
        var login = Login();
        http.Items[OriginalLoginSession.ValidatedContextItem] = login;
        Assert.Same(login, OriginalLoginSession.ValidatedRequest(http));
        http.Items[OriginalLoginSession.ValidatedContextItem] = login with { LoginId = Guid.Empty };
        Assert.Throws<UnauthorizedAccessException>(() => OriginalLoginSession.ValidatedRequest(http));
    }

    [Fact]
    public async Task Transaction_RejectsDifferentActorBeforeOpeningSqlOrRunningBusinessCode()
    {
        using var connection = new SqlConnection();
        using var command = new SqlCommand("irrelevant", connection);
        var invoked = false;
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => OriginalLoginTransaction.ExecuteAsync(
            connection, command, Login(), 16, null, () => { invoked = true; return Task.FromResult(1); }));
        Assert.False(invoked);
        Assert.Equal(System.Data.ConnectionState.Closed, connection.State);
    }

    [Fact]
    public async Task Transaction_RejectsNoncanonicalContextBeforeOpeningSql()
    {
        using var connection = new SqlConnection();
        using var command = new SqlCommand("irrelevant", connection);
        var login = Login();
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => OriginalLoginTransaction.ExecuteAsync(
            connection, command, login with { ExpiresUtc = login.ExpiresUtc.AddTicks(1) }, login.UserId,
            "GARANTIAS_GESTIONAR", () => Task.FromResult(1)));
        Assert.Equal(System.Data.ConnectionState.Closed, connection.State);
    }
}
