using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class ComboListItemViewModel
{
    public int ComboId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal Precio { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacionUtc { get; set; }
    public string RegistradoPorNombre { get; set; } = string.Empty;
    public int CantidadProductos { get; set; }
    public int StockDisponibleCombo { get; set; }
    public string EstadoDisponibilidad { get; set; } = "No disponible";
    public bool PuedeVenderse => Activo && CantidadProductos > 0 && StockDisponibleCombo > 0
        && string.Equals(EstadoDisponibilidad, "Disponible", StringComparison.Ordinal);
}

public sealed class ComboDetailViewModel
{
    public int ComboId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal Precio { get; set; }
    public bool Activo { get; set; }
    public string RegistradoPorNombre { get; set; } = string.Empty;
    public DateTime FechaCreacionUtc { get; set; }
    public int StockDisponibleCombo { get; set; }
    public string EstadoDisponibilidad { get; set; } = "No disponible";
    public List<ComboDetailLineViewModel> Componentes { get; set; } = new();
}

public sealed class ComboDetailLineViewModel
{
    public int ProductoId { get; set; }
    public string ProductoNombre { get; set; } = string.Empty;
    public int Cantidad { get; set; }
    public int StockDisponible { get; set; }
    public bool ProductoActivo { get; set; }
    public int CombosPosibles => !ProductoActivo || Cantidad <= 0 ? 0 : StockDisponible / Cantidad;
}

public sealed class ComboFormViewModel : IValidatableObject
{
    [Display(Name = "Nombre del combo")]
    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(150, ErrorMessage = "El nombre no puede superar los 150 caracteres.")]
    public string Nombre { get; set; } = string.Empty;

    [Display(Name = "Descripción")]
    [StringLength(500, ErrorMessage = "La descripción no puede superar los 500 caracteres.")]
    public string? Descripcion { get; set; }

    [Display(Name = "Precio del combo")]
    [Range(typeof(decimal), "0.01", "999999999999.99", ParseLimitsInInvariantCulture = true,
        ErrorMessage = "El precio debe ser mayor que cero.")]
    public decimal Precio { get; set; }

    public List<ComboProductSelectionViewModel> Productos { get; set; } = new();

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        var seleccionados = Productos.Where(producto => producto.Seleccionado).ToList();
        if (seleccionados.Count == 0)
        {
            yield return new ValidationResult(
                "Debe seleccionar al menos un producto para armar el combo.",
                new[] { nameof(Productos) });
            yield break;
        }

        if (seleccionados.Any(producto => producto.ProductoId <= 0 || producto.Cantidad <= 0))
        {
            yield return new ValidationResult(
                "Cada componente seleccionado debe tener un producto y una cantidad mayor que cero.",
                new[] { nameof(Productos) });
        }

        if (seleccionados.GroupBy(producto => producto.ProductoId).Any(group => group.Count() > 1))
        {
            yield return new ValidationResult(
                "Un producto no puede repetirse dentro del mismo combo.",
                new[] { nameof(Productos) });
        }
    }
}

public sealed class ComboProductSelectionViewModel
{
    public int ProductoId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int StockActual { get; set; }
    public bool Seleccionado { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "La cantidad debe ser mayor que cero.")]
    public int Cantidad { get; set; } = 1;
}

public sealed class StoreComboViewModel
{
    public int ComboId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Descripcion { get; set; } = string.Empty;
    public decimal Precio { get; set; }
    public int StockDisponible { get; set; }
    public int CantidadProductos { get; set; }
    public string ComponentesResumen { get; set; } = string.Empty;
    public string ImagenUrl { get; set; } = "~/img/OFER-Combo.webp";
    public bool ComponentesValidos { get; set; } = true;
    public bool Disponible => ComponentesValidos && StockDisponible > 0 && CantidadProductos > 0;
}
