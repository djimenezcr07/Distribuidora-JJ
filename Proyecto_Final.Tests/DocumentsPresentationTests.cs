using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class DocumentsPresentationTests
{
    [Theory]
    [InlineData("Index")] [InlineData("Create")] [InlineData("Edit")] [InlineData("Details")] [InlineData("Alerts")]
    public void PagesUseWorkspaceWithoutLegacyAndProtectPosts(string name)
    {
        var view = Read("Views/Documents/" + name + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Contains("_DocumentsNavigation", view);
        Assert.Single(Regex.Matches(view, "<h1>"));
        Assert.DoesNotMatch("custom-theme|s4-|fa fa-|data-toggle=|style=", view);
        foreach (Match classes in Regex.Matches(view, "class=\"([^\"]*)\""))
            Assert.DoesNotMatch("(?:^|\\s)(?:btn|row|col-[a-z0-9-]+|form-control|form-group|table-responsive)(?:\\s|$)", classes.Groups[1].Value);
        foreach (Match form in Regex.Matches(view, "<form[^>]*method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(view, "<table.*?</table>", RegexOptions.Singleline))
        { Assert.Contains("<caption", table.Value); Assert.Contains("scope=\"col\"", table.Value); }
    }

    [Theory]
    [InlineData("Vigente", "success")] [InlineData("Por vencer", "warning")]
    [InlineData("Vence hoy", "warning")] [InlineData("Vencido", "danger")]
    [InlineData("No vence", "neutral")] [InlineData("Inactivo", "neutral")]
    [InlineData("Estado futuro", "neutral")] [InlineData(null, "neutral")]
    public void ExpirationUsesServerStateWithNeutralFallback(string? state, string tone) =>
        Assert.Equal(tone, DocumentPresentation.ExpirationTone(state));

    [Theory]
    [InlineData(true, "Vigente", "success")] [InlineData(true, "Suspendido", "warning")]
    [InlineData(true, "Archivado", "neutral")] [InlineData(false, "Vigente", "neutral")]
    [InlineData(true, "Futuro", "neutral")]
    public void BusinessStatusIsSeparateFromExpiration(bool active, string state, string tone) =>
        Assert.Equal(tone, DocumentPresentation.DocumentTone(active, state));

    [Theory]
    [InlineData("Ready", true, false, true)] [InlineData("Ready", false, false, false)]
    [InlineData("Ready", false, true, true)] [InlineData("Pending", true, true, false)]
    [InlineData("Legacy", true, true, false)] [InlineData("Unknown", true, true, false)]
    [InlineData(null, true, true, false)]
    public void DownloadVisibilityNeverPromotesStorage(string? state, bool active, bool manage, bool visible) =>
        Assert.Equal(visible, DocumentPresentation.ShowDownload(state, active, manage));

    [Theory]
    [InlineData("Ready", "success", "Disponible (Ready)")]
    [InlineData("Pending", "warning", "Pendiente (Pending)")]
    [InlineData("Legacy", "neutral", "Heredado (Legacy)")]
    [InlineData("Future", "neutral", "Future")]
    public void StorageRemainsLiteralAndDistinct(string state, string tone, string label)
    { Assert.Equal(tone, DocumentPresentation.StorageTone(state)); Assert.Equal(label, DocumentPresentation.StorageLabel(state)); }

    [Fact]
    public void FormKeepsBindingAndDoesNotInventAVersionInput()
    {
        var form = Read("Views/Documents/_Form.cshtml");
        Assert.DoesNotContain("Layout =", form);
        Assert.DoesNotMatch("form-control|form-group|form-row|col-md|custom-control|s4-|fa fa-", form);
        foreach (var field in new[] { "DocumentId", "TypeId", "DepartmentId", "Title", "Description", "ReferenceNumber", "IssueDate", "ExpirationDate", "DoesNotExpire", "Status", "File" })
            Assert.Contains("asp-for=\"" + field + "\"", form);
        Assert.Contains("Model.DocumentId == 0", form);
        Assert.Contains("type=\"file\"", form); Assert.Contains("data-file-label=\"document-file-name\"", form);
        Assert.DoesNotContain("asp-for=\"Version\"", form);
        Assert.Contains("enctype=\"multipart/form-data\"", Read("Views/Documents/Create.cshtml"));
        Assert.DoesNotContain("enctype=", Read("Views/Documents/Edit.cshtml"));
    }

    [Fact]
    public void AlertRowsDoNotDropAnyServerResultOrRecalculateThresholds()
    {
        var alerts = Read("Views/Documents/Alerts.cshtml");
        Assert.Contains("foreach (var alert in Model.Alerts.Items)", alerts);
        Assert.DoesNotContain(".Where(", alerts);
        Assert.DoesNotContain("PriorityClass", alerts);
        foreach (var field in new[] { "ResponsibleName", "ExpirationDate", "DaysRemaining", "ExpirationStatus", "Status", "DepartmentName" })
            Assert.Contains("alert." + field, alerts);
    }

    [Fact]
    public void OwnerScopedControlsCannotRestoreTheFormerAdministratorBypass()
    {
        Assert.Contains("if (canManage)", Read("Views/Documents/Index.cshtml"));
        Assert.Contains("if (canManage)", Read("Views/Documents/Details.cshtml"));
        Assert.Contains("if (canGenerate)", Read("Views/Documents/Alerts.cshtml"));
        Assert.Contains("canHandle && alert.Status == \"Activa\"", Read("Views/Documents/Alerts.cshtml"));
        Assert.NotNull(typeof(DocumentsController).GetCustomAttribute<SessionAuthorizeAttribute>());
        Assert.NotNull(typeof(DocumentsController).GetCustomAttribute<DocumentAccessExceptionFilterAttribute>());
        Assert.Null(typeof(DocumentsController).GetCustomAttribute<AdminAuthorizeAttribute>());
        foreach (var path in new[] { "Views/Documents/Index.cshtml", "Views/Documents/Details.cshtml", "Views/Documents/Alerts.cshtml", "Views/Shared/_DocumentsNavigation.cshtml" })
        {
            Assert.Contains("DocumentOwnerScope", Read(path));
            Assert.DoesNotContain("Administrador", Read(path));
        }
    }

    [Fact]
    public void HistoryPreservesVersionIdentityWithoutPrivatePaths()
    {
        var details = Read("Views/Documents/Details.cshtml");
        Assert.Contains("version.VersionId", details); Assert.Contains("version.CreatedByName", details);
        Assert.Contains("version.Sha256", details); Assert.Contains("version.StorageStatus", details);
        Assert.Contains("DocumentPresentation.ShowDownload", details);
        Assert.Contains("asp-action=\"Download\"", details);
        Assert.DoesNotMatch("StorageKey|PhysicalPath|wwwroot|App_Data", details);
        Assert.Contains("v@(Model.Document.Version)", details);
        Assert.Contains("v@(item.Version)", Read("Views/Documents/Index.cshtml"));
        Assert.Contains("id=\"replacement-file\"", details); Assert.Contains("name=\"file\"", details);
    }

    [Fact]
    public void EveryDocumentMutationRetainsAntiforgeryWithoutRoleBypass()
    {
        var posts = typeof(DocumentsController).GetMethods()
            .Where(method => method.GetCustomAttribute<HttpPostAttribute>() is not null).ToArray();
        Assert.Equal(6, posts.Length);
        foreach (var method in posts)
        {
            Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
            Assert.Empty(method.GetCustomAttributes<AdminAuthorizeAttribute>());
        }
    }

    private static string Read(string path)
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !Directory.Exists(Path.Combine(root.FullName, "Proyecto_Final"))) root = root.Parent;
        return File.ReadAllText(Path.Combine(root!.FullName, "Proyecto_Final", path));
    }
}
