using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-141 / CU-142 — Devoluciones y cuarentena de productos.

    public class ReturnListItemViewModel
    {
        public int DevolucionId { get; set; }
        public int? PedidoId { get; set; }
        public int ProductoId { get; set; }
        public string ProductoNombre { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public string Motivo { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string ClienteInfo { get; set; } = string.Empty;
        public string RegistradoPorNombre { get; set; } = string.Empty;
        public DateTime FechaRegistro { get; set; }
        public string ResueltoPorNombre { get; set; } = string.Empty;
        public DateTime? FechaResolucion { get; set; }
        public string ObservacionResolucion { get; set; } = string.Empty;
    }

    public class ReturnFormViewModel
    {
        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un producto.")]
        public int ProductoId { get; set; }

        public int? PedidoId { get; set; }

        [Range(1, 1000000, ErrorMessage = "La cantidad debe ser mayor a cero.")]
        public int Cantidad { get; set; } = 1;

        [Required(ErrorMessage = "El motivo es obligatorio.")]
        [StringLength(300, ErrorMessage = "El motivo no puede exceder 300 caracteres.")]
        public string Motivo { get; set; } = string.Empty;

        [StringLength(150, ErrorMessage = "El dato del cliente no puede exceder 150 caracteres.")]
        public string? ClienteInfo { get; set; }
    }

    public class ReturnsIndexViewModel
    {
        public List<ReturnListItemViewModel> Devoluciones { get; set; } = new();
        public ReturnFormViewModel Nueva { get; set; } = new();
        public string? Buscar { get; set; }
        public string? Estado { get; set; }
    }
}
