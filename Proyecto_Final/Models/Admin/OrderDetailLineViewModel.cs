public class OrderDetailLineViewModel
{
    public int PedidoDetalleId { get; set; }
    public int PedidoId { get; set; }
    public int ProductoId { get; set; }
    public int UsuarioId { get; set; }
    public string Producto { get; set; } = string.Empty;
    public int Cantidad { get; set; }
    public decimal PrecioUnitario { get; set; }
    public decimal Subtotal { get; set; }

    public int StockActual { get; set; }
    public bool IsCombo { get; set; }
    public bool CanRequestWarranty { get; set; }


}
