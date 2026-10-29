namespace Proyecto_Final.Models.Admin
{
    public class ManagementDashboardViewModel
    {
        public DateTime Desde { get; set; }
        public DateTime Hasta { get; set; }
        // "hoy" | "semana" | "mes" | "personalizado"
        public string Rango { get; set; } = "hoy";

        public decimal VentasPeriodo { get; set; }
        public int FacturasPeriodo { get; set; }
        public int PedidosPeriodo { get; set; }
        public decimal TicketPromedio { get; set; }
        public int StockBajo { get; set; }
        public int ProductosAgotados { get; set; }
        public int PedidosEnRuta { get; set; }
        public decimal CobrosPendientes { get; set; }
        public bool HayDatos { get; set; }

        public List<SalesSeriePointViewModel> Serie { get; set; } = new();
    }

    public class SalesSeriePointViewModel
    {
        public DateTime Dia { get; set; }
        public decimal Total { get; set; }
        public int Facturas { get; set; }
    }
}
