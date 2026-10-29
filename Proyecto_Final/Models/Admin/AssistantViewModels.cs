namespace Proyecto_Final.Models.Admin
{
    // CU-261 / CU-263 — Asistente virtual (motor de reglas).
    public class AssistantAnswerViewModel
    {
        public string Tipo { get; set; } = "no_interpretado";   // metrica | ayuda | no_interpretado
        public string Intent { get; set; } = string.Empty;
        public bool Interpretado { get; set; }
        public string Titulo { get; set; } = string.Empty;
        public string Respuesta { get; set; } = string.Empty;
        public List<string> Sugerencias { get; set; } = new();
    }
}
