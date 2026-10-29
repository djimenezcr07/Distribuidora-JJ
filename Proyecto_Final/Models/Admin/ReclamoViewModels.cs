using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-191/192 — ViewModels del módulo de reclamos (servicio al cliente).

    public class ReclamoListItemViewModel
    {
        public int ReclamoId { get; set; }
        public string Asunto { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string Prioridad { get; set; } = string.Empty;
        public string Estado { get; set; } = "Abierto";
        public DateTime FechaRegistro { get; set; }
        public DateTime? FechaCierre { get; set; }
        public int UsuarioId { get; set; }
        public string ClienteNombre { get; set; } = string.Empty;
        public string ClienteCorreo { get; set; } = string.Empty;
        public string? NumeroFactura { get; set; }
    }

    public class ReclamoFilterViewModel
    {
        public string? Estado { get; set; }
        public string? Buscar { get; set; }
        public List<ReclamoListItemViewModel> Reclamos { get; set; } = new();
    }

    public class ReclamoFormViewModel
    {
        [Required(ErrorMessage = "Debe seleccionar el cliente.")]
        [Display(Name = "Cliente")]
        public int UsuarioId { get; set; }

        [Display(Name = "Factura relacionada")]
        public int? FacturaId { get; set; }

        [Display(Name = "Pedido relacionado")]
        public int? PedidoId { get; set; }

        [Required(ErrorMessage = "El asunto es obligatorio.")]
        [StringLength(150, ErrorMessage = "El asunto no puede superar los 150 caracteres.")]
        public string Asunto { get; set; } = string.Empty;

        [Required(ErrorMessage = "La descripción es obligatoria.")]
        [StringLength(1000, ErrorMessage = "La descripción no puede superar los 1000 caracteres.")]
        public string Descripcion { get; set; } = string.Empty;

        [Required(ErrorMessage = "La categoría es obligatoria.")]
        public string Categoria { get; set; } = "Otro";

        [Required(ErrorMessage = "La prioridad es obligatoria.")]
        public string Prioridad { get; set; } = "Media";

        // Combos de apoyo.
        public List<ClienteOptionViewModel> Clientes { get; set; } = new();
        public List<FacturaOptionViewModel> Facturas { get; set; } = new();
    }

    public class ReclamoDetailViewModel
    {
        public int ReclamoId { get; set; }
        public int UsuarioId { get; set; }
        public int? FacturaId { get; set; }
        public int? PedidoId { get; set; }
        public string Asunto { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string Prioridad { get; set; } = string.Empty;
        public string Estado { get; set; } = "Abierto";
        public string ResolucionDescripcion { get; set; } = string.Empty;
        public DateTime? FechaCierre { get; set; }
        public string? CerradoPorNombre { get; set; }
        public string? RegistradoPorNombre { get; set; }
        public DateTime FechaRegistro { get; set; }
        public DateTime? FechaActualizacion { get; set; }

        public string ClienteNombre { get; set; } = string.Empty;
        public string ClienteCorreo { get; set; } = string.Empty;
        public string? ClienteTelefono { get; set; }
        public string? NumeroFactura { get; set; }
        public decimal? FacturaTotal { get; set; }
        public DateTime? FechaFactura { get; set; }
    }

    public class ReclamoUpdateStatusViewModel
    {
        public int ReclamoId { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string Estado { get; set; } = "Abierto";

        [StringLength(1000, ErrorMessage = "La resolución no puede superar los 1000 caracteres.")]
        [Display(Name = "Resolución")]
        public string? Resolucion { get; set; }
    }

    public class ClienteOptionViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
    }

    public class FacturaOptionViewModel
    {
        public int FacturaId { get; set; }
        public string NumeroFactura { get; set; } = string.Empty;
        public DateTime FechaFactura { get; set; }
        public decimal Total { get; set; }
    }
}
