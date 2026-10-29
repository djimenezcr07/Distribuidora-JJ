using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Razor.TagHelpers;
using Microsoft.Extensions.FileProviders;
using Moq;
using Proyecto_Final.Services;
using Proyecto_Final.TagHelpers;

namespace Proyecto_Final.Tests;

public sealed class ProductImagePresentationTests
{
    [Theory]
    [InlineData("")]
    [InlineData("~/img/missing.jpg")]
    [InlineData("//example.test/image.jpg")]
    [InlineData("javascript:alert(1)")]
    [InlineData("/img/%2e%2e/private.jpg")]
    [InlineData("/img/%5c..%5cprivate.jpg")]
    public async Task MissingOrInvalidSource_UsesNeutralPlaceholder(string source)
    {
        var (helper, output) = Create(source);
        await helper.ProcessAsync(Context(), output);
        Assert.Equal(ProductImageTagHelper.Placeholder, output.Attributes["src"].Value);
        Assert.Equal("true", output.Attributes["data-djj-image-missing"].Value);
    }

    [Fact]
    public async Task ExistingLocalImage_IsPreserved()
    {
        var file = Mock.Of<IFileInfo>(info => info.Exists && !info.IsDirectory);
        var files = new Mock<IFileProvider>();
        files.Setup(provider => provider.GetFileInfo("img/product.jpg")).Returns(file);
        var (helper, output) = Create("~/img/product.jpg", files.Object);
        await helper.ProcessAsync(Context(), output);
        Assert.Equal("/img/product.jpg", output.Attributes["src"].Value);
        Assert.False(output.Attributes.ContainsName("data-djj-image-missing"));
    }

    [Fact]
    public async Task ManagedPrivateImage_WithQuery_IsPreservedAndStreamClosed()
    {
        var stream = new MemoryStream([1, 2, 3]);
        var storage = new Mock<IProductImageStorageService>();
        storage.Setup(service => service.OpenReadAsync("product.jpg", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new StoredProductImage(stream, "image/jpeg"));
        var (helper, output) = Create("~/product-images/product.jpg?v=1", storage: storage.Object);
        await helper.ProcessAsync(Context(), output);
        Assert.Equal("/product-images/product.jpg", output.Attributes["src"].Value);
        Assert.False(stream.CanRead);
    }

    [Fact]
    public async Task ManagedImageRemovedDuringRender_UsesPlaceholder()
    {
        var storage = new Mock<IProductImageStorageService>();
        storage.Setup(service => service.OpenReadAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new FileNotFoundException());
        var (helper, output) = Create("~/product-images/product.jpg", storage: storage.Object);
        await helper.ProcessAsync(Context(), output);
        Assert.Equal(ProductImageTagHelper.Placeholder, output.Attributes["src"].Value);
    }

    private static TagHelperContext Context() => new(new TagHelperAttributeList(), new Dictionary<object, object>(), "image");

    private static (ProductImageTagHelper Helper, TagHelperOutput Output) Create(
        string source, IFileProvider? files = null, IProductImageStorageService? storage = null)
    {
        var environment = Mock.Of<IWebHostEnvironment>(env => env.WebRootFileProvider == (files ?? new NullFileProvider()));
        var output = new TagHelperOutput("img", new TagHelperAttributeList { { "src", source } },
            (_, _) => Task.FromResult<TagHelperContent>(new DefaultTagHelperContent()));
        return (new ProductImageTagHelper(environment, storage ?? Mock.Of<IProductImageStorageService>()), output);
    }
}
