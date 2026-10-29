namespace Proyecto_Final.Models.Store
{
    public class HomeFeaturedViewModel
    {
        public List<StoreProductViewModel> ProductosDestacados { get; set; } = new();
    }

    public class StoreProductViewModel
    {
        public int ProductoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public decimal Precio { get; set; }
        public int Stock { get; set; }
        public string ImagenUrl { get; set; } = string.Empty;
        public bool EsDestacado { get; set; }

        public string EstadoStock
        {
            get
            {
                if (Stock <= 0) return "Agotado";
                if (Stock <= 5) return "Stock bajo";
                return "Disponible";
            }
        }
    }
}
