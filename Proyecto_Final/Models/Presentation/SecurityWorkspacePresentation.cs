using System.Text.RegularExpressions;
namespace Proyecto_Final.Models.Presentation;

// Presentation-only redaction; Razor still encodes the returned plain text.
public static partial class SecurityWorkspacePresentation
{
    public static string SafeAuditText(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "No registrado";
        var text = BearerTokens().Replace(value, "[token_oculto]");
        text = CredentialValues().Replace(text, "$1=[oculto]");
        text = PasswordHashes().Replace(text, "[hash oculto]");
        return BearerTokens().Replace(text, "[token oculto]");
    }
    [GeneratedRegex(@"(?i)\b(password|pwd|contraseña|contrasena|token|secret|authorization|connectionstring|server|data source|database|initial catalog|user id)\s*[:=]\s*(?:""[^""]*""|'[^']*'|[^;\s,]+)")]
    private static partial Regex CredentialValues();
    [GeneratedRegex(@"(?i)pbkdf2-sha256\$[^\s;]+|sha(?:256|512)[:$][a-f0-9]+")]
    private static partial Regex PasswordHashes();
    [GeneratedRegex(@"(?i)Bearer\s+[^\s;]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")]
    private static partial Regex BearerTokens();
}
