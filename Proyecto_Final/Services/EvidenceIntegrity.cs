using System.Security.Cryptography;

namespace Proyecto_Final.Services;

public static class EvidenceIntegrity
{
    public static async Task<bool> VerifyAsync(Stream stream, string sha256, long length, CancellationToken cancellationToken = default)
    {
        if (!stream.CanSeek || length <= 0 || stream.Length != length || sha256.Length != 64)
            return false;
        byte[] expected;
        try { expected = Convert.FromHexString(sha256); }
        catch (FormatException) { return false; }
        stream.Position = 0;
        var actual = await SHA256.HashDataAsync(stream, cancellationToken);
        stream.Position = 0;
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}
