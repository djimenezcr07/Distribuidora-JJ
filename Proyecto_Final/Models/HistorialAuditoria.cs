using System;

namespace Proyecto_Final.Models
{
    public class HistorialAuditoria
    {
        public int AuditoriaId { get; set; }
        public int UsuarioId { get; set; }
        public string Accion { get; set; } = string.Empty;
        public string Modulo { get; set; } = string.Empty;
        public string? Detalles { get; set; }
        public DateTime FechaHora { get; set; }

        // Propiedad auxiliar opcional, útil para mostrar el nombre/correo en las tablas de la vista
        public string? CorreoUsuario { get; set; }
    }
}
