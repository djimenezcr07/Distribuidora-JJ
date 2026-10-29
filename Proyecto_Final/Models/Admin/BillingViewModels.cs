namespace Proyecto_Final.Models.Admin
{
    public class SalesReportViewModel
    {
        public decimal VentasTotales { get; set; }
        public decimal VentasMesActual { get; set; }
        public int TotalFacturas { get; set; }
        public int FacturasMesActual { get; set; }
        public int PedidosEntregados { get; set; }
        public List<InvoiceListItemViewModel> Facturas { get; set; } = new();
        public List<TopSellingProductViewModel> ProductosMasVendidos { get; set; } = new();
        public List<MonthlySalesViewModel> VentasPorMes { get; set; } = new();
    }

    public class InvoiceListItemViewModel
    {
        public int FacturaId { get; set; }
        public int PedidoId { get; set; }
        public string NumeroFactura { get; set; } = string.Empty;
        public string Cliente { get; set; } = string.Empty;
        public DateTime FechaFactura { get; set; }
        public decimal Subtotal { get; set; }
        public decimal Impuesto { get; set; }
        public decimal Total { get; set; }
        public string Estado { get; set; } = string.Empty;
    }

    public class InvoiceDetailViewModel
    {
        public int FacturaId { get; set; }
        public int PedidoId { get; set; }
        public string NumeroFactura { get; set; } = string.Empty;
        public string Cliente { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public DateTime FechaFactura { get; set; }
        public decimal Subtotal { get; set; }
        public decimal Impuesto { get; set; }
        public decimal Total { get; set; }
        public string Estado { get; set; } = string.Empty;
        public List<InvoiceDetailLineViewModel> Detalles { get; set; } = new();
    }

    public class InvoiceDetailLineViewModel
    {
        public string Producto { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public decimal PrecioUnitario { get; set; }
        public decimal Subtotal { get; set; }
    }

    public class TopSellingProductViewModel
    {
        public string Producto { get; set; } = string.Empty;
        public int CantidadVendida { get; set; }
        public decimal MontoVendido { get; set; }
    }

    public class MonthlySalesViewModel
    {
        public string Periodo { get; set; } = string.Empty;
        public decimal Total { get; set; }
    }
}
