namespace Proyecto_Final.Models.Admin;

public sealed class PriceHistoryLineViewModel
{
    public int OrdenCompraId { get; init; }
    public int ProveedorId { get; init; }
    public string ProveedorNombre { get; init; } = string.Empty;
    public decimal PrecioUnitario { get; init; }
    public decimal? PrecioAnterior { get; init; }
    public decimal? VariacionPorcentual { get; init; }
    public bool VariacionSignificativa => PurchasingPolicy.IsSignificantPriceVariation(VariacionPorcentual);
    public string Estado { get; init; } = string.Empty;
    public DateTime FechaCreacionUtc { get; init; }
}

public sealed class PriceHistoryViewModel
{
    public int ProductoId { get; set; }
    public string ProductoNombre { get; set; } = string.Empty;
    public IReadOnlyList<PriceHistoryLineViewModel> Historial { get; set; } = [];
    public IReadOnlyList<ProductAdminViewModel> ProductosDisponibles { get; set; } = [];
}
