using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class Sprint4DomainTests
{
    [Fact]
    public void AnnualDistribution_PreservesExactCents()
    {
        var months = BudgetRules.DistributeAnnual(1000m);
        Assert.Equal(12, months.Count);
        Assert.Equal(1000m, months.Sum());
        Assert.Equal(83.37m, months[^1]);
    }

    [Theory]
    [InlineData("Presentado", 10, 11, true)]
    [InlineData("Presentado", 10, 10, false)]
    [InlineData("Borrador", 10, 11, false)]
    public void BudgetApproval_EnforcesStateAndSeparation(string state, int creator, int approver, bool expected) =>
        Assert.Equal(expected, BudgetRules.CanApprove(state, creator, approver));

    [Fact]
    public void BudgetDetails_EmptyLinesAndAuditAreValidForANewDraft()
    {
        var model = new BudgetDetailsViewModel
        {
            Budget = new BudgetListItemViewModel { Status = "Borrador", AnnualAmount = 100m },
            Details = Array.Empty<BudgetDetailLineViewModel>(),
            Audit = Array.Empty<BudgetAuditViewModel>()
        };

        Assert.True(model.CanEdit);
        Assert.Empty(model.Details);
        Assert.Equal(0m, model.Details.Sum(line => line.AllocatedAmount));
    }

    [Fact]
    public void ExpenseTotal_IsCalculatedServerSideEquivalentWithDecimalPrecision() =>
        Assert.Equal(113.25m, ExpenseRules.CalculateTotal(100.22m, 13.03m));

    [Theory]
    [InlineData(79.99, "Normal")]
    [InlineData(80, "Advertencia")]
    [InlineData(90, "Crítico")]
    [InlineData(100, "Excedido")]
    public void ConsumptionLevels_UseRequiredThresholds(double percentage, string expected) =>
        Assert.Equal(expected, ExpenseRules.ConsumptionLevel((decimal)percentage));

    [Fact]
    public void Projection_IsDeterministicAndNotAiBased()
    {
        Assert.Equal(2400m, BudgetComparisonCalculator.Projection(800m, 4));
        Assert.Equal(25m, BudgetComparisonCalculator.Percentage(50m, 200m));
    }

    [Theory]
    [InlineData("=2+3")]
    [InlineData("+cmd|' /C calc'!A0")]
    [InlineData("-1")]
    [InlineData("@SUM(A1:A2)")]
    public void CsvExport_NeutralizesSpreadsheetFormulaInjection(string value)
    {
        var cell = CsvExportSanitizer.Cell(value);
        Assert.StartsWith("\"'", cell);
    }

    [Fact]
    public void BusinessDate_UsesCostaRicaRatherThanUtcDate()
    {
        var utc = new DateTimeOffset(2026, 7, 22, 5, 30, 0, TimeSpan.Zero);
        Assert.Equal(new DateTime(2026, 7, 21), DocumentExpirationPolicy.BusinessDate(utc));
    }

    [Theory]
    [InlineData(true, false, "Inactivo")]
    [InlineData(false, true, "No vence")]
    [InlineData(false, false, "Vencido")]
    public void DocumentExpiration_ClassifiesImportantStates(bool inactive, bool noExpiration, string expected)
    {
        var businessDate = new DateTime(2026, 7, 22);
        DateTime? expiration = noExpiration ? null : businessDate.AddDays(-1);
        Assert.Equal(expected, DocumentExpirationPolicy.Classify(!inactive, noExpiration, expiration, businessDate, 30));
    }

    [Fact]
    public void Combo_RequiresAtLeastOneSelectedComponent()
    {
        var model = new ComboFormViewModel
        {
            Nombre = "Combo prueba",
            Precio = 1000m,
            Productos = [new ComboProductSelectionViewModel { ProductoId = 1, Cantidad = 1 }]
        };

        Assert.Contains(Validate(model), result => result.MemberNames.Contains(nameof(model.Productos)));
    }

    [Fact]
    public void Combo_RejectsDuplicateProducts()
    {
        var model = new ComboFormViewModel
        {
            Nombre = "Combo duplicado",
            Precio = 1000m,
            Productos =
            [
                new ComboProductSelectionViewModel { ProductoId = 7, Cantidad = 1, Seleccionado = true },
                new ComboProductSelectionViewModel { ProductoId = 7, Cantidad = 2, Seleccionado = true }
            ]
        };

        Assert.Contains(Validate(model), result => result.ErrorMessage!.Contains("repetirse", StringComparison.OrdinalIgnoreCase));
    }

    [Theory]
    [InlineData(0, 1, false)]
    [InlineData(3, 0, false)]
    [InlineData(3, 2, true)]
    public void StoreCombo_AvailabilityRequiresStockAndComponents(int stock, int components, bool expected)
    {
        var combo = new StoreComboViewModel { StockDisponible = stock, CantidadProductos = components };
        Assert.Equal(expected, combo.Disponible);
    }

    [Fact]
    public void StoreCombo_InactiveOrMissingComponent_IsNotAvailable()
    {
        var combo = new StoreComboViewModel
        {
            StockDisponible = 10,
            CantidadProductos = 2,
            ComponentesValidos = false
        };

        Assert.False(combo.Disponible);
    }

    [Fact]
    public void CartRefreshPolicy_RemovesAComboThatIsNoLongerSellable()
    {
        var refreshedCombo = new StoreComboViewModel
        {
            StockDisponible = 0,
            CantidadProductos = 2,
            ComponentesValidos = true
        };

        Assert.False(refreshedCombo.Disponible);
    }

    [Fact]
    public void StockTransformation_RejectsSameSourceAndDestination()
    {
        var model = new StockTransformationFormViewModel
        {
            ProductoOrigenId = 5,
            ProductoDestinoId = 5,
            CantidadOrigen = 1,
            CantidadDestino = 6
        };

        Assert.Contains(Validate(model), result => result.MemberNames.Contains(nameof(model.ProductoDestinoId)));
    }

    [Theory]
    [InlineData(12, 3, 2, 2, 3, 7)]
    [InlineData(0, 3, 2, 5, 8, 0)]
    public void PurchaseSuggestion_UsesDemandCoverageAndSafetyStock(
        int sold, int months, int coverage, int safetyStock, int currentStock, int expected) =>
        Assert.Equal(expected, InventoryIntelligencePolicy.CalculateSuggestedQuantity(
            sold, months, coverage, safetyStock, currentStock));

    [Fact]
    public void SeasonalTrend_AlwaysReturnsTwelveUniqueOrderedMonths()
    {
        var normalized = InventoryIntelligencePolicy.NormalizeTwelveMonths(
        [
            new SeasonalTrendPoint { NumeroMes = 2, TotalVendido = 10m, UnidadesVendidas = 1 },
            new SeasonalTrendPoint { NumeroMes = 2, TotalVendido = 15m, UnidadesVendidas = 2 },
            new SeasonalTrendPoint { NumeroMes = 12, TotalVendido = 20m, UnidadesVendidas = 3 }
        ]);

        Assert.Equal(Enumerable.Range(1, 12), normalized.Select(point => point.NumeroMes));
        Assert.Equal(25m, normalized.Single(point => point.NumeroMes == 2).TotalVendido);
        Assert.Equal(3, normalized.Single(point => point.NumeroMes == 2).UnidadesVendidas);
    }

    [Fact]
    public void CheckoutPayload_ContainsOnlyIdentifiersTypeAndQuantity()
    {
        var json = StoreCheckoutPayloadBuilder.CreateItemsJson(
        [
            new CartItemViewModel
            {
                ItemType = CartItemTypes.Product,
                ProductoId = 12,
                Cantidad = 2,
                Precio = 999999m,
                StockDisponible = 999,
                Nombre = "Dato manipulable"
            },
            new CartItemViewModel
            {
                ItemType = CartItemTypes.Combo,
                ComboId = 8,
                Cantidad = 1,
                Precio = 1m
            }
        ]);

        using var document = JsonDocument.Parse(json);
        var lines = document.RootElement.EnumerateArray().ToArray();
        Assert.Equal(2, lines.Length);
        Assert.All(lines, line => Assert.Equal(
            ["tipo", "productoId", "comboId", "cantidad"],
            line.EnumerateObject().Select(property => property.Name).ToArray()));
        Assert.Equal(12, lines[0].GetProperty("productoId").GetInt32());
        Assert.Equal(8, lines[1].GetProperty("comboId").GetInt32());
        Assert.DoesNotContain("precio", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("stock", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("nombre", json, StringComparison.OrdinalIgnoreCase);
    }

    private static List<ValidationResult> Validate(object model)
    {
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(model, new ValidationContext(model), results, validateAllProperties: true);
        return results;
    }
}
