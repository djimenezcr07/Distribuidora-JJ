namespace Proyecto_Final.Services
{
    public static class ChatMessagePolicy
    {
        public const int MaximumLength = 1000;

        public static bool TryNormalize(string? content, out string normalized, out string error)
        {
            normalized = content?.Trim() ?? string.Empty;
            if (normalized.Length == 0)
            {
                error = "Escriba un mensaje.";
                return false;
            }

            if (normalized.Length > MaximumLength)
            {
                error = $"El mensaje no puede superar los {MaximumLength} caracteres.";
                return false;
            }

            error = string.Empty;
            return true;
        }
    }
}
