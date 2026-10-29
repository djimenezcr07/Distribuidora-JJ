using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Models
{
    public class RegistroViewModel
    {
        [Required(ErrorMessage = "El nombre es obligatorio")]
        [StringLength(60, MinimumLength = 2, ErrorMessage = "El nombre debe tener entre 2 y 60 caracteres")]
        [Display(Name = "Nombre completo")]
        public required string FullName { get; set; }

        [Required(ErrorMessage = "El correo es obligatorio")]
        [EmailAddress(ErrorMessage = "Formato de correo inválido")]
        [Display(Name = "Correo electrónico")]
        public required string Email { get; set; }

        [Required(ErrorMessage = "La contraseña es obligatoria")]
        [StringLength(PasswordPolicy.MaximumLength, MinimumLength = PasswordPolicy.MinimumLength, ErrorMessage = "La contraseña debe tener entre 12 y 128 caracteres")]
        [DataType(DataType.Password)]
        [Display(Name = "Contraseña")]
        public required string Password { get; set; }

        [Required(ErrorMessage = "Confirmar la contraseña es obligatorio")]
        [DataType(DataType.Password)]
        [Display(Name = "Confirmar contraseña")]
        [Compare(nameof(Password), ErrorMessage = "Las contraseñas no coinciden")]
        public required string ConfirmPassword { get; set; }

        [Display(Name = "Acepto los términos")]
        [Range(typeof(bool), "true", "true", ErrorMessage = "Debe aceptar los términos para continuar")]
        public bool AcceptTerms { get; set; }
    }
}
