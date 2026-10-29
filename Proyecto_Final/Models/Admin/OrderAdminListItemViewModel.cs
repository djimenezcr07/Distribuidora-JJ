namespace Proyecto_Final.Models.Admin
{
    public class AccountReceivableListItemViewModel
    {
        public int FacturaId { get; set; }
        public int PedidoId { get; set; }

        public string NumeroFactura { get; set; } = string.Empty;
        public string Cliente { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;

        public DateTime FechaEmision { get; set; }
        public DateTime? FechaVencimiento { get; set; }

        public decimal TotalFactura { get; set; }
        public decimal TotalAbonado { get; set; }
        public decimal SaldoPendiente { get; set; }

        public string Estado { get; set; } = string.Empty;

        public bool EstaVencida =>
            SaldoPendiente > 0 &&
            FechaVencimiento.HasValue &&
            FechaVencimiento.Value.Date < DateTime.Today;
    }
}