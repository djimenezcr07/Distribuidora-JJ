using System.Reflection;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Tests;

public sealed class AuthorizationMatrixAndOwnershipTests
{
    [Fact]
    public void EveryExactControllerCapability_IsDeclaredInVersionedSql()
    {
        var root = FindRepositoryRoot();
        var sql = string.Join('\n', Directory.EnumerateFiles(Path.Combine(root, "database"), "*.sql", SearchOption.AllDirectories)
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}demo{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            .Select(File.ReadAllText));
        var capabilities = typeof(HomeController).Assembly.GetTypes()
            .Where(type => type.IsClass && !type.IsAbstract && typeof(Microsoft.AspNetCore.Mvc.ControllerBase).IsAssignableFrom(type))
            .SelectMany(type => type.GetCustomAttributes<AdminAuthorizeAttribute>(true)
                .Concat(type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                    .SelectMany(method => method.GetCustomAttributes<AdminAuthorizeAttribute>(true))))
            .Select(attribute => attribute.Arguments is { Length: > 1 } ? attribute.Arguments[1]?.ToString() : null)
            .Where(code => !string.IsNullOrWhiteSpace(code))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        Assert.NotEmpty(capabilities);
        Assert.All(capabilities, code => Assert.Contains(code!, sql, StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ClientOwnedResources_CompareOrPassTheSessionUserId()
    {
        var source = File.ReadAllText(SourcePath("Controllers", "ClientPortalController.cs"));

        Assert.Contains("pedido.UsuarioId != usuarioId", source, StringComparison.Ordinal);
        Assert.Contains("GetClientInvoiceByOrderAsync(id, usuarioId)", source, StringComparison.Ordinal);
        Assert.Contains("CancelClientPendingOrderAsync(id, usuarioId)", source, StringComparison.Ordinal);
        Assert.Contains("detalle.UsuarioId != usuarioId", source, StringComparison.Ordinal);
        Assert.Contains("GetClientWarrantyRequestsAsync(usuarioId)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void DriverAndPrivateFileSql_EnforceActorOwnership()
    {
        var logistics = File.ReadAllText(SourcePath("Services", "LogisticsDbService.cs"));
        var evidence = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "database", "migrations", "0004_private_delivery_evidence.sql"));
        var warranties = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "database", "migrations", "0006_warranty_workflow.sql"));

        Assert.Contains("@ChoferUsuarioId", logistics, StringComparison.Ordinal);
        Assert.Contains("r.ChoferUsuarioId = @RegistradoPorUsuarioId", evidence, StringComparison.Ordinal);
        Assert.Contains("pedido.UsuarioId = @UsuarioId", evidence, StringComparison.Ordinal);
        Assert.Contains("pedido.UsuarioId = @UsuarioId", warranties, StringComparison.Ordinal);
    }

    private static string SourcePath(params string[] parts) =>
        Path.Combine(new[] { FindRepositoryRoot(), "Proyecto_Final" }.Concat(parts).ToArray());

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException();
    }
}
