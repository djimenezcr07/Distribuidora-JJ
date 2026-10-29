namespace Proyecto_Final.Models.Chat
{
    public class ChatConversationViewModel
    {
        public int ConversacionId { get; set; }

        public int UsuarioUnoId { get; set; }

        public int UsuarioDosId { get; set; }

        public DateTime FechaCreacion { get; set; }

        public bool Activo { get; set; }
    }
}