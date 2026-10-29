using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-161 — Activos de la empresa (neveras, exhibidores) para préstamo.
    public class AssetListItemViewModel
    {
        public int ActivoId { get; set; }
        public string CodigoActivo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Tipo { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string ClientePrestamo { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
    }

    public class AssetFormViewModel
    {
        public int ActivoId { get; set; }

        [Required(ErrorMessage = "El código de activo es obligatorio.")]
        [StringLength(40, ErrorMessage = "El código no puede exceder 40 caracteres.")]
        public string CodigoActivo { get; set; } = string.Empty;

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(150, ErrorMessage = "El nombre no puede exceder 150 caracteres.")]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "El tipo es obligatorio.")]
        public string Tipo { get; set; } = "Nevera";

        [StringLength(300)]
        public string? Descripcion { get; set; }

        public string Estado { get; set; } = "Disponible";

        [StringLength(150)]
        public string? ClientePrestamo { get; set; }
    }
}
