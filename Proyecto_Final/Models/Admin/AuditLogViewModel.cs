using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class AuditLogViewModel
    {
        public int AuditoriaId { get; set; }
        public int? UsuarioId { get; set; }
        public string UsuarioNombre { get; set; } = string.Empty;
        public string UsuarioCorreo { get; set; } = string.Empty;
        public string Rol { get; set; } = string.Empty;
        public string Accion { get; set; } = string.Empty;
        public string Modulo { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public string? DireccionIp { get; set; }
        public string? UserAgent { get; set; }
        public DateTime FechaRegistro { get; set; }
    }

    public class AuditLogFilterViewModel
    {
        [Display(Name = "Módulo")]
        public string? Modulo { get; set; }

        [Display(Name = "Acción")]
        public string? Accion { get; set; }

        [Display(Name = "Buscar")]
        public string? Buscar { get; set; }

        public List<AuditLogViewModel> Registros { get; set; } = new();
    }
}
