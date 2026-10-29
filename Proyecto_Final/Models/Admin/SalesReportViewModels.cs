using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public static class SalesReportGrouping
{
    public const string Daily = "diario";
    public const string Monthly = "mensual";
    public const string Category = "categoria";
    public static readonly IReadOnlySet<string> Allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { Daily, Monthly, Category };
}

public sealed class SalesReportFilterViewModel : IValidatableObject
{
    [DataType(DataType.Date)]
    public DateTime Desde { get; set; } = new(DateTime.Today.Year, DateTime.Today.Month, 1);

    [DataType(DataType.Date)]
    public DateTime Hasta { get; set; } = DateTime.Today;

    public string Agrupacion { get; set; } = SalesReportGrouping.Daily;

    [StringLength(100)]
    public string? Categoria { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Desde.Date > Hasta.Date)
            yield return new ValidationResult("La fecha inicial no puede superar la final.", [nameof(Desde), nameof(Hasta)]);
        if ((Hasta.Date - Desde.Date).TotalDays > 731)
            yield return new ValidationResult("El reporte admite un rango máximo de dos años.", [nameof(Desde), nameof(Hasta)]);
        if (!SalesReportGrouping.Allowed.Contains(Agrupacion ?? string.Empty))
            yield return new ValidationResult("La agrupación solicitada no es válida.", [nameof(Agrupacion)]);
    }
}

public sealed class SalesReportRowViewModel
{
    public string Clave { get; init; } = string.Empty;
    public string Etiqueta { get; init; } = string.Empty;
    public DateTime? Fecha { get; init; }
    public string? Categoria { get; init; }
    public decimal TotalVentas { get; init; }
    public int Facturas { get; init; }
    public int Pedidos { get; init; }
    public decimal TicketPromedio { get; init; }
    public int Unidades { get; init; }
}

public sealed class DetailedSalesReportViewModel
{
    public SalesReportFilterViewModel Filtro { get; init; } = new();
    public decimal TotalVentas { get; init; }
    public int Facturas { get; init; }
    public int Pedidos { get; init; }
    public decimal TicketPromedio { get; init; }
    public IReadOnlyList<SalesReportRowViewModel> Filas { get; init; } = [];
    public IReadOnlyList<string> Categorias { get; init; } = [];
    public bool HayDatos => Filas.Count > 0;
}

public sealed class SellerPerformanceFilterViewModel : IValidatableObject
{
    [DataType(DataType.Date)] public DateTime Desde { get; set; } = new(DateTime.Today.Year, DateTime.Today.Month, 1);
    [DataType(DataType.Date)] public DateTime Hasta { get; set; } = DateTime.Today;
    public int? VendedorUsuarioId { get; set; }
    public string Orden { get; set; } = "ventas_desc";

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Desde.Date > Hasta.Date)
            yield return new ValidationResult("La fecha inicial no puede superar la final.", [nameof(Desde), nameof(Hasta)]);
        if ((Hasta.Date - Desde.Date).TotalDays > 731)
            yield return new ValidationResult("El reporte admite un rango máximo de dos años.", [nameof(Desde), nameof(Hasta)]);
        if (VendedorUsuarioId is <= 0)
            yield return new ValidationResult("El vendedor seleccionado no es válido.", [nameof(VendedorUsuarioId)]);
        if (Orden is not ("ventas_desc" or "ventas_asc" or "nombre" or "cumplimiento_desc"))
            yield return new ValidationResult("El orden solicitado no es válido.", [nameof(Orden)]);
    }
}

public sealed class SellerPerformanceRowViewModel
{
    public int VendedorUsuarioId { get; init; }
    public string VendedorNombre { get; init; } = string.Empty;
    public decimal Ventas { get; init; }
    public int Pedidos { get; init; }
    public int Facturas { get; init; }
    public decimal TicketPromedio { get; init; }
    public int ClientesAtendidos { get; init; }
    public decimal? Meta { get; init; }
    public decimal? CumplimientoPorcentual { get; init; }
}

public sealed class SellerPerformanceViewModel
{
    public SellerPerformanceFilterViewModel Filtro { get; init; } = new();
    public IReadOnlyList<SellerPerformanceRowViewModel> Filas { get; init; } = [];
    public IReadOnlyList<VendedorOptionViewModel> Vendedores { get; init; } = [];
    public decimal TotalVentas => Filas.Sum(row => row.Ventas);
    public int TotalPedidos => Filas.Sum(row => row.Pedidos);
    public decimal TicketPromedio => ReportMetrics.CalculateAverage(TotalVentas, TotalPedidos);
    public bool HayDatos => Filas.Count > 0;
}

public static class ReportMetrics
{
    public static decimal CalculateAverage(decimal total, int count) =>
        count <= 0 ? 0m : decimal.Round(total / count, 2, MidpointRounding.AwayFromZero);
}
