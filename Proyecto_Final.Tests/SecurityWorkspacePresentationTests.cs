using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class SecurityWorkspacePresentationTests
{
    [Theory]
    [InlineData("Roles/Index")] [InlineData("Roles/Create")] [InlineData("Roles/Edit")]
    [InlineData("Permissions/Index")] [InlineData("Permissions/Edit")]
    [InlineData("Audit/Index")] [InlineData("Assistant/Index")]
    public void WorkspacePagesKeepAccessibleTablesAndProtectedPosts(string path)
    {
        var text = Read("Views/" + path + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", text);
        Assert.Single(Regex.Matches(text, "<h1>"));
        Assert.DoesNotMatch("custom-theme|form-control|form-group|col-md-|fa fa-|style=|onclick=|<script>", text);
        foreach (Match form in Regex.Matches(text, "<form[^>]*method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(text, "<table.*?</table>", RegexOptions.Singleline))
        { Assert.Contains("<caption", table.Value); Assert.Contains("scope=\"col\"", table.Value); }
    }

    [Theory]
    [InlineData(null, "No registrado")] [InlineData("  ", "No registrado")]
    [InlineData("Acción legítima · Unicode ñ & <script>", "Acción legítima · Unicode ñ & <script>")]
    [InlineData("password=synthetic", "password=[oculto]")]
    [InlineData("Authorization: Bearer synthetic-token", "Authorization=[oculto]")]
    [InlineData("token=\"synthetic token\"", "token=[oculto]")]
    [InlineData("pbkdf2-sha256$synthetic", "[hash oculto]")]
    [InlineData("eyJabc.def.ghi", "[token_oculto]")]
    public void AuditPresentationRedactsKnownCredentialsWithoutTreatingTextAsMarkup(string? value, string expected)
        => Assert.Equal(expected, SecurityWorkspacePresentation.SafeAuditText(value));

    [Fact]
    public void AuditKeepsTraceabilityAndOnlyExistingFilters()
    {
        var text = Read("Views/Audit/Index.cshtml");
        Assert.DoesNotContain("Html.Raw", text);
        foreach(var field in new[] { "UsuarioNombre", "UsuarioCorreo", "Rol", "Modulo", "Accion", "Descripcion", "DireccionIp", "UserAgent" })
            Assert.Contains("SafeAuditText(item." + field + ")", text);
        foreach(var field in new[] { "AuditoriaId", "UsuarioId", "FechaRegistro" }) Assert.Contains("item."+field, text);
        foreach(var field in new[] { "modulo", "accion", "buscar" }) Assert.Contains("name=\""+field+"\"", text);
        Assert.DoesNotContain("ToUniversalTime", text); Assert.DoesNotContain(" UTC", text);
    }

    [Fact]
    public void ExistingServerPoliciesAndAntiforgeryRemainAuthoritative()
    {
        Assert.Equal("Seguridad", typeof(RolesController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![0]);
        Assert.Equal("Seguridad", typeof(PermissionsController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![0]);
        Assert.Equal("Auditoria", typeof(AuditController).GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![0]);
        Assert.NotNull(typeof(AssistantController).GetCustomAttribute<SessionAuthorizeAttribute>());
        foreach(var type in new[] { typeof(RolesController), typeof(PermissionsController), typeof(AssistantController) })
            foreach(var method in type.GetMethods().Where(m => m.GetCustomAttribute<HttpPostAttribute>() is not null))
            {
                Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
                if(type != typeof(AssistantController)) Assert.Equal(type==typeof(RolesController)?"ROLES_CREAR_EDITAR":"PERMISOS_ASIGNAR", method.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
            }
        Assert.Equal("assistant", typeof(AssistantController).GetMethod("Ask")!.GetCustomAttribute<EnableRateLimitingAttribute>()!.PolicyName);
        Assert.Equal(new[] { "pregunta", "contexto" }, typeof(AssistantController).GetMethod("Ask")!.GetParameters().Select(p=>p.Name));
    }

    [Fact]
    public void FormsKeepBindingAndAdministratorCatalogIsReadOnly()
    {
        foreach(var view in new[] { "Create", "Edit" })
        {
            var text=Read("Views/Roles/"+view+".cshtml");
            foreach(var field in new[] { "Nombre", "Descripcion", "Activo" }) Assert.Contains("asp-for=\""+field+"\"",text);
            Assert.Contains("_ValidationScriptsPartial",text); Assert.Contains("if (canManage)",text);
        }
        var edit=Read("Views/Roles/Edit.cshtml");
        foreach(var field in new[] { "PerfilId", "FechaCreacion", "TotalUsuarios" }) Assert.Contains("asp-for=\""+field+"\" type=\"hidden\"",edit);
        var permissions=Read("Views/Permissions/Edit.cshtml");
        Assert.Contains("name=\"perfilId\"",permissions); Assert.Contains("name=\"permisosSeleccionados\"",permissions);
        Assert.Contains("value=\"@permiso.PermisoId\"",permissions); Assert.Contains("disabled=\"@readOnly\"",permissions);
        Assert.Contains("esAdministrador || !canAssign",permissions); Assert.Contains("if (!readOnly)",permissions);
        Assert.Contains("<legend>@grupo.Modulo</legend>",permissions); Assert.Contains("@permiso.Codigo",permissions);
        Assert.Contains("class=\"djj-choice\"",permissions);
        Assert.Contains("type=\"checkbox\" class=\"djj-checkbox\"",permissions);
        var post=typeof(PermissionsController).GetMethods().Single(m=>m.Name=="Edit" && m.GetCustomAttribute<HttpPostAttribute>() is not null);
        Assert.Equal(new[] { "perfilId", "permisosSeleccionados" },post.GetParameters().Select(p=>p.Name));
    }

    [Theory]
    [InlineData("Administrador",true,true)] [InlineData("Cliente",true,true)]
    [InlineData("Empleado",true,false)] [InlineData("Desconocido",false,false)]
    public void ExistingBaseRoleProtectionDoesNotExpand(string name,bool basis,bool protectedState)
    { var model=new RoleFormViewModel { Nombre=name }; Assert.Equal(basis,model.EsRolBase); Assert.Equal(protectedState,model.BloqueaInactivacion); }

    [Fact]
    public void NavigationUsesServerModuleSemanticsAndAssistantKeepsExternalScript()
    {
        var nav=Read("Views/Shared/_SecurityNavigation.cshtml");
        Assert.Contains("HasModulePermissionAsync(role, \"Seguridad\")",nav);
        Assert.Contains("HasModulePermissionAsync(role, \"Auditoria\")",nav);
        var assistant=Read("Views/Assistant/Index.cshtml");
        Assert.Contains("~/js/stage2/assistant.js",assistant); Assert.Contains("aria-live=\"polite\"",assistant);
        Assert.Contains("maxlength=\"500\"",assistant); Assert.Contains("@Url.Action(\"Ask\", \"Assistant\")",assistant);
        var js=Read("wwwroot/js/stage2/assistant.js");
        Assert.DoesNotMatch("innerHTML|outerHTML|insertAdjacentHTML|DOMParser",js);
        Assert.Contains("textContent",js); Assert.Contains("createElement",js);
    }

    private static string Read(string path)
    {
        var directory=new DirectoryInfo(AppContext.BaseDirectory);
        while(directory is not null && !Directory.Exists(Path.Combine(directory.FullName,"Proyecto_Final"))) directory=directory.Parent;
        return File.ReadAllText(Path.Combine(directory!.FullName,"Proyecto_Final",path));
    }
}
