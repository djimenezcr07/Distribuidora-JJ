using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Validation;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-152 / CU-153 / CU-154 / CU-161 — Kilometraje, mantenimiento, alertas y activos.
    public class FleetDbService
    {
        private readonly string _connectionString;

        public FleetDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ── CU-152 Kilometraje ──────────────────────────────
        public async Task<List<MileageListItemViewModel>> GetMileageAsync(int? vehiculoId, int? choferUsuarioId)
        {
            var lista = new List<MileageListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Kilometraje_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = vehiculoId.HasValue ? vehiculoId.Value : DBNull.Value;
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferUsuarioId.HasValue ? choferUsuarioId.Value : DBNull.Value;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new MileageListItemViewModel
                {
                    KilometrajeId = reader.GetInt32(0),
                    VehiculoId = reader.GetInt32(1),
                    VehiculoPlaca = reader.GetString(2),
                    ChoferNombre = reader.GetString(3),
                    Fecha = reader.GetDateTime(4),
                    KmInicial = reader.GetInt32(5),
                    KmFinal = reader.IsDBNull(6) ? null : reader.GetInt32(6),
                    Recorrido = reader.IsDBNull(7) ? null : reader.GetInt32(7),
                    Observaciones = reader.GetString(8),
                    FechaRegistro = reader.GetDateTime(9)
                });
            }
            return lista;
        }

        public async Task<int> OpenMileageAsync(MileageOpenViewModel model, int choferId, string choferNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Kilometraje_Abrir", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = model.VehiculoId;
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferId > 0 ? choferId : DBNull.Value;
            command.Parameters.Add("@ChoferNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(choferNombre) ? DBNull.Value : choferNombre;
            command.Parameters.Add("@KmInicial", SqlDbType.Int).Value = model.KmInicial;
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task CloseMileageAsync(int kilometrajeId, int kmFinal, int actorUsuarioId, bool puedeAdministrar)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Kilometraje_Cerrar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@KilometrajeId", SqlDbType.Int).Value = kilometrajeId;
            command.Parameters.Add("@KmFinal", SqlDbType.Int).Value = kmFinal;
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@PuedeAdministrar", SqlDbType.Bit).Value = puedeAdministrar;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-153 Mantenimiento ────────────────────────────
        public async Task<List<MaintenanceListItemViewModel>> GetMaintenanceAsync(int? vehiculoId, string? estado)
        {
            var lista = new List<MaintenanceListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Mantenimiento_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = vehiculoId.HasValue ? vehiculoId.Value : DBNull.Value;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new MaintenanceListItemViewModel
                {
                    OrdenMantenimientoId = reader.GetInt32(0),
                    VehiculoId = reader.GetInt32(1),
                    VehiculoPlaca = reader.GetString(2),
                    Tipo = reader.GetString(3),
                    Descripcion = reader.GetString(4),
                    Taller = reader.GetString(5),
                    Costo = reader.GetDecimal(6),
                    Estado = reader.GetString(7),
                    FechaProgramada = reader.IsDBNull(8) ? null : reader.GetDateTime(8),
                    FechaRealizada = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                    KilometrajeProximo = reader.IsDBNull(10) ? null : reader.GetInt32(10),
                    RegistradoPorNombre = reader.GetString(11),
                    FechaRegistro = reader.GetDateTime(12)
                });
            }
            return lista;
        }

        public async Task<int> CreateMaintenanceAsync(MaintenanceFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Mantenimiento_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = model.VehiculoId;
            command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 20).Value = model.Tipo;
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 300).Value = model.Descripcion.Trim();
            command.Parameters.Add("@Taller", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(model.Taller) ? DBNull.Value : model.Taller.Trim();
            command.Parameters.Add("@Costo", SqlDbType.Decimal).Value = model.Costo;
            command.Parameters["@Costo"].Precision = 18;
            command.Parameters["@Costo"].Scale = 2;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = model.Estado;
            command.Parameters.Add("@FechaProgramada", SqlDbType.Date).Value = model.FechaProgramada.HasValue ? model.FechaProgramada.Value.Date : DBNull.Value;
            command.Parameters.Add("@FechaRealizada", SqlDbType.Date).Value = model.FechaRealizada.HasValue ? model.FechaRealizada.Value.Date : DBNull.Value;
            command.Parameters.Add("@KilometrajeProximo", SqlDbType.Int).Value = model.KilometrajeProximo.HasValue ? model.KilometrajeProximo.Value : DBNull.Value;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task CompleteMaintenanceAsync(int ordenId, DateTime? fechaRealizada, decimal? costo)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Mantenimiento_MarcarCompletada", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@OrdenMantenimientoId", SqlDbType.Int).Value = ordenId;
            command.Parameters.Add("@FechaRealizada", SqlDbType.Date).Value = fechaRealizada.HasValue ? fechaRealizada.Value.Date : DBNull.Value;
            command.Parameters.Add("@Costo", SqlDbType.Decimal).Value = costo.HasValue ? costo.Value : DBNull.Value;
            command.Parameters["@Costo"].Precision = 18;
            command.Parameters["@Costo"].Scale = 2;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-154 Alertas y documentos ─────────────────────
        public async Task<List<FleetAlertViewModel>> GetAlertsAsync(int diasAviso)
        {
            var lista = new List<FleetAlertViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Flota_Alertas", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@DiasAviso", SqlDbType.Int).Value = diasAviso;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new FleetAlertViewModel
                {
                    Categoria = reader.GetString(0),
                    VehiculoPlaca = reader.GetString(1),
                    Detalle = reader.GetString(2),
                    Fecha = reader.IsDBNull(3) ? null : reader.GetDateTime(3),
                    DiasRestantes = reader.IsDBNull(4) ? null : reader.GetInt32(4),
                    Severidad = reader.GetString(5)
                });
            }
            return lista;
        }

        public async Task CreateDocumentAsync(VehicleDocumentFormViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_VehiculoDocumento_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = model.VehiculoId;
            command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 40).Value = model.Tipo;
            command.Parameters.Add("@FechaVencimiento", SqlDbType.Date).Value = model.FechaVencimiento.Date;
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-161 Activos ──────────────────────────────────
        public async Task<List<AssetListItemViewModel>> GetAssetsAsync(string? buscar, string? estado)
        {
            var lista = new List<AssetListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new AssetListItemViewModel
                {
                    ActivoId = reader.GetInt32(0),
                    CodigoActivo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    Tipo = reader.GetString(3),
                    Descripcion = reader.GetString(4),
                    Estado = reader.GetString(5),
                    ClientePrestamo = reader.GetString(6),
                    Activo = reader.GetBoolean(7),
                    FechaRegistro = reader.GetDateTime(8)
                });
            }
            return lista;
        }

        public async Task<AssetFormViewModel?> GetAssetByIdAsync(int activoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_GetById", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActivoId", SqlDbType.Int).Value = activoId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new AssetFormViewModel
                {
                    ActivoId = reader.GetInt32(0),
                    CodigoActivo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    Tipo = reader.GetString(3),
                    Descripcion = reader.GetString(4),
                    Estado = reader.GetString(5),
                    ClientePrestamo = reader.GetString(6)
                };
            }
            return null;
        }

        public async Task CreateAssetAsync(AssetFormViewModel model)
        {
            // Un activo nuevo siempre nace Disponible; Estado y "Prestado a" los gobierna Comodatos.
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_Create", connection) { CommandType = CommandType.StoredProcedure };
            AddAssetInfoParams(command, model);
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task UpdateAssetAsync(AssetFormViewModel model)
        {
            // sp_Activos_UpdateInfo NO toca Estado ni ClientePrestamo (responsabilidad de Comodatos).
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_UpdateInfo", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActivoId", SqlDbType.Int).Value = model.ActivoId;
            AddAssetInfoParams(command, model);
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task DeleteAssetAsync(int activoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_Delete", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActivoId", SqlDbType.Int).Value = activoId;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<List<ComodatoHistoryItemViewModel>> GetAssetComodatoHistoryAsync(int activoId)
        {
            var lista = new List<ComodatoHistoryItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Comodato_HistorialPorActivo", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActivoId", SqlDbType.Int).Value = activoId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ComodatoHistoryItemViewModel
                {
                    ComodatoId = reader.GetInt32(0),
                    ClienteNombre = reader.GetString(1),
                    FechaAsignacion = reader.GetDateTime(2),
                    FechaDevolucion = reader.IsDBNull(3) ? null : reader.GetDateTime(3),
                    Estado = reader.GetString(4),
                    DestinoDevolucion = reader.GetString(5),
                    Observaciones = reader.GetString(6)
                });
            }
            return lista;
        }

        private static void AddAssetInfoParams(SqlCommand command, AssetFormViewModel model)
        {
            command.Parameters.Add("@CodigoActivo", SqlDbType.NVarChar, 40).Value = model.CodigoActivo.Trim();
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = model.Nombre.Trim();
            command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 40).Value = model.Tipo;
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
        }

        // ── CU-162/163/164 Comodatos ────────────────────────
        public async Task<List<ComodatoListItemViewModel>> GetComodatosAsync(string? estado, string? buscar)
        {
            var lista = new List<ComodatoListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Comodato_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ComodatoListItemViewModel
                {
                    ComodatoId = reader.GetInt32(0),
                    ActivoId = reader.GetInt32(1),
                    CodigoActivo = reader.GetString(2),
                    ActivoNombre = reader.GetString(3),
                    ActivoTipo = reader.GetString(4),
                    ClienteNombre = reader.GetString(5),
                    ClienteIdentificacion = reader.GetString(6),
                    Ubicacion = reader.GetString(7),
                    FechaAsignacion = reader.GetDateTime(8),
                    FechaDevolucion = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                    Estado = reader.GetString(10),
                    DestinoDevolucion = reader.GetString(11),
                    DiasEnComodato = reader.GetInt32(12)
                });
            }
            return lista;
        }

        // Activos disponibles para combo de asignación (reutiliza sp_Activos_List con filtro).
        public async Task<List<AssetOptionViewModel>> GetAvailableAssetsAsync()
        {
            var lista = new List<AssetOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Activos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = DBNull.Value;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = "Disponible";
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new AssetOptionViewModel
                {
                    ActivoId = reader.GetInt32(0),
                    CodigoActivo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    Tipo = reader.GetString(3)
                });
            }
            return lista;
        }

        public async Task<int> AssignComodatoAsync(ComodatoAssignViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Comodato_Asignar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ActivoId", SqlDbType.Int).Value = model.ActivoId;
            command.Parameters.Add("@ClienteUsuarioId", SqlDbType.Int).Value = model.ClienteUsuarioId.HasValue ? model.ClienteUsuarioId.Value : DBNull.Value;
            command.Parameters.Add("@ClienteNombre", SqlDbType.NVarChar, 150).Value = model.ClienteNombre.Trim();
            command.Parameters.Add("@ClienteIdentificacion", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(model.ClienteIdentificacion) ? DBNull.Value : CostaRicanIdentificationAttribute.Normalize(model.ClienteIdentificacion);
            command.Parameters.Add("@Ubicacion", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(model.Ubicacion) ? DBNull.Value : model.Ubicacion.Trim();
            command.Parameters.Add("@FechaAsignacion", SqlDbType.Date).Value = model.FechaAsignacion.HasValue ? model.FechaAsignacion.Value.Date : DBNull.Value;
            command.Parameters.Add("@CondicionEntrega", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.CondicionEntrega) ? DBNull.Value : model.CondicionEntrega.Trim();
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task ReturnComodatoAsync(ComodatoReturnViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Comodato_Devolver", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ComodatoId", SqlDbType.Int).Value = model.ComodatoId;
            command.Parameters.Add("@Destino", SqlDbType.NVarChar, 20).Value = model.Destino;
            command.Parameters.Add("@CondicionDevolucion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.CondicionDevolucion) ? DBNull.Value : model.CondicionDevolucion.Trim();
            command.Parameters.Add("@FechaDevolucion", SqlDbType.Date).Value = DBNull.Value;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<List<ComodatoProfitabilityViewModel>> GetComodatoProfitabilityAsync()
        {
            var lista = new List<ComodatoProfitabilityViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Comodato_Rentabilidad", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ComodatoProfitabilityViewModel
                {
                    ComodatoId = reader.GetInt32(0),
                    CodigoActivo = reader.GetString(1),
                    ActivoNombre = reader.GetString(2),
                    ActivoTipo = reader.GetString(3),
                    ClienteNombre = reader.GetString(4),
                    ClienteUsuarioId = reader.IsDBNull(5) ? null : reader.GetInt32(5),
                    FechaAsignacion = reader.GetDateTime(6),
                    DiasEnComodato = reader.GetInt32(7),
                    NumPedidos = reader.GetInt32(8),
                    TotalComprado = reader.GetDecimal(9),
                    UltimaCompra = reader.IsDBNull(10) ? null : reader.GetDateTime(10)
                });
            }
            return lista;
        }
    }
}
