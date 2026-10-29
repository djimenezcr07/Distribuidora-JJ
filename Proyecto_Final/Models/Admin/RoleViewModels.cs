using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class RoleListItemViewModel
    {
        public int PerfilId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public DateTime FechaCreacion { get; set; }
        public int TotalUsuarios { get; set; }

        public bool EsRolBase =>
            string.Equals(Nombre, "Administrador", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Cliente", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Empleado", StringComparison.OrdinalIgnoreCase);

        public bool BloqueaInactivacion =>
            string.Equals(Nombre, "Administrador", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Cliente", StringComparison.OrdinalIgnoreCase);
    }

    public class RoleFormViewModel
    {
        public int PerfilId { get; set; }

        [Required(ErrorMessage = "El nombre del rol es obligatorio.")]
        [StringLength(50, ErrorMessage = "El nombre no puede superar los 50 caracteres.")]
        [Display(Name = "Nombre del rol")]
        public string Nombre { get; set; } = string.Empty;

        [StringLength(255, ErrorMessage = "La descripción no puede superar los 255 caracteres.")]
        [Display(Name = "Descripción")]
        public string? Descripcion { get; set; }

        [Display(Name = "Rol activo")]
        public bool Activo { get; set; } = true;

        public DateTime FechaCreacion { get; set; }
        public int TotalUsuarios { get; set; }

        public bool EsRolBase =>
            string.Equals(Nombre, "Administrador", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Cliente", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Empleado", StringComparison.OrdinalIgnoreCase);

        public bool BloqueaInactivacion =>
            string.Equals(Nombre, "Administrador", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Nombre, "Cliente", StringComparison.OrdinalIgnoreCase);
    }
}
