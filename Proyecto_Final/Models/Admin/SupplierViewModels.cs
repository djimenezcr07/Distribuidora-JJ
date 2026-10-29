using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class SupplierListItemViewModel
{
    public int ProveedorId { get; init; }
    public string Nombre { get; init; } = string.Empty;
    public string? Contacto { get; init; }
    public string? Telefono { get; init; }
    public string? Email { get; init; }
    public bool Activo { get; init; }
    public DateTime FechaCreacionUtc { get; init; }
    public DateTime? FechaActualizacionUtc { get; init; }
}

public sealed class SupplierFormViewModel
{
    [Range(0, int.MaxValue)]
    public int ProveedorId { get; set; }

    [Required(ErrorMessage = "El nombre del proveedor es obligatorio.")]
    [StringLength(150, MinimumLength = 2)]
    public string Nombre { get; set; } = string.Empty;

    [StringLength(150)]
    public string? Contacto { get; set; }

    [StringLength(30)]
    public string? Telefono { get; set; }

    [StringLength(150)]
    [EmailAddress(ErrorMessage = "El correo no tiene un formato válido.")]
    public string? Email { get; set; }

    public bool Activo { get; set; } = true;
}

public sealed class SuppliersIndexViewModel
{
    public IReadOnlyList<SupplierListItemViewModel> Proveedores { get; init; } = [];
    public SupplierFormViewModel Formulario { get; init; } = new();
    public bool? SoloActivos { get; init; }
    public string? Filtro { get; init; }
}
