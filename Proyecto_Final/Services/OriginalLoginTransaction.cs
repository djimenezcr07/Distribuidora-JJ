using System.Data;
using Microsoft.Data.SqlClient;

namespace Proyecto_Final.Services;

internal static class OriginalLoginTransaction
{
    // The context comes from the middleware snapshot, never from a posted DTO.
    internal static async Task<T> ExecuteAsync<T>(SqlConnection connection, SqlCommand command,
        OriginalLoginContext login, int actorId, string? permission, Func<Task<T>> operation,
        CancellationToken cancellationToken = default)
    {
        if (!login.HasCanonicalLifetime || login.UserId != actorId)
            throw new UnauthorizedAccessException("El contexto original no corresponde al actor.");
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        command.Transaction = transaction;
        await RequireAsync();
        var result = await operation();
        // Recheck the absolute deadline after the operation, before committing.
        await RequireAsync();
        await transaction.CommitAsync(cancellationToken);
        return result;

        async Task RequireAsync()
        {
            await using var guard = OriginalLoginService.ContextCommand(connection,
                "dbo.sp_Stage2_RequireOriginalLogin", login);
            guard.Transaction = transaction;
            guard.Parameters.Add("@PermissionCode", SqlDbType.NVarChar, 100).Value =
                permission is null ? DBNull.Value : permission;
            await guard.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}
