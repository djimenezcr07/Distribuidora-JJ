using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class DocumentsDownloadTests
{
    [Theory]
    [InlineData(null)] [InlineData(73)]
    public async Task DownloadUsesAuthorizedMetadataAndVersionWithoutOpeningDatabase(int? versionId)
    {
        var db = new Mock<IDocumentManagementDbService>(MockBehavior.Strict);
        var storage = new Mock<IPrivateFileStorageService>(MockBehavior.Strict);
        const string key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf";
        db.Setup(x => x.GetAuthorizedFileAsync(42, versionId, 999, false)).ReturnsAsync(new PrivateFileMetadata
        { OwnerId = 42, VersionId = versionId, StorageKey = key, OriginalName = "informe sintético.pdf", MimeType = "application/pdf" });
        var bytes = "%PDF-1.7 synthetic"u8.ToArray();
        using var stream = new MemoryStream(bytes);
        storage.Setup(x => x.OpenReadAsync(PrivateStorageArea.Documents, key, CancellationToken.None)).ReturnsAsync(stream);
        var controller = Controller(db.Object, storage.Object);
        var file = Assert.IsType<FileStreamResult>(await controller.Download(42, versionId, CancellationToken.None));
        Assert.Same(stream, file.FileStream); Assert.Equal("application/pdf", file.ContentType);
        var disposition = controller.Response.Headers.ContentDisposition.ToString();
        Assert.StartsWith("attachment; filename*=UTF-8''", disposition);
        Assert.Contains(Uri.EscapeDataString("informe sintético.pdf"), disposition);
        Assert.DoesNotContain(key, disposition);
        db.VerifyAll(); storage.VerifyAll();
    }

    [Fact]
    public async Task DeniedOrNonReadyMetadataNeverOpensStorage()
    {
        var db = new Mock<IDocumentManagementDbService>(MockBehavior.Strict);
        db.Setup(x => x.GetAuthorizedFileAsync(42, null, 999, false)).ReturnsAsync((PrivateFileMetadata?)null);
        var storage = new Mock<IPrivateFileStorageService>(MockBehavior.Strict);
        Assert.IsType<NotFoundResult>(await Controller(db.Object, storage.Object).Download(42, null, CancellationToken.None));
        storage.VerifyNoOtherCalls(); db.VerifyAll();
    }

    [Fact]
    public async Task MissingPrivateFileReturnsNotFoundWithoutPublicFallback()
    {
        var db = new Mock<IDocumentManagementDbService>(MockBehavior.Strict);
        db.Setup(x => x.GetAuthorizedFileAsync(42, null, 999, false)).ReturnsAsync(new PrivateFileMetadata { StorageKey = "synthetic.pdf" });
        var storage = new Mock<IPrivateFileStorageService>(MockBehavior.Strict);
        storage.Setup(x => x.OpenReadAsync(PrivateStorageArea.Documents, "synthetic.pdf", CancellationToken.None)).ReturnsAsync((Stream?)null);
        Assert.IsType<NotFoundResult>(await Controller(db.Object, storage.Object).Download(42, null, CancellationToken.None));
        db.VerifyAll(); storage.VerifyAll();
    }

    private static DocumentsController Controller(IDocumentManagementDbService db, IPrivateFileStorageService storage)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:DefaultConnection"] = "Server=invalid;Database=isolated;Integrated Security=true" }).Build();
        var session = new TestSession();
        session.SetInt32("UserId", 999); session.SetString("UserRole", "Administrador");
        return new DocumentsController(db, storage, Mock.Of<IDocumentAlertService>(),
            new AdminDbService(configuration, Mock.Of<IPasswordHashService>()), NullLogger<DocumentsController>.Instance)
        { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { Session = session } } };
    }

    private sealed class TestSession : ISession
    {
        private readonly Dictionary<string, byte[]> values = new();
        public bool IsAvailable => true;
        public string Id => "isolated";
        public IEnumerable<string> Keys => values.Keys;
        public void Clear() => values.Clear();
        public Task CommitAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task LoadAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public void Remove(string key) => values.Remove(key);
        public void Set(string key, byte[] value) => values[key] = value;
        public bool TryGetValue(string key, out byte[] value) => values.TryGetValue(key, out value!);
    }
}
