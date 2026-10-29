using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Models.Admin
{
    public class ClientListItemViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
        public int TotalPedidos { get; set; }
        public decimal TotalComprado { get; set; }
        public DateTime? UltimoPedido { get; set; }
        public string? MotivoInactivacion { get; set; }
        public DateTime? FechaInactivacion { get; set; }
    }

    public class ClientFilterViewModel
    {
        public string? Buscar { get; set; }
        public string? Estado { get; set; }
        public List<ClientListItemViewModel> Clientes { get; set; } = new();
    }

    public class ClientFormViewModel
    {
        public int UsuarioId { get; set; }

        [Required(ErrorMessage = "El nombre del cliente es obligatorio.")]
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

        [Display(Name = "Cliente activo")]
        public bool Activo { get; set; } = true;

        [StringLength(255, ErrorMessage = "El motivo no puede superar los 255 caracteres.")]
        [Display(Name = "Motivo de inactivación")]
        public string? MotivoInactivacion { get; set; }

        public DateTime FechaRegistro { get; set; }
        public int TotalPedidos { get; set; }
        public decimal TotalComprado { get; set; }
        public DateTime? UltimoPedido { get; set; }
        public DateTime? FechaInactivacion { get; set; }
    }

    public class ClientDetailViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public string? Direccion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
        public int TotalPedidos { get; set; }
        public decimal TotalComprado { get; set; }
        public DateTime? UltimoPedido { get; set; }
        public string? MotivoInactivacion { get; set; }
        public DateTime? FechaInactivacion { get; set; }
        public List<ClientOrderSummaryViewModel> Pedidos { get; set; } = new();
    }

    public class ClientOrderSummaryViewModel
    {
        public int PedidoId { get; set; }
        public DateTime FechaPedido { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string? TipoEntrega { get; set; }
        public string? DireccionEntrega { get; set; }
        public decimal Total { get; set; }
        public string? Observaciones { get; set; }
    }
}
