using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Match = System.Text.RegularExpressions.Match;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Presentation;

namespace Proyecto_Final.Tests;

public sealed class OrderWorkflowPresentationTests
{
    [Theory]
    [InlineData("SellerOrders/Index")]
    [InlineData("SellerOrders/MyOrders")]
    [InlineData("SellerOrders/Confirmation")]
    [InlineData("SellerOrders/RetainedConfirmation")]
    [InlineData("ManagerOrders/Index")]
    [InlineData("ManagerOrders/Review")]
    [InlineData("ManagerOrders/ApproveConfirmation")]
    public void OrderViews_UseWorkspaceAndAccessibleStage2Markup(string route)
    {
        var view = Read("Views/" + route + ".cshtml");
        Assert.Contains("Layout = \"_WorkspaceLayout\"", view);
        Assert.Single(Regex.Matches(view, "<h1>").Cast<Match>());
        Assert.DoesNotMatch("bootstrap|custom-theme|fa fa-|class=\"(?:btn |form-control|container-fluid|row )", view);
        foreach (Match form in Regex.Matches(view, "<form[^>]+method=\"post\".*?</form>", RegexOptions.Singleline))
            Assert.Contains("@Html.AntiForgeryToken()", form.Value);
        foreach (Match table in Regex.Matches(view, "<table.*?</table>", RegexOptions.Singleline))
        {
            Assert.Contains("<caption", table.Value);
            Assert.Contains("scope=\"col\"", table.Value);
        }
    }

    [Theory]
    [InlineData("Retenido", "warning")]
    [InlineData("Rechazado", "danger")]
    [InlineData("Liberado", "success")]
    [InlineData("Aprobado", "success")]
    [InlineData("Entregado", "success")]
    [InlineData("Pendiente", "info")]
    [InlineData("EnProceso", "info")]
    [InlineData("Cancelado", "neutral")]
    [InlineData("Otro", "neutral")]
    [InlineData(null, "neutral")]
    public void BusinessStates_KeepTheirMeaningAndUnknownStatesStayNeutral(string? state, string tone) =>
        Assert.Equal(tone, OrderStatusPresentation.Tone(state));

    [Fact]
    public void SellerCapture_PreservesIndexedFieldsStockAndInlineValidation()
    {
        var view = Read("Views/SellerOrders/Index.cshtml");
        Assert.Contains("asp-controller=\"SellerOrders\" asp-action=\"Create\" method=\"post\"", view);
        foreach (var field in new[] { "ClienteUsuarioId", "TipoEntrega", "DireccionEntrega", "IdentificacionCliente", "Observaciones" })
        {
            Assert.Matches($"<(?:input|select|textarea)[^>]*asp-for=\"{field}\"", view);
            Assert.Contains($"asp-validation-for=\"{field}\"", view);
            Assert.Contains($"label asp-for=\"{field}\"", view);
        }
        foreach (var field in new[] { "ProductoId", "Nombre", "Categoria", "Precio", "Stock", "Cantidad" })
            Assert.Contains($"asp-for=\"Productos[i].{field}\"", view);
        Assert.Contains("label asp-for=\"Productos[i].Cantidad\"", view);
        Assert.Contains("asp-validation-for=\"Productos[i].Cantidad\"", view);
        Assert.Contains("max=\"@Model.Productos[i].Stock\"", view);
        Assert.Contains("asp-validation-summary=\"All\"", view);
        foreach (var id in new[] { "sellerOrderForm", "productsGrid", "productSearch", "selectedItems", "selectedUnits", "selectedTotal", "pendingOrdersPanel", "pendingOrdersList", "connectionStatus", "connectionStatusText", "pendingOrdersCount", "togglePendingOrders", "syncPendingOrders", "clearSyncedOrders", "saveOfflineOrder", "sellerOfflineMessage" })
            Assert.Contains($"id=\"{id}\"", view);
    }

    [Fact]
    public void Review_PreservesSeparatePostBindingsAntiforgeryAndBothConfirmations()
    {
        var view = Read("Views/ManagerOrders/Review.cshtml");
        foreach (var action in new[] { "Approve", "Reject" })
        {
            var form = Regex.Match(view, $"<form asp-action=\"{action}\".*?</form>", RegexOptions.Singleline).Value;
            Assert.Contains("method=\"post\"", form);
            Assert.Contains("@Html.AntiForgeryToken()", form);
            Assert.Contains("data-djj-confirm=", form);
            Assert.Contains(action == "Approve" ? "name=\"pedidoId\"" : "asp-for=\"RechazarForm.PedidoId\"", form);
        }
        Assert.Contains("asp-for=\"RechazarForm.MotivoRechazo\"", view);
        Assert.Contains("asp-validation-for=\"RechazarForm.MotivoRechazo\"", view);
        Assert.Contains("asp-validation-summary=\"All\"", view);
        Assert.Contains("StockActual < d.Cantidad", view);
        Assert.DoesNotContain("onclick=", view);
        var prefix = typeof(ManagerOrdersController).GetMethod("Reject")!.GetParameters()[0].GetCustomAttribute<BindAttribute>();
        Assert.Equal("RechazarForm", prefix!.Prefix);
    }

    [Fact]
    public void ListsAndSharedDetail_KeepServerTotalsTraceabilityAndStockContext()
    {
        var seller = Read("Views/SellerOrders/MyOrders.cshtml");
        foreach (var field in new[] { "PedidoId", "Cliente", "FechaPedido", "Total", "Estado", "NumeroFactura", "FechaActualizacion", "MotivoRechazo" })
            Assert.Contains("pedido." + field, seller);
        var manager = Read("Views/ManagerOrders/Index.cshtml");
        foreach (var field in new[] { "PedidoId", "Cliente", "Correo", "VendedorNombre", "FechaPedido", "CanalPedido", "TipoEntrega", "TotalLineas", "Total" })
            Assert.Contains("p." + field, manager);
        Assert.Contains("name=\"buscar\"", manager);
        Assert.Contains("method=\"get\"", manager);
        var lines = Read("Views/Shared/_OrderWorkflowLines.cshtml");
        foreach (var field in new[] { "Producto", "Cantidad", "PrecioUnitario", "Subtotal", "StockActual", "IsCombo" })
            Assert.Contains("item." + field, lines);
        Assert.Contains("@Model.Total.ToString", lines);
        Assert.DoesNotContain("Sum(", lines);
        Assert.Contains("Suficiente", lines);
        Assert.Contains("Insuficiente", lines);
        var summary = Read("Views/Shared/_OrderWorkflowSummary.cshtml");
        foreach (var field in new[] { "Cliente", "Correo", "FechaPedido", "Estado", "Total", "TipoEntrega", "DireccionEntrega", "Observaciones", "MotivoRechazo" })
            Assert.Contains("Model." + field, summary);
        Assert.DoesNotContain("VendedorNombre", summary); // Not available in this contract.
        Assert.DoesNotContain("Impuesto", summary);
    }

    [Fact]
    public void Confirmations_DoNotInventInvoiceOrRetainedStateOnLaterGet()
    {
        var confirmation = Read("Views/SellerOrders/Confirmation.cshtml");
        Assert.Contains("Model.HasInvoice && !string.IsNullOrWhiteSpace(numeroFactura)", confirmation);
        var retained = Read("Views/SellerOrders/RetainedConfirmation.cshtml");
        Assert.Contains("if (Model.Estado == \"Retenido\")", retained);
        Assert.DoesNotContain("umbral", retained, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("_OrderWorkflowSummary", retained);
        Assert.Contains("_OrderWorkflowLines", retained);
    }

    [Fact]
    public void Authorization_RemainsOnServerAndWorkspaceLinksUseTheSameCapabilities()
    {
        foreach (var (controller, capability) in new[] { (typeof(SellerOrdersController), "VENTA_MOVIL_CREAR"), (typeof(ManagerOrdersController), "PEDIDOS_AUTORIZAR_RECHAZAR") })
        {
            Assert.Equal(capability, controller.GetCustomAttribute<AdminAuthorizeAttribute>()!.Arguments![1]);
            foreach (var method in controller.GetMethods().Where(m => m.IsDefined(typeof(HttpPostAttribute))))
                Assert.NotNull(method.GetCustomAttribute<ValidateAntiForgeryTokenAttribute>());
        }
        var layout = Read("Views/Shared/_WorkspaceLayout.cshtml");
        Assert.Contains("Can(\"VENTA_MOVIL_CREAR\")", layout);
        Assert.Contains("Can(\"PEDIDOS_AUTORIZAR_RECHAZAR\")", layout);
        Assert.Contains("if (canSellerOrders)", layout);
        Assert.Contains("if (canManagerOrders)", layout);
        Assert.Contains("asp-controller=\"@workspaceController\"", layout);
        Assert.Contains("IsCurrent(\"SellerOrders\") && canSellerOrders ? \"SellerOrders\"", layout);
        Assert.Contains("IsCurrent(\"ManagerOrders\") && canManagerOrders ? \"ManagerOrders\"", layout);
        Assert.Single(Regex.Matches(layout, "asp-controller=\"SellerOrders\"").Cast<Match>());
        Assert.Single(Regex.Matches(layout, "asp-controller=\"ManagerOrders\"").Cast<Match>());
        Assert.Contains("HasModulePermissionAsync(role, \"Pedidos\")", Read("Views/Shared/_OrderWorkflowDetailLink.cshtml"));
        Assert.Contains("SellerOwnsOrderAsync(id, vendedorId)", Read("Controllers/SellerOrdersController.cs"));
    }

    [Theory]
    [InlineData(0, "", false)]
    [InlineData(42, "FAC-42", true)]
    public void ApprovalConfirmation_UsesExistingTempDataWithoutExecutingApproval(int id, string invoice, bool hasResult)
    {
        // This GET action does not use the service: no SQL or operational POST is executed.
        var controller = new ManagerOrdersController(null!, NullLogger<ManagerOrdersController>.Instance);
        controller.TempData = new TempDataDictionary(new DefaultHttpContext(), Mock.Of<ITempDataProvider>());
        if (id > 0) { controller.TempData["Confirm_PedidoId"] = id; controller.TempData["Confirm_NumeroFactura"] = invoice; }
        var result = controller.ApproveConfirmation();
        if (!hasResult) { Assert.Equal("Index", Assert.IsType<RedirectToActionResult>(result).ActionName); return; }
        var model = Assert.IsType<ManagerApproveResultViewModel>(Assert.IsType<ViewResult>(result).Model);
        Assert.Equal(id, model.PedidoId);
        Assert.Equal(invoice, model.NumeroFactura);
        Assert.Equal("Liberado", model.Estado);
    }

    private static string Read(string path)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx"))) directory = directory.Parent;
        return File.ReadAllText(Path.Combine(directory?.FullName ?? throw new DirectoryNotFoundException(), "Proyecto_Final", path));
    }
}
