using Microsoft.AspNetCore.Mvc.Rendering;
using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Models.Admin
{
    public class EmployeeListItemViewModel
    {
        public int EmpleadoId { get; set; }
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }
        public string Rol { get; set; } = string.Empty;
        public string Puesto { get; set; } = string.Empty;
        public string? Departamento { get; set; }
        public decimal Salario { get; set; }
        public DateTime? FechaContratacion { get; set; }
        public bool Activo { get; set; }
        public bool UsuarioActivo { get; set; }
        public int TareasPendientes { get; set; }
        public int SolicitudesPendientes { get; set; }
    }

    public class EmployeeFilterViewModel
    {
        public string? Buscar { get; set; }
        public string? Estado { get; set; }
        public List<EmployeeListItemViewModel> Empleados { get; set; } = new();
    }

    public class EmployeeRoleOptionViewModel
    {
        public int PerfilId { get; set; }
        public string Nombre { get; set; } = string.Empty;
    }

    public class EmployeeFormViewModel
    {
        public int EmpleadoId { get; set; }
        public int UsuarioId { get; set; }

        [Required(ErrorMessage = "Debe seleccionar un rol del sistema.")]
        [Display(Name = "Rol del sistema")]
        public int PerfilId { get; set; }

        public string? Rol { get; set; }

        [Required(ErrorMessage = "El nombre completo es obligatorio.")]
        [StringLength(150, ErrorMessage = "El nombre no puede superar los 150 caracteres.")]
        [Display(Name = "Nombre completo")]
        public string NombreCompleto { get; set; } = string.Empty;

        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Ingrese un correo válido.")]
        [StringLength(150, ErrorMessage = "El correo no puede superar los 150 caracteres.")]
        [Display(Name = "Correo electrónico")]
        public string Correo { get; set; } = string.Empty;

        [StringLength(30, ErrorMessage = "El teléfono no puede superar los 30 caracteres.")]
        [Display(Name = "Teléfono")]
        public string? Telefono { get; set; }

        [StringLength(255, ErrorMessage = "La dirección no puede superar los 255 caracteres.")]
        [Display(Name = "Dirección")]
        public string? Direccion { get; set; }

        [StringLength(PasswordPolicy.MaximumLength, MinimumLength = PasswordPolicy.MinimumLength, ErrorMessage = "La contraseña debe tener entre 12 y 128 caracteres.")]
        [DataType(DataType.Password)]
        [Display(Name = "Contraseña")]
        public string? Contrasena { get; set; }

        [Required(ErrorMessage = "El puesto es obligatorio.")]
        [StringLength(100, ErrorMessage = "El puesto no puede superar los 100 caracteres.")]
        [Display(Name = "Puesto")]
        public string Puesto { get; set; } = string.Empty;

        [StringLength(100, ErrorMessage = "El departamento no puede superar los 100 caracteres.")]
        [Display(Name = "Departamento")]
        public string? Departamento { get; set; }

        [Range(0, 99999999, ErrorMessage = "El salario debe ser mayor o igual a cero.")]
        [Display(Name = "Salario")]
        public decimal Salario { get; set; }

        [DataType(DataType.Date)]
        [Display(Name = "Fecha de contratación")]
        public DateTime? FechaContratacion { get; set; }

        [Display(Name = "Responsabilidades")]
        public string? Responsabilidades { get; set; }

        [Display(Name = "Observaciones internas")]
        public string? ObservacionesInternas { get; set; }

        [Display(Name = "Empleado activo")]
        public bool Activo { get; set; } = true;

        [StringLength(255, ErrorMessage = "El motivo no puede superar los 255 caracteres.")]
        [Display(Name = "Motivo de cambio salarial")]
        public string? MotivoCambioSalario { get; set; }

        public DateTime FechaRegistro { get; set; }
        public DateTime? FechaActualizacion { get; set; }

        public string RowVersionBase64 { get; set; } = string.Empty;
        public List<SelectListItem> RolesDisponibles { get; set; } = new();
    }

    public class EmployeeDetailViewModel
    {
        public int EmpleadoId { get; set; }
        public int UsuarioId { get; set; }
        public int PerfilId { get; set; }
        public string Rol { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }
        public string Puesto { get; set; } = string.Empty;
        public string? Departamento { get; set; }
        public decimal Salario { get; set; }
        public DateTime? FechaContratacion { get; set; }
        public string? Responsabilidades { get; set; }
        public string? ObservacionesInternas { get; set; }
        public bool Activo { get; set; }
        public bool UsuarioActivo { get; set; }
        public DateTime FechaRegistro { get; set; }
        public DateTime? FechaActualizacion { get; set; }
        public string RowVersionBase64 { get; set; } = string.Empty;
        public List<EmployeeTaskViewModel> Tareas { get; set; } = new();
        public List<EmployeeLeaveRequestViewModel> Solicitudes { get; set; } = new();
        public List<EmployeeSalaryHistoryViewModel> HistorialSalarios { get; set; } = new();
        public EmployeeTaskFormViewModel NuevaTarea { get; set; } = new();
    }

    public class EmployeeTaskViewModel
    {
        public int TareaId { get; set; }
        public int EmpleadoId { get; set; }
        public string Titulo { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public string Prioridad { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public DateTime FechaAsignacion { get; set; }
        public DateTime? FechaLimite { get; set; }
        public string? UsuarioAsignacionNombre { get; set; }
        public DateTime? FechaActualizacion { get; set; }
    }

    public class EmployeeTaskFormViewModel
    {
        public int EmpleadoId { get; set; }

        [Required(ErrorMessage = "El título de la tarea es obligatorio.")]
        [StringLength(150, ErrorMessage = "El título no puede superar los 150 caracteres.")]
        [Display(Name = "Título")]
        public string Titulo { get; set; } = string.Empty;

        [StringLength(700, ErrorMessage = "La descripción no puede superar los 700 caracteres.")]
        [Display(Name = "Descripción")]
        public string? Descripcion { get; set; }

        [Required(ErrorMessage = "Debe seleccionar una prioridad.")]
        [Display(Name = "Prioridad")]
        public string Prioridad { get; set; } = "Media";

        [DataType(DataType.Date)]
        [Display(Name = "Fecha límite")]
        public DateTime? FechaLimite { get; set; }
    }

    public class EmployeeTaskStatusViewModel
    {
        public int TareaId { get; set; }
        public int EmpleadoId { get; set; }
        public string Estado { get; set; } = string.Empty;
    }

    public class EmployeeLeaveRequestViewModel
    {
        public int SolicitudId { get; set; }
        public int EmpleadoId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string Puesto { get; set; } = string.Empty;
        public DateTime FechaInicio { get; set; }
        public DateTime FechaFin { get; set; }
        public int CantidadDias { get; set; }
        public string TipoSolicitud { get; set; } = string.Empty;
        public string Motivo { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string? RespuestaAdmin { get; set; }
        public string? UsuarioRespuestaNombre { get; set; }
        public DateTime FechaSolicitud { get; set; }
        public DateTime? FechaRespuesta { get; set; }
    }

    public class EmployeeLeaveRequestFormViewModel
    {
        [Required(ErrorMessage = "La fecha inicial es obligatoria.")]
        [DataType(DataType.Date)]
        [Display(Name = "Fecha inicial")]
        public DateTime FechaInicio { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "La fecha final es obligatoria.")]
        [DataType(DataType.Date)]
        [Display(Name = "Fecha final")]
        public DateTime FechaFin { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "Debe seleccionar el tipo de solicitud.")]
        [Display(Name = "Tipo de solicitud")]
        public string TipoSolicitud { get; set; } = "Con goce salarial";

        [Required(ErrorMessage = "Debe indicar el motivo de la solicitud.")]
        [StringLength(500, ErrorMessage = "El motivo no puede superar los 500 caracteres.")]
        [Display(Name = "Motivo")]
        public string Motivo { get; set; } = string.Empty;
    }

    public class EmployeeLeaveRequestDecisionViewModel
    {
        public int SolicitudId { get; set; }
        public string Estado { get; set; } = string.Empty;

        [StringLength(500, ErrorMessage = "La respuesta no puede superar los 500 caracteres.")]
        public string? RespuestaAdmin { get; set; }
    }

    public class EmployeeSalaryHistoryViewModel
    {
        public int HistorialSalarioId { get; set; }
        public int EmpleadoId { get; set; }
        public decimal? SalarioAnterior { get; set; }
        public decimal SalarioNuevo { get; set; }
        public string? Motivo { get; set; }
        public string? UsuarioCambioNombre { get; set; }
        public DateTime FechaCambio { get; set; }
    }

    public class EmployeePortalViewModel
    {
        public EmployeeDetailViewModel? Perfil { get; set; }
        public List<EmployeeTaskViewModel> Tareas { get; set; } = new();
        public List<EmployeeLeaveRequestViewModel> Solicitudes { get; set; } = new();
        public EmployeeLeaveRequestFormViewModel NuevaSolicitud { get; set; } = new();
    }
}
