using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services;

public interface IAttendanceService
{
    Task<List<AttendanceEntryViewModel>> GetMineAsync(int userId, DateTime from, DateTime to, CancellationToken cancellationToken);
    Task SaveMineAsync(int userId, AttendanceFormViewModel model, bool submit, CancellationToken cancellationToken);
    Task<List<AttendanceEntryViewModel>> GetPendingAsync(DateTime from, DateTime to, CancellationToken cancellationToken);
    Task DecideAsync(AttendanceDecisionViewModel model, int supervisorUserId, string supervisorName, CancellationToken cancellationToken);
}

public sealed class AttendanceDbService : IAttendanceService
{
    private readonly string _connectionString;

    public AttendanceDbService(IConfiguration configuration) =>
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la cadena DefaultConnection.");

    public Task<List<AttendanceEntryViewModel>> GetMineAsync(int userId, DateTime from, DateTime to, CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_RRHH_ListarMisJornadas", userId, from, to, cancellationToken);

    public Task<List<AttendanceEntryViewModel>> GetPendingAsync(DateTime from, DateTime to, CancellationToken cancellationToken) =>
        QueryAsync("dbo.sp_RRHH_ListarJornadasPendientes", null, from, to, cancellationToken);

    public async Task SaveMineAsync(int userId, AttendanceFormViewModel model, bool submit, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_RRHH_GuardarMiJornada", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@JornadaId", SqlDbType.BigInt).Value = model.JornadaId > 0 ? model.JornadaId : DBNull.Value;
        command.Parameters.Add("@Fecha", SqlDbType.Date).Value = model.Fecha.Date;
        AddDecimal(command, "@HorasOrdinarias", model.HorasOrdinarias);
        AddDecimal(command, "@HorasExtra", model.HorasExtra);
        AddDecimal(command, "@HorasAusencia", model.HorasAusencia);
        command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
        command.Parameters.Add("@Enviar", SqlDbType.Bit).Value = submit;
        command.Parameters.Add("@IdempotencyKey", SqlDbType.UniqueIdentifier).Value = model.IdempotencyKey;
        command.Parameters.Add("@VersionFila", SqlDbType.Binary, 8).Value = string.IsNullOrWhiteSpace(model.RowVersionBase64)
            ? DBNull.Value : Convert.FromBase64String(model.RowVersionBase64);
        await connection.OpenAsync(cancellationToken);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DecideAsync(AttendanceDecisionViewModel model, int supervisorUserId, string supervisorName, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand("dbo.sp_RRHH_ResolverJornada", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.Add("@JornadaId", SqlDbType.BigInt).Value = model.JornadaId;
        command.Parameters.Add("@Decision", SqlDbType.NVarChar, 20).Value = model.Decision;
        command.Parameters.Add("@RespuestaSupervisor", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.RespuestaSupervisor) ? DBNull.Value : model.RespuestaSupervisor.Trim();
        command.Parameters.Add("@SupervisorUsuarioId", SqlDbType.Int).Value = supervisorUserId;
        command.Parameters.Add("@SupervisorNombre", SqlDbType.NVarChar, 150).Value = supervisorName;
        command.Parameters.Add("@VersionFila", SqlDbType.Binary, 8).Value = Convert.FromBase64String(model.RowVersionBase64);
        await connection.OpenAsync(cancellationToken);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task<List<AttendanceEntryViewModel>> QueryAsync(string procedure, int? userId, DateTime from, DateTime to, CancellationToken cancellationToken)
    {
        var result = new List<AttendanceEntryViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand(procedure, connection) { CommandType = CommandType.StoredProcedure };
        if (userId.HasValue) command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId.Value;
        command.Parameters.Add("@Desde", SqlDbType.Date).Value = from.Date;
        command.Parameters.Add("@Hasta", SqlDbType.Date).Value = to.Date;
        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AttendanceEntryViewModel
            {
                JornadaId = reader.GetInt64(0), EmpleadoId = reader.GetInt32(1), NombreCompleto = reader.GetString(2),
                Fecha = reader.GetDateTime(3), HorasOrdinarias = reader.GetDecimal(4), HorasExtra = reader.GetDecimal(5),
                HorasAusencia = reader.GetDecimal(6), Observaciones = reader.IsDBNull(7) ? null : reader.GetString(7),
                Estado = reader.GetString(8), RespuestaSupervisor = reader.IsDBNull(9) ? null : reader.GetString(9),
                RowVersionBase64 = Convert.ToBase64String((byte[])reader.GetValue(10))
            });
        }
        return result;
    }

    private static void AddDecimal(SqlCommand command, string name, decimal value)
    {
        var parameter = command.Parameters.Add(name, SqlDbType.Decimal);
        parameter.Precision = 5; parameter.Scale = 2; parameter.Value = value;
    }
}
