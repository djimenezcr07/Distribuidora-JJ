namespace Proyecto_FinalAPI.Models
{
    public class ProductApiItem
    {
        public int ProductoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public decimal Precio { get; set; }
        public int Stock { get; set; }
        public string ImagenUrl { get; set; } = string.Empty;
        public bool EsDestacado { get; set; }
        public string EstadoStock => Stock <= 0 ? "Agotado" : "Disponible";
    }
}
