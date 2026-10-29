using System.Text.RegularExpressions;

namespace Proyecto_Final.Tests;

public sealed class Stage2DesignSystemTests
{
    private static readonly string[][] MigratedStorefrontViews =
    [
        ["Views", "Home", "Index.cshtml"], ["Views", "Home", "Shop.cshtml"], ["Views", "Home", "Detail.cshtml"], ["Views", "Home", "ComboDetail.cshtml"],
        ["Views", "Cart", "Index.cshtml"], ["Views", "Cart", "Checkout.cshtml"], ["Views", "Cart", "Confirmation.cshtml"],
        ["Views", "ClientPortal", "Index.cshtml"], ["Views", "ClientPortal", "Detail.cshtml"], ["Views", "ClientPortal", "Invoice.cshtml"], ["Views", "ClientPortal", "Statement.cshtml"], ["Views", "ClientPortal", "Warranty.cshtml"], ["Views", "ClientPortal", "Warranties.cshtml"],
        ["Views", "Profile", "Edit.cshtml"], ["Views", "Account", "Login.cshtml"], ["Views", "Account", "Registro.cshtml"], ["Views", "Account", "ForgotPassword.cshtml"], ["Views", "Account", "ResetPassword.cshtml"]
    ];
    private static readonly string[][] MigratedBackofficeViews =
    [
        ["Views", "Inventory", "Index.cshtml"], ["Views", "Inventory", "Create.cshtml"], ["Views", "Inventory", "Edit.cshtml"],
        ["Views", "Inventory", "Movements.cshtml"], ["Views", "Inventory", "RegisterMovement.cshtml"], ["Views", "Inventory", "TransformStock.cshtml"],
        ["Views", "InventoryIntelligence", "Index.cshtml"], ["Views", "OrdersAdmin", "Index.cshtml"], ["Views", "OrdersAdmin", "Detail.cshtml"],
        ["Views", "Suppliers", "Index.cshtml"], ["Views", "PurchaseOrders", "Index.cshtml"], ["Views", "PurchaseOrders", "Create.cshtml"],
        ["Views", "PurchaseOrders", "Detail.cshtml"], ["Views", "PriceHistory", "Index.cshtml"]
        , ["Views", "Combos", "Index.cshtml"], ["Views", "Returns", "Index.cshtml"], ["Views", "Returns", "Quarantine.cshtml"]
    ];
    private static readonly string[][] MigratedFinanceViews =
    [
        ["Views", "Finance", "Index.cshtml"], ["Views", "Finance", "Liquidate.cshtml"],
        ["Views", "Credits", "Index.cshtml"], ["Views", "Credits", "Details.cshtml"],
        ["Views", "AccountsReceivableAdmin", "Index.cshtml"], ["Views", "AccountsReceivableAdmin", "Detail.cshtml"],
        ["Views", "Clients", "Index.cshtml"], ["Views", "Clients", "Create.cshtml"], ["Views", "Clients", "Edit.cshtml"], ["Views", "Clients", "Details.cshtml"],
        ["Views", "Budgets", "Index.cshtml"], ["Views", "Budgets", "Create.cshtml"], ["Views", "Budgets", "Edit.cshtml"], ["Views", "Budgets", "Details.cshtml"],
        ["Views", "Expenses", "Index.cshtml"], ["Views", "Expenses", "Create.cshtml"], ["Views", "Expenses", "Edit.cshtml"], ["Views", "Expenses", "Details.cshtml"], ["Views", "Expenses", "Accounts.cshtml"],
        ["Views", "BudgetComparison", "Index.cshtml"], ["Views", "Billing", "Index.cshtml"], ["Views", "Billing", "Detail.cshtml"]
    ];
    private static readonly string[][] MigratedHrViews =
    [
        ["Views", "Employees", "Index.cshtml"], ["Views", "Employees", "Create.cshtml"], ["Views", "Employees", "Edit.cshtml"],
        ["Views", "Employees", "Details.cshtml"], ["Views", "Employees", "LeaveRequests.cshtml"],
        ["Views", "EmployeePortal", "Index.cshtml"], ["Views", "Attendance", "Index.cshtml"], ["Views", "MyAttendance", "Index.cshtml"],
        ["Views", "Payroll", "Index.cshtml"], ["Views", "PaySlips", "Index.cshtml"],
        ["Views", "MyPaySlips", "Index.cshtml"], ["Views", "MyPaySlips", "Details.cshtml"]
    ];

    [Fact]
    public void PilotViews_UseOnlyTheirStage2Layouts()
    {
        var home = ReadProject("Views", "Home", "Index.cshtml");
        var admin = ReadProject("Views", "Admin", "Index.cshtml");

        Assert.Contains("Layout = \"_StorefrontLayout\"", home, StringComparison.Ordinal);
        Assert.Contains("Layout = \"_WorkspaceLayout\"", admin, StringComparison.Ordinal);
        Assert.DoesNotContain("custom-theme.css", home, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("custom-theme.css", admin, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("fa fa-", home, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("fa fa-", admin, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Stage2Layouts_AreAccessibleAndDoNotLoadLegacyVisualDependencies()
    {
        var layouts = new[] { "_StorefrontLayout.cshtml", "_WorkspaceLayout.cshtml", "_FieldLayout.cshtml" }
            .Select(name => ReadProject("Views", "Shared", name))
            .ToArray();

        Assert.All(layouts, layout =>
        {
            Assert.Contains("djj-skip-link", layout, StringComparison.Ordinal);
            Assert.Contains("id=\"djj-main-content\"", layout, StringComparison.Ordinal);
            Assert.Contains("_DjjIconSprite", layout, StringComparison.Ordinal);
            Assert.DoesNotContain("bootstrap", layout, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("font-awesome", layout, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("custom-theme.css", layout, StringComparison.OrdinalIgnoreCase);
        });
        Assert.Contains("aria-expanded=\"false\"", layouts[0], StringComparison.Ordinal);
        Assert.Contains("aria-controls=\"djj-workspace-sidebar\"", layouts[1], StringComparison.Ordinal);
        Assert.Contains("viewport-fit=cover", layouts[2], StringComparison.Ordinal);
    }

    [Fact]
    public void Stage2Css_UsesPrefixedTokensAndIntroducesNoImportantOverrides()
    {
        var cssRoot = ProjectPath("wwwroot", "css", "stage2");
        var files = Directory.EnumerateFiles(cssRoot, "*.css").ToArray();

        Assert.Equal(new[] { "base.css", "components.css", "field.css", "public-surfaces.css", "storefront.css", "tokens.css", "utilities.css", "workspace.css" },
            files.Select(Path.GetFileName).OrderBy(name => name, StringComparer.Ordinal));
        Assert.All(files, path => Assert.DoesNotContain("!important", File.ReadAllText(path), StringComparison.OrdinalIgnoreCase));
        Assert.All(files, path => Assert.DoesNotMatch(new Regex(@"(?m)^\s*--(?!djj-)[a-zA-Z]", RegexOptions.CultureInvariant), File.ReadAllText(path)));
    }

    [Fact]
    public void EveryPilotPhosphorReference_ExistsInTheLocalSprite()
    {
        var sprite = ReadProject("Views", "Shared", "_DjjIconSprite.cshtml");
        var sources = MigratedStorefrontViews.Select(ReadProject).Concat(MigratedBackofficeViews.Select(ReadProject)).Concat(MigratedFinanceViews.Select(ReadProject)).Concat(MigratedHrViews.Select(ReadProject)).Concat(new[]
        {
            ReadProject("Views", "Admin", "Index.cshtml"),
            ReadProject("Views", "Shared", "_StorefrontLayout.cshtml"),
            ReadProject("Views", "Shared", "_WorkspaceLayout.cshtml"),
            ReadProject("Views", "Shared", "_FieldLayout.cshtml")
        });
        var references = sources.SelectMany(source => Regex.Matches(source, "#djj-icon-([a-z0-9-]+)").Select(match => match.Groups[1].Value)).Distinct();

        Assert.All(references, icon => Assert.Contains($"id=\"djj-icon-{icon}\"", sprite, StringComparison.Ordinal));
    }

    [Fact]
    public void MigratedStorefrontFlow_HasNoLegacyVisualDependencies()
    {
        Assert.All(MigratedStorefrontViews.Select(ReadProject), view =>
        {
            Assert.Contains("Layout", view, StringComparison.Ordinal);
            Assert.DoesNotContain("s3-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("s4-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("fa fa-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("font-awesome", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("custom-theme.css", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("logo-icon.png", view, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact]
    public void StorefrontForms_ExposeAccessibleValidationAndPreservePostContracts()
    {
        var checkout = ReadProject("Views", "Cart", "Checkout.cshtml");
        var warranty = ReadProject("Views", "ClientPortal", "Warranty.cshtml");
        var login = ReadProject("Views", "Account", "Login.cshtml");

        Assert.All(new[] { checkout, warranty, login }, view =>
        {
            Assert.Contains("asp-validation-summary", view, StringComparison.Ordinal);
            Assert.Contains("role=\"alert\"", view, StringComparison.Ordinal);
            Assert.Contains("data-djj-validation-summary", view, StringComparison.Ordinal);
        });
        Assert.Contains("asp-for=\"OperationToken\"", checkout, StringComparison.Ordinal);
        Assert.Contains("id=\"provincia\"", checkout, StringComparison.Ordinal);
        Assert.Contains("id=\"canton\"", checkout, StringComparison.Ordinal);
        Assert.Contains("id=\"distrito\"", checkout, StringComparison.Ordinal);
        Assert.Contains("aria-describedby=\"Provincia-error\"", checkout, StringComparison.Ordinal);
        Assert.Contains("aria-describedby=\"ReferenciaPago-hint ReferenciaPago-error\"", checkout, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminDashboard_HasThreeProminentActionsAndElevenSecondaryDestinations()
    {
        var admin = ReadProject("Views", "Admin", "Index.cshtml");
        Assert.Equal(3, Regex.Matches(admin, "djj-admin-quick-link--primary").Count);
        Assert.Contains("Ver los otros 11 módulos", admin, StringComparison.Ordinal);
        Assert.Contains("asp-controller=\"AccountsReceivableAdmin\"", admin, StringComparison.Ordinal);
    }

    [Fact]
    public void MigratedBackofficeCore_UsesWorkspaceAndHasNoLegacyVisualDependencies()
    {
        Assert.All(MigratedBackofficeViews.Select(ReadProject), view =>
        {
            Assert.Contains("_WorkspaceLayout", view, StringComparison.Ordinal);
            Assert.DoesNotContain("s3-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("s4-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("fa fa-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("custom-theme.css", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("logo-icon.png", view, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact]
    public void BackofficeCore_PreservesOperationalPostContractsAndAccessibleTables()
    {
        var movement = ReadProject("Views", "Inventory", "RegisterMovement.cshtml");
        var purchase = ReadProject("Views", "PurchaseOrders", "Create.cshtml");
        var receipt = ReadProject("Views", "PurchaseOrders", "Detail.cshtml");

        Assert.Contains("id=\"tipoMovimiento\"", movement, StringComparison.Ordinal);
        Assert.Contains("id=\"generaGasto\"", movement, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"TokenOperacion\"", purchase, StringComparison.Ordinal);
        Assert.Contains("id=\"purchase-lines\"", purchase, StringComparison.Ordinal);
        Assert.Contains("name=\"CantidadRecibidaAhora\"", receipt, StringComparison.Ordinal);
        Assert.All(MigratedBackofficeViews.Select(ReadProject), view => Assert.DoesNotContain("<table class=\"table", view, StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void WorkspaceNavigation_GroupsOperationalDomainsWithoutBypassingPermissions()
    {
        var layout = ReadProject("Views", "Shared", "_WorkspaceLayout.cshtml");
        Assert.Contains("Ventas y pedidos", layout, StringComparison.Ordinal);
        Assert.Contains("<li class=\"djj-workspace-nav__label\">Inventario</li>", layout, StringComparison.Ordinal);
        Assert.Contains("<li class=\"djj-workspace-nav__label\">Compras</li>", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canInventory)", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canPurchases)", layout, StringComparison.Ordinal);
    }

    [Fact]
    public void MigratedFinanceDomains_UseWorkspaceAndHaveNoLegacyVisualDependencies()
    {
        Assert.All(MigratedFinanceViews.Select(ReadProject), view =>
        {
            Assert.Contains("_WorkspaceLayout", view, StringComparison.Ordinal);
            Assert.DoesNotContain("s3-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("s4-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("fa fa-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("font-awesome", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("custom-theme.css", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("logo-icon.png", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("<table class=\"table", view, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact]
    public void FinanceForms_PreserveSensitivePostContractsAndAccessibleRecovery()
    {
        var liquidation = ReadProject("Views", "Finance", "Liquidate.cshtml");
        var credit = ReadProject("Views", "AccountsReceivableAdmin", "Detail.cshtml");
        var client = ReadProject("Views", "Clients", "Details.cshtml");
        var budget = ReadProject("Views", "Budgets", "Details.cshtml");
        var expense = ReadProject("Views", "Expenses", "Details.cshtml");
        var expenseForm = ReadProject("Views", "Expenses", "_OperatingForm.cshtml");

        Assert.Contains("Comprobantes[@i].Monto", liquidation, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"SettingsForm.UsuarioId\"", credit, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"MovementForm.UsuarioId\"", credit, StringComparison.Ordinal);
        Assert.Contains("name=\"returnTo\" value=\"details\"", client, StringComparison.Ordinal);
        Assert.Contains("asp-action=\"Approve\"", budget, StringComparison.Ordinal);
        Assert.Contains("asp-action=\"Reject\"", budget, StringComparison.Ordinal);
        Assert.Contains("asp-action=\"Pay\"", expense, StringComparison.Ordinal);
        Assert.Contains("asp-action=\"Cancel\"", expense, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"OperationToken\"", expenseForm, StringComparison.Ordinal);
        Assert.Contains("data-expense-money", expenseForm, StringComparison.Ordinal);
        Assert.Contains("data-expense-total", expenseForm, StringComparison.Ordinal);
        Assert.All(new[] { liquidation, credit }, view =>
        {
            Assert.Contains("role=\"alert\"", view, StringComparison.Ordinal);
            Assert.Contains("data-djj-validation-summary", view, StringComparison.Ordinal);
        });
    }

    [Fact]
    public void FinancePresentation_UsesExplicitMoneyAndContextualConfirmations()
    {
        var sources = MigratedFinanceViews.Select(ReadProject).ToArray();
        Assert.All(sources.Where(view => view.Contains("<table", StringComparison.OrdinalIgnoreCase)), view =>
            Assert.Contains("djj-table", view, StringComparison.Ordinal));

        var budget = ReadProject("Views", "Budgets", "Details.cshtml");
        var expense = ReadProject("Views", "Expenses", "Details.cshtml");
        var liquidation = ReadProject("Views", "Finance", "Liquidate.cshtml");
        Assert.Contains("₡", budget, StringComparison.Ordinal);
        Assert.Contains("data-djj-confirm", budget, StringComparison.Ordinal);
        Assert.Contains("data-djj-confirm", expense, StringComparison.Ordinal);
        Assert.Contains("data-djj-confirm", liquidation, StringComparison.Ordinal);
        Assert.DoesNotContain("!important", string.Concat(sources), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WorkspaceNavigation_UsesRealFinancialPermissions()
    {
        var layout = ReadProject("Views", "Shared", "_WorkspaceLayout.cshtml");
        Assert.Contains("Can(\"CREDITOS_VER\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"FACTURACION_VER\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"LIQUIDACION_FINANCIERA\")", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canCredits)", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canBilling)", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canFinance)", layout, StringComparison.Ordinal);
    }

    [Fact]
    public void MigratedHrDomains_UseWorkspaceAndHaveNoLegacyVisualDependencies()
    {
        Assert.All(MigratedHrViews.Select(ReadProject), view =>
        {
            Assert.Contains("_WorkspaceLayout", view, StringComparison.Ordinal);
            Assert.DoesNotContain("s3-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("s4-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("fa fa-", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("font-awesome", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("custom-theme.css", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("sprint3-employees.css", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("<table class=\"table", view, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("<style", view, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact]
    public void EmployeePresentation_MinimizesListExposureAndPreservesWriteContracts()
    {
        var index = ReadProject("Views", "Employees", "Index.cshtml");
        var create = ReadProject("Views", "Employees", "Create.cshtml");
        var edit = ReadProject("Views", "Employees", "Edit.cshtml");
        var details = ReadProject("Views", "Employees", "Details.cshtml");
        var requests = ReadProject("Views", "Employees", "LeaveRequests.cshtml");

        Assert.DoesNotContain("item.Salario", index, StringComparison.Ordinal);
        Assert.DoesNotContain("item.Correo", index, StringComparison.Ordinal);
        Assert.DoesNotContain("item.Telefono", index, StringComparison.Ordinal);
        Assert.Contains("Can(\"EMPLEADOS_CREAR\")", index, StringComparison.Ordinal);
        Assert.Contains("Can(\"EMPLEADOS_EDITAR\")", index, StringComparison.Ordinal);
        Assert.Contains("asp-validation-summary", create, StringComparison.Ordinal);
        Assert.Contains("data-djj-validation-summary", edit, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"RowVersionBase64\"", edit, StringComparison.Ordinal);
        Assert.Contains("name=\"EmpleadoId\"", details, StringComparison.Ordinal);
        Assert.Contains("name=\"TareaId\"", details, StringComparison.Ordinal);
        Assert.Contains("name=\"SolicitudId\"", requests, StringComparison.Ordinal);
        Assert.Contains("value=\"Cancelada\"", requests, StringComparison.Ordinal);
        Assert.Contains("value=\"Pendiente\"", requests, StringComparison.Ordinal);
        Assert.Contains("data-djj-confirm", requests, StringComparison.Ordinal);
        Assert.All(new[] { create, edit, details, requests }, view => Assert.Contains("AntiForgeryToken", view, StringComparison.Ordinal));
    }

    [Fact]
    public void AttendanceAndPayroll_PreserveSensitivePostContracts()
    {
        var attendance = ReadProject("Views", "Attendance", "Index.cshtml");
        var mine = ReadProject("Views", "MyAttendance", "Index.cshtml");
        var payroll = ReadProject("Views", "Payroll", "Index.cshtml");
        var slips = ReadProject("Views", "PaySlips", "Index.cshtml");

        Assert.Contains("name=\"RowVersionBase64\"", attendance, StringComparison.Ordinal);
        Assert.Contains("name=\"Decision\" value=\"Aprobada\"", attendance, StringComparison.Ordinal);
        Assert.Contains("name=\"Decision\" value=\"Rechazada\"", attendance, StringComparison.Ordinal);
        Assert.Contains("asp-for=\"Form.IdempotencyKey\"", mine, StringComparison.Ordinal);
        Assert.Contains("name=\"submit\" value=\"false\"", mine, StringComparison.Ordinal);
        Assert.Contains("name=\"submit\" value=\"true\"", mine, StringComparison.Ordinal);
        Assert.Contains("name=\"IdempotencyKey\"", payroll, StringComparison.Ordinal);
        Assert.Contains("name=\"CalculoId\"", payroll, StringComparison.Ordinal);
        Assert.Contains("name=\"RowVersionBase64\"", payroll, StringComparison.Ordinal);
        Assert.Contains("Can(\"PLANILLA_APROBAR\")", payroll, StringComparison.Ordinal);
        Assert.Contains("Can(\"PLANILLA_PAGAR\")", payroll, StringComparison.Ordinal);
        Assert.Contains("Can(\"PLANILLA_REVERTIR\")", payroll, StringComparison.Ordinal);
        Assert.Contains("name=\"IdempotencyKey\"", slips, StringComparison.Ordinal);
        Assert.All(new[] { attendance, mine, payroll, slips }, view => Assert.Contains("AntiForgeryToken", view, StringComparison.Ordinal));
    }

    [Fact]
    public void WorkspaceNavigation_UsesRealHrPermissionsAndEmployeeRelationship()
    {
        var layout = ReadProject("Views", "Shared", "_WorkspaceLayout.cshtml");
        Assert.Contains("Can(\"EMPLEADOS_VER\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"EMPLEADOS_SOLICITUDES\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"RRHH_JORNADAS_APROBAR\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"PLANILLA_VER\")", layout, StringComparison.Ordinal);
        Assert.Contains("Can(\"PLANILLA_BOLETAS_GESTIONAR\")", layout, StringComparison.Ordinal);
        Assert.Contains("EmployeeRelationshipService.IsEmployeeAsync", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canPayroll)", layout, StringComparison.Ordinal);
        Assert.Contains("@if (canManagePaySlips)", layout, StringComparison.Ordinal);
    }

    [Fact]
    public void PaySlipDetail_IsBrandedPrivateAndPrintable()
    {
        var detail = ReadProject("Views", "MyPaySlips", "Details.cshtml");
        var workspace = ReadProject("wwwroot", "css", "stage2", "workspace.css");
        Assert.Contains("Distribuidora JJ", detail, StringComparison.Ordinal);
        Assert.Contains("Licorera - Distribuidora", detail, StringComparison.Ordinal);
        Assert.Contains("data-djj-print-document", detail, StringComparison.Ordinal);
        Assert.Contains("data-djj-screen-only", detail, StringComparison.Ordinal);
        Assert.Contains("@media print", workspace, StringComparison.Ordinal);
        Assert.DoesNotContain("logo-icon.png", detail, StringComparison.OrdinalIgnoreCase);
    }

    private static string ReadProject(params string[] parts) => File.ReadAllText(ProjectPath(parts));

    private static string ProjectPath(params string[] parts) =>
        Path.Combine(new[] { RepositoryRoot(), "Proyecto_Final" }.Concat(parts).ToArray());

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz de la solución.");
    }
}
