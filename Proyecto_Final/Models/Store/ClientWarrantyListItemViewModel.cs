namespace Proyecto_Final.Models.Store
{
    public class ClientWarrantyListItemViewModel
    {
        public int GarantiaId { get; set; }
        public int PedidoId { get; set; }
        public int PedidoDetalleId { get; set; }

        public string Producto { get; set; } = string.Empty;
        public DateTime FechaSolicitud { get; set; }

        public string Motivo { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public string Estado { get; set; } = string.Empty;

        public string? Resolucion { get; set; }
        public DateTime? FechaResolucion { get; set; }
    }
}