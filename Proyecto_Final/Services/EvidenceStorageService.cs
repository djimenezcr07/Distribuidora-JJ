using System.Text.RegularExpressions;
using System.Security.Cryptography;

namespace Proyecto_Final.Services
{
    public sealed record StagedEvidence(
        string TemporaryKey,
        string StorageKey,
        string ContentType,
        string Extension,
        long Length,
        string? Sha256 = null);

    public sealed class EvidenceValidationException : Exception
    {
        public EvidenceValidationException(string message) : base(message) { }
    }

    public interface IEvidenceStorageService
    {
        Task<StagedEvidence?> StageUploadAsync(IFormFile? file, CancellationToken cancellationToken = default);
        Task<StagedEvidence?> StageSignatureAsync(string? dataUrl, CancellationToken cancellationToken = default);
        Task CommitAsync(StagedEvidence evidence, CancellationToken cancellationToken = default);
        Task DeleteStageAsync(StagedEvidence evidence);
        Task DeleteUnpublishedAsync(StagedEvidence evidence, CancellationToken cancellationToken = default);
        Task<Stream?> OpenReadAsync(string storageKey, CancellationToken cancellationToken = default);
    }

    public sealed class FileEvidenceStorageService : IEvidenceStorageService
    {
        public const long MaximumBytes = 5 * 1024 * 1024;
        private static readonly Regex SafeStorageKey = new(
            "^[a-f0-9]{32}\\.(jpg|png|webp)$",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private readonly string _temporaryRoot;
        private readonly string _filesRoot;

        public FileEvidenceStorageService(IConfiguration configuration, IWebHostEnvironment environment)
        {
            var configuredRoot = configuration["EvidenceStorage:RootPath"];
            var root = string.IsNullOrWhiteSpace(configuredRoot)
                ? Path.Combine(environment.ContentRootPath, "App_Data", "DeliveryEvidence")
                : Path.IsPathRooted(configuredRoot)
                    ? configuredRoot
                    : Path.Combine(environment.ContentRootPath, configuredRoot);

            root = Path.GetFullPath(root);
            if (!string.IsNullOrWhiteSpace(environment.WebRootPath) && IsInside(root, Path.GetFullPath(environment.WebRootPath)))
            {
                throw new InvalidOperationException("EvidenceStorage:RootPath debe estar fuera de wwwroot.");
            }

            _temporaryRoot = Path.Combine(root, "staging");
            _filesRoot = Path.Combine(root, "files");
            Directory.CreateDirectory(_temporaryRoot);
            Directory.CreateDirectory(_filesRoot);
        }

        public async Task<StagedEvidence?> StageUploadAsync(
            IFormFile? file,
            CancellationToken cancellationToken = default)
        {
            if (file is null || file.Length == 0) return null;
            if (file.Length > MaximumBytes)
                throw new EvidenceValidationException("La imagen supera el tamaño máximo permitido de 5 MB.");

            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            var expectedContentType = extension switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".webp" => "image/webp",
                _ => throw new EvidenceValidationException("La imagen debe estar en formato JPG, JPEG, PNG o WEBP.")
            };

            if (!string.Equals(file.ContentType, expectedContentType, StringComparison.OrdinalIgnoreCase))
                throw new EvidenceValidationException("El tipo declarado no coincide con la extensión de la imagen.");

            await using var source = file.OpenReadStream();
            return await StageStreamAsync(source, expectedContentType, extension, file.Length, cancellationToken);
        }

        public async Task<StagedEvidence?> StageSignatureAsync(
            string? dataUrl,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(dataUrl)) return null;
            const string prefix = "data:image/png;base64,";
            if (!dataUrl.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                throw new EvidenceValidationException("La firma debe ser una imagen PNG válida.");

            byte[] bytes;
            try
            {
                bytes = Convert.FromBase64String(dataUrl[prefix.Length..]);
            }
            catch (FormatException)
            {
                throw new EvidenceValidationException("La firma capturada no es válida.");
            }

            if (bytes.Length == 0) return null;
            if (bytes.Length > MaximumBytes)
                throw new EvidenceValidationException("La firma supera el tamaño máximo permitido de 5 MB.");

            await using var stream = new MemoryStream(bytes, writable: false);
            return await StageStreamAsync(stream, "image/png", ".png", bytes.Length, cancellationToken);
        }

        public async Task CommitAsync(StagedEvidence evidence, CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var source = GetTemporaryPath(evidence.TemporaryKey);
            var destination = GetFinalPath(evidence.StorageKey);
            await using (var stream = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.None, 64 * 1024, true))
                if (evidence.Sha256 is null || !await EvidenceIntegrity.VerifyAsync(stream, evidence.Sha256, evidence.Length, cancellationToken))
                    throw new EvidenceValidationException("El archivo temporal cambió; volvé a cargar la evidencia.");
            File.Move(source, destination, overwrite: false);
        }

        public Task DeleteStageAsync(StagedEvidence evidence)
        {
            var path = GetTemporaryPath(evidence.TemporaryKey);
            if (File.Exists(path)) File.Delete(path);
            return Task.CompletedTask;
        }

        public async Task DeleteUnpublishedAsync(StagedEvidence evidence, CancellationToken cancellationToken = default)
        {
            var path = GetFinalPath(evidence.StorageKey);
            if (!File.Exists(path)) return;
            await using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None, 64 * 1024, true))
                if (evidence.Sha256 is null || !await EvidenceIntegrity.VerifyAsync(stream, evidence.Sha256, evidence.Length, cancellationToken))
                    throw new EvidenceValidationException("No se puede compensar un archivo cuya propiedad e integridad no coinciden.");
            File.Delete(path); // Only the newly staged, unpublished GUID and matching bytes.
        }

        public Task<Stream?> OpenReadAsync(string storageKey, CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!IsSafeStorageKey(storageKey)) return Task.FromResult<Stream?>(null);
            var path = GetFinalPath(storageKey);
            Stream? stream = File.Exists(path)
                ? new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 64 * 1024, useAsync: true)
                : null;
            return Task.FromResult(stream);
        }

        public static bool IsSafeStorageKey(string? storageKey) =>
            !string.IsNullOrWhiteSpace(storageKey) && SafeStorageKey.IsMatch(storageKey);

        public static bool HasExpectedSignature(ReadOnlySpan<byte> header, string contentType) => contentType switch
        {
            "image/jpeg" => header.Length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
            "image/png" => header.Length >= 8 && header[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            "image/webp" => header.Length >= 12 &&
                            header[..4].SequenceEqual("RIFF"u8) &&
                            header.Slice(8, 4).SequenceEqual("WEBP"u8),
            _ => false
        };

        private async Task<StagedEvidence> StageStreamAsync(
            Stream source,
            string contentType,
            string extension,
            long length,
            CancellationToken cancellationToken)
        {
            var header = new byte[12];
            var headerLength = await source.ReadAsync(header.AsMemory(), cancellationToken);
            if (!HasExpectedSignature(header.AsSpan(0, headerLength), contentType))
                throw new EvidenceValidationException("El contenido del archivo no corresponde a una imagen admitida.");

            if (source.CanSeek) source.Position = 0;
            else throw new EvidenceValidationException("No fue posible validar el archivo cargado.");

            var normalizedExtension = extension == ".jpeg" ? ".jpg" : extension;
            var key = $"{Guid.NewGuid():N}{normalizedExtension}";
            var temporaryKey = $"{Guid.NewGuid():N}.stage";
            var temporaryPath = GetTemporaryPath(temporaryKey);

            await using var destination = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.ReadWrite,
                FileShare.None,
                64 * 1024,
                useAsync: true);
            try
            {
            var buffer = new byte[64 * 1024];
            long actualLength = 0;
            int count;
            while ((count = await source.ReadAsync(buffer.AsMemory(), cancellationToken)) > 0)
            {
                actualLength = checked(actualLength + count);
                if (actualLength > MaximumBytes || actualLength > length)
                    throw new EvidenceValidationException("El tamaño real del archivo no coincide con el permitido.");
                await destination.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
            }
            if (actualLength != length)
                throw new EvidenceValidationException("El archivo cargado está incompleto.");
            await destination.FlushAsync(cancellationToken);
            destination.Position = 0;
            var hash = Convert.ToHexString(await SHA256.HashDataAsync(destination, cancellationToken));
            return new StagedEvidence(temporaryKey, key, contentType, normalizedExtension, actualLength, hash);
            }
            catch
            {
                await destination.DisposeAsync();
                File.Delete(temporaryPath); // This method created the unique temporary file.
                throw;
            }
        }

        private string GetTemporaryPath(string temporaryKey)
        {
            if (!Regex.IsMatch(temporaryKey ?? string.Empty, "^[a-f0-9]{32}\\.stage$", RegexOptions.CultureInvariant))
                throw new EvidenceValidationException("La referencia temporal de evidencia no es válida.");
            return Path.Combine(_temporaryRoot, temporaryKey!);
        }

        private string GetFinalPath(string storageKey)
        {
            if (!IsSafeStorageKey(storageKey))
                throw new EvidenceValidationException("La referencia de evidencia no es válida.");
            return Path.Combine(_filesRoot, storageKey);
        }

        private static bool IsInside(string candidate, string parent)
        {
            var parentWithSeparator = parent.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                                      + Path.DirectorySeparatorChar;
            return candidate.Equals(parent, StringComparison.OrdinalIgnoreCase) ||
                   candidate.StartsWith(parentWithSeparator, StringComparison.OrdinalIgnoreCase);
        }
    }
}
