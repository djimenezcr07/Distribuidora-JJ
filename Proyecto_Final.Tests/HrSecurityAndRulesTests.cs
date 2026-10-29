using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;
using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Tests;

public sealed class HrSecurityAndRulesTests
{
    [Fact]
    public void EmployeesService_UsesExplicitInterface() =>
        Assert.Contains(typeof(IEmployeesService), typeof(EmployeesDbService).GetInterfaces());

    [Theory]
    [InlineData(typeof(EmployeesController), "Create", "EMPLEADOS_CREAR")]
    [InlineData(typeof(EmployeesController), "Edit", "EMPLEADOS_EDITAR")]
    [InlineData(typeof(EmployeesController), "ToggleStatus", "EMPLEADOS_EDITAR")]
    public void EmployeeWrites_RequireExactPermission(Type controller, string method, string permission)
    {
        var actions = controller.GetMethods().Where(candidate => candidate.Name == method &&
            candidate.GetCustomAttributes(typeof(HttpPostAttribute), true).Any()).ToArray();
        Assert.NotEmpty(actions);
        Assert.All(actions, action =>
        {
            var attribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(action.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)));
            Assert.Equal(permission, attribute.Arguments![1]);
            Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true));
        });
    }

    [Fact]
    public void AttendanceApproval_RequiresExactPermission()
    {
        var attribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(
            typeof(AttendanceController).GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)));
        Assert.Equal("RRHH_JORNADAS_APROBAR", attribute.Arguments![1]);
    }

    [Theory]
    [InlineData(typeof(AttendanceController), "Decide")]
    [InlineData(typeof(MyAttendanceController), "Save")]
    public void AttendanceWrites_RequireAntiforgery(Type controller, string method)
    {
        var action = controller.GetMethods().Single(candidate => candidate.Name == method);
        Assert.NotEmpty(action.GetCustomAttributes(typeof(HttpPostAttribute), true));
        Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true));
    }

    [Theory]
    [InlineData(8, 2, 0, true)]
    [InlineData(0, 0, 0, false)]
    [InlineData(20, 5, 0, false)]
    [InlineData(-1, 0, 0, false)]
    public void AttendanceRules_ValidateDailyHours(double ordinary, double overtime, double absence, bool valid) =>
        Assert.Equal(valid, AttendanceRules.Validate((decimal)ordinary, (decimal)overtime, (decimal)absence).Count == 0);

    [Fact]
    public void EmployeeCreate_DoesNotRequireConcurrencyToken()
    {
        var model = new EmployeeFormViewModel
        {
            PerfilId = 1, NombreCompleto = "Persona sintética", Correo = "synthetic@example.invalid",
            Puesto = "Pruebas", RowVersionBase64 = string.Empty
        };
        var results = new List<ValidationResult>();
        Assert.True(Validator.TryValidateObject(model, new ValidationContext(model), results, true));
        Assert.DoesNotContain(results, result => result.MemberNames.Contains(nameof(model.RowVersionBase64)));
    }
}
