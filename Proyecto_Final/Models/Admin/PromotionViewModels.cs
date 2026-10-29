using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-171/172/174 — Promociones.
    public class PromotionListItemViewModel
    {
        public int PromocionId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Tipo { get; set; } = string.Empty;
        public string SegmentoCliente { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public DateTime FechaInicio { get; set; }
        public DateTime FechaFin { get; set; }
        public int CantidadMinima { get; set; }
        public decimal? PorcentajeDescuento { get; set; }
        public int? CantidadRegalo { get; set; }
        public int Prioridad { get; set; }
        public string ProductoNombre { get; set; } = string.Empty;
        public string? ProductoRegaloNombre { get; set; }
        public bool Vigente { get; set; }
    }

    public class PromotionFormViewModel
    {
        public int PromocionId { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(150)]
        [Display(Name = "Nombre")]
        public string Nombre { get; set; } = string.Empty;

        [StringLength(300)]
        [Display(Name = "Descripción")]
        public string? Descripcion { get; set; }

        [Required]
        [Display(Name = "Tipo de promoción")]
        public string Tipo { get; set; } = "DescuentoPorcentual"; // DescuentoPorcentual | RegaliaPorVolumen

        [Required(ErrorMessage = "Seleccione el producto estratégico.")]
        [Display(Name = "Producto estratégico")]
        public int ProductoId { get; set; }

        [Range(1, 100000, ErrorMessage = "La cantidad mínima debe ser al menos 1.")]
        [Display(Name = "Cantidad mínima")]
        public int CantidadMinima { get; set; } = 1;

        [Range(0.01, 100, ErrorMessage = "El porcentaje debe estar entre 0 y 100.")]
        [Display(Name = "Porcentaje de descuento")]
        public decimal? PorcentajeDescuento { get; set; }

        [Display(Name = "Producto de regalía")]
        public int? ProductoRegaloId { get; set; }

        [Range(1, 100000, ErrorMessage = "La cantidad de regalía debe ser al menos 1.")]
        [Display(Name = "Cantidad de regalía")]
        public int? CantidadRegalo { get; set; }

        [Required]
        [Display(Name = "Segmento de cliente")]
        public string SegmentoCliente { get; set; } = "Todos"; // Todos | Mayorista | Minorista

        [Required(ErrorMessage = "La fecha de inicio es obligatoria.")]
        [DataType(DataType.Date)]
        [Display(Name = "Fecha de inicio")]
        public DateTime FechaInicio { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "La fecha de fin es obligatoria.")]
        [DataType(DataType.Date)]
        [Display(Name = "Fecha de fin")]
        public DateTime FechaFin { get; set; } = DateTime.Today.AddDays(30);

        [Range(0, 1000)]
        [Display(Name = "Prioridad")]
        public int Prioridad { get; set; }

        public List<ProductOptionViewModel> Productos { get; set; } = new();
    }

    public class ProductOptionViewModel
    {
        public int ProductoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public decimal Precio { get; set; }
    }

    // CU-173 — Promoción vigente (fila de sp_Promociones_Vigentes) para el motor del carrito.
    public class ActivePromotionViewModel
    {
        public int PromocionId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Tipo { get; set; } = string.Empty;
        public int ProductoId { get; set; }
        public int CantidadMinima { get; set; }
        public decimal? PorcentajeDescuento { get; set; }
        public int? ProductoRegaloId { get; set; }
        public string? ProductoRegaloNombre { get; set; }
        public decimal ProductoRegaloPrecio { get; set; }
        public int ProductoRegaloStock { get; set; }
        public int? CantidadRegalo { get; set; }
        public int Prioridad { get; set; }
        public string SegmentoCliente { get; set; } = "Todos";
        public DateTime FechaInicio { get; set; } = DateTime.MinValue;
        public DateTime FechaFin { get; set; } = DateTime.MaxValue;
    }

    // CU-172 — Segmento de cliente.
    public class ClientSegmentViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string SegmentoCliente { get; set; } = "Minorista";
    }
}
