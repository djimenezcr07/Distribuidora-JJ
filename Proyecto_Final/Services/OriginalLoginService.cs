using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services;

public sealed record OriginalLoginContext(Guid LoginId, int UserId, int ProfileId, Guid SecurityStamp,
    DateTime IssuedUtc, DateTime ExpiresUtc, ReadOnlyMemory<byte> BindingHash)
{
    public bool HasCanonicalLifetime => LoginId != Guid.Empty && UserId > 0 && ProfileId > 0
        && SecurityStamp != Guid.Empty && BindingHash.Length == 32
        && IssuedUtc.Kind == DateTimeKind.Utc && ExpiresUtc.Kind == DateTimeKind.Utc
        && ExpiresUtc - IssuedUtc == TimeSpan.FromHours(8);
}

public interface IOriginalLoginService
{
    Task<OriginalLoginContext> CreateAsync(int userId, int profileId, Guid stamp, byte[] bindingHash, CancellationToken cancellationToken = default);
    Task<UserSessionState?> ValidateAsync(OriginalLoginContext login, CancellationToken cancellationToken = default);
    Task RevokeAsync(OriginalLoginContext login, CancellationToken cancellationToken = default);
}

public sealed class OriginalLoginService(IConfiguration configuration) : IOriginalLoginService
{
    private readonly string _connectionString = configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("Falta DefaultConnection.");

    // This method is called only by MVC after the credential API has authenticated
    // the account. SQL independently locks and rechecks that exact profile/stamp.
    public async Task<OriginalLoginContext> CreateAsync(int userId, int profileId, Guid stamp, byte[] bindingHash, CancellationToken cancellationToken = default)
    {
        if (userId <= 0 || profileId <= 0 || stamp == Guid.Empty || bindingHash.Length != 32)
            throw new InvalidOperationException("Contexto de login no válido.");
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_Stage2_CreateOriginalLogin", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = profileId;
        command.Parameters.Add("@SecurityStamp", SqlDbType.UniqueIdentifier).Value = stamp;
        command.Parameters.Add("@BindingHash", SqlDbType.Binary, 32).Value = bindingHash;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("No se acreditó el login original.");
        var login = new OriginalLoginContext(reader.GetGuid(0), userId, profileId, stamp,
            DateTime.SpecifyKind(reader.GetDateTime(1), DateTimeKind.Utc),
            DateTime.SpecifyKind(reader.GetDateTime(2), DateTimeKind.Utc), bindingHash.ToArray());
        if (!login.HasCanonicalLifetime) throw new InvalidOperationException("Vigencia de login no válida.");
        return login;
    }

    public async Task<UserSessionState?> ValidateAsync(OriginalLoginContext login, CancellationToken cancellationToken = default)
    {
        if (!login.HasCanonicalLifetime) return null;
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ContextCommand(connection, "dbo.sp_Stage2_ValidateOriginalLogin", login);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? UserSessionValidationService.ReadState(reader) : null;
    }

    public async Task RevokeAsync(OriginalLoginContext login, CancellationToken cancellationToken = default)
    {
        if (!login.HasCanonicalLifetime) return;
        await using var connection = new SqlConnection(_connectionString);
        await using var command = ContextCommand(connection, "dbo.sp_Stage2_RevokeOriginalLogin", login);
        await connection.OpenAsync(cancellationToken);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal static SqlCommand ContextCommand(SqlConnection connection, string procedure, OriginalLoginContext login)
    {
        var command = new SqlCommand(procedure, connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.Add("@LoginId", SqlDbType.UniqueIdentifier).Value = login.LoginId;
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = login.UserId;
        command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = login.ProfileId;
        command.Parameters.Add("@SecurityStamp", SqlDbType.UniqueIdentifier).Value = login.SecurityStamp;
        command.Parameters.Add("@BindingHash", SqlDbType.Binary, 32).Value = login.BindingHash.ToArray();
        command.Parameters.Add(new SqlParameter("@IssuedUtc", SqlDbType.DateTime2) { Scale = 7, Value = login.IssuedUtc });
        command.Parameters.Add(new SqlParameter("@ExpiresUtc", SqlDbType.DateTime2) { Scale = 7, Value = login.ExpiresUtc });
        return command;
    }
}

public static class OriginalLoginSession
{
    public const string ValidatedContextItem = "Stage2.ValidatedOriginalLogin";

    public static OriginalLoginContext ValidatedRequest(HttpContext context) =>
        context.Items[ValidatedContextItem] is OriginalLoginContext login && login.HasCanonicalLifetime
            ? login : throw new UnauthorizedAccessException("Falta el contexto original validado del request.");

    public static string NewNonce() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    public static byte[] Binding(string sessionId, string nonce) =>
        SHA256.HashData(Encoding.UTF8.GetBytes("Stage2:OriginalLogin:v1|" + sessionId + "|" + nonce));

    public static void Store(ISession session, OriginalLoginContext login, string nonce)
    {
        if (!login.HasCanonicalLifetime || !CryptographicOperations.FixedTimeEquals(Binding(session.Id, nonce), login.BindingHash.Span))
            throw new InvalidOperationException("El login no corresponde a la sesión.");
        session.SetString("OriginalLoginId", login.LoginId.ToString("D"));
        session.SetString("OriginalLoginNonce", nonce);
        session.SetString("OriginalLoginIssuedUtc", login.IssuedUtc.ToString("O", CultureInfo.InvariantCulture));
        session.SetString("OriginalLoginExpiresUtc", login.ExpiresUtc.ToString("O", CultureInfo.InvariantCulture));
    }

    public static OriginalLoginContext? Read(ISession session)
    {
        var nonce = session.GetString("OriginalLoginNonce");
        if (nonce is null || nonce.Length != 44) return null;
        try { if (Convert.FromBase64String(nonce).Length != 32) return null; }
        catch (FormatException) { return null; }
        if (!Guid.TryParse(session.GetString("OriginalLoginId"), out var id)
            || !Guid.TryParse(session.GetString("SecurityStamp"), out var stamp)
            || !DateTime.TryParseExact(session.GetString("OriginalLoginIssuedUtc"), "O", CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var issued)
            || !DateTime.TryParseExact(session.GetString("OriginalLoginExpiresUtc"), "O", CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var expires)) return null;
        var login = new OriginalLoginContext(id, session.GetInt32("UserId") ?? 0, session.GetInt32("ProfileId") ?? 0,
            stamp, issued, expires, Binding(session.Id, nonce));
        return login.HasCanonicalLifetime ? login : null;
    }
}
