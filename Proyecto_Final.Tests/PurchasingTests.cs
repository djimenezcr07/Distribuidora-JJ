using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Tests;

public sealed class PurchasingTests
{
    [Fact]
    public void PurchaseOrder_RequiresAtLeastOneSelectedProduct()
    {
        var model = ValidOrder();
        model.Productos[0].Seleccionado = false;

        Assert.Contains(Validate(model), result => result.ErrorMessage!.Contains("al menos", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void PurchaseOrder_RejectsDuplicateProducts()
    {
        var model = ValidOrder();
        model.Productos.Add(new PurchaseOrderLineSelectionViewModel
        {
            ProductoId = model.Productos[0].ProductoId,
            Seleccionado = true,
            Cantidad = 2,
            PrecioUnitario = 900m
        });

        Assert.Contains(Validate(model), result => result.ErrorMessage!.Contains("una sola vez", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void PurchaseOrder_RejectsMoreThanFiftySelectedLines()
    {
        var model = ValidOrder();
        model.Productos = Enumerable.Range(1, PurchasingPolicy.MaximumLinesPerOrder + 1)
            .Select(id => new PurchaseOrderLineSelectionViewModel
            {
                ProductoId = id,
                Seleccionado = true,
                Cantidad = 1,
                PrecioUnitario = 1m
            })
            .ToList();

        Assert.Contains(Validate(model), result => result.ErrorMessage!.Contains("50 líneas", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void NormalizeLines_IsDeterministicAndDoesNotMutateInput()
    {
        var first = new PurchaseOrderLineSelectionViewModel { ProductoId = 9, Seleccionado = true, Cantidad = 2, PrecioUnitario = 10.125m };
        var second = new PurchaseOrderLineSelectionViewModel { ProductoId = 3, Seleccionado = true, Cantidad = 1, PrecioUnitario = 20m };

        var normalized = PurchasingPolicy.NormalizeLines([first, second]);

        Assert.Equal([3, 9], normalized.Select(line => line.ProductoId));
        Assert.Equal(10.13m, normalized[1].PrecioUnitario);
        Assert.Equal(10.125m, first.PrecioUnitario);
    }

    [Theory]
    [InlineData(115, 100, 15, false)]
    [InlineData(116, 100, 16, true)]
    [InlineData(80, 100, -20, true)]
    public void PriceVariation_UsesAbsoluteFifteenPercentThreshold(double current, double previous, double expected, bool significant)
    {
        var variation = PurchasingPolicy.CalculatePriceVariation((decimal)current, (decimal)previous);
        Assert.Equal((decimal)expected, variation);
        Assert.Equal(significant, PurchasingPolicy.IsSignificantPriceVariation(variation));
    }

    [Theory]
    [InlineData(typeof(SuppliersController), "Index", "PROVEEDORES_VER")]
    [InlineData(typeof(SuppliersController), "Save", "PROVEEDORES_GESTIONAR")]
    [InlineData(typeof(PurchaseOrdersController), "Index", "COMPRAS_ORDENES_VER")]
    [InlineData(typeof(PurchaseOrdersController), "Create", "COMPRAS_ORDENES_CREAR")]
    [InlineData(typeof(PurchaseOrdersController), "Suggestions", "COMPRAS_SUGERENCIAS_VER")]
    [InlineData(typeof(PurchaseOrdersController), "Receive", "COMPRAS_ORDENES_RECIBIR")]
    [InlineData(typeof(PurchaseOrdersController), "CloseWithDiscrepancy", "COMPRAS_ORDENES_CERRAR")]
    [InlineData(typeof(PurchaseOrdersController), "Cancel", "COMPRAS_ORDENES_CANCELAR")]
    [InlineData(typeof(PriceHistoryController), "Index", "COMPRAS_PRECIOS_VER")]
    public void PurchasingActions_RequireExactPermission(Type controller, string method, string permission)
    {
        var actions = controller.GetMethods().Where(candidate => candidate.Name == method).ToArray();
        Assert.NotEmpty(actions);
        Assert.All(actions, action => Assert.Contains(
            action.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true).Cast<AdminAuthorizeAttribute>(),
            attribute => Equals(attribute.Arguments![1], permission)));
    }

    [Theory]
    [InlineData(typeof(SuppliersController), "Save")]
    [InlineData(typeof(SuppliersController), "ChangeStatus")]
    [InlineData(typeof(PurchaseOrdersController), "Create")]
    [InlineData(typeof(PurchaseOrdersController), "Receive")]
    [InlineData(typeof(PurchaseOrdersController), "CloseWithDiscrepancy")]
    [InlineData(typeof(PurchaseOrdersController), "Cancel")]
    public void PurchasingWrites_RequireAntiforgeryAndRateLimit(Type controller, string method)
    {
        var action = controller.GetMethods().Single(candidate =>
            candidate.Name == method && candidate.GetCustomAttributes(typeof(HttpPostAttribute), true).Any());

        Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true));
        Assert.NotEmpty(action.GetCustomAttributes(typeof(EnableRateLimitingAttribute), true));
    }

    [Fact]
    public void Migration0013_DeclaresIncrementalLedgerVerifyAndCriticalContracts()
    {
        var root = FindRepositoryRoot();
        var migration = File.ReadAllText(Path.Combine(root, "database", "migrations", "0013_purchasing_suppliers_orders.sql"));
        var verify = File.ReadAllText(Path.Combine(root, "database", "migrations", "0013_purchasing_suppliers_orders.verify.sql"));

        Assert.Contains("0013_purchasing_suppliers_orders", migration, StringComparison.Ordinal);
        Assert.Contains("SchemaMigrationHistory", migration, StringComparison.Ordinal);
        Assert.Contains("sp_Compras_RecibirDetalle", migration, StringComparison.Ordinal);
        Assert.Contains("ComprasRecepcionOperaciones", migration, StringComparison.Ordinal);
        Assert.Contains("CantidadRecibida <= CantidadOrdenada", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("0007_compras", migration, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("THROW", verify, StringComparison.Ordinal);
    }

    private static PurchaseOrderFormViewModel ValidOrder() => new()
    {
        ProveedorId = 3,
        Productos =
        [
            new PurchaseOrderLineSelectionViewModel
            {
                ProductoId = 7,
                Seleccionado = true,
                Cantidad = 4,
                PrecioUnitario = 800m
            }
        ]
    };

    private static List<ValidationResult> Validate(object model)
    {
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(model, new ValidationContext(model), results, true);
        return results;
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Proyecto_Final.slnx")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new DirectoryNotFoundException("No se encontró la raíz de la solución.");
    }
}
