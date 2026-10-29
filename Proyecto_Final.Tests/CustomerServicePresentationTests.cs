using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Controllers.Admin;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class CustomerServicePresentationTests
{
    [Theory]
    [InlineData("Consultations/Index")] [InlineData("Consultations/Details")]
    [InlineData("Reclamos/Index")] [InlineData("Reclamos/Create")] [InlineData("Reclamos/Details")]
    [InlineData("WarrantyRequestsAdmin/Index")]
    public void PagesUseWorkspaceAndKeepPostsProtected(string path)
    {
        var text = Read("Views/" + path + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", text);
        Assert.Contains("_CustomerServiceNavigation", text);
        Assert.Single(Regex.Matches(text, "<h1>"));
        Assert.DoesNotMatch("custom-theme|form-control|form-group|col-md-|col-lg-|fa fa-|style=|onclick=|<script>", text);
        foreach (Match form in Regex.Matches(text, "<form[^>]*method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(text, "<table.*?</table>", RegexOptions.Singleline))
        { Assert.Contains("<caption", table.Value); Assert.Contains("scope=\"col\"", table.Value); }
    }

    [Theory]
    [InlineData("consultation", "Pendiente", "info")] [InlineData("consultation", "Atendida", "success")]
    [InlineData("consultation", "Cerrada", "neutral")] [InlineData("consultation", "Futuro", "neutral")]
    [InlineData("complaint", "Abierto", "info")] [InlineData("complaint", "EnProceso", "warning")]
    [InlineData("complaint", "Cerrado", "neutral")] [InlineData("complaint", "Futuro", "neutral")]
    [InlineData("warranty", "Pendiente", "info")] [InlineData("warranty", "En revisión", "warning")]
    [InlineData("warranty", "Aprobada", "success")] [InlineData("warranty", "Rechazada", "danger")]
    [InlineData("warranty", "Futuro", "neutral")] [InlineData("priority", "Alta", "danger")]
    [InlineData("priority", "Media", "warning")] [InlineData("priority", "Baja", "neutral")]
    [InlineData("priority", "Futuro", "neutral")]
    public void StatesRemainSeparateAndUnknownIsNeutral(string domain, string state, string expected)
    {
        var actual = domain switch { "consultation" => CustomerServicePresentation.ConsultationTone(state),
          "complaint" => CustomerServicePresentation.ComplaintTone(state), "warranty" => CustomerServicePresentation.WarrantyTone(state),
          _ => CustomerServicePresentation.PriorityTone(state) };
        Assert.Equal(expected, actual);
    }

    [Theory]
    [InlineData("Cerrado", true, false)] [InlineData("Aprobada", false, true)]
    [InlineData("Rechazada", false, true)] [InlineData("EnProceso", false, false)] [InlineData("Futuro", false, false)]
    public void OnlyAuditedTerminalStatesSuppressManagement(string state, bool complaint, bool warranty)
    { Assert.Equal(complaint, CustomerServicePresentation.ComplaintClosed(state)); Assert.Equal(warranty, CustomerServicePresentation.WarrantyClosed(state)); }

    [Fact]
    public void PermissionAndAntiforgeryMatchExistingEndpoints()
    {
        AssertPolicy(typeof(ConsultationsController), "CONSULTAS_VER");
        AssertPolicy(typeof(ReclamosController), "RECLAMOS_GESTIONAR");
        AssertPolicy(typeof(WarrantyRequestsAdminController), "GARANTIAS_GESTIONAR");
        var update = typeof(ConsultationsController).GetMethod("UpdateStatus")!;
        Assert.Equal("CONSULTAS_ATENDER", update.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
        foreach (var type in new[] { typeof(ConsultationsController), typeof(ReclamosController), typeof(WarrantyRequestsAdminController) })
            foreach (var method in type.GetMethods().Where(x => x.GetCustomAttribute<HttpPostAttribute>() is not null))
                Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        var nav = Read("Views/Shared/_CustomerServiceNavigation.cshtml");
        foreach(var permission in new[] { "CONSULTAS_VER", "RECLAMOS_GESTIONAR", "GARANTIAS_GESTIONAR" }) Assert.Contains(permission, nav);
        Assert.Contains("CLIENTES_VER", Read("Views/WarrantyRequestsAdmin/Index.cshtml"));
    }

    [Fact]
    public void CreatePreservesBindingAndInvoiceLookup()
    {
        var text = Read("Views/Reclamos/Create.cshtml");
        foreach (var field in new[] { "UsuarioId", "FacturaId", "PedidoId", "Categoria", "Prioridad", "Asunto", "Descripcion" })
            Assert.Contains("asp-for=\"" + field + "\"", text);
        Assert.Contains("InvoicesByClient", text); Assert.Contains("_ValidationScriptsPartial", text);
        Assert.Contains("asp-validation-summary=\"All\"", text);
    }

    [Fact]
    public void DetailsKeepInternalResponseResolutionAndOptionalRelationships()
    {
        var consultation = Read("Views/Consultations/Details.cshtml");
        foreach (var field in new[] { "ConsultaId", "Estado", "RespuestaInterna" }) Assert.Contains("name=\"" + field + "\"", consultation);
        Assert.Contains("Model.RespuestaInterna", consultation); Assert.Contains("if (canManage)", consultation);
        var complaint = Read("Views/Reclamos/Details.cshtml");
        foreach (var field in new[] { "PedidoId", "FacturaId", "NumeroFactura", "FacturaTotal", "FechaFactura", "FechaActualizacion", "ResolucionDescripcion", "CerradoPorNombre" }) Assert.Contains("Model." + field, complaint);
        foreach (var field in new[] { "ReclamoId", "Estado", "Resolucion" }) Assert.Contains("name=\"" + field + "\"", complaint);
        Assert.Contains("else if (canManage)", complaint);
        var warranty = Read("Views/WarrantyRequestsAdmin/Index.cshtml");
        foreach (var field in new[] { "garantiaId", "estado", "resolucion" }) Assert.Contains("name=\"" + field + "\"", warranty);
        Assert.Contains("item.FechaResolucion", warranty); Assert.Contains("data-djj-confirm", warranty);
    }

    private static void AssertPolicy(Type type, string code) => Assert.Equal(code, type.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
    private static string Read(string path)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while(directory is not null && !Directory.Exists(Path.Combine(directory.FullName,"Proyecto_Final"))) directory=directory.Parent;
        return File.ReadAllText(Path.Combine(directory!.FullName,"Proyecto_Final",path));
    }
}
