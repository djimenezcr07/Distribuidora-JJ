using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Moq;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class Stage11ClosureTests
{
    [Fact]
    public async Task EmployeeWithoutChatPermission_IsDeniedByControllerPolicy()
    {
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.HasCodePermissionAsync("Empleado", "CHAT_USAR")).ReturnsAsync(false);
        var context = CreateContext("Empleado");

        await new AdminAuthorizeFilter("Chat", "CHAT_USAR", permissions.Object).OnAuthorizationAsync(context);

        var denied = Assert.IsType<ViewResult>(context.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, denied.StatusCode);
    }

    [Theory]
    [InlineData("Empleado")]
    [InlineData("Rol Personalizado")]
    public async Task AnyRoleWithChatPermission_IsAllowed(string role)
    {
        var permissions = new Mock<IRolePermissionService>();
        permissions.Setup(service => service.HasCodePermissionAsync(role, "CHAT_USAR")).ReturnsAsync(true);
        var context = CreateContext(role);

        await new AdminAuthorizeFilter("Chat", "CHAT_USAR", permissions.Object).OnAuthorizationAsync(context);

        Assert.Null(context.Result);
    }

    [Fact]
    public async Task Administrator_KeepsChatSuperuserBypass()
    {
        var permissions = new Mock<IRolePermissionService>(MockBehavior.Strict);
        var context = CreateContext("Administrador");

        await new AdminAuthorizeFilter("Chat", "CHAT_USAR", permissions.Object).OnAuthorizationAsync(context);

        Assert.Null(context.Result);
    }

    [Fact]
    public void MileageClose_IsAtomicConditionalAndOwned()
    {
        var migration = File.ReadAllText(RepositoryPath("database", "migrations", "0024_stage1_ownership_security.sql"));
        var procedure = migration.IndexOf("CREATE OR ALTER PROCEDURE", StringComparison.Ordinal);
        var transaction = migration.IndexOf("BEGIN TRANSACTION", procedure, StringComparison.Ordinal);
        var protectedRead = migration.IndexOf("WITH (UPDLOCK, HOLDLOCK)", procedure, StringComparison.Ordinal);

        Assert.True(transaction >= 0 && transaction < protectedRead);
        Assert.Contains("AND KmFinal IS NULL", migration, StringComparison.Ordinal);
        Assert.Contains("ChoferUsuarioId = @ActorUsuarioId", migration, StringComparison.Ordinal);
        Assert.Contains("IF @@ROWCOUNT <> 1", migration, StringComparison.Ordinal);
        Assert.Contains("THROW 53044", migration, StringComparison.Ordinal);
    }

    [Fact]
    public void ActiveCode_HasNoObsoleteSystemBrands()
    {
        var obsoleteBrands = new[]
        {
            string.Concat("Supermercado", " Mayoreo"),
            string.Concat("Licorera", " La Bodega")
        };
        var roots = new[] { RepositoryPath("Proyecto_Final"), RepositoryPath("Proyecto_FinalAPI") };
        var activeFiles = roots.SelectMany(root => Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}wwwroot{Path.DirectorySeparatorChar}lib{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            .Where(path => new[] { ".cs", ".cshtml", ".js", ".css", ".json", ".html" }.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase));

        Assert.All(activeFiles, path => Assert.All(obsoleteBrands,
            brand => Assert.DoesNotContain(brand, File.ReadAllText(path), StringComparison.OrdinalIgnoreCase)));
    }

    private static AuthorizationFilterContext CreateContext(string role)
    {
        var http = new DefaultHttpContext { Session = new TestSession() };
        http.Session.SetInt32("UserId", 42);
        http.Session.SetString("UserEmail", "stage11@example.test");
        http.Session.SetString("UserRole", role);
        return new AuthorizationFilterContext(
            new ActionContext(http, new RouteData(), new ActionDescriptor()),
            []);
    }

    private static string RepositoryPath(params string[] parts)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return Path.Combine(new[] { directory?.FullName ?? throw new DirectoryNotFoundException() }.Concat(parts).ToArray());
    }

    private sealed class TestSession : ISession
    {
        private readonly Dictionary<string, byte[]> _values = new(StringComparer.Ordinal);
        public string Id => "stage11";
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
