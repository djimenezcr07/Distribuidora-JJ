using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-152 / CU-153 / CU-154 — Kilometraje, mantenimiento y alertas de flota.

    // ── CU-152 Kilometraje ──────────────────────────────────
    public class MileageListItemViewModel
    {
        public int KilometrajeId { get; set; }
        public int VehiculoId { get; set; }
        public string VehiculoPlaca { get; set; } = string.Empty;
        public string ChoferNombre { get; set; } = string.Empty;
        public DateTime Fecha { get; set; }
        public int KmInicial { get; set; }
        public int? KmFinal { get; set; }
        public int? Recorrido { get; set; }
        public string Observaciones { get; set; } = string.Empty;
        public DateTime FechaRegistro { get; set; }
        public bool Abierta => KmFinal == null;
    }

    public class MileageOpenViewModel
    {
        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un vehículo.")]
        public int VehiculoId { get; set; }

        [Range(0, int.MaxValue, ErrorMessage = "El kilometraje inicial no es válido.")]
        public int KmInicial { get; set; }

        [StringLength(300)]
        public string? Observaciones { get; set; }
    }

    public class MileageIndexViewModel
    {
        public List<MileageListItemViewModel> Jornadas { get; set; } = new();
        public MileageOpenViewModel Nueva { get; set; } = new();
    }

    // ── CU-153 Mantenimiento ────────────────────────────────
    public class MaintenanceListItemViewModel
    {
        public int OrdenMantenimientoId { get; set; }
        public int VehiculoId { get; set; }
        public string VehiculoPlaca { get; set; } = string.Empty;
        public string Tipo { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public string Taller { get; set; } = string.Empty;
        public decimal Costo { get; set; }
        public string Estado { get; set; } = string.Empty;
        public DateTime? FechaProgramada { get; set; }
        public DateTime? FechaRealizada { get; set; }
        public int? KilometrajeProximo { get; set; }
        public string RegistradoPorNombre { get; set; } = string.Empty;
        public DateTime FechaRegistro { get; set; }
    }

    public class MaintenanceFormViewModel
    {
        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un vehículo.")]
        public int VehiculoId { get; set; }

        [Required(ErrorMessage = "El tipo es obligatorio.")]
        public string Tipo { get; set; } = "Preventivo";

        [Required(ErrorMessage = "La descripción es obligatoria.")]
        [StringLength(300)]
        public string Descripcion { get; set; } = string.Empty;

        [StringLength(150)]
        public string? Taller { get; set; }

        [Range(0, 100000000, ErrorMessage = "El costo no es válido.")]
        public decimal Costo { get; set; }

        public string Estado { get; set; } = "Programada";

        [DataType(DataType.Date)]
        public DateTime? FechaProgramada { get; set; }

        [DataType(DataType.Date)]
        public DateTime? FechaRealizada { get; set; }

        public int? KilometrajeProximo { get; set; }
    }

    public class MaintenanceIndexViewModel
    {
        public List<MaintenanceListItemViewModel> Ordenes { get; set; } = new();
        public MaintenanceFormViewModel Nueva { get; set; } = new();
        public string? Estado { get; set; }
    }

    // ── CU-154 Alertas ──────────────────────────────────────
    public class FleetAlertViewModel
    {
        public string Categoria { get; set; } = string.Empty;   // Documento | Mantenimiento
        public string VehiculoPlaca { get; set; } = string.Empty;
        public string Detalle { get; set; } = string.Empty;
        public DateTime? Fecha { get; set; }
        public int? DiasRestantes { get; set; }
        public string Severidad { get; set; } = string.Empty;   // Vencido | PorVencer
    }

    public class VehicleDocumentFormViewModel
    {
        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un vehículo.")]
        public int VehiculoId { get; set; }

        [Required(ErrorMessage = "El tipo de documento es obligatorio.")]
        public string Tipo { get; set; } = "Marchamo";

        [Required(ErrorMessage = "La fecha de vencimiento es obligatoria.")]
        [DataType(DataType.Date)]
        public DateTime FechaVencimiento { get; set; } = DateTime.Today;

        [StringLength(300)]
        public string? Observaciones { get; set; }
    }

    public class FleetAlertsViewModel
    {
        public List<FleetAlertViewModel> Alertas { get; set; } = new();
        public VehicleDocumentFormViewModel NuevoDocumento { get; set; } = new();
        public int DiasAviso { get; set; } = 15;
    }
}
