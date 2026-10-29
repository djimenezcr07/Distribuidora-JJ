namespace Proyecto_Final.Models.Chat
{
    public class ChatDepartmentViewModel
    {
        public int DepartamentoId { get; set; }

        public int PerfilId
        {
            get => DepartamentoId;
            set => DepartamentoId = value;
        }

        public string Nombre { get; set; } = string.Empty;

        public string? Descripcion { get; set; }

        public int TotalUsuarios { get; set; }

        public bool PuedePublicar { get; set; }
    }
}
