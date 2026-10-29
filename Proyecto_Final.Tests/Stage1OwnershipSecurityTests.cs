using Proyecto_Final.Controllers;

namespace Proyecto_Final.Tests;

public sealed class Stage1OwnershipSecurityTests
{
    [Fact]
    public void SellerConfirmations_CheckAuthenticatedSellerOwnershipBeforeLoadingDetail()
    {
        var source = File.ReadAllText(SourcePath("Controllers", "SellerOrdersController.cs"));

        Assert.Equal(2, Count(source, "SellerOwnsOrderAsync(id, vendedorId)"));
        Assert.Contains("return NotFound();", source, StringComparison.Ordinal);
    }

    [Fact]
    public void MileageCloseCarriesActorAndAdministrativeCapabilityToDatabase()
    {
        var controller = File.ReadAllText(SourcePath("Controllers", "FleetController.cs"));
        var service = File.ReadAllText(SourcePath("Services", "FleetDbService.cs"));
        var migration = File.ReadAllText(Path.Combine(RepositoryRoot(), "database", "migrations", "0024_stage1_ownership_security.sql"));

        Assert.Contains("actorUsuarioId", controller, StringComparison.Ordinal);
        Assert.Contains("@ActorUsuarioId", service, StringComparison.Ordinal);
        Assert.Contains("@PuedeAdministrar", service, StringComparison.Ordinal);
        Assert.Contains("ChoferUsuarioId = @ActorUsuarioId", migration, StringComparison.Ordinal);
        Assert.Contains("THROW 53048", migration, StringComparison.Ordinal);
    }

    private static int Count(string text, string value) =>
        text.Split(value, StringSplitOptions.None).Length - 1;

    private static string SourcePath(params string[] parts) =>
        Path.Combine(new[] { RepositoryRoot(), "Proyecto_Final" }.Concat(parts).ToArray());

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
            directory = directory.Parent;

        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz del repositorio.");
    }
}
