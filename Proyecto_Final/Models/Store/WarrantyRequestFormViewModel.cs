using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Store
{
    public class WarrantyRequestFormViewModel
    {
        public int PedidoDetalleId { get; set; }

        public int PedidoId { get; set; }

        public string Producto { get; set; } = string.Empty;


        [Display(Name = "Teléfono")]
        public string? Telefono { get; set; }


        [Required(ErrorMessage = "Seleccione el motivo de la garantía.")]
        [StringLength(250)]
        [Display(Name = "Motivo")]
        public string Motivo { get; set; } = string.Empty;

        [StringLength(1000, ErrorMessage = "La descripción no puede superar los 1000 caracteres.")]
        [Display(Name = "Descripción del inconveniente")]
        public string? Descripcion { get; set; }
    }
}