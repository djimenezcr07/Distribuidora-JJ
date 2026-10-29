using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Tests;

public sealed class PayrollRulesAndSecurityTests
{
    [Theory]
    [InlineData("ConfigureRule", "PLANILLA_CONFIGURAR")]
    [InlineData("CreatePeriod", "PLANILLA_GESTIONAR")]
    [InlineData("Calculate", "PLANILLA_CALCULAR")]
    [InlineData("Approve", "PLANILLA_APROBAR")]
    [InlineData("Pay", "PLANILLA_PAGAR")]
    [InlineData("Revert", "PLANILLA_REVERTIR")]
    public void PayrollWrites_RequireExactPermissionAndAntiforgery(string method, string permission)
    {
        var action = typeof(PayrollController).GetMethods().Single(candidate => candidate.Name == method);
        var attribute = Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(action.GetCustomAttributes(typeof(AdminAuthorizeAttribute), true)));
        Assert.Equal(permission, attribute.Arguments![1]);
        Assert.NotEmpty(action.GetCustomAttributes(typeof(HttpPostAttribute), true));
        Assert.NotEmpty(action.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute), true));
    }

    [Fact]
    public void Calculation_IsDeterministicAndKeepsAuditableSnapshot()
    {
        var input = ValidInput();

        var first = PayrollCalculationPolicy.Calculate(input);
        var second = PayrollCalculationPolicy.Calculate(input);

        Assert.Equal(1170m, first.TotalBruto);
        Assert.Equal(117m, first.TotalDeducciones);
        Assert.Equal(1053m, first.TotalNeto);
        Assert.Equal(first.Fingerprint, second.Fingerprint);
        Assert.Equal(first.ReglasSnapshotJson, second.ReglasSnapshotJson);
        Assert.Contains("Fuente aprobada", first.ReglasSnapshotJson);
        Assert.Contains("FactorSalario", first.ReglasSnapshotJson);
    }

    [Fact]
    public void Calculation_RejectsOvertimeWithoutConfiguredRule()
    {
        var input = ValidInput();
        input = new PayrollCalculationInput
        {
            PeriodoId = input.PeriodoId,
            EmpleadoId = input.EmpleadoId,
            SalarioBase = input.SalarioBase,
            HorasOrdinarias = input.HorasOrdinarias,
            HorasExtra = input.HorasExtra,
            Comisiones = input.Comisiones,
            FactorSalario = input.FactorSalario,
            FuenteConfiguracionPeriodo = input.FuenteConfiguracionPeriodo,
            FechaCalculo = input.FechaCalculo,
            Reglas = input.Reglas.Where(rule => rule.TipoCalculo != "PorHoraExtra").ToList()
        };

        Assert.Throws<PayrollConfigurationException>(() => PayrollCalculationPolicy.Calculate(input));
    }

    [Fact]
    public void Calculation_RejectsDeductionsAboveGross()
    {
        var input = ValidInput();
        input.Reglas.Single(rule => rule.Codigo == "DED").Valor = 2m;

        Assert.Throws<PayrollConfigurationException>(() => PayrollCalculationPolicy.Calculate(input));
    }

    private static PayrollCalculationInput ValidInput() => new()
    {
        PeriodoId = 10,
        EmpleadoId = 20,
        SalarioBase = 1000m,
        HorasOrdinarias = 80m,
        HorasExtra = 2m,
        Comisiones = 50m,
        FactorSalario = 0.5m,
        FuenteConfiguracionPeriodo = "Fuente aprobada del periodo",
        FechaCalculo = new DateTime(2026, 8, 15),
        Reglas =
        [
            new() { ReglaId = 1, Codigo = "BONO", Nombre = "Bono", Tipo = "Ingreso", TipoCalculo = "MontoFijo", Valor = 100m, VigenteDesde = new DateTime(2026, 1, 1), Fuente = "Fuente aprobada" },
            new() { ReglaId = 2, Codigo = "EXTRA", Nombre = "Hora extra", Tipo = "Ingreso", TipoCalculo = "PorHoraExtra", Valor = 10m, VigenteDesde = new DateTime(2026, 1, 1), Fuente = "Fuente aprobada" },
            new() { ReglaId = 3, Codigo = "DED", Nombre = "Deducción", Tipo = "Deduccion", TipoCalculo = "PorcentajeBruto", Valor = 0.1m, VigenteDesde = new DateTime(2026, 1, 1), Fuente = "Fuente aprobada" }
        ]
    };
}
