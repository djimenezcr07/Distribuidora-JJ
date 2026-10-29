using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class PurchasingErrorSecurityTests
{
    [Fact]
    public void PurchasingOperationException_SeparatesPublicMessageFromTechnicalDetail()
    {
        var technical = new InvalidOperationException("server=db; procedure=internal_proc");
        var exception = new PurchasingOperationException("El proveedor indicado no existe.", technical);

        Assert.Equal("El proveedor indicado no existe.", exception.UserMessage);
        Assert.Equal("La operación de compras fue rechazada.", exception.Message);
        Assert.DoesNotContain("internal_proc", exception.UserMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Same(technical, exception.InnerException);
    }
}
