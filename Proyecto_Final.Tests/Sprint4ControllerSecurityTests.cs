using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;

namespace Proyecto_Final.Tests;

public sealed class Sprint4ControllerSecurityTests
{
    [Theory]
    [InlineData(typeof(DocumentsController))]
    [InlineData(typeof(BudgetsController))]
    [InlineData(typeof(ExpensesController))]
    [InlineData(typeof(BudgetComparisonController))]
    public void Sprint4Controllers_RequirePermissionAuthorization(Type type) =>
        Assert.NotNull(type.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true).SingleOrDefault());

    [Theory]
    [InlineData(typeof(DocumentsController), "Create")]
    [InlineData(typeof(DocumentsController), "ReplaceFile")]
    [InlineData(typeof(DocumentsController), "SetActive")]
    [InlineData(typeof(DocumentsController), "GenerateAlerts")]
    [InlineData(typeof(BudgetsController), "Create")]
    [InlineData(typeof(BudgetsController), "UpdateDraft")]
    [InlineData(typeof(BudgetsController), "Approve")]
    [InlineData(typeof(BudgetsController), "Reject")]
    [InlineData(typeof(ExpensesController), "Create")]
    [InlineData(typeof(ExpensesController), "Approve")]
    [InlineData(typeof(ExpensesController), "Pay")]
    [InlineData(typeof(ExpensesController), "Cancel")]
    public void MutatingEndpoints_RequireAntiforgery(Type type, string method)
    {
        var candidates = type.GetMethods().Where(x => x.Name == method && x.GetCustomAttributes(typeof(HttpPostAttribute), true).Any()).ToArray();
        Assert.NotEmpty(candidates);
        Assert.All(candidates, action => Assert.True(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true).Any()));
    }

    [Theory]
    [InlineData(typeof(DocumentsController), "Create")]
    [InlineData(typeof(DocumentsController), "ReplaceFile")]
    [InlineData(typeof(DocumentsController), "GenerateAlerts")]
    [InlineData(typeof(ExpensesController), "Create")]
    [InlineData(typeof(ExpensesController), "Approve")]
    [InlineData(typeof(BudgetsController), "Approve")]
    public void SensitiveWrites_AreRateLimited(Type type, string method)
    {
        var action = type.GetMethods().Single(x => x.Name == method && x.GetCustomAttributes(typeof(HttpPostAttribute), true).Any());
        Assert.True(action.GetCustomAttributes(typeof(EnableRateLimitingAttribute), true).Any());
    }

    [Theory]
    [InlineData(typeof(CombosController), "COMBOS_VER")]
    [InlineData(typeof(InventoryIntelligenceController), "INVENTARIO_INTELIGENCIA_VER")]
    public void NewSprint4Controllers_RequireExactReadPermission(Type type, string permission) =>
        AssertPermission(type.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true), permission);

    [Theory]
    [InlineData(typeof(CombosController), "Create", "COMBOS_GESTIONAR")]
    [InlineData(typeof(CombosController), "ToggleStatus", "COMBOS_GESTIONAR")]
    [InlineData(typeof(InventoryController), "TransformStock", "INVENTARIO_TRANSFORMAR")]
    public void NewSprint4Writes_RequireExactPermission(Type type, string method, string permission)
    {
        var actions = type.GetMethods().Where(candidate =>
            candidate.Name == method && candidate.GetCustomAttributes(typeof(HttpPostAttribute), true).Any()).ToArray();

        Assert.NotEmpty(actions);
        Assert.All(actions, action => AssertPermission(
            action.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true), permission));
    }

    [Theory]
    [InlineData(typeof(CombosController), "Create")]
    [InlineData(typeof(CombosController), "ToggleStatus")]
    [InlineData(typeof(InventoryController), "TransformStock")]
    public void NewSprint4Writes_RequireAntiforgery(Type type, string method)
    {
        var actions = type.GetMethods().Where(candidate =>
            candidate.Name == method && candidate.GetCustomAttributes(typeof(HttpPostAttribute), true).Any()).ToArray();

        Assert.NotEmpty(actions);
        Assert.All(actions, action => Assert.NotEmpty(
            action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true)));
    }

    [Fact]
    public void AddCombo_RequiresAntiforgery()
    {
        var action = typeof(CartController).GetMethods().Single(candidate =>
            candidate.Name == "AddCombo" && candidate.GetCustomAttributes(typeof(HttpPostAttribute), true).Any());

        Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true));
    }

    private static void AssertPermission(IEnumerable<object> attributes, string expected)
    {
        var attribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(attributes));
        Assert.Equal(expected, attribute.Arguments![1]);
    }
}
