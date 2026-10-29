using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-081 / CU-082 / CU-083 — Rutas de entrega, estado de entrega y evidencias.
    // Acceso a datos con ADO.NET + stored procedures (mismo patrón del proyecto).
    public class LogisticsDbService
    {
        private readonly string _connectionString;
        private readonly IHttpContextAccessor? _contextAccessor;

        public LogisticsDbService(IConfiguration configuration, IHttpContextAccessor? contextAccessor = null)
        {
            _contextAccessor = contextAccessor;
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ────────────────────────────────────────────────────
        // VEHÍCULOS
        // ────────────────────────────────────────────────────
        public async Task<List<VehicleListItemViewModel>> GetVehiclesAsync(string? buscar)
        {
            var lista = new List<VehicleListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Vehiculos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new VehicleListItemViewModel
                {
                    VehiculoId = reader.GetInt32(0),
                    Placa = reader.GetString(1),
                    Descripcion = reader.GetString(2),
                    Capacidad = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                    Activo = !reader.IsDBNull(4) && reader.GetBoolean(4),
                    RutasAbiertas = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    Marca = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    KilometrajeActual = reader.IsDBNull(7) ? 0 : reader.GetInt32(7)
                });
            }
            return lista;
        }

        public async Task<VehicleFormViewModel?> GetVehicleByIdAsync(int vehiculoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Vehiculos_GetById", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = vehiculoId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new VehicleFormViewModel
                {
                    VehiculoId = reader.GetInt32(0),
                    Placa = reader.GetString(1),
                    Descripcion = reader.GetString(2),
                    Capacidad = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                    Activo = !reader.IsDBNull(4) && reader.GetBoolean(4),
                    Marca = reader.IsDBNull(5) ? null : reader.GetString(5)
                };
            }
            return null;
        }

        public async Task<int> CreateVehicleAsync(VehicleFormViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Vehiculos_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Placa", SqlDbType.NVarChar, 20).Value = model.Placa.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 150).Value = model.Descripcion.Trim();
            command.Parameters.Add("@Capacidad", SqlDbType.Int).Value = model.Capacidad;
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
            command.Parameters.Add("@Marca", SqlDbType.NVarChar, 60).Value = string.IsNullOrWhiteSpace(model.Marca) ? DBNull.Value : model.Marca.Trim();
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task UpdateVehicleAsync(VehicleFormViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Vehiculos_Update", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = model.VehiculoId;
            command.Parameters.Add("@Placa", SqlDbType.NVarChar, 20).Value = model.Placa.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 150).Value = model.Descripcion.Trim();
            command.Parameters.Add("@Capacidad", SqlDbType.Int).Value = model.Capacidad;
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
            command.Parameters.Add("@Marca", SqlDbType.NVarChar, 60).Value = string.IsNullOrWhiteSpace(model.Marca) ? DBNull.Value : model.Marca.Trim();
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<bool> ToggleVehicleStatusAsync(int vehiculoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Vehiculos_ToggleStatus", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = vehiculoId;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is bool b && b;
        }

        // ────────────────────────────────────────────────────
        // RUTAS (admin)
        // ────────────────────────────────────────────────────
        public async Task<List<AssignableOrderViewModel>> GetAssignableOrdersAsync(string? buscar)
        {
            var lista = new List<AssignableOrderViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_GetAssignableOrders", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new AssignableOrderViewModel
                {
                    PedidoId = reader.GetInt32(0),
                    Cliente = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    FechaPedido = reader.IsDBNull(3) ? DateTime.MinValue : reader.GetDateTime(3),
                    Estado = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    TipoEntrega = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    DireccionEntrega = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    Total = reader.IsDBNull(7) ? 0 : reader.GetDecimal(7),
                    TotalLineas = reader.IsDBNull(8) ? 0 : reader.GetInt32(8)
                });
            }
            return lista;
        }

        public async Task<List<DriverOptionViewModel>> GetAvailableDriversAsync()
        {
            var lista = new List<DriverOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_GetAvailableDrivers", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new DriverOptionViewModel
                {
                    UsuarioId = reader.GetInt32(0),
                    NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Telefono = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    RutasAbiertas = reader.IsDBNull(4) ? 0 : reader.GetInt32(4)
                });
            }
            return lista;
        }

        public async Task<List<VehicleOptionViewModel>> GetAvailableVehiclesAsync()
        {
            var lista = new List<VehicleOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_GetAvailableVehicles", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new VehicleOptionViewModel
                {
                    VehiculoId = reader.GetInt32(0),
                    Placa = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Descripcion = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Capacidad = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                    RutasAbiertas = reader.IsDBNull(4) ? 0 : reader.GetInt32(4)
                });
            }
            return lista;
        }

        public async Task<(int RutaId, string Codigo)> CreateRouteAsync(
            string zona, int choferUsuarioId, int vehiculoId, string? observaciones,
            List<int> pedidos, int creadaPorUsuarioId, string creadaPorNombre)
        {
            var pedidosJson = "[" + string.Join(",", pedidos.Distinct().Select(id => $"{{\"pedidoId\":{id}}}")) + "]";

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_Create", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Zona", SqlDbType.NVarChar, 120).Value = zona.Trim();
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferUsuarioId;
            command.Parameters.Add("@VehiculoId", SqlDbType.Int).Value = vehiculoId;
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(observaciones) ? DBNull.Value : observaciones.Trim();
            command.Parameters.Add("@PedidosJson", SqlDbType.NVarChar, -1).Value = pedidosJson;
            command.Parameters.Add("@CreadaPorUsuarioId", SqlDbType.Int).Value = creadaPorUsuarioId > 0 ? creadaPorUsuarioId : DBNull.Value;
            command.Parameters.Add("@CreadaPorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(creadaPorNombre) ? DBNull.Value : creadaPorNombre.Trim();
            return await ExecuteLogisticsAsync<(int RutaId, string Codigo)>(connection, command, "Create", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return (reader.GetInt32(0), reader.IsDBNull(1) ? string.Empty : reader.GetString(1));
            }
            return (0, string.Empty);
            });
        }

        public async Task<List<RouteListItemViewModel>> GetRoutesAsync(string? estado, string? buscar)
        {
            var lista = new List<RouteListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new RouteListItemViewModel
                {
                    RutaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Zona = reader.GetString(2),
                    Estado = reader.GetString(3),
                    Chofer = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    VehiculoPlaca = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    FechaCreacion = reader.GetDateTime(6),
                    FechaDespacho = reader.IsDBNull(7) ? null : reader.GetDateTime(7),
                    TotalPedidos = reader.IsDBNull(8) ? 0 : reader.GetInt32(8),
                    Entregados = reader.IsDBNull(9) ? 0 : reader.GetInt32(9),
                    Fallidos = reader.IsDBNull(10) ? 0 : reader.GetInt32(10),
                    Pendientes = reader.IsDBNull(11) ? 0 : reader.GetInt32(11)
                });
            }
            return lista;
        }

        public async Task<RouteHeaderViewModel?> GetRouteHeaderAsync(int rutaId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_GetHeader", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new RouteHeaderViewModel
                {
                    RutaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Zona = reader.GetString(2),
                    Estado = reader.GetString(3),
                    ChoferUsuarioId = reader.GetInt32(4),
                    Chofer = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    VehiculoId = reader.GetInt32(6),
                    VehiculoPlaca = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                    VehiculoDescripcion = reader.IsDBNull(8) ? string.Empty : reader.GetString(8),
                    Observaciones = reader.IsDBNull(9) ? string.Empty : reader.GetString(9),
                    CreadaPorNombre = reader.IsDBNull(10) ? string.Empty : reader.GetString(10),
                    FechaCreacion = reader.GetDateTime(11),
                    FechaDespacho = reader.IsDBNull(12) ? null : reader.GetDateTime(12),
                    FechaCierre = reader.IsDBNull(13) ? null : reader.GetDateTime(13)
                };
            }
            return null;
        }

        public async Task<List<RouteOrderItemViewModel>> GetRouteOrdersAsync(int rutaId)
        {
            var lista = new List<RouteOrderItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_GetOrders", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new RouteOrderItemViewModel
                {
                    RutaPedidoId = reader.GetInt32(0),
                    PedidoId = reader.GetInt32(1),
                    Secuencia = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                    EstadoEntrega = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    MotivoFallo = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    FechaEntrega = reader.IsDBNull(5) ? null : reader.GetDateTime(5),
                    Cliente = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    ClienteCorreo = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                    DireccionEntrega = reader.IsDBNull(8) ? string.Empty : reader.GetString(8),
                    Total = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9),
                    EstadoPedido = reader.IsDBNull(10) ? string.Empty : reader.GetString(10),
                    TotalEvidencias = reader.IsDBNull(11) ? 0 : reader.GetInt32(11),
                    Latitud = reader.IsDBNull(12) ? null : reader.GetDecimal(12),
                    Longitud = reader.IsDBNull(13) ? null : reader.GetDecimal(13)
                });
            }
            return lista;
        }

        public async Task AddOrderToRouteAsync(int rutaId, int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_AddOrder", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            await ExecuteLogisticsAsync(connection, command, "AddOrder", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        public async Task RemoveOrderFromRouteAsync(int rutaId, int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_RemoveOrder", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            await ExecuteLogisticsAsync(connection, command, "RemoveOrder", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        public async Task<List<(int PedidoId, string Nombre, string Correo)>> DispatchRouteAsync(int rutaId, int usuarioId, string usuarioNombre)
        {
            var destinatarios = new List<(int, string, string)>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_Dispatch", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();
            return await ExecuteLogisticsAsync<List<(int PedidoId, string Nombre, string Correo)>>(connection, command, "Dispatch", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                destinatarios.Add((
                    reader.GetInt32(0),
                    reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    reader.IsDBNull(2) ? string.Empty : reader.GetString(2)));
            }
            return destinatarios;
            });
        }

        // CU-251 E1 — Secuenciar automáticamente (vecino más cercano).
        // Devuelve (puntos secuenciados, puntos sin coordenada capturada).
        public async Task<(int Secuenciados, int SinCoordenadas)> SequenceRouteAsync(int rutaId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_Secuenciar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            return await ExecuteLogisticsAsync<(int Secuenciados, int SinCoordenadas)>(connection, command, "Sequence", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return (reader.IsDBNull(0) ? 0 : reader.GetInt32(0), reader.IsDBNull(1) ? 0 : reader.GetInt32(1));
            }
            return (0, 0);
            });
        }

        // CU-251 E3 — Guardar secuencia manual + coordenadas.
        public async Task SaveSequenceAsync(int rutaId, string itemsJson)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_GuardarSecuencia", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@ItemsJson", SqlDbType.NVarChar, -1).Value = itemsJson;
            await ExecuteLogisticsAsync(connection, command, "SaveSequence", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        // CU-253 — Recalcular ruta despachada. Devuelve puntos re-secuenciados.
        public async Task<int> RecalculateRouteAsync(int rutaId, int? excluirRutaPedidoId, string? motivoFallo)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_Recalcular", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@ExcluirRutaPedidoId", SqlDbType.Int).Value = excluirRutaPedidoId.HasValue && excluirRutaPedidoId > 0 ? excluirRutaPedidoId.Value : DBNull.Value;
            command.Parameters.Add("@MotivoFallo", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(motivoFallo) ? DBNull.Value : motivoFallo.Trim();
            return await ExecuteLogisticsAsync<int>(connection, command, "Recalculate", async () =>
            {
            var result = await command.ExecuteScalarAsync();
            return result is int n ? n : Convert.ToInt32(result ?? 0);
            });
        }

        // CU-105 — Liquidar ruta: reingresa al inventario la mercadería no entregada
        // y cierra la ruta. Devuelve (pedidos reingresados, unidades reingresadas).
        public async Task<(int PedidosReingresados, int UnidadesReingresadas)> LiquidateRouteAsync(int rutaId, int usuarioId, string usuarioNombre)
        {
            return await Task.FromException<(int, int)>(new LogisticsSettlementUnavailableException());
        }

        // ── CU-106 Liquidación financiera de cobros de ruta ──
        public async Task<CashSettlementPrepareViewModel?> PrepareCashSettlementAsync(int rutaId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_LiquidacionCobros_Preparar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            var model = new CashSettlementPrepareViewModel
            {
                RutaId = reader.GetInt32(0),
                RutaCodigo = reader.GetString(1),
                EstadoRuta = reader.GetString(2),
                Liquidada = reader.GetBoolean(3),
                YaLiquidadaFinanciera = reader.GetInt32(4) > 0,
                EsperadoEfectivo = reader.GetDecimal(5),
                EsperadoOtros = reader.GetDecimal(6)
            };

            if (await reader.NextResultAsync())
            {
                while (await reader.ReadAsync())
                {
                    model.Pedidos.Add(new CashSettlementOrderLine
                    {
                        PedidoId = reader.GetInt32(0),
                        Total = reader.GetDecimal(1),
                        MetodoPago = reader.GetString(2),
                        EstadoPago = reader.GetString(3),
                        Cliente = reader.GetString(4)
                    });
                }
            }
            return model;
        }

        public async Task<(int LiquidacionId, string Estado, decimal Diferencia)> RegisterCashSettlementAsync(
            CashSettlementFormViewModel model, string comprobantesJson, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_LiquidacionCobros_Registrar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = model.RutaId;
            command.Parameters.Add("@MontoEfectivoRecibido", SqlDbType.Decimal).Value = model.MontoEfectivoRecibido;
            command.Parameters["@MontoEfectivoRecibido"].Precision = 18;
            command.Parameters["@MontoEfectivoRecibido"].Scale = 2;
            command.Parameters.Add("@MontoComprobantes", SqlDbType.Decimal).Value = model.MontoComprobantes;
            command.Parameters["@MontoComprobantes"].Precision = 18;
            command.Parameters["@MontoComprobantes"].Scale = 2;
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 400).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
            command.Parameters.Add("@ComprobantesJson", SqlDbType.NVarChar, -1).Value = string.IsNullOrWhiteSpace(comprobantesJson) ? DBNull.Value : comprobantesJson;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return (reader.GetInt32(0), reader.GetString(1), reader.GetDecimal(2));
            }
            return (0, string.Empty, 0m);
        }

        public async Task<List<CashSettlementListItemViewModel>> GetCashSettlementsAsync(string? estado)
        {
            var lista = new List<CashSettlementListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_LiquidacionCobros_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new CashSettlementListItemViewModel
                {
                    LiquidacionCobrosId = reader.GetInt32(0),
                    RutaId = reader.GetInt32(1),
                    RutaCodigo = reader.GetString(2),
                    MontoEsperadoEfectivo = reader.GetDecimal(3),
                    MontoEsperadoOtros = reader.GetDecimal(4),
                    MontoEfectivoRecibido = reader.GetDecimal(5),
                    MontoComprobantes = reader.GetDecimal(6),
                    Diferencia = reader.GetDecimal(7),
                    Estado = reader.GetString(8),
                    LiquidadoPorNombre = reader.GetString(9),
                    FechaLiquidacion = reader.GetDateTime(10)
                });
            }
            return lista;
        }

        public async Task CancelRouteAsync(int rutaId, string? motivo, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Rutas_Cancel", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(motivo) ? DBNull.Value : motivo.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();
            await ExecuteLogisticsAsync(connection, command, "Cancel", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        // ────────────────────────────────────────────────────
        // PORTAL DEL CHOFER
        // ────────────────────────────────────────────────────
        public async Task<List<DriverRouteItemViewModel>> GetDriverRoutesAsync(int choferUsuarioId)
        {
            var lista = new List<DriverRouteItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Chofer_GetMyRoutes", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferUsuarioId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new DriverRouteItemViewModel
                {
                    RutaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Zona = reader.GetString(2),
                    Estado = reader.GetString(3),
                    VehiculoPlaca = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    FechaDespacho = reader.IsDBNull(5) ? null : reader.GetDateTime(5),
                    TotalPedidos = reader.IsDBNull(6) ? 0 : reader.GetInt32(6),
                    Pendientes = reader.IsDBNull(7) ? 0 : reader.GetInt32(7),
                    Entregados = reader.IsDBNull(8) ? 0 : reader.GetInt32(8)
                });
            }
            return lista;
        }

        public async Task<DriverRouteViewModel?> GetDriverRouteAsync(int rutaId, int choferUsuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Chofer_GetRouteDeliveries", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferUsuarioId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            DriverRouteViewModel? vm = null;
            if (await reader.ReadAsync())
            {
                vm = new DriverRouteViewModel
                {
                    RutaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Zona = reader.GetString(2),
                    Estado = reader.GetString(3),
                    VehiculoPlaca = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    FechaDespacho = reader.IsDBNull(5) ? null : reader.GetDateTime(5)
                };
            }

            if (vm != null && await reader.NextResultAsync())
            {
                while (await reader.ReadAsync())
                {
                    vm.Entregas.Add(new DriverDeliveryItemViewModel
                    {
                        RutaPedidoId = reader.GetInt32(0),
                        PedidoId = reader.GetInt32(1),
                        Secuencia = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                        EstadoEntrega = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        MotivoFallo = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                        FechaEntrega = reader.IsDBNull(5) ? null : reader.GetDateTime(5),
                        Cliente = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                        Telefono = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                        DireccionEntrega = reader.IsDBNull(8) ? string.Empty : reader.GetString(8),
                        Total = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9),
                        TotalEvidencias = reader.IsDBNull(10) ? 0 : reader.GetInt32(10),
                        Latitud = reader.IsDBNull(11) ? null : reader.GetDecimal(11),
                        Longitud = reader.IsDBNull(12) ? null : reader.GetDecimal(12)
                    });
                }
            }
            return vm;
        }

        public async Task<UpdateDeliveryStatusResultViewModel?> UpdateDeliveryStatusAsync(
            int rutaPedidoId, string nuevoEstado, Guid syncGuid, string? motivoFallo,
            int choferUsuarioId, string choferNombre, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_ConfirmDelivery", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaPedidoId", SqlDbType.Int).Value = rutaPedidoId;
            command.Parameters.Add("@NuevoEstado", SqlDbType.NVarChar, 20).Value = nuevoEstado.Trim();
            command.Parameters.Add("@SyncGuid", SqlDbType.UniqueIdentifier).Value = syncGuid;
            command.Parameters.Add("@MotivoFallo", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(motivoFallo) ? DBNull.Value : motivoFallo.Trim();
            command.Parameters.Add("@ChoferUsuarioId", SqlDbType.Int).Value = choferUsuarioId;
            command.Parameters.Add("@ChoferNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(choferNombre) ? DBNull.Value : choferNombre.Trim();
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, choferUsuarioId, null, async () =>
            {
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                return new UpdateDeliveryStatusResultViewModel
                {
                    RutaPedidoId = reader.GetInt32(0),
                    EstadoEntrega = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    PedidoId = reader.GetInt32(2),
                    ClienteCorreo = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    ClienteNombre = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    Notificar = !reader.IsDBNull(5) && reader.GetBoolean(5),
                    RutaCompletada = !reader.IsDBNull(6) && reader.GetBoolean(6),
                    Duplicado = !reader.IsDBNull(7) && reader.GetBoolean(7)
                };
                }
                return null;
            });
        }

        // ────────────────────────────────────────────────────
        // EVIDENCIAS (CU-083)
        // ────────────────────────────────────────────────────
        public async Task<int> RegisterEvidenceAsync(
            int pedidoId, int? rutaId, string tipoEvidencia, string storageKey, string mimeType,
            string? observaciones, int registradoPorUsuarioId, string registradoPorNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_RegisterEvidence", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId.HasValue && rutaId.Value > 0 ? rutaId.Value : DBNull.Value;
            command.Parameters.Add("@TipoEvidencia", SqlDbType.NVarChar, 20).Value = tipoEvidencia.Trim();
            command.Parameters.Add("@StorageKey", SqlDbType.NVarChar, 160).Value = storageKey.Trim();
            command.Parameters.Add("@MimeType", SqlDbType.NVarChar, 100).Value = mimeType.Trim();
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(observaciones) ? DBNull.Value : observaciones.Trim();
            command.Parameters.Add("@RegistradoPorUsuarioId", SqlDbType.Int).Value = registradoPorUsuarioId > 0 ? registradoPorUsuarioId : DBNull.Value;
            command.Parameters.Add("@RegistradoPorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(registradoPorNombre) ? DBNull.Value : registradoPorNombre.Trim();
            return await ExecuteLogisticsAsync<int>(connection, command, "Evidence", async () =>
            {
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
            });
        }

        public async Task MarkEvidenceReadyAsync(int evidenciaId, int registradoPorUsuarioId, string sha256, long length)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_MarkEvidenceReady", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@EvidenciaId", SqlDbType.Int).Value = evidenciaId;
            command.Parameters.Add("@RegistradoPorUsuarioId", SqlDbType.Int).Value = registradoPorUsuarioId;
            command.Parameters.Add("@Sha256", SqlDbType.Char, 64).Value = sha256;
            command.Parameters.Add("@Length", SqlDbType.BigInt).Value = length;
            await ExecuteLogisticsAsync(connection, command, "Evidence", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        public async Task DeletePendingEvidenceAsync(int evidenciaId, int registradoPorUsuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_DeletePendingEvidence", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@EvidenciaId", SqlDbType.Int).Value = evidenciaId;
            command.Parameters.Add("@RegistradoPorUsuarioId", SqlDbType.Int).Value = registradoPorUsuarioId;
            await ExecuteLogisticsAsync(connection, command, "Evidence", async () =>
            {
            await command.ExecuteNonQueryAsync();
            });
        }

        public async Task<AuthorizedEvidenceViewModel?> GetAuthorizedEvidenceAsync(
            int evidenciaId,
            int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_GetAuthorizedEvidence", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@EvidenciaId", SqlDbType.Int).Value = evidenciaId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            return await ExecuteLogisticsAsync<AuthorizedEvidenceViewModel?>(connection, command, "Evidence", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
            if (!await reader.ReadAsync()) return null;
            return new AuthorizedEvidenceViewModel
            {
                EvidenciaId = reader.GetInt32(0),
                PedidoId = reader.GetInt32(1),
                StorageKey = reader.GetString(2),
                MimeType = reader.GetString(3),
                TipoEvidencia = reader.GetString(4),
                Sha256 = reader.IsDBNull(5) ? null : reader.GetString(5),
                LengthBytes = reader.IsDBNull(6) ? null : reader.GetInt64(6)
            };
            });
        }

        public async Task<List<EvidenceItemViewModel>> GetEvidencesByOrderAsync(int pedidoId)
        {
            var lista = new List<EvidenceItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_GetEvidencesByOrder", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@Actor", SqlDbType.Int).Value = OriginalLoginSession.ValidatedRequest(_contextAccessor?.HttpContext ?? throw new UnauthorizedAccessException()).UserId;
            return await ExecuteLogisticsAsync<List<EvidenceItemViewModel>>(connection, command, "Evidence", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(ReadEvidence(reader));
            }
            return lista;
            });
        }

        public async Task<RouteEvidencesViewModel> GetRouteEvidencesAsync(int rutaId, RouteHeaderViewModel cabecera)
        {
            var vm = new RouteEvidencesViewModel { Cabecera = cabecera };
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_GetEvidencesByRoute", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@RutaId", SqlDbType.Int).Value = rutaId;
            command.Parameters.Add("@Actor", SqlDbType.Int).Value = OriginalLoginSession.ValidatedRequest(_contextAccessor?.HttpContext ?? throw new UnauthorizedAccessException()).UserId;
            return await ExecuteLogisticsAsync<RouteEvidencesViewModel>(connection, command, "Evidence", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                vm.Resumen.Add(new RouteEvidenceSummaryViewModel
                {
                    PedidoId = reader.GetInt32(0),
                    EstadoEntrega = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Cliente = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    TotalEvidencias = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                    SinEvidencia = !reader.IsDBNull(4) && reader.GetBoolean(4)
                });
            }
            if (await reader.NextResultAsync())
            {
                while (await reader.ReadAsync())
                {
                    vm.Evidencias.Add(new EvidenceItemViewModel
                    {
                        EvidenciaId = reader.GetInt32(0),
                        PedidoId = reader.GetInt32(1),
                        TipoEvidencia = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                        StorageKey = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        MimeType = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                        Observaciones = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                        RegistradoPorNombre = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                        FechaRegistro = reader.GetDateTime(7)
                    });
                }
            }
            return vm;
            });
        }

        private static EvidenceItemViewModel ReadEvidence(SqlDataReader reader) => new EvidenceItemViewModel
        {
            EvidenciaId = reader.GetInt32(0),
            PedidoId = reader.GetInt32(1),
            RutaId = reader.IsDBNull(2) ? null : reader.GetInt32(2),
            TipoEvidencia = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
            StorageKey = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
            MimeType = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
            Observaciones = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
            RegistradoPorNombre = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
            FechaRegistro = reader.GetDateTime(8)
        };
        private Task<T> ExecuteLogisticsAsync<T>(SqlConnection connection, SqlCommand command, string operation, Func<Task<T>> work)
        {
            var login = OriginalLoginSession.ValidatedRequest(_contextAccessor?.HttpContext
                ?? throw new UnauthorizedAccessException("Falta el contexto original de la solicitud."));
            foreach (var name in new[] { "@UsuarioId", "@CreadaPorUsuarioId", "@RegistradoPorUsuarioId" })
                if (command.Parameters.Contains(name) && command.Parameters[name].Value is int actor && actor != login.UserId)
                    throw new UnauthorizedAccessException("El actor no corresponde al login original.");
            if (operation == "Create")
            {
                command.CommandText = "dbo.sp_Stage2_CreateRoute";
                command.Parameters.Add("@Actor", SqlDbType.Int).Value = login.UserId;
            }
            else if (operation != "Evidence")
            {
                command.CommandText = "dbo.sp_Stage2_RouteOperation";
                command.Parameters.Add("@Actor", SqlDbType.Int).Value = login.UserId;
                command.Parameters.Add("@Operation", SqlDbType.NVarChar, 20).Value = operation;
            }
            return OriginalLoginTransaction.ExecuteAsync(connection, command, login, login.UserId,
                operation == "Evidence" ? null : "RUTAS_GESTIONAR", work);
        }

        private Task ExecuteLogisticsAsync(SqlConnection connection, SqlCommand command, string operation, Func<Task> work) =>
            ExecuteLogisticsAsync(connection, command, operation, async () => { await work(); return 0; });

    }
}
