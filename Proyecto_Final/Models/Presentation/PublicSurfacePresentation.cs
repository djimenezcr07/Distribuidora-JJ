namespace Proyecto_Final.Models.Presentation;

/// <summary>Only bounded trace identifiers belong on a public failure surface.</summary>
public static class PublicSurfacePresentation
{
    public static string? SafeRequestId(string? value) =>
        value is { Length: > 0 and <= 160 }
        && value.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '.' or '_' or ':' or '-')
            ? value : null;
}
