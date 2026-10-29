using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models
{
    public class ProfileEditViewModel
    {
        [Required(ErrorMessage = "El nombre completo es obligatorio.")]
        [StringLength(150, ErrorMessage = "El nombre completo no puede superar 150 caracteres.")]
        [Display(Name = "Nombre completo")]
        public string NombreCompleto { get; set; } = string.Empty;

        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Ingrese un correo valido.")]
        [StringLength(150, ErrorMessage = "El correo no puede superar 150 caracteres.")]
        [Display(Name = "Correo")]
        public string Correo { get; set; } = string.Empty;

        [StringLength(30, ErrorMessage = "El telefono no puede superar 30 caracteres.")]
        [Display(Name = "Telefono")]
        public string? Telefono { get; set; }

        [StringLength(255, ErrorMessage = "La direccion no puede superar 255 caracteres.")]
        [Display(Name = "Direccion")]
        public string? Direccion { get; set; }
    }
}
