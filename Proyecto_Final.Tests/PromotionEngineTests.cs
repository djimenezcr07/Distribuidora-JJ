using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class PromotionEngineTests
{
    [Fact]
    public void Apply_UsesHighestPriorityOnceAndRoundsDiscount()
    {
        var items = new List<CartItemViewModel>
        {
            new() { ProductoId = 7, Precio = 999.95m, Cantidad = 2 }
        };
        var promotions = new[]
        {
            Discount(1, 7, 10m, priority: 1),
            Discount(2, 7, 15m, priority: 10)
        };

        var result = PromotionEngine.Apply(items, promotions, "Minorista", new DateTime(2026, 7, 22));

        Assert.Single(result.Applied);
        Assert.Equal(2, result.Applied[0].PromocionId);
        Assert.Equal(299.99m, items[0].MontoDescuento);
    }

    [Fact]
    public void Apply_RespectsSegmentAndDate()
    {
        var items = new List<CartItemViewModel> { new() { ProductoId = 1, Precio = 100m, Cantidad = 1 } };
        var promotions = new[]
        {
            Discount(1, 1, 10m, 1, "Mayorista", new DateTime(2026, 1, 1), new DateTime(2026, 12, 31)),
            Discount(2, 1, 20m, 2, "Minorista", new DateTime(2025, 1, 1), new DateTime(2025, 12, 31))
        };

        var result = PromotionEngine.Apply(items, promotions, "Minorista", new DateTime(2026, 7, 22));

        Assert.Empty(result.Applied);
        Assert.Equal(0m, items[0].MontoDescuento);
    }

    [Fact]
    public void Apply_CapsGiftAtAvailableStock()
    {
        var items = new List<CartItemViewModel> { new() { ProductoId = 4, Precio = 10m, Cantidad = 7 } };
        var promotion = new ActivePromotionViewModel
        {
            PromocionId = 3,
            Nombre = "Tres por dos",
            Tipo = "RegaliaPorVolumen",
            ProductoId = 4,
            CantidadMinima = 2,
            ProductoRegaloId = 9,
            ProductoRegaloNombre = "Regalo",
            CantidadRegalo = 2,
            ProductoRegaloStock = 5
        };

        var result = PromotionEngine.Apply(items, new[] { promotion });

        Assert.Single(result.Gifts);
        Assert.Equal(5, result.Gifts[0].Cantidad);
        Assert.Single(result.Applied);
    }

    private static ActivePromotionViewModel Discount(
        int id,
        int productId,
        decimal percentage,
        int priority,
        string segment = "Todos",
        DateTime? start = null,
        DateTime? end = null) => new()
        {
            PromocionId = id,
            Nombre = $"Promo {id}",
            Tipo = "DescuentoPorcentual",
            ProductoId = productId,
            CantidadMinima = 1,
            PorcentajeDescuento = percentage,
            Prioridad = priority,
            SegmentoCliente = segment,
            FechaInicio = start ?? DateTime.MinValue,
            FechaFin = end ?? DateTime.MaxValue
        };
}
