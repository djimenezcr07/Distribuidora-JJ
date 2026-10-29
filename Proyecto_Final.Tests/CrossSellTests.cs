using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Tests;

public sealed class CrossSellTests
{
    [Fact]
    public void Select_PrefersSupportedAndClientRelevantCandidates()
    {
        var result = CrossSellPolicy.Select([
            Candidate(2, support: 3, clientSupport: 0),
            Candidate(3, support: 2, clientSupport: 1),
            Candidate(4, support: 1, categoryMatch: true)
        ], new HashSet<int> { 1 });

        Assert.Equal([3, 2], result.Select(item => item.ProductoId));
        Assert.All(result, item => Assert.Contains("pedidos", item.Explanation));
    }

    [Fact]
    public void Select_UsesCategoryThenPopularityWhenHistoryIsInsufficient()
    {
        var result = CrossSellPolicy.Select([
            Candidate(2, support: 1, popularity: 20),
            Candidate(3, categoryMatch: true, popularity: 1)
        ], new HashSet<int> { 1 });

        Assert.Equal([3, 2], result.Select(item => item.ProductoId));
        Assert.Contains("categoría", result[0].Explanation);
    }

    [Fact]
    public void Select_ExcludesCartInactiveAndOutOfStockProducts()
    {
        var result = CrossSellPolicy.Select([
            Candidate(1, support: 5),
            Candidate(2, support: 5, active: false),
            Candidate(3, support: 5, stock: 0),
            Candidate(4, support: 5)
        ], new HashSet<int> { 1 });

        Assert.Equal(4, Assert.Single(result).ProductoId);
    }

    [Fact]
    public void Select_ReturnsEmptyForCartWithoutProductsOrNoEligibleFallback()
    {
        Assert.Empty(CrossSellPolicy.Select([Candidate(2, support: 5)], new HashSet<int>()));
        Assert.Empty(CrossSellPolicy.Select([Candidate(2)], new HashSet<int> { 1 }));
    }

    [Fact]
    public void Migration0016_DeclaresMinimumSupportAndDoesNotChangePrices()
    {
        var migration = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "database", "migrations", "0016_cross_sell_recommendations.sql"));
        Assert.Contains("sp_Ventas_CrossSellSuggestions", migration, StringComparison.Ordinal);
        Assert.Contains("Support,0)>=2", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("UPDATE dbo.Productos", migration, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("INSERT dbo.PedidoDetalle", migration, StringComparison.OrdinalIgnoreCase);
    }

    private static CrossSellCandidate Candidate(int id, int support = 0, int clientSupport = 0,
        bool categoryMatch = false, int popularity = 0, bool active = true, int stock = 3) =>
        new(id, $"Producto {id}", "Categoría", 100m, stock, "~/img/fallback.webp", active,
            support, clientSupport, categoryMatch, popularity);

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException();
    }
}
