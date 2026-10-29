namespace Proyecto_Final.Models
{
    public class Perfil
    {
        public int PerfilId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public bool Activo { get; set; }
    }
}
