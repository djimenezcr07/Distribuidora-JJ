using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-141 / CU-142 — Devoluciones y cuarentena de productos.
    // Acceso a datos con ADO.NET + stored procedures (patrón del proyecto).
    public class WarehouseDbService
    {
        private readonly string _connectionString;

        public WarehouseDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        public async Task<List<ReturnListItemViewModel>> GetReturnsAsync(string? estado, string? buscar)
        {
            var lista = new List<ReturnListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Devoluciones_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ReturnListItemViewModel
                {
                    DevolucionId = reader.GetInt32(0),
                    PedidoId = reader.IsDBNull(1) ? null : reader.GetInt32(1),
                    ProductoId = reader.GetInt32(2),
                    ProductoNombre = reader.GetString(3),
                    Cantidad = reader.GetInt32(4),
                    Motivo = reader.GetString(5),
                    Estado = reader.GetString(6),
                    ClienteInfo = reader.GetString(7),
                    RegistradoPorNombre = reader.GetString(8),
                    FechaRegistro = reader.GetDateTime(9),
                    ResueltoPorNombre = reader.GetString(10),
                    FechaResolucion = reader.IsDBNull(11) ? null : reader.GetDateTime(11),
                    ObservacionResolucion = reader.GetString(12)
                });
            }
            return lista;
        }

        public async Task<int> CreateReturnAsync(ReturnFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Devoluciones_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = model.PedidoId.HasValue && model.PedidoId > 0 ? model.PedidoId.Value : DBNull.Value;
            command.Parameters.Add("@ProductoId", SqlDbType.Int).Value = model.ProductoId;
            command.Parameters.Add("@Cantidad", SqlDbType.Int).Value = model.Cantidad;
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 300).Value = model.Motivo.Trim();
            command.Parameters.Add("@ClienteInfo", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(model.ClienteInfo) ? DBNull.Value : model.ClienteInfo.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = usuarioNombre;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task ReleaseFromQuarantineAsync(int devolucionId, int usuarioId, string usuarioNombre, string? observacion)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Cuarentena_Liberar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@DevolucionId", SqlDbType.Int).Value = devolucionId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = usuarioNombre;
            command.Parameters.Add("@Observacion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(observacion) ? DBNull.Value : observacion.Trim();
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task DiscardFromQuarantineAsync(int devolucionId, int usuarioId, string usuarioNombre, string? observacion)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Cuarentena_Descartar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@DevolucionId", SqlDbType.Int).Value = devolucionId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = usuarioNombre;
            command.Parameters.Add("@Observacion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(observacion) ? DBNull.Value : observacion.Trim();
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }
    }
}
