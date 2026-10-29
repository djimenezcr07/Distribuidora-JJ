using Proyecto_Final.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;

namespace Proyecto_Final.Tests;

public sealed class EvidenceStorageTests
{
    [Theory]
    [InlineData("image/jpeg", new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 })]
    [InlineData("image/png", new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })]
    [InlineData("image/webp", new byte[] { 0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50 })]
    public void HasExpectedSignature_AcceptsRealMagicBytes(string mimeType, byte[] header)
    {
        Assert.True(FileEvidenceStorageService.HasExpectedSignature(header, mimeType));
    }

    [Theory]
    [InlineData("image/jpeg")]
    [InlineData("image/png")]
    [InlineData("image/webp")]
    [InlineData("text/html")]
    public void HasExpectedSignature_RejectsSpoofedContent(string mimeType)
    {
        Assert.False(FileEvidenceStorageService.HasExpectedSignature("<script>alert(1)</script>"u8, mimeType));
    }

    [Theory]
    [InlineData("../secret.png")]
    [InlineData("..\\secret.png")]
    [InlineData("C:\\temp\\secret.png")]
    [InlineData("abc.png/other")]
    [InlineData("")]
    public void IsSafeStorageKey_RejectsTraversalAndPaths(string key)
    {
        Assert.False(FileEvidenceStorageService.IsSafeStorageKey(key));
    }

    [Fact]
    public void IsSafeStorageKey_AcceptsGeneratedKey()
    {
        Assert.True(FileEvidenceStorageService.IsSafeStorageKey("0123456789abcdef0123456789abcdef.png"));
    }

    [Fact]
    public async Task StageUpload_RejectsInvalidExtension()
    {
        await WithStorageAsync(async storage =>
        {
            var file = FormFile("malware.exe", "image/png", ValidPng());
            await Assert.ThrowsAsync<EvidenceValidationException>(() => storage.StageUploadAsync(file));
        });
    }

    [Fact]
    public async Task StageUpload_RejectsMismatchedMimeType()
    {
        await WithStorageAsync(async storage =>
        {
            var file = FormFile("photo.png", "image/jpeg", ValidPng());
            await Assert.ThrowsAsync<EvidenceValidationException>(() => storage.StageUploadAsync(file));
        });
    }

    [Fact]
    public async Task StageCommitAndRead_RoundTripsValidatedContent()
    {
        await WithStorageAsync(async storage =>
        {
            var bytes = ValidPng();
            var staged = await storage.StageUploadAsync(FormFile("photo.png", "image/png", bytes));
            Assert.NotNull(staged);
            await storage.CommitAsync(staged!);
            await using var stream = await storage.OpenReadAsync(staged!.StorageKey);
            Assert.NotNull(stream);
            using var memory = new MemoryStream();
            await stream!.CopyToAsync(memory);
            Assert.Equal(bytes, memory.ToArray());
        });
    }

    private static FormFile FormFile(string fileName, string mimeType, byte[] bytes) =>
        new(new MemoryStream(bytes), 0, bytes.Length, "archivo", fileName)
        {
            Headers = new HeaderDictionary(),
            ContentType = mimeType
        };

    private static byte[] ValidPng() =>
        new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0 };

    private static async Task WithStorageAsync(Func<FileEvidenceStorageService, Task> test)
    {
        var taskRoot = Path.Combine(Path.GetTempPath(), "TrilogiaEvidenceTests", Guid.NewGuid().ToString("N"));
        var evidenceRoot = Path.Combine(taskRoot, "evidence");
        var webRoot = Path.Combine(taskRoot, "wwwroot");
        Directory.CreateDirectory(webRoot);
        try
        {
            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["EvidenceStorage:RootPath"] = evidenceRoot
                })
                .Build();
            var environment = new TestEnvironment(taskRoot, webRoot);
            await test(new FileEvidenceStorageService(configuration, environment));
        }
        finally
        {
            if (Directory.Exists(taskRoot)) Directory.Delete(taskRoot, recursive: true);
        }
    }

    private sealed class TestEnvironment(string contentRoot, string webRoot) : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "Proyecto_Final.Tests";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = webRoot;
        public string EnvironmentName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = contentRoot;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
