using System.Security.Cryptography;
using Microsoft.Extensions.Configuration;
using Proyecto_Final.Services;
using Xunit;

public sealed class EvidenceIntegrityTests
{
    [Fact]
    public async Task VerifiedStreamIsRewoundForTheAuthorizedResponse()
    {
        var bytes = new byte[] { 0x89, 0x50, 0x4e, 0x47, 1, 2, 3 };
        await using var stream = new MemoryStream(bytes);
        stream.Position = 4;
        Assert.True(await EvidenceIntegrity.VerifyAsync(stream, Convert.ToHexString(SHA256.HashData(bytes)), bytes.Length));
        Assert.Equal(0, stream.Position);
    }

    [Fact]
    public async Task TamperedContentWrongSizeAndMalformedHashAreDenied()
    {
        var bytes = new byte[] { 1, 2, 3, 4 };
        await using var stream = new MemoryStream(bytes);
        Assert.False(await EvidenceIntegrity.VerifyAsync(stream, Convert.ToHexString(SHA256.HashData(new byte[] { 4, 3, 2, 1 })), bytes.Length));
        Assert.False(await EvidenceIntegrity.VerifyAsync(stream, Convert.ToHexString(SHA256.HashData(bytes)), bytes.Length + 1));
        Assert.False(await EvidenceIntegrity.VerifyAsync(stream, new string('Z', 64), bytes.Length));
    }

    [Fact]
    public async Task SettlementFailsBeforeAnyConnectionCanOpen()
    {
        var config = new Microsoft.Extensions.Configuration.ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string,string?> { ["ConnectionStrings:DefaultConnection"] = "invalid" }).Build();
        await Assert.ThrowsAsync<LogisticsSettlementUnavailableException>(() => new LogisticsDbService(config).LiquidateRouteAsync(1, 1, "ignored"));
    }
}
