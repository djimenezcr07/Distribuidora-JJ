using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    public class PermissionItemViewModel
    {
        public int PermisoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Modulo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public bool Asignado { get; set; }
    }

    public class PermissionModuleGroupViewModel
    {
        public string Modulo { get; set; } = string.Empty;
        public List<PermissionItemViewModel> Permisos { get; set; } = new();
    }

    public class RolePermissionAssignmentViewModel
    {
        public int PerfilId { get; set; }
        public string RolNombre { get; set; } = string.Empty;
        public string RolDescripcion { get; set; } = string.Empty;
        public bool RolActivo { get; set; }
        public List<PermissionModuleGroupViewModel> Modulos { get; set; } = new();

        [Display(Name = "Permisos seleccionados")]
        public List<int> PermisosSeleccionados { get; set; } = new();

        public bool EsAdministrador =>
            string.Equals(RolNombre, "Administrador", StringComparison.OrdinalIgnoreCase);

        public int TotalPermisos => Modulos.Sum(m => m.Permisos.Count);
        public int TotalAsignados => Modulos.Sum(m => m.Permisos.Count(p => p.Asignado));
    }
}
