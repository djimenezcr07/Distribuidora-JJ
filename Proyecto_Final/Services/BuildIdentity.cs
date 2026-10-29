using System.Reflection;

namespace Proyecto_Final.Services;

public static class BuildIdentity
{
    public static string CommitSha => GetCommitSha(Assembly.GetEntryAssembly());

    internal static string GetCommitSha(Assembly? assembly)
    {
        var value = assembly?
            .GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(attribute => string.Equals(attribute.Key, "BuildCommitSha", StringComparison.Ordinal))?
            .Value;

        return value is { Length: 40 } && value.All(Uri.IsHexDigit)
            ? value.ToLowerInvariant()
            : "unknown";
    }
}
