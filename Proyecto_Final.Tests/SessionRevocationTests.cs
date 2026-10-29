using Proyecto_Final.Middleware;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class SessionRevocationTests
{
    [Fact]
    public void CurrentSession_RequiresActiveUserSameRoleAndSameStamp()
    {
        var current = new UserSessionState(true, "Supervisor", "stamp-1", 7, true);

        Assert.True(SessionValidationMiddleware.IsCurrent(current, "supervisor", "STAMP-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(current with { ProfileActive = false }, "Supervisor", "stamp-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(current, "Supervisor", "stamp-1", 8));
        Assert.False(SessionValidationMiddleware.IsCurrent(current, "Supervisor", "stamp-1"));
        Assert.False(SessionValidationMiddleware.IsCurrent(current with { Active = false }, "Supervisor", "stamp-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(current with { Role = "Gerente" }, "Supervisor", "stamp-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(current with { SecurityStamp = "stamp-2" }, "Supervisor", "stamp-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(null, "Supervisor", "stamp-1", 7));
        Assert.False(SessionValidationMiddleware.IsCurrent(current, "Supervisor", null, 7));
    }

    [Fact]
    public void MigrationRevokesOnStatusRoleAndCredentialChanges()
    {
        var migration = File.ReadAllText(Path.Combine(RepositoryRoot(), "database", "migrations", "0025_session_revocation.sql"));

        Assert.Contains("nuevo.Activo <> anterior.Activo", migration, StringComparison.Ordinal);
        Assert.Contains("nuevo.PerfilId <> anterior.PerfilId", migration, StringComparison.Ordinal);
        Assert.Contains("nuevo.ContrasenaHash", migration, StringComparison.Ordinal);
        Assert.Contains("nuevo.PasswordVersion", migration, StringComparison.Ordinal);
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
            directory = directory.Parent;

        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz del repositorio.");
    }
}
