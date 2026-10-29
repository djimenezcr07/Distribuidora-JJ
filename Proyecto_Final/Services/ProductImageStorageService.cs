namespace Proyecto_Final.Services;

public sealed record StagedProductImage(string PublicUrl, string PhysicalPath);
public sealed record StoredProductImage(Stream Content, string ContentType);

public sealed class ProductImageValidationException : Exception
{
    public ProductImageValidationException(string userMessage) : base(userMessage) => UserMessage = userMessage;
    public string UserMessage { get; }
}

public interface IProductImageStorageService
{
    Task<StagedProductImage?> StageAsync(IFormFile? file, CancellationToken cancellationToken = default);
    Task<StoredProductImage?> OpenReadAsync(string fileName, CancellationToken cancellationToken = default);
    Task DeleteAsync(string? publicUrl, CancellationToken cancellationToken = default);
}

public sealed class ProductImageStorageService : IProductImageStorageService
{
    public const long MaxBytes = 2 * 1024 * 1024;
    public const string PublicPrefix = "~/product-images/";
    private static readonly IReadOnlyDictionary<string, string> AllowedTypes =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [".jpg"] = "image/jpeg",
            [".jpeg"] = "image/jpeg",
            [".png"] = "image/png",
            [".webp"] = "image/webp"
        };

    private readonly string _root;

    public ProductImageStorageService(IWebHostEnvironment environment, IConfiguration configuration)
    {
        var configured = configuration["ProductImages:StoragePath"];
        _root = Path.GetFullPath(string.IsNullOrWhiteSpace(configured)
            ? Path.Combine(environment.ContentRootPath, "App_Data", "product-images")
            : Path.IsPathRooted(configured) ? configured : Path.Combine(environment.ContentRootPath, configured));
        var webRoot = Path.GetFullPath(environment.WebRootPath);
        if (_root.Equals(webRoot, StringComparison.OrdinalIgnoreCase) || _root.StartsWith(webRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("ProductImages:StoragePath debe estar fuera de wwwroot.");
    }

    public async Task<StagedProductImage?> StageAsync(IFormFile? file, CancellationToken cancellationToken = default)
    {
        if (file is null || file.Length == 0) return null;
        if (file.Length > MaxBytes)
            throw new ProductImageValidationException("La imagen supera el tamaño máximo permitido de 2 MB.");

        var extension = Path.GetExtension(Path.GetFileName(file.FileName)).ToLowerInvariant();
        if (!AllowedTypes.TryGetValue(extension, out var expectedType))
            throw new ProductImageValidationException("La imagen debe estar en formato JPG, JPEG, PNG o WEBP.");
        if (!string.Equals(file.ContentType, expectedType, StringComparison.OrdinalIgnoreCase))
            throw new ProductImageValidationException("El tipo MIME de la imagen no coincide con su extensión.");
        if (!await HasValidSignatureAsync(file, extension, cancellationToken))
            throw new ProductImageValidationException("La firma binaria no corresponde a una imagen permitida.");

        Directory.CreateDirectory(_root);
        var fileName = $"producto-{Guid.NewGuid():N}{extension}";
        var path = ResolveManagedPath(fileName);
        await using var target = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true);
        await file.CopyToAsync(target, cancellationToken);
        return new StagedProductImage($"{PublicPrefix}{fileName}", path);
    }

    public Task<StoredProductImage?> OpenReadAsync(string fileName, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!IsValidManagedFileName(fileName)) return Task.FromResult<StoredProductImage?>(null);
        var extension = Path.GetExtension(fileName);
        if (!AllowedTypes.TryGetValue(extension, out var contentType)) return Task.FromResult<StoredProductImage?>(null);
        var path = ResolveManagedPath(fileName);
        if (!File.Exists(path)) return Task.FromResult<StoredProductImage?>(null);
        return Task.FromResult<StoredProductImage?>(new(new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read), contentType));
    }

    public Task DeleteAsync(string? publicUrl, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (string.IsNullOrWhiteSpace(publicUrl) || !publicUrl.StartsWith(PublicPrefix, StringComparison.OrdinalIgnoreCase))
            return Task.CompletedTask;
        var fileName = publicUrl[PublicPrefix.Length..];
        if (!IsValidManagedFileName(fileName) || !string.Equals(publicUrl, $"{PublicPrefix}{fileName}", StringComparison.OrdinalIgnoreCase))
            return Task.CompletedTask;
        var path = ResolveManagedPath(fileName);
        if (File.Exists(path)) File.Delete(path);
        return Task.CompletedTask;
    }

    private static bool IsValidManagedFileName(string fileName) =>
        !string.IsNullOrWhiteSpace(fileName) &&
        string.Equals(fileName, Path.GetFileName(fileName), StringComparison.Ordinal) &&
        fileName.StartsWith("producto-", StringComparison.OrdinalIgnoreCase) &&
        fileName.Length <= 80;

    private string ResolveManagedPath(string fileName)
    {
        var path = Path.GetFullPath(Path.Combine(_root, fileName));
        if (!path.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new ProductImageValidationException("La ruta de imagen no es válida.");
        return path;
    }

    private static async Task<bool> HasValidSignatureAsync(IFormFile file, string extension, CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        var header = new byte[12];
        var read = await stream.ReadAsync(header.AsMemory(), cancellationToken);
        return extension switch
        {
            ".jpg" or ".jpeg" => read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
            ".png" => read >= 8 && header[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            ".webp" => read >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8),
            _ => false
        };
    }
}
