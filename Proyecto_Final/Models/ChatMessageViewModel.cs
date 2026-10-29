namespace Proyecto_Final.Models.Chat
{
    public class ChatMessageViewModel
    {
        public int MensajeId { get; set; }

        public int ConversacionId { get; set; }

        public int RemitenteId { get; set; }

        public string Contenido { get; set; } = string.Empty;

        public DateTime FechaEnvio { get; set; }

        public bool Leido { get; set; }
    }
}