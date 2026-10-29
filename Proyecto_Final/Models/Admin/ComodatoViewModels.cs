using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Models.Admin
{
    // CU-162/163/164 — Comodatos (activos prestados a clientes).
    public class ComodatoListItemViewModel
    {
        public int ComodatoId { get; set; }
        public int ActivoId { get; set; }
        public string CodigoActivo { get; set; } = string.Empty;
        public string ActivoNombre { get; set; } = string.Empty;
        public string ActivoTipo { get; set; } = string.Empty;
        public string ClienteNombre { get; set; } = string.Empty;
        public string ClienteIdentificacion { get; set; } = string.Empty;
        public string Ubicacion { get; set; } = string.Empty;
        public DateTime FechaAsignacion { get; set; }
        public DateTime? FechaDevolucion { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string DestinoDevolucion { get; set; } = string.Empty;
        public int DiasEnComodato { get; set; }
    }

    // CU-162 — Formulario de asignación.
    public class ComodatoAssignViewModel
    {
        [Required(ErrorMessage = "Seleccione el activo a prestar.")]
        [Display(Name = "Activo")]
        public int ActivoId { get; set; }

        [Display(Name = "Cliente (usuario)")]
        public int? ClienteUsuarioId { get; set; }

        [Required(ErrorMessage = "El nombre del cliente es obligatorio.")]
        [StringLength(150)]
        [Display(Name = "Cliente")]
        public string ClienteNombre { get; set; } = string.Empty;

        [StringLength(50)]
        [Display(Name = "Identificación")]
        [CostaRicanIdentification]
        public string? ClienteIdentificacion { get; set; }

        [StringLength(200)]
        [Display(Name = "Ubicación del equipo")]
        public string? Ubicacion { get; set; }

        [Display(Name = "Fecha de asignación")]
        [DataType(DataType.Date)]
        public DateTime? FechaAsignacion { get; set; }

        [StringLength(300)]
        [Display(Name = "Condición de entrega")]
        public string? CondicionEntrega { get; set; }

        [StringLength(300)]
        [Display(Name = "Observaciones")]
        public string? Observaciones { get; set; }

        // Opciones para el combo de activos disponibles.
        public List<AssetOptionViewModel> ActivosDisponibles { get; set; } = new();
    }

    public class AssetOptionViewModel
    {
        public int ActivoId { get; set; }
        public string CodigoActivo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Tipo { get; set; } = string.Empty;
    }

    // Historial de comodatos de un activo (para el detalle del activo).
    public class ComodatoHistoryItemViewModel
    {
        public int ComodatoId { get; set; }
        public string ClienteNombre { get; set; } = string.Empty;
        public DateTime FechaAsignacion { get; set; }
        public DateTime? FechaDevolucion { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string DestinoDevolucion { get; set; } = string.Empty;
        public string Observaciones { get; set; } = string.Empty;
    }

    // Detalle de un activo + su historial de comodatos.
    public class AssetDetailViewModel
    {
        public AssetFormViewModel Activo { get; set; } = new();
        public List<ComodatoHistoryItemViewModel> Historial { get; set; } = new();
    }

    // CU-163 — Formulario de devolución/retiro.
    public class ComodatoReturnViewModel
    {
        public int ComodatoId { get; set; }

        [Required(ErrorMessage = "Seleccione el destino del equipo.")]
        [Display(Name = "Destino")]
        public string Destino { get; set; } = "Inventario"; // Inventario | Mantenimiento

        [StringLength(300)]
        [Display(Name = "Condición de devolución")]
        public string? CondicionDevolucion { get; set; }
    }

    // CU-164 — Rentabilidad (inventario prestado cruzado con compras).
    public class ComodatoProfitabilityViewModel
    {
        public int ComodatoId { get; set; }
        public string CodigoActivo { get; set; } = string.Empty;
        public string ActivoNombre { get; set; } = string.Empty;
        public string ActivoTipo { get; set; } = string.Empty;
        public string ClienteNombre { get; set; } = string.Empty;
        public int? ClienteUsuarioId { get; set; }
        public DateTime FechaAsignacion { get; set; }
        public int DiasEnComodato { get; set; }
        public int NumPedidos { get; set; }
        public decimal TotalComprado { get; set; }
        public DateTime? UltimaCompra { get; set; }
    }
}
