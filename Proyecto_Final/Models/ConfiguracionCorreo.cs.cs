namespace Proyecto_Final.Models
{
    public class ConfiguracionCorreo
    {
        public string Host { get; set; } = string.Empty;
        public int Puerto { get; set; }
        public string Remitente { get; set; } = string.Empty;
        public string Contrasenna { get; set; } = string.Empty;
    }
}