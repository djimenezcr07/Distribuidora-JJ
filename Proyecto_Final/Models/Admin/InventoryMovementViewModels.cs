using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class InventoryMovementViewModel
    {
        public int MovimientoId { get; set; }
        public int ProductoId { get; set; }
        public string Producto { get; set; } = string.Empty;
        public string TipoMovimiento { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public int StockAnterior { get; set; }
        public int StockNuevo { get; set; }
        public string? Motivo { get; set; }
        public string Usuario { get; set; } = string.Empty;
        public DateTime FechaMovimiento { get; set; }
    }

    public class InventoryMovementFormViewModel
    {
        [Display(Name = "Producto")]
        [Range(1, int.MaxValue, ErrorMessage = "Debes seleccionar un producto.")]
        public int ProductoId { get; set; }

        [Display(Name = "Tipo de movimiento")]
        [Required(ErrorMessage = "El tipo de movimiento es obligatorio.")]
        public string TipoMovimiento { get; set; } = "Entrada";

        [Display(Name = "Cantidad")]
        [Range(1, int.MaxValue, ErrorMessage = "La cantidad debe ser mayor que cero.")]
        public int Cantidad { get; set; } = 1;

        [Display(Name = "Motivo")]
        [StringLength(300, ErrorMessage = "El motivo no puede superar los 300 caracteres.")]
        public string? Motivo { get; set; } = string.Empty;

        [Display(Name = "Esta entrada representa una compra")]
        public bool GeneraGasto { get; set; }

        [Display(Name = "Costo unitario")]
        [Range(0.01, double.MaxValue,
            ErrorMessage = "El costo unitario debe ser mayor que cero.")]
        public decimal? CostoUnitario { get; set; }

        [Display(Name = "Categoría del gasto")]
        [StringLength(100, ErrorMessage = "La categoría no puede superar los 100 caracteres.")]
        public string? CategoriaGasto { get; set; }

        public List<ProductAdminViewModel> ProductosDisponibles { get; set; } = new();
    }

    // CU-182 — Transforma stock de un producto "origen" (ej. caja) a un producto "destino" (ej. unidad).
    public class StockTransformationFormViewModel : IValidatableObject
    {
        [Display(Name = "Producto origen")]
        [Range(1, int.MaxValue, ErrorMessage = "Debes seleccionar el producto de origen.")]
        public int ProductoOrigenId { get; set; }

        [Display(Name = "Cantidad a descontar del origen")]
        [Range(1, int.MaxValue, ErrorMessage = "La cantidad de origen debe ser mayor que cero.")]
        public int CantidadOrigen { get; set; } = 1;

        [Display(Name = "Producto destino")]
        [Range(1, int.MaxValue, ErrorMessage = "Debes seleccionar el producto de destino.")]
        public int ProductoDestinoId { get; set; }

        [Display(Name = "Cantidad a sumar al destino")]
        [Range(1, int.MaxValue, ErrorMessage = "La cantidad de destino debe ser mayor que cero.")]
        public int CantidadDestino { get; set; } = 1;

        [Display(Name = "Motivo")]
        [StringLength(300, ErrorMessage = "El motivo no puede superar los 300 caracteres.")]
        public string? Motivo { get; set; } = string.Empty;

        public List<ProductAdminViewModel> ProductosDisponibles { get; set; } = new();

        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            if (ProductoOrigenId > 0 && ProductoOrigenId == ProductoDestinoId)
            {
                yield return new ValidationResult(
                    "El producto de origen y destino deben ser diferentes.",
                    new[] { nameof(ProductoDestinoId) });
            }
        }
    }

    public sealed class StockTransformationResultViewModel
    {
        public Guid Reference { get; set; }
        public int SourceProductId { get; set; }
        public string SourceProductName { get; set; } = string.Empty;
        public int SourceStockBefore { get; set; }
        public int SourceStockAfter { get; set; }
        public int DestinationProductId { get; set; }
        public string DestinationProductName { get; set; } = string.Empty;
        public int DestinationStockBefore { get; set; }
        public int DestinationStockAfter { get; set; }
    }
}
