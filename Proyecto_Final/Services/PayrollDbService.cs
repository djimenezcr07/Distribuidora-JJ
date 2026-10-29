using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;
using System.Text.Json;

namespace Proyecto_Final.Services;

public interface IPayrollService
{
    Task<int> CreatePeriodAsync(PayrollPeriodFormViewModel model, int actorId, string actorName, CancellationToken cancellationToken);
    Task SaveRuleAsync(PayrollRuleFormViewModel model, int actorId, string actorName, CancellationToken cancellationToken);
    Task CalculateAsync(PayrollCalculationRequestViewModel model, int actorId, string actorName, CancellationToken cancellationToken);
    Task ChangeStateAsync(PayrollStateChangeViewModel model, int actorId, string actorName, CancellationToken cancellationToken);
    Task<List<PayrollListItemViewModel>> ListAsync(CancellationToken cancellationToken);
}

public sealed class PayrollDbService : IPayrollService
{
    private readonly string _connectionString;
    public PayrollDbService(IConfiguration configuration) => _connectionString = configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("No se encontró DefaultConnection.");

    public async Task<int> CreatePeriodAsync(PayrollPeriodFormViewModel model, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Command(connection, "dbo.sp_Payroll_CrearPeriodo");
        command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 20).Value = model.Tipo;
        command.Parameters.Add("@Desde", SqlDbType.Date).Value = model.Desde.Date; command.Parameters.Add("@Hasta", SqlDbType.Date).Value = model.Hasta.Date;
        AddRate(command, "@FactorSalario", model.FactorSalario);
        command.Parameters.Add("@FuenteConfiguracion", SqlDbType.NVarChar, 500).Value = model.FuenteConfiguracion.Trim();
        Actor(command, actorId, actorName); await connection.OpenAsync(cancellationToken);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task SaveRuleAsync(PayrollRuleFormViewModel model, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString); await using var command = Command(connection, "dbo.sp_Payroll_GuardarRegla");
        command.Parameters.Add("@Codigo", SqlDbType.NVarChar, 50).Value = model.Codigo.Trim().ToUpperInvariant(); command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = model.Nombre.Trim();
        command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 20).Value = model.Tipo; command.Parameters.Add("@TipoCalculo", SqlDbType.NVarChar, 30).Value = model.TipoCalculo;
        AddRate(command, "@Valor", model.Valor); AddMoney(command, "@Tope", model.Tope);
        command.Parameters.Add("@VigenteDesde", SqlDbType.Date).Value = model.VigenteDesde.Date; command.Parameters.Add("@VigenteHasta", SqlDbType.Date).Value = model.VigenteHasta?.Date ?? (object)DBNull.Value;
        command.Parameters.Add("@Fuente", SqlDbType.NVarChar, 500).Value = model.Fuente.Trim(); Actor(command, actorId, actorName);
        await connection.OpenAsync(cancellationToken); await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task CalculateAsync(PayrollCalculationRequestViewModel model, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString); await connection.OpenAsync(cancellationToken);
        var input = await LoadInputAsync(connection, model, cancellationToken);
        var result = PayrollCalculationPolicy.Calculate(input);
        await using var command = Command(connection, "dbo.sp_Payroll_GuardarCalculo");
        command.Parameters.Add("@PeriodoId", SqlDbType.Int).Value = model.PeriodoId; command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = model.EmpleadoId;
        AddMoney(command, "@SalarioBase", result.SalarioBase); AddHours(command, "@HorasOrdinarias", result.HorasOrdinarias); AddHours(command, "@HorasExtra", result.HorasExtra);
        AddMoney(command, "@Comisiones", result.Comisiones); AddMoney(command, "@TotalIngresos", result.TotalIngresos); AddMoney(command, "@TotalDeducciones", result.TotalDeducciones);
        AddMoney(command, "@TotalBruto", result.TotalBruto); AddMoney(command, "@TotalNeto", result.TotalNeto);
        command.Parameters.Add("@ReglasSnapshotJson", SqlDbType.NVarChar, -1).Value = result.ReglasSnapshotJson;
        command.Parameters.Add("@DetalleJson", SqlDbType.NVarChar, -1).Value = JsonSerializer.Serialize(result.Lineas);
        command.Parameters.Add("@Fingerprint", SqlDbType.Binary, 32).Value = result.Fingerprint; command.Parameters.Add("@IdempotencyKey", SqlDbType.UniqueIdentifier).Value = model.IdempotencyKey;
        Actor(command, actorId, actorName); await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task ChangeStateAsync(PayrollStateChangeViewModel model, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString); await using var command = Command(connection, "dbo.sp_Payroll_CambiarEstado");
        command.Parameters.Add("@CalculoId", SqlDbType.BigInt).Value = model.CalculoId; command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = model.Estado;
        command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.Motivo) ? DBNull.Value : model.Motivo.Trim();
        command.Parameters.Add("@VersionFila", SqlDbType.Binary, 8).Value = Convert.FromBase64String(model.RowVersionBase64); Actor(command, actorId, actorName);
        await connection.OpenAsync(cancellationToken); await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<List<PayrollListItemViewModel>> ListAsync(CancellationToken cancellationToken)
    {
        var items = new List<PayrollListItemViewModel>(); await using var connection = new SqlConnection(_connectionString); await using var command = Command(connection, "dbo.sp_Payroll_ListarCalculos");
        await connection.OpenAsync(cancellationToken); await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken)) items.Add(new PayrollListItemViewModel
        {
            CalculoId=reader.GetInt64(0),PeriodoId=reader.GetInt32(1),Periodo=reader.GetString(2),EmpleadoId=reader.GetInt32(3),Empleado=reader.GetString(4),
            TotalBruto=reader.GetDecimal(5),TotalDeducciones=reader.GetDecimal(6),TotalNeto=reader.GetDecimal(7),Estado=reader.GetString(8),RowVersionBase64=Convert.ToBase64String((byte[])reader.GetValue(9))
        }); return items;
    }

    private static async Task<PayrollCalculationInput> LoadInputAsync(SqlConnection connection, PayrollCalculationRequestViewModel request, CancellationToken cancellationToken)
    {
        await using var command = Command(connection, "dbo.sp_Payroll_ObtenerEntradaCalculo"); command.Parameters.Add("@PeriodoId", SqlDbType.Int).Value=request.PeriodoId; command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value=request.EmpleadoId;
        await using var reader=await command.ExecuteReaderAsync(cancellationToken); if(!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("No existe entrada de planilla.");
        var input=new PayrollCalculationInput{PeriodoId=request.PeriodoId,EmpleadoId=request.EmpleadoId,SalarioBase=reader.GetDecimal(0),HorasOrdinarias=reader.GetDecimal(1),HorasExtra=reader.GetDecimal(2),Comisiones=request.Comisiones,FechaCalculo=reader.GetDateTime(3),FactorSalario=reader.GetDecimal(4),FuenteConfiguracionPeriodo=reader.GetString(5)};
        var rules=new List<PayrollRuleViewModel>(); await reader.NextResultAsync(cancellationToken); while(await reader.ReadAsync(cancellationToken)) rules.Add(new PayrollRuleViewModel{ReglaId=reader.GetInt32(0),Codigo=reader.GetString(1),Nombre=reader.GetString(2),Tipo=reader.GetString(3),TipoCalculo=reader.GetString(4),Valor=reader.GetDecimal(5),Tope=reader.IsDBNull(6)?null:reader.GetDecimal(6),VigenteDesde=reader.GetDateTime(7),VigenteHasta=reader.IsDBNull(8)?null:reader.GetDateTime(8),Fuente=reader.GetString(9)});
        return new PayrollCalculationInput{PeriodoId=input.PeriodoId,EmpleadoId=input.EmpleadoId,SalarioBase=input.SalarioBase,HorasOrdinarias=input.HorasOrdinarias,HorasExtra=input.HorasExtra,Comisiones=input.Comisiones,FechaCalculo=input.FechaCalculo,FactorSalario=input.FactorSalario,FuenteConfiguracionPeriodo=input.FuenteConfiguracionPeriodo,Reglas=rules};
    }

    private static SqlCommand Command(SqlConnection connection,string name)=>new(name,connection){CommandType=CommandType.StoredProcedure};
    private static void Actor(SqlCommand command,int id,string name){command.Parameters.Add("@ActorUsuarioId",SqlDbType.Int).Value=id;command.Parameters.Add("@ActorNombre",SqlDbType.NVarChar,150).Value=name;}
    private static void AddMoney(SqlCommand command,string name,decimal? value){var p=command.Parameters.Add(name,SqlDbType.Decimal);p.Precision=18;p.Scale=2;p.Value=value??(object)DBNull.Value;}
    private static void AddHours(SqlCommand command,string name,decimal value){var p=command.Parameters.Add(name,SqlDbType.Decimal);p.Precision=8;p.Scale=2;p.Value=value;}
    private static void AddRate(SqlCommand command,string name,decimal value){var p=command.Parameters.Add(name,SqlDbType.Decimal);p.Precision=9;p.Scale=6;p.Value=value;}
}
