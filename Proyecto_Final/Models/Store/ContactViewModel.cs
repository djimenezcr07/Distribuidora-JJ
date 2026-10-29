using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Store
{
    public class ContactViewModel
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(100, ErrorMessage = "El nombre no puede superar los 100 caracteres.")]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Ingresa un correo válido.")]
        public string Correo { get; set; } = string.Empty;

        [Required(ErrorMessage = "El asunto es obligatorio.")]
        [StringLength(120, ErrorMessage = "El asunto no puede superar los 120 caracteres.")]
        public string Asunto { get; set; } = string.Empty;

        [Required(ErrorMessage = "El mensaje es obligatorio.")]
        [StringLength(1000, ErrorMessage = "El mensaje no puede superar los 1000 caracteres.")]
        public string Mensaje { get; set; } = string.Empty;
    }
}