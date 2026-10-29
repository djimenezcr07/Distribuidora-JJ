using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Models
{
    public class ForgotPasswordViewModel
    {
        [Required(ErrorMessage = "El correo es obligatorio")]
        [EmailAddress(ErrorMessage = "Formato de correo inválido")]
        [Display(Name = "Correo electrónico")]
        public string Email { get; set; } = string.Empty;
    }

    public class ResetPasswordViewModel
    {
        public string Token { get; set; } = string.Empty;

        [Required(ErrorMessage = "La nueva contraseña es obligatoria")]
        [StringLength(PasswordPolicy.MaximumLength, MinimumLength = PasswordPolicy.MinimumLength, ErrorMessage = "La contraseña debe tener entre 12 y 128 caracteres")]
        [DataType(DataType.Password)]
        [Display(Name = "Nueva contraseña")]
        public string Password { get; set; } = string.Empty;

        [Required(ErrorMessage = "Confirmar la contraseña es obligatorio")]
        [DataType(DataType.Password)]
        [Display(Name = "Confirmar contraseña")]
        [Compare(nameof(Password), ErrorMessage = "Las contraseñas no coinciden")]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
