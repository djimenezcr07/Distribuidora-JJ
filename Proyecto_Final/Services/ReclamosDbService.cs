using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-191/192 — Acceso a datos del módulo de reclamos (servicio al cliente).
    public class ReclamosDbService
    {
        private readonly string _connectionString;

        public ReclamosDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ── CU-191/192 Listado ──────────────────────────────
        public async Task<List<ReclamoListItemViewModel>> GetReclamosAsync(string? estado, string? buscar, int actorUsuarioId, OriginalLoginContext originalLogin)
        {
            var lista = new List<ReclamoListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, actorUsuarioId, "RECLAMOS_GESTIONAR", async () =>
            {
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                lista.Add(new ReclamoListItemViewModel
                {
                    ReclamoId = reader.GetInt32(0),
                    Asunto = reader.GetString(1),
                    Categoria = reader.GetString(2),
                    Prioridad = reader.GetString(3),
                    Estado = reader.GetString(4),
                    FechaRegistro = reader.GetDateTime(5),
                    FechaCierre = reader.IsDBNull(6) ? null : reader.GetDateTime(6),
                    UsuarioId = reader.GetInt32(7),
                    ClienteNombre = reader.GetString(8),
                    ClienteCorreo = reader.GetString(9),
                    NumeroFactura = reader.IsDBNull(10) ? null : reader.GetString(10)
                });
                }
                return lista;
            });
        }

        // ── CU-191 Detalle ──────────────────────────────────
        public async Task<ReclamoDetailViewModel?> GetReclamoByIdAsync(int reclamoId, int actorUsuarioId, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_GetById", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@ReclamoId", SqlDbType.Int).Value = reclamoId;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, actorUsuarioId, "RECLAMOS_GESTIONAR", async () =>
            {
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                return new ReclamoDetailViewModel
                {
                    ReclamoId = reader.GetInt32(0),
                    UsuarioId = reader.GetInt32(1),
                    FacturaId = reader.IsDBNull(2) ? null : reader.GetInt32(2),
                    PedidoId = reader.IsDBNull(3) ? null : reader.GetInt32(3),
                    Asunto = reader.GetString(4),
                    Descripcion = reader.GetString(5),
                    Categoria = reader.GetString(6),
                    Prioridad = reader.GetString(7),
                    Estado = reader.GetString(8),
                    ResolucionDescripcion = reader.GetString(9),
                    FechaCierre = reader.IsDBNull(10) ? null : reader.GetDateTime(10),
                    CerradoPorNombre = reader.IsDBNull(11) ? null : reader.GetString(11),
                    RegistradoPorNombre = reader.IsDBNull(12) ? null : reader.GetString(12),
                    FechaRegistro = reader.GetDateTime(13),
                    FechaActualizacion = reader.IsDBNull(14) ? null : reader.GetDateTime(14),
                    ClienteNombre = reader.GetString(15),
                    ClienteCorreo = reader.GetString(16),
                    ClienteTelefono = reader.IsDBNull(17) ? null : reader.GetString(17),
                    NumeroFactura = reader.IsDBNull(18) ? null : reader.GetString(18),
                    FacturaTotal = reader.IsDBNull(19) ? null : reader.GetDecimal(19),
                    FechaFactura = reader.IsDBNull(20) ? null : reader.GetDateTime(20)
                };
                }
                return null;
            });
        }

        // ── CU-191 Registrar ────────────────────────────────
        public async Task<int> CreateReclamoAsync(ReclamoFormViewModel model, int agenteId, string agenteNombre, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = model.UsuarioId;
            command.Parameters.Add("@FacturaId", SqlDbType.Int).Value = model.FacturaId.HasValue ? model.FacturaId.Value : DBNull.Value;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = model.PedidoId.HasValue ? model.PedidoId.Value : DBNull.Value;
            command.Parameters.Add("@Asunto", SqlDbType.NVarChar, 150).Value = model.Asunto.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 1000).Value = model.Descripcion.Trim();
            command.Parameters.Add("@Categoria", SqlDbType.NVarChar, 40).Value = model.Categoria;
            command.Parameters.Add("@Prioridad", SqlDbType.NVarChar, 20).Value = model.Prioridad;
            command.Parameters.Add("@AgenteId", SqlDbType.Int).Value = agenteId > 0 ? agenteId : DBNull.Value;
            command.Parameters.Add("@AgenteNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(agenteNombre) ? DBNull.Value : agenteNombre;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, agenteId, "RECLAMOS_GESTIONAR", async () =>
            {
                var result = await command.ExecuteScalarAsync();
                return result is int id ? id : Convert.ToInt32(result);
            });
        }

        // ── CU-192 Cambiar estado ───────────────────────────
        public async Task ChangeStatusAsync(int reclamoId, string estado, string? resolucion, int usuarioId, string usuarioNombre, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_CambiarEstado", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ReclamoId", SqlDbType.Int).Value = reclamoId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = estado;
            command.Parameters.Add("@Resolucion", SqlDbType.NVarChar, 1000).Value = string.IsNullOrWhiteSpace(resolucion) ? DBNull.Value : resolucion.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, usuarioId, "RECLAMOS_GESTIONAR", async () =>
            {
                await command.ExecuteNonQueryAsync();
                return 0;
            });
        }

        // ── Combos de apoyo ─────────────────────────────────
        public async Task<List<ClienteOptionViewModel>> SearchClientsAsync(string? buscar, int actorUsuarioId, OriginalLoginContext originalLogin)
        {
            var lista = new List<ClienteOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_Clientes_Buscar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, actorUsuarioId, "RECLAMOS_GESTIONAR", async () =>
            {
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                lista.Add(new ClienteOptionViewModel
                {
                    UsuarioId = reader.GetInt32(0),
                    NombreCompleto = reader.GetString(1),
                    Correo = reader.GetString(2)
                });
                }
                return lista;
            });
        }

        public async Task<List<FacturaOptionViewModel>> GetInvoicesByClientAsync(int usuarioId, int actorUsuarioId, OriginalLoginContext originalLogin)
        {
            var lista = new List<FacturaOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reclamos_FacturasPorCliente", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, actorUsuarioId, "RECLAMOS_GESTIONAR", async () =>
            {
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                lista.Add(new FacturaOptionViewModel
                {
                    FacturaId = reader.GetInt32(0),
                    NumeroFactura = reader.GetString(1),
                    FechaFactura = reader.GetDateTime(2),
                    Total = reader.GetDecimal(3)
                });
                }
                return lista;
            });
        }
    }
}
