using Microsoft.AspNetCore.Razor.TagHelpers;
using Proyecto_Final.Services;

namespace Proyecto_Final.TagHelpers;

/// <summary>Resolves catalog media without emitting requests for missing local files.</summary>
[HtmlTargetElement("img", Attributes = "data-djj-product-image")]
public sealed class ProductImageTagHelper(IWebHostEnvironment environment, IProductImageStorageService storage) : TagHelper
{
    public const string Placeholder = "/img/product-placeholder.svg";
    public override int Order => 1000;

    public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
    {
        var source = output.Attributes["src"]?.Value?.ToString()?.Trim() ?? string.Empty;
        var resolved = Resolve(source);
        var managed = source.Replace('\\', '/').TrimStart('~', '/').Split('?', '#')[0];
        if (managed.StartsWith("product-images/", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var stored = await storage.OpenReadAsync(managed["product-images/".Length..]);
                if (stored is not null)
                {
                    await stored.Content.DisposeAsync();
                    resolved = "/" + managed;
                }
            }
            catch (IOException) { resolved = Placeholder; }
        }
        output.Attributes.SetAttribute("src", resolved);
        output.Attributes.SetAttribute("data-djj-image-fallback", Placeholder);
        if (resolved == Placeholder)
            output.Attributes.SetAttribute("data-djj-image-missing", "true");
    }

    private string Resolve(string source)
    {
        if (string.IsNullOrWhiteSpace(source) || source.StartsWith("//")) return Placeholder;
        if (Uri.TryCreate(source, UriKind.Absolute, out var uri) && !source.StartsWith('/'))
            return uri.Scheme == Uri.UriSchemeHttps ? source : Placeholder;

        var path = source.Replace('\\', '/').TrimStart('~', '/');
        var pathOnly = path.Split('?', '#')[0];
        try
        {
            pathOnly = Uri.UnescapeDataString(pathOnly).Replace('\\', '/');
            if (pathOnly.Split('/').Any(segment => segment is ".." or ".") || pathOnly.Contains(':')) return Placeholder;
            var file = environment.WebRootFileProvider.GetFileInfo(pathOnly);
            return file.Exists && !file.IsDirectory ? "/" + path : Placeholder;
        }
        catch (ArgumentException) { return Placeholder; }
    }
}
