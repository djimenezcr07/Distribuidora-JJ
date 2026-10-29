namespace Proyecto_Final.Models.Admin
{
    public class DashboardSummaryViewModel
    {
        public int TotalProductos { get; set; }
        public int ProductosActivos { get; set; }
        public int StockBajo { get; set; }
        public int ProductosAgotados { get; set; }
        public int TotalPedidos { get; set; }
        public int PedidosPendientes { get; set; }
        public int PedidosEnProceso { get; set; }
        public int PedidosEntregados { get; set; }
        public decimal VentasTotales { get; set; }
        public decimal VentasMesActual { get; set; }
        public List<LowStockProductViewModel> ProductosCriticos { get; set; } = new();
        public List<RecentOrderViewModel> PedidosRecientes { get; set; } = new();
    }

    public class LowStockProductViewModel
    {
        public int ProductoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public int Stock { get; set; }
        public int StockMinimo { get; set; } = 5;
        public string EstadoStock { get; set; } = string.Empty;
    }

    public class RecentOrderViewModel
    {
        public int PedidoId { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public DateTime FechaPedido { get; set; }
        public string Estado { get; set; } = string.Empty;
        public decimal Total { get; set; }
    }
}
