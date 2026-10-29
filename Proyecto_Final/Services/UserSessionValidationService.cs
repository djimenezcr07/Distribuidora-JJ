using Microsoft.Data.SqlClient;
using System.Data;
using System.Data.Common;

namespace Proyecto_Final.Services;

public sealed record UserSessionState(bool Active, string Role, string SecurityStamp, int ProfileId = 0, bool ProfileActive = false);

public interface IUserSessionValidationService
{
    Task<UserSessionState?> GetCurrentStateAsync(int userId, CancellationToken cancellationToken = default);
}

public sealed class UserSessionValidationService : IUserSessionValidationService
{
    private readonly string _connectionString;

    public UserSessionValidationService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
    }

    public async Task<UserSessionState?> GetCurrentStateAsync(int userId, CancellationToken cancellationToken = default)
    {
        if (userId <= 0)
            return null;

        await using var connection = new SqlConnection(_connectionString);
        await using var command = CreateStateCommand(connection, userId);
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return ReadState(reader);
    }

    internal static SqlCommand CreateStateCommand(SqlConnection connection, int userId)
    {
        // Canonical FK/state in one read; the historical SP omits profile identity
        // and activity. No authorization revision is inferred from this snapshot.
        var command = new SqlCommand("""
            SELECT u.Activo, p.Nombre AS PerfilNombre, u.SecurityStamp,
                   u.PerfilId, p.Activo AS PerfilActivo
            FROM dbo.Usuarios AS u
            INNER JOIN dbo.Perfiles AS p ON p.PerfilId = u.PerfilId
            WHERE u.UsuarioId = @UsuarioId;
            """, connection);
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        return command;
    }

    internal static UserSessionState ReadState(DbDataReader reader) =>
        new(
            reader.GetBoolean(reader.GetOrdinal("Activo")),
            reader.GetString(reader.GetOrdinal("PerfilNombre")),
            reader.GetGuid(reader.GetOrdinal("SecurityStamp")).ToString("D"),
            reader.GetInt32(reader.GetOrdinal("PerfilId")),
            reader.GetBoolean(reader.GetOrdinal("PerfilActivo")));
}
