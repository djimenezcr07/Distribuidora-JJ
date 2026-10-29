namespace Proyecto_Final.Models.Admin
{
    public class AccountReceivableDetailViewModel
    {
        public int UsuarioId { get; set; }

        public int FacturaId { get; set; }
        public int PedidoId { get; set; }

        public string NumeroFactura { get; set; } = string.Empty;

        public string Cliente { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }

        public bool ClienteActivo { get; set; }

        public DateTime FechaEmision { get; set; }
        public DateTime? FechaVencimiento { get; set; }

        public decimal TotalFactura { get; set; }
        public decimal TotalAbonado { get; set; }
        public decimal SaldoPendiente { get; set; }

        public decimal LimiteCredito { get; set; }
        public decimal CreditoDisponible { get; set; }

        public decimal TotalCargos { get; set; }
        public decimal TotalAbonos { get; set; }

        public string Estado { get; set; } = string.Empty;

        public bool CreditoActivo { get; set; }
        public bool CreditoBloqueado { get; set; }
        public string? MotivoBloqueo { get; set; }

        public DateTime? FechaActualizacion { get; set; }

        public List<AccountReceivableMovementViewModel> Movimientos { get; set; } = new();

        public AccountReceivableSettingsViewModel SettingsForm { get; set; } = new();

        public AccountReceivableMovementFormViewModel MovementForm { get; set; } = new();
    }
}