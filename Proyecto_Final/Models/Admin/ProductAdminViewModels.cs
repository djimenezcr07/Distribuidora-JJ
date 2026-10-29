using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class ProductAdminViewModel
    {
        public int ProductoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public decimal Precio { get; set; }
        public int Stock { get; set; }
        public int StockMinimo { get; set; } = 5;
        public string EstadoStock { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public bool EsDestacado { get; set; }
        public DateTime FechaCreacion { get; set; }
        public string ImagenUrl { get; set; } = string.Empty;
    }

    public class ProductFormViewModel
    {
        public int ProductoId { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(150)]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "La categoría es obligatoria.")]
        [StringLength(100)]
        public string Categoria { get; set; } = string.Empty;

        [StringLength(255)]
        public string? Descripcion { get; set; }

        [Required(ErrorMessage = "El precio es obligatorio.")]
        [Range(0.01, 999999999, ErrorMessage = "El precio debe ser mayor a cero.")]
        public decimal Precio { get; set; }

        [Required(ErrorMessage = "El stock es obligatorio.")]
        [Range(0, int.MaxValue, ErrorMessage = "El stock no puede ser negativo.")]
        public int Stock { get; set; }

        [Required(ErrorMessage = "El stock mínimo es obligatorio.")]
        [Display(Name = "Stock mínimo")]
        [Range(0, int.MaxValue, ErrorMessage = "El stock mínimo no puede ser negativo.")]
        public int StockMinimo { get; set; } = 5;

        [Display(Name = "Ruta o URL de imagen")]
        [StringLength(255)]
        public string? ImagenUrl { get; set; }

        [Display(Name = "Subir imagen")]
        public IFormFile? ImagenArchivo { get; set; }

        [Display(Name = "Producto destacado")]
        public bool EsDestacado { get; set; }

        public bool Activo { get; set; } = true;
    }
}
