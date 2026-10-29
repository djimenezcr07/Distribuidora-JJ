using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace Proyecto_Final.Services;

public enum PrivateStorageArea
{
    Documents,
    ExpenseReceipts
}

public sealed record StagedPrivateFile(
    PrivateStorageArea Area,
    string TemporaryKey,
    string StorageKey,
    string OriginalName,
    string ContentType,
    string Extension,
    long Length,
    string Sha256);

public sealed class PrivateFileValidationException : Exception
{
    public PrivateFileValidationException(string message) : base(message) { }
}

public interface IPrivateFileStorageService
{
    Task<StagedPrivateFile?> StageAsync(IFormFile? file, PrivateStorageArea area, CancellationToken cancellationToken = default);
    Task CommitAsync(StagedPrivateFile file, CancellationToken cancellationToken = default);
    Task DeleteStageAsync(StagedPrivateFile file);
    Task DeleteCommittedAsync(PrivateStorageArea area, string storageKey);
    Task<Stream?> OpenReadAsync(PrivateStorageArea area, string storageKey, CancellationToken cancellationToken = default);
}

public sealed class PrivateFileStorageService : IPrivateFileStorageService
{
    public const long MaximumBytes = 10 * 1024 * 1024;
    private static readonly Regex SafeKey = new("^[a-f0-9]{32}\\.(pdf|jpg|png)$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex SafeTemporaryKey = new("^[a-f0-9]{32}\\.stage$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private readonly string _root;

    public PrivateFileStorageService(IConfiguration configuration, IWebHostEnvironment environment)
    {
        var configuredRoot = configuration["PrivateStorage:RootPath"];
        var root = string.IsNullOrWhiteSpace(configuredRoot)
            ? Path.Combine(environment.ContentRootPath, "App_Data", "PrivateStorage")
            : Path.IsPathRooted(configuredRoot)
                ? configuredRoot
                : Path.Combine(environment.ContentRootPath, configuredRoot);
        _root = Path.GetFullPath(root);
        if (!string.IsNullOrWhiteSpace(environment.WebRootPath) && IsInside(_root, Path.GetFullPath(environment.WebRootPath)))
            throw new InvalidOperationException("PrivateStorage:RootPath debe estar fuera de wwwroot.");

        foreach (var area in Enum.GetValues<PrivateStorageArea>())
        {
            Directory.CreateDirectory(StageRoot(area));
            Directory.CreateDirectory(FilesRoot(area));
        }
    }

    public async Task<StagedPrivateFile?> StageAsync(
        IFormFile? file,
        PrivateStorageArea area,
        CancellationToken cancellationToken = default)
    {
        if (file is null || file.Length == 0) return null;
        if (file.Length > MaximumBytes)
            throw new PrivateFileValidationException("El archivo supera el tamaño máximo permitido de 10 MB.");

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (extension == ".jpeg") extension = ".jpg";
        var expectedMime = extension switch
        {
            ".pdf" => "application/pdf",
            ".jpg" => "image/jpeg",
            ".png" => "image/png",
            _ => throw new PrivateFileValidationException("El archivo debe estar en formato PDF, JPG, JPEG o PNG.")
        };
        if (!string.Equals(file.ContentType, expectedMime, StringComparison.OrdinalIgnoreCase))
            throw new PrivateFileValidationException("El tipo declarado no coincide con la extensión del archivo.");

        await using var source = file.OpenReadStream();
        var header = new byte[12];
        var read = await source.ReadAsync(header.AsMemory(), cancellationToken);
        if (!HasExpectedSignature(header.AsSpan(0, read), expectedMime))
            throw new PrivateFileValidationException("El contenido del archivo no corresponde a un formato admitido.");
        if (!source.CanSeek) throw new PrivateFileValidationException("No fue posible validar el archivo cargado.");
        source.Position = 0;

        var storageKey = $"{Guid.NewGuid():N}{extension}";
        var temporaryKey = $"{Guid.NewGuid():N}.stage";
        var path = TemporaryPath(area, temporaryKey);
        string sha256;
        long written = 0;
        try
        {
            await using var destination = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 64 * 1024, true);
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var buffer = new byte[64 * 1024];
            int count;
            while ((count = await source.ReadAsync(buffer.AsMemory(), cancellationToken)) > 0)
            {
                written += count;
                if (written > MaximumBytes) throw new PrivateFileValidationException("El archivo supera el tamaño máximo permitido de 10 MB.");
                await destination.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
                hash.AppendData(buffer, 0, count);
            }
            sha256 = Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
        }
        catch
        {
            if (File.Exists(path)) File.Delete(path);
            throw;
        }

        var original = Path.GetFileName(file.FileName);
        if (string.IsNullOrWhiteSpace(original)) original = $"archivo{extension}";
        return new StagedPrivateFile(
            area,
            temporaryKey,
            storageKey,
            original[..Math.Min(original.Length, 255)],
            expectedMime,
            extension,
            written,
            sha256);
    }

    public Task CommitAsync(StagedPrivateFile file, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        File.Move(TemporaryPath(file.Area, file.TemporaryKey), FinalPath(file.Area, file.StorageKey), false);
        return Task.CompletedTask;
    }

    public Task DeleteStageAsync(StagedPrivateFile file)
    {
        var path = TemporaryPath(file.Area, file.TemporaryKey);
        if (File.Exists(path)) File.Delete(path);
        return Task.CompletedTask;
    }

    public Task DeleteCommittedAsync(PrivateStorageArea area, string storageKey)
    {
        var path = FinalPath(area, storageKey);
        if (File.Exists(path)) File.Delete(path);
        return Task.CompletedTask;
    }

    public Task<Stream?> OpenReadAsync(PrivateStorageArea area, string storageKey, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!IsSafeStorageKey(storageKey)) return Task.FromResult<Stream?>(null);
        var path = FinalPath(area, storageKey);
        Stream? stream = File.Exists(path)
            ? new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 64 * 1024, true)
            : null;
        return Task.FromResult(stream);
    }

    public static bool IsSafeStorageKey(string? key) => !string.IsNullOrWhiteSpace(key) && SafeKey.IsMatch(key);

    public static bool HasExpectedSignature(ReadOnlySpan<byte> header, string mimeType) => mimeType switch
    {
        "application/pdf" => header.Length >= 5 && header[..5].SequenceEqual("%PDF-"u8),
        "image/jpeg" => header.Length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
        "image/png" => header.Length >= 8 && header[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
        _ => false
    };

    private string StageRoot(PrivateStorageArea area) => Path.Combine(_root, AreaName(area), "staging");
    private string FilesRoot(PrivateStorageArea area) => Path.Combine(_root, AreaName(area), "files");

    private string TemporaryPath(PrivateStorageArea area, string key)
    {
        if (string.IsNullOrWhiteSpace(key) || !SafeTemporaryKey.IsMatch(key)) throw new PrivateFileValidationException("La referencia temporal no es válida.");
        return Path.Combine(StageRoot(area), key);
    }

    private string FinalPath(PrivateStorageArea area, string key)
    {
        if (!IsSafeStorageKey(key)) throw new PrivateFileValidationException("La referencia de almacenamiento no es válida.");
        return Path.Combine(FilesRoot(area), key);
    }

    private static string AreaName(PrivateStorageArea area) => area switch
    {
        PrivateStorageArea.Documents => "documents",
        PrivateStorageArea.ExpenseReceipts => "expense-receipts",
        _ => throw new ArgumentOutOfRangeException(nameof(area))
    };

    private static bool IsInside(string candidate, string parent)
    {
        var prefix = parent.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return candidate.Equals(parent, StringComparison.OrdinalIgnoreCase) || candidate.StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
    }
}
