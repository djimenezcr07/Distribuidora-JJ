namespace Proyecto_Final.Models.Store;

public sealed record CrossSellCandidate(
    int ProductoId,
    string Nombre,
    string Categoria,
    decimal Precio,
    int Stock,
    string ImagenUrl,
    bool Activo,
    int Support,
    int ClientSupport,
    bool CategoryMatch,
    int Popularity);

public sealed record CrossSellSuggestion(
    int ProductoId,
    string Nombre,
    string Categoria,
    decimal Precio,
    int Stock,
    string ImagenUrl,
    string Explanation);

public static class CrossSellPolicy
{
    public const int MinimumSupport = 2;

    public static IReadOnlyList<CrossSellSuggestion> Select(
        IEnumerable<CrossSellCandidate> source,
        IReadOnlySet<int> cartProductIds,
        int limit = 4)
    {
        if (limit <= 0 || cartProductIds.Count == 0) return [];

        var eligible = source
            .Where(item => item.Activo && item.Stock > 0 && !cartProductIds.Contains(item.ProductoId))
            .ToArray();
        var supported = eligible.Where(item => item.Support >= MinimumSupport).ToArray();
        var ranked = supported.Length > 0
            ? supported.OrderByDescending(item => item.ClientSupport)
                .ThenByDescending(item => item.Support)
                .ThenByDescending(item => item.CategoryMatch)
                .ThenByDescending(item => item.Popularity)
            : eligible.Where(item => item.CategoryMatch || item.Popularity > 0)
                .OrderByDescending(item => item.CategoryMatch)
                .ThenByDescending(item => item.Popularity);

        return ranked.Take(Math.Min(limit, 8)).Select(item => new CrossSellSuggestion(
            item.ProductoId,
            item.Nombre,
            item.Categoria,
            item.Precio,
            item.Stock,
            item.ImagenUrl,
            item.Support >= MinimumSupport
                ? $"Se compró junto con productos del carrito en {item.Support} pedidos."
                : item.CategoryMatch
                    ? "Alternativa relacionada por categoría; todavía no hay historial conjunto suficiente."
                    : "Producto popular; todavía no hay historial conjunto suficiente."
        )).ToArray();
    }
}
