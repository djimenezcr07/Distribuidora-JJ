namespace Proyecto_Final.Tests;

public sealed class HashOnlyCredentialTests
{
    [Fact]
    public void ActiveMvcServices_DoNotValidateOrSendPlaintextPasswords()
    {
        var account = File.ReadAllText(SourcePath("Services", "AccountDbService.cs"));
        var admin = File.ReadAllText(SourcePath("Services", "AdminDbService.cs"));
        var employees = File.ReadAllText(SourcePath("Services", "EmployeesDbService.cs"));

        Assert.DoesNotContain("ValidateUserAsync", account, StringComparison.Ordinal);
        Assert.DoesNotContain("RegisterClientAsync", account, StringComparison.Ordinal);
        Assert.DoesNotContain("\"@Contrasena\"", admin, StringComparison.Ordinal);
        Assert.DoesNotContain("\"@Contrasena\"", employees, StringComparison.Ordinal);
        Assert.Contains("\"@ContrasenaHash\"", admin, StringComparison.Ordinal);
        Assert.Contains("\"@ContrasenaHash\"", employees, StringComparison.Ordinal);
    }

    [Fact]
    public void RetirementMigrationBlocksUntilEveryActiveUserHasHash()
    {
        var migration = File.ReadAllText(Path.Combine(RepositoryRoot(), "database", "migrations", "0026_hash_only_credentials.sql"));

        Assert.Contains("Hay usuarios activos sin hash", migration, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetLoginCredential", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("LegacyPasswordMatches", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("@Contrasena NVARCHAR", migration, StringComparison.Ordinal);
    }

    private static string SourcePath(params string[] parts) =>
        Path.Combine(new[] { RepositoryRoot(), "Proyecto_Final" }.Concat(parts).ToArray());

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
            directory = directory.Parent;

        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz del repositorio.");
    }
}
