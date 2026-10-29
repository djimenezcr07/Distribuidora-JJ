namespace Proyecto_Final.Models
{
    public class AuthResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public int? UserId { get; set; }
        public string? FullName { get; set; }
        public string? Email { get; set; }
        public string? Role { get; set; }
        public int? ProfileId { get; set; }
        public string? SecurityStamp { get; set; }
    }
}
