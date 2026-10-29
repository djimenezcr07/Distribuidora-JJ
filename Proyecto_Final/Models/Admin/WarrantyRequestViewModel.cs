using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class WarrantyRequestViewModel
    {
        public int GarantiaId { get; set; }

        [Required(ErrorMessage = "Debe seleccionar el detalle del pedido.")]
        [Display(Name = "Producto comprado")]
        public int PedidoDetalleId { get; set; }

        [Required(ErrorMessage = "Debe seleccionar el cliente.")]
        [Display(Name = "Cliente")]
        public int UsuarioId { get; set; }

        [Display(Name = "Cliente")]
        public string Cliente { get; set; } = string.Empty;

        [Display(Name = "Producto")]
        public string Producto { get; set; } = string.Empty;

        [Display(Name = "Número de pedido")]
        public int PedidoId { get; set; }

        [Display(Name = "Fecha de solicitud")]
        public DateTime FechaSolicitud { get; set; }

        [Required(ErrorMessage = "Debe ingresar el motivo de la garantía.")]
        [StringLength(250)]
        public string Motivo { get; set; } = string.Empty;

        [Display(Name = "Descripción del problema")]
        public string? Descripcion { get; set; }

        public string Estado { get; set; } = "Pendiente";

        [Display(Name = "Resolución")]
        public string? Resolucion { get; set; }

        [Display(Name = "Fecha de resolución")]
        public DateTime? FechaResolucion { get; set; }

        [StringLength(1000)]
        public string? ResolucionNueva { get; set; }
    }
}
