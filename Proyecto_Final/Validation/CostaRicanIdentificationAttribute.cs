using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace Proyecto_Final.Validation;

/// <summary>Validates the Costa Rican identification formats supported by the application.</summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter)]
public sealed partial class CostaRicanIdentificationAttribute : ValidationAttribute
{
    private const string DefaultMessage = "La identificación debe ser una cédula costarricense, jurídica, DIMEX o NITE válida.";

    public CostaRicanIdentificationAttribute() : base(DefaultMessage) { }

    public override bool IsValid(object? value)
    {
        if (value is null || string.IsNullOrWhiteSpace(value.ToString())) return true;
        var normalized = Normalize(value.ToString());

        return PhysicalId().IsMatch(normalized)
            || LegalEntityId().IsMatch(normalized)
            || DimexId().IsMatch(normalized)
            || NiteId().IsMatch(normalized);
    }

    public static string Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? string.Empty
            : string.Concat(value.Where(char.IsDigit));

    [GeneratedRegex("^[1-9][0-9]{8}$", RegexOptions.CultureInvariant)]
    private static partial Regex PhysicalId();

    [GeneratedRegex("^3[0-9]{9}$", RegexOptions.CultureInvariant)]
    private static partial Regex LegalEntityId();

    [GeneratedRegex("^[12][0-9]{10,11}$", RegexOptions.CultureInvariant)]
    private static partial Regex DimexId();

    [GeneratedRegex("^4[0-9]{9}$", RegexOptions.CultureInvariant)]
    private static partial Regex NiteId();
}
