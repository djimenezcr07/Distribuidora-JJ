using System.ComponentModel.DataAnnotations;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Validation;

namespace Proyecto_Final.Tests;

public sealed class CostaRicanIdentificationTests
{
    [Theory]
    [InlineData("1-9876-5432")]
    [InlineData("3 987 654321")]
    [InlineData("1-9876-543210")]
    [InlineData("2 9876 5432109")]
    [InlineData("4-9876-54321")]
    public void AcceptsSupportedCostaRicanFormats(string identification) =>
        Assert.True(new CostaRicanIdentificationAttribute().IsValid(identification));

    [Theory]
    [InlineData("0")]
    [InlineData("000000000")]
    [InlineData("098765432")]
    [InlineData("5987654321")]
    [InlineData("39876543210")]
    [InlineData("no-es-una-cedula")]
    public void RejectsInvalidCostaRicanFormats(string identification) =>
        Assert.False(new CostaRicanIdentificationAttribute().IsValid(identification));

    [Fact]
    public void CheckoutRequiresAndNormalizesIdentification()
    {
        var checkout = new CheckoutViewModel { Identificacion = "1-9876-5432" };
        Assert.DoesNotContain(Validate(checkout), result => result.MemberNames.Contains(nameof(checkout.Identificacion)));
        Assert.Equal("198765432", CostaRicanIdentificationAttribute.Normalize(checkout.Identificacion));
    }

    [Fact]
    public void CheckoutRejectsAnEmptyIdentification()
    {
        var checkout = new CheckoutViewModel();
        Assert.Contains(Validate(checkout), result => result.MemberNames.Contains(nameof(checkout.Identificacion)));
    }

    [Fact]
    public void OptionalSellerAndComodatoIdentificationRejectInvalidValues()
    {
        var seller = new SellerOrderCreateViewModel { IdentificacionCliente = "000000000" };
        var comodato = new ComodatoAssignViewModel { ClienteIdentificacion = "000000000" };

        Assert.Contains(Validate(seller), result => result.MemberNames.Contains(nameof(seller.IdentificacionCliente)));
        Assert.Contains(Validate(comodato), result => result.MemberNames.Contains(nameof(comodato.ClienteIdentificacion)));
    }

    private static List<ValidationResult> Validate(object model)
    {
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(model, new ValidationContext(model), results, validateAllProperties: true);
        return results;
    }
}
