using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class ConsultationViewModel
    {
        public int ConsultaId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string Asunto { get; set; } = string.Empty;
        public string Mensaje { get; set; } = string.Empty;
        public string Estado { get; set; } = "Pendiente";
        public string? RespuestaInterna { get; set; }
        public int? AtendidoPorUsuarioId { get; set; }
        public string? AtendidoPorNombre { get; set; }
        public DateTime? FechaAtencion { get; set; }
        public DateTime FechaCreacion { get; set; }
    }

    public class ConsultationFilterViewModel
    {
        public string? Estado { get; set; }
        public string? Buscar { get; set; }
        public List<ConsultationViewModel> Consultas { get; set; } = new();
    }

    public class ConsultationDetailViewModel
    {
        public int ConsultaId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string Asunto { get; set; } = string.Empty;
        public string Mensaje { get; set; } = string.Empty;
        public string Estado { get; set; } = "Pendiente";
        public string? RespuestaInterna { get; set; }
        public int? AtendidoPorUsuarioId { get; set; }
        public string? AtendidoPorNombre { get; set; }
        public DateTime? FechaAtencion { get; set; }
        public DateTime FechaCreacion { get; set; }
    }

    public class ConsultationUpdateStatusViewModel
    {
        public int ConsultaId { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string Estado { get; set; } = "Pendiente";

        [StringLength(1000, ErrorMessage = "La observación no puede superar los 1000 caracteres.")]
        [Display(Name = "Respuesta u observación interna")]
        public string? RespuestaInterna { get; set; }
    }
}
