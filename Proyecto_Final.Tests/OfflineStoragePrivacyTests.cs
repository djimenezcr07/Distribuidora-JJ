namespace Proyecto_Final.Tests;

public sealed class OfflineStoragePrivacyTests
{
    [Theory]
    [InlineData("_StorefrontLayout.cshtml")]
    [InlineData("_WorkspaceLayout.cshtml")]
    [InlineData("_FieldLayout.cshtml")]
    public void Stage2Layouts_ProvideIdentityAndStorageBeforePageScripts(string file)
    {
        var layout = File.ReadAllText(SourcePath("Views", "Shared", file));
        Assert.Contains("data-authenticated-user-id", layout, StringComparison.Ordinal);
        var storageIndex = layout.IndexOf("secure-offline-storage.js", StringComparison.Ordinal);
        var pageIndex = layout.IndexOf("RenderSectionAsync(\"Scripts\"", StringComparison.Ordinal);
        Assert.True(storageIndex >= 0 && storageIndex < pageIndex);
    }

    [Fact]
    public void OfflineStorage_IsUserScopedExpiringAndClearedOnLogout()
    {
        var helper = File.ReadAllText(SourcePath("wwwroot", "js", "secure-offline-storage.js"));
        var layout = File.ReadAllText(SourcePath("Views", "Shared", "_Layout.cshtml"));

        Assert.Contains("ownerUserId", helper, StringComparison.Ordinal);
        Assert.Contains("expiresAt", helper, StringComparison.Ordinal);
        Assert.Contains("clearCurrentUser", helper, StringComparison.Ordinal);
        Assert.Contains("data-clear-private-storage", layout, StringComparison.Ordinal);
        Assert.Contains("secure-offline-storage.js", layout, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("Views", "SellerOrders", "Index.cshtml")]
    [InlineData("wwwroot", "js", "driver-route-map.js")]
    [InlineData("wwwroot", "js", "driver-deliveries.js")]
    public void PrivateOfflineFeatures_UseSharedStorageInsteadOfRawLocalStorage(params string[] parts)
    {
        var source = File.ReadAllText(SourcePath(parts));

        Assert.Contains("DistribuidoraJJOfflineStorage", source, StringComparison.Ordinal);
        Assert.DoesNotContain("localStorage.getItem", source, StringComparison.Ordinal);
        Assert.DoesNotContain("localStorage.setItem", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SellerOfflineOrder_DoesNotPersistDisplayNamesOrCatalog()
    {
        var source = File.ReadAllText(SourcePath("Views", "SellerOrders", "Index.cshtml"));

        Assert.DoesNotContain("clienteNombre:", source, StringComparison.Ordinal);
        Assert.DoesNotContain("cacheCatalog", source, StringComparison.Ordinal);
        Assert.DoesNotContain("catalogKey", source, StringComparison.Ordinal);
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
