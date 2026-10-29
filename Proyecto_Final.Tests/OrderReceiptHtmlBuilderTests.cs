using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;
using System.Text.RegularExpressions;

namespace Proyecto_Final.Tests;

public sealed class OrderReceiptHtmlBuilderTests
{
    private const string Template = "TOTAL={{TOTAL}}|SUBTOTAL={{SUBTOTAL}}|{{DESCUENTO}}|{{PRODUCTOS}}|CLIENTE={{CLIENTE}}";

    [Fact]
    public void Receipt_UsesAuthoritativeTotalAfterDiscount()
    {
        var html = Build(
            [new CartItemViewModel { Nombre = "Producto", Precio = 10000m, Cantidad = 1, MontoDescuento = 1000m }],
            9000m,
            1000m);

        Assert.Contains($"TOTAL={OrderReceiptHtmlBuilder.FormatCurrency(9000m)}", html);
        Assert.Contains("Descuento:", html);
    }

    [Fact]
    public void Receipt_ShowsComboQuantityAndAuthoritativeTotal()
    {
        var html = Build(
            [new CartItemViewModel
            {
                ItemType = CartItemTypes.Combo,
                Nombre = "Café y galletas",
                Precio = 8000m,
                Cantidad = 2
            }],
            16000m,
            0m);

        Assert.Contains("Combo:", html);
        Assert.Contains("galletas", html);
        Assert.Contains(OrderReceiptHtmlBuilder.FormatCurrency(16000m), html);
    }

    [Fact]
    public void Receipt_ShowsGiftsAtZeroWithoutIncreasingTheTotal()
    {
        var html = Build(
            [new CartItemViewModel
            {
                Nombre = "Regalo promocional",
                Precio = 1500m,
                Cantidad = 1,
                EsRegalo = true,
                PromocionNombre = "Cliente frecuente"
            }],
            0m,
            0m);

        Assert.Contains("Regalo", html);
        Assert.Contains(OrderReceiptHtmlBuilder.FormatCurrency(0m), html);
        Assert.Contains($"TOTAL={OrderReceiptHtmlBuilder.FormatCurrency(0m)}", html);
    }

    [Fact]
    public void Receipt_MixedOrderKeepsSqlConfirmedTotalAndEscapesText()
    {
        var html = Build(
        [
            new CartItemViewModel { Nombre = "Producto <script>", Precio = 10000m, Cantidad = 1, MontoDescuento = 1000m },
            new CartItemViewModel { ItemType = CartItemTypes.Combo, Nombre = "Combo", Precio = 8000m, Cantidad = 2 },
            new CartItemViewModel { Nombre = "Regalo", Precio = 100m, Cantidad = 1, EsRegalo = true }
        ],
        25000m,
        1000m);

        Assert.Contains($"TOTAL={OrderReceiptHtmlBuilder.FormatCurrency(25000m)}", html);
        Assert.Contains("Producto &lt;script&gt;", html);
        Assert.DoesNotContain("Producto <script>", html);
    }

    [Fact]
    public void Receipt_RealTemplate_ReplacesEveryKnownTokenAndUsesConfiguredBrand()
    {
        var template = File.ReadAllText(RepositoryPath("Proyecto_Final", "EmailTemplates", "OrderReceipt.html"));
        var sourceTokens = Regex.Matches(template, @"\{\{[A-Z_]+\}\}")
            .Select(match => match.Value)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        var html = OrderReceiptHtmlBuilder.Build(
            template,
            "Cliente QA",
            125,
            new CheckoutViewModel
            {
                MetodoPago = "Tarjeta QA",
                TipoEntrega = "Retiro en tienda",
                DireccionEntrega = "Sucursal QA"
            },
            [new CartItemViewModel { Nombre = "Producto QA", Precio = 10000m, Cantidad = 1 }],
            10000m,
            0m,
            new DateTime(2026, 8, 21, 9, 30, 0),
            new CompanyOptions { BrandName = "Distribuidora JJ", BrandSubtitle = "Licorera - Distribuidora" });

        Assert.Contains("Distribuidora JJ", html);
        Assert.Contains("Licorera - Distribuidora", html);
        Assert.Contains("<title>Confirmación de pedido - Distribuidora JJ</title>", html);
        Assert.DoesNotContain("{{BRAND_NAME}}", html);
        Assert.DoesNotContain("{{BRAND_SUBTITLE}}", html);
        Assert.DoesNotContain(sourceTokens, token => html.Contains(token, StringComparison.Ordinal));
    }

    [Fact]
    public void Receipt_EmailService_UsesBusinessClockInsteadOfSystemClock()
    {
        var source = File.ReadAllText(RepositoryPath("Proyecto_Final", "Services", "EmailService.cs"));

        Assert.Contains("BusinessClock clock", source, StringComparison.Ordinal);
        Assert.Contains("_clock.LocalNow", source, StringComparison.Ordinal);
        Assert.DoesNotContain("DateTime.Now", source, StringComparison.Ordinal);
    }

    private static string Build(
        IReadOnlyCollection<CartItemViewModel> items,
        decimal totalConfirmado,
        decimal descuentoTotal) => OrderReceiptHtmlBuilder.Build(
            Template,
            "Cliente",
            42,
            new CheckoutViewModel
            {
                MetodoPago = "Tarjeta demo",
                TipoEntrega = "Retiro en tienda",
                DireccionEntrega = "Sucursal"
            },
            items,
            totalConfirmado,
            descuentoTotal,
            new DateTime(2026, 7, 27, 10, 0, 0),
            new CompanyOptions { BrandName = "Distribuidora JJ", BrandSubtitle = "Licorera - Distribuidora" });

    private static string RepositoryPath(params string[] parts)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return Path.Combine(new[] { directory?.FullName ?? throw new DirectoryNotFoundException() }.Concat(parts).ToArray());
    }
}
