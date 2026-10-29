using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class ClientCreditListItemViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public bool ClienteActivo { get; set; }
        public decimal LimiteCredito { get; set; }
        public bool CreditoActivo { get; set; }
        public bool CreditoBloqueado { get; set; }
        public string? MotivoBloqueo { get; set; }
        public decimal DeudaActual { get; set; }
        public decimal CreditoDisponible { get; set; }
        public int TotalMovimientos { get; set; }
        public DateTime? UltimoMovimiento { get; set; }
        public DateTime? FechaActualizacion { get; set; }
    }

    public class ClientCreditFilterViewModel
    {
        public string? Buscar { get; set; }
        public string? EstadoCredito { get; set; }
        public List<ClientCreditListItemViewModel> Clientes { get; set; } = new();
    }

    public class ClientCreditDetailViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }
        public bool ClienteActivo { get; set; }
        public decimal LimiteCredito { get; set; }
        public bool CreditoActivo { get; set; }
        public bool CreditoBloqueado { get; set; }
        public string? MotivoBloqueo { get; set; }
        public decimal DeudaActual { get; set; }
        public decimal CreditoDisponible { get; set; }
        public decimal TotalCargos { get; set; }
        public decimal TotalAbonos { get; set; }
        public DateTime? FechaActualizacion { get; set; }
        public List<ClientCreditMovementViewModel> Movimientos { get; set; } = new();
        public ClientCreditSettingsViewModel SettingsForm { get; set; } = new();
        public ClientCreditMovementFormViewModel MovementForm { get; set; } = new();
    }

    public class ClientCreditSettingsViewModel
    {
        public int UsuarioId { get; set; }

        [Required(ErrorMessage = "El límite de crédito es obligatorio.")]
        [Range(0, 999999999, ErrorMessage = "El límite de crédito debe ser mayor o igual a cero.")]
        [Display(Name = "Límite de crédito")]
        public decimal LimiteCredito { get; set; }

        [Display(Name = "Crédito activo")]
        public bool CreditoActivo { get; set; }

        [Display(Name = "Crédito bloqueado")]
        public bool CreditoBloqueado { get; set; }

        [StringLength(255, ErrorMessage = "El motivo no puede superar los 255 caracteres.")]
        [Display(Name = "Motivo de bloqueo o desactivación")]
        public string? MotivoBloqueo { get; set; }
    }

    public class ClientCreditMovementFormViewModel
    {
        public int UsuarioId { get; set; }

        [Required(ErrorMessage = "Debe seleccionar un tipo de movimiento.")]
        [Display(Name = "Tipo de movimiento")]
        public string TipoMovimiento { get; set; } = "Abono";

        [Required(ErrorMessage = "El monto es obligatorio.")]
        [Range(1, 999999999, ErrorMessage = "El monto debe ser mayor a cero.")]
        [Display(Name = "Monto")]
        public decimal Monto { get; set; }

        [Required(ErrorMessage = "La descripción es obligatoria.")]
        [StringLength(500, ErrorMessage = "La descripción no puede superar los 500 caracteres.")]
        [Display(Name = "Descripción")]
        public string Descripcion { get; set; } = string.Empty;

        [StringLength(100, ErrorMessage = "La referencia no puede superar los 100 caracteres.")]
        [Display(Name = "Referencia")]
        public string? Referencia { get; set; }
    }

    public class ClientCreditMovementViewModel
    {
        public int CreditoMovimientoId { get; set; }
        public string TipoMovimiento { get; set; } = string.Empty;
        public decimal Monto { get; set; }
        public string Descripcion { get; set; } = string.Empty;
        public string? Referencia { get; set; }
        public int? RegistradoPorUsuarioId { get; set; }
        public string? RegistradoPorNombre { get; set; }
        public DateTime FechaMovimiento { get; set; }
    }
}
