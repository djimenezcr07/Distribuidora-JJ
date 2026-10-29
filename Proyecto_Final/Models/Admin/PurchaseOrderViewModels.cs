using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public static class PurchaseOrderStatus
{
    public const string Pending = "Pendiente";
    public const string PartiallyReceived = "RecibidaParcial";
    public const string Received = "Recibida";
    public const string ClosedWithDiscrepancy = "CerradaConDiscrepancia";
    public const string Cancelled = "Cancelada";
}

public sealed class PurchaseOrderListItemViewModel
{
    public int OrdenCompraId { get; init; }
    public int ProveedorId { get; init; }
    public string ProveedorNombre { get; init; } = string.Empty;
    public string Estado { get; init; } = string.Empty;
    public string? Notas { get; init; }
    public DateTime FechaCreacionUtc { get; init; }
    public DateTime? FechaRecepcionUtc { get; init; }
    public DateTime? FechaCierreUtc { get; init; }
    public decimal MontoTotal { get; init; }
    public int TotalOrdenado { get; init; }
    public int TotalRecibido { get; init; }
}

public sealed class PurchaseOrderLineSelectionViewModel
{
    public int ProductoId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int StockActual { get; set; }
    public bool Seleccionado { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "La cantidad debe ser mayor a cero.")]
    public int Cantidad { get; set; } = 1;

    //[Range(typeof(decimal), "0.01", "9999999999999999.99", ErrorMessage = "El precio debe ser mayor a cero.")]
    public decimal PrecioUnitario { get; set; } = 1m;

    public decimal PrecioTienda { get; set; }
    public decimal PromedioVentaMensual { get; set; }
    public decimal? UltimoPrecioPagado { get; set; }
    public bool DatosInsuficientes { get; set; }
    public decimal? VariacionPorcentual => PurchasingPolicy.CalculatePriceVariation(PrecioUnitario, UltimoPrecioPagado);
}

public sealed class PurchaseOrderFormViewModel : IValidatableObject
{
    [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un proveedor.")]
    public int ProveedorId { get; set; }

    [StringLength(300)]
    public string? Notas { get; set; }

    public Guid TokenOperacion { get; set; } = Guid.NewGuid();
    public IReadOnlyList<SupplierListItemViewModel> Proveedores { get; set; } = [];
    public List<PurchaseOrderLineSelectionViewModel> Productos { get; set; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext) =>
        PurchasingPolicy.ValidateLines(Productos);
}

public sealed class PurchaseOrderDetailLineViewModel
{
    public int DetalleOrdenCompraId { get; init; }
    public int ProductoId { get; init; }
    public string ProductoNombre { get; init; } = string.Empty;
    public int CantidadOrdenada { get; init; }
    public int CantidadRecibida { get; init; }
    public decimal PrecioUnitario { get; init; }
    public int Pendiente => Math.Max(0, CantidadOrdenada - CantidadRecibida);
}

public sealed class PurchaseOrderDetailViewModel
{
    public int OrdenCompraId { get; init; }
    public int ProveedorId { get; init; }
    public string ProveedorNombre { get; init; } = string.Empty;
    public string Estado { get; init; } = string.Empty;
    public string? Notas { get; init; }
    public string? MotivoCierre { get; init; }
    public DateTime FechaCreacionUtc { get; init; }
    public DateTime? FechaRecepcionUtc { get; init; }
    public DateTime? FechaCierreUtc { get; init; }
    public IReadOnlyList<PurchaseOrderDetailLineViewModel> Lineas { get; set; } = [];
    public bool PermiteRecepcion => Estado is PurchaseOrderStatus.Pending or PurchaseOrderStatus.PartiallyReceived;
    public bool PermiteCerrarConDiscrepancia => PermiteRecepcion && Lineas.Any(line => line.Pendiente > 0);
    public bool PermiteCancelar => Estado == PurchaseOrderStatus.Pending && Lineas.All(line => line.CantidadRecibida == 0);
}

public sealed class PurchaseOrderReceiveViewModel
{
    [Range(1, int.MaxValue)]
    public int OrdenCompraId { get; set; }

    [Range(1, int.MaxValue)]
    public int DetalleOrdenCompraId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "La cantidad recibida debe ser mayor a cero.")]
    public int CantidadRecibidaAhora { get; set; }

    public Guid TokenOperacion { get; set; }
}

public sealed class PurchaseOrderCloseViewModel
{
    [Range(1, int.MaxValue)]
    public int OrdenCompraId { get; set; }

    [Required]
    [StringLength(500, MinimumLength = 10)]
    public string Motivo { get; set; } = string.Empty;

    public Guid TokenOperacion { get; set; }
}

public sealed record PurchaseOrderLineRequest(int ProductoId, int Cantidad, decimal PrecioUnitario);

public static class PurchasingPolicy
{
    public const decimal SignificantPriceVariationPercent = 15m;
    public const int MaximumLinesPerOrder = 50;

    public static IReadOnlyList<PurchaseOrderLineRequest> NormalizeLines(
        IEnumerable<PurchaseOrderLineSelectionViewModel>? products) =>
        (products ?? [])
            .Where(product => product.Seleccionado)
            .OrderBy(product => product.ProductoId)
            .Select(product => new PurchaseOrderLineRequest(
                product.ProductoId,
                product.Cantidad,
                decimal.Round(product.PrecioUnitario, 2, MidpointRounding.AwayFromZero)))
            .ToArray();

    public static IEnumerable<ValidationResult> ValidateLines(
        IEnumerable<PurchaseOrderLineSelectionViewModel>? products)
    {
        var selected = (products ?? []).Where(product => product.Seleccionado).ToArray();
        if (selected.Length == 0)
        {
            yield return new ValidationResult("Debe seleccionar al menos un producto.", [nameof(PurchaseOrderFormViewModel.Productos)]);
            yield break;
        }

        if (selected.Length > MaximumLinesPerOrder)
        {
            yield return new ValidationResult($"Una orden no puede superar {MaximumLinesPerOrder} líneas.", [nameof(PurchaseOrderFormViewModel.Productos)]);
        }

        if (selected.GroupBy(product => product.ProductoId).Any(group => group.Key <= 0 || group.Count() > 1))
        {
            yield return new ValidationResult("Cada producto puede aparecer una sola vez en la orden.", [nameof(PurchaseOrderFormViewModel.Productos)]);
        }

        if (selected.Any(product => product.Cantidad <= 0))
        {
            yield return new ValidationResult("Las cantidades deben ser mayores a cero.", [nameof(PurchaseOrderFormViewModel.Productos)]);
        }

        if (selected.Any(product => product.PrecioUnitario <= 0))
        {
            yield return new ValidationResult("Los precios de compra deben ser mayores a cero.", [nameof(PurchaseOrderFormViewModel.Productos)]);
        }
    }

    public static decimal? CalculatePriceVariation(decimal currentPrice, decimal? previousPrice)
    {
        if (currentPrice <= 0 || previousPrice is null or <= 0)
        {
            return null;
        }

        return decimal.Round(((currentPrice - previousPrice.Value) / previousPrice.Value) * 100m, 2, MidpointRounding.AwayFromZero);
    }

    public static bool IsSignificantPriceVariation(decimal? variationPercent) =>
        variationPercent.HasValue && Math.Abs(variationPercent.Value) > SignificantPriceVariationPercent;
}
