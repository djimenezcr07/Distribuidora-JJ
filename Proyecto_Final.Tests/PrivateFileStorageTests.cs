using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class PrivateFileStorageTests
{
    [Theory]
    [InlineData("application/pdf", new byte[] { 0x25, 0x50, 0x44, 0x46, 0x2D })]
    [InlineData("image/jpeg", new byte[] { 0xFF, 0xD8, 0xFF })]
    [InlineData("image/png", new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })]
    public void MagicBytes_AcceptSupportedFormats(string mime, byte[] bytes) =>
        Assert.True(PrivateFileStorageService.HasExpectedSignature(bytes, mime));

    [Theory]
    [InlineData("../secret.pdf")]
    [InlineData("C:\\secret.pdf")]
    [InlineData("abc.pdf/other")]
    [InlineData("")]
    public void StorageKey_RejectsTraversal(string key) => Assert.False(PrivateFileStorageService.IsSafeStorageKey(key));

    [Fact]
    public async Task ValidPdf_IsHashedCommittedAndReadOutsideWebRoot()
    {
        await WithStorageAsync(async storage =>
        {
            var bytes = "%PDF-1.7\nprivate"u8.ToArray();
            var staged = await storage.StageAsync(File("contract.pdf", "application/pdf", bytes), PrivateStorageArea.Documents);
            Assert.NotNull(staged);
            Assert.Equal(64, staged!.Sha256.Length);
            await storage.CommitAsync(staged);
            await using var stream = await storage.OpenReadAsync(PrivateStorageArea.Documents, staged.StorageKey);
            Assert.NotNull(stream);
            using var result = new MemoryStream(); await stream!.CopyToAsync(result);
            Assert.Equal(bytes, result.ToArray());
        });
    }

    [Fact]
    public async Task SpoofedExtensionAndMime_AreRejected()
    {
        await WithStorageAsync(async storage =>
            await Assert.ThrowsAsync<PrivateFileValidationException>(() => storage.StageAsync(
                File("receipt.png", "image/png", "<html>"u8.ToArray()), PrivateStorageArea.ExpenseReceipts)));
    }

    [Fact]
    public async Task DeclaredMimeMustMatchExtension()
    {
        await WithStorageAsync(async storage =>
            await Assert.ThrowsAsync<PrivateFileValidationException>(() => storage.StageAsync(
                File("receipt.png", "image/jpeg", ValidPng()), PrivateStorageArea.ExpenseReceipts)));
    }

    [Fact]
    public async Task FilesLargerThanTenMegabytesAreRejected()
    {
        await WithStorageAsync(async storage =>
            await Assert.ThrowsAsync<PrivateFileValidationException>(() => storage.StageAsync(
                File("large.png", "image/png", new byte[(int)PrivateFileStorageService.MaximumBytes + 1]), PrivateStorageArea.Documents)));
    }

    [Fact]
    public void RootInsideWebRoot_IsRejected()
    {
        var root = Path.Combine(Path.GetTempPath(), "TrilogiaPrivateTests", Guid.NewGuid().ToString("N"));
        var webRoot = Path.Combine(root, "wwwroot"); Directory.CreateDirectory(webRoot);
        try
        {
            var config = Config(Path.Combine(webRoot, "private"));
            Assert.Throws<InvalidOperationException>(() => new PrivateFileStorageService(config, new EnvironmentStub(root, webRoot)));
        }
        finally { Directory.Delete(root, true); }
    }

    private static FormFile File(string name, string mime, byte[] bytes) => new(new MemoryStream(bytes), 0, bytes.Length, "file", name)
    { Headers = new HeaderDictionary(), ContentType = mime };
    private static byte[] ValidPng() => [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];

    private static async Task WithStorageAsync(Func<PrivateFileStorageService, Task> test)
    {
        var root = Path.Combine(Path.GetTempPath(), "TrilogiaPrivateTests", Guid.NewGuid().ToString("N"));
        var webRoot = Path.Combine(root, "wwwroot"); var privateRoot = Path.Combine(root, "private"); Directory.CreateDirectory(webRoot);
        try { await test(new PrivateFileStorageService(Config(privateRoot), new EnvironmentStub(root, webRoot))); }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }

    private static IConfiguration Config(string path) => new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?> { ["PrivateStorage:RootPath"] = path }).Build();

    private sealed class EnvironmentStub(string contentRoot, string webRoot) : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "Tests"; public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = webRoot; public string EnvironmentName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = contentRoot; public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
