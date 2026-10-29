namespace Proyecto_Final.Models.Store
{
    public class ShopViewModel
    {
        public string? Categoria { get; set; }
        public string? Buscar { get; set; }
        public string Titulo { get; set; } = "Tienda";
        public List<StoreProductViewModel> Productos { get; set; } = new();
        public List<Proyecto_Final.Models.Admin.StoreComboViewModel> Combos { get; set; } = new();
        public List<string> Categorias { get; set; } = new();
    }
}
