namespace Proyecto_Final.Models
{
    public class PermisoPerfil
    {
        public int PerfilId { get; set; }
        public int ModuloId { get; set; }

        // Propiedades de navegación (útiles si luego usas Entity Framework, o para relacionar objetos)
        public Perfil? Perfil { get; set; }
        public Modulo? Modulo { get; set; }
    }
}