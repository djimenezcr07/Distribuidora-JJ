using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class OrderCommercialStateTests
{
    [Theory]
    [InlineData("Pendiente")]
    [InlineData("Aprobado")]
    [InlineData("EnProceso")]
    [InlineData("Liberado")]
    [InlineData("Retenido")]
    [InlineData("Facturado")]
    [InlineData("Entregado")]
    [InlineData("unrecognized")]
    public void ManualControls_NeverOfferDeliveryReleaseOrBilling(string state)
    {
        var options = OrderActions.ManualStates(state, false);
        Assert.DoesNotContain("Entregado", options);
        Assert.DoesNotContain("Liberado", options);
        Assert.DoesNotContain("Facturado", options);
        Assert.Empty(OrderActions.ManualStates(state, true));
    }

    [Theory]
    [InlineData("Entregado")]
    [InlineData("Retenido")]
    [InlineData("Cancelado")]
    [InlineData("Rechazado")]
    public void BillingControls_DoNotReinterpretHistoricalOrBlockedStates(string state) =>
        Assert.False(Order(state, 1m).CanGenerateInvoice);

    [Fact]
    public void BillingControls_RequireStockEvidenceAndNoPreviousInvoice()
    {
        var order = Order("Pendiente", 1m);
        Assert.True(order.CanGenerateInvoice);
        order.InventoryDebited = false;
        Assert.False(order.CanGenerateInvoice);
        order.InventoryDebited = true;
        order.HasInvoice = true;
        Assert.False(order.CanGenerateInvoice);
    }

    [Fact]
    public void InvoicePreview_RoundsTaxAwayFromZeroOnAggregateNet()
    {
        var order = Order("Pendiente", 0.25m);
        order.Detalles.Add(new() { Subtotal = 0.25m });
        Assert.Equal(0.07m, order.InvoiceTax);
        Assert.Equal(0.57m, order.InvoiceTotal);
        Assert.True(order.CanGenerateInvoice);
    }

    [Fact]
    public void BillingControls_CompareFinalTaxInclusiveAmount()
    {
        var order = Order("Pendiente", 1_769_911.50m);
        Assert.Equal(2_000_000m, order.InvoiceTotal);
        Assert.True(order.CanGenerateInvoice);
        order.Detalles[0].Subtotal += 0.01m;
        Assert.True(order.InvoiceTotal > 2_000_000m);
        Assert.False(order.CanGenerateInvoice);
    }

    private static OrderDetailViewModel Order(string state, decimal net) => new()
    {
        Estado = state, InventoryDebited = true,
        Detalles = [new() { Cantidad = 1, PrecioUnitario = net, Subtotal = net }]
    };
}
