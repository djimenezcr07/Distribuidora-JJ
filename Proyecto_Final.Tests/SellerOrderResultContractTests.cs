using System.Data;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class SellerOrderResultContractTests
{
    [Theory]
    [InlineData("Retenido", 0, "", true)]
    [InlineData("Facturado", 8, "FAC-8", true)]
    [InlineData("Entregado", 8, "FAC-8", false)]
    [InlineData("Pendiente", 0, "", false)]
    [InlineData("Facturado", 0, "", false)]
    [InlineData("Retenido", 8, "FAC-8", false)]
    public void Result_RequiresRetainedOrActuallyInvoicedState(string state, int invoice, string number, bool accepted)
    {
        var table = new DataTable();
        table.Columns.Add("PedidoId", typeof(int)); table.Columns.Add("Estado", typeof(string));
        table.Columns.Add("FacturaId", typeof(int)); table.Columns.Add("NumeroFactura", typeof(string));
        table.Rows.Add(7, state, invoice, number);
        using var reader = table.CreateDataReader(); reader.Read();
        if (accepted) Assert.Equal(7, SellerOrderResultReader.Read(reader).PedidoId);
        else Assert.Throws<InvalidOperationException>(() => SellerOrderResultReader.Read(reader));
    }

    [Fact]
    public void LegacyResult_WithoutInvoiceContractIsRejected()
    {
        var table = new DataTable();
        table.Columns.Add("PedidoId", typeof(int)); table.Columns.Add("Estado", typeof(string));
        table.Rows.Add(7, "Pendiente");
        using var reader = table.CreateDataReader(); reader.Read();
        Assert.Throws<InvalidOperationException>(() => SellerOrderResultReader.Read(reader));
    }
}
