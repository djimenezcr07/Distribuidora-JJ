using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-222 — Acceso a datos de gastos operativos y cuentas presupuestarias.
    public partial class ExpensesDbService
    {
        private readonly string _connectionString;

        public ExpensesDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ── Cuentas (combos y gestión) ──────────────────────
        public async Task<List<CuentaOptionViewModel>> GetAccountOptionsAsync()
        {
            var lista = new List<CuentaOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_CuentasPresupuestarias_Options", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new CuentaOptionViewModel
                {
                    CuentaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    PresupuestoMensual = reader.GetDecimal(3)
                });
            }
            return lista;
        }

        public async Task<List<CuentaViewModel>> GetAccountsAsync()
        {
            var lista = new List<CuentaViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_CuentasPresupuestarias_List", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new CuentaViewModel
                {
                    CuentaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    Descripcion = reader.GetString(3),
                    PresupuestoMensual = reader.GetDecimal(4),
                    Activo = reader.GetBoolean(5)
                });
            }
            return lista;
        }

        public async Task UpsertAccountAsync(CuentaViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_CuentasPresupuestarias_Upsert", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@CuentaId", SqlDbType.Int).Value = model.CuentaId > 0 ? model.CuentaId : DBNull.Value;
            command.Parameters.Add("@Codigo", SqlDbType.NVarChar, 20).Value = model.Codigo.Trim();
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 120).Value = model.Nombre.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
            command.Parameters.Add("@PresupuestoMensual", SqlDbType.Decimal).Value = model.PresupuestoMensual;
            command.Parameters["@PresupuestoMensual"].Precision = 18;
            command.Parameters["@PresupuestoMensual"].Scale = 2;
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-222 Registrar gasto ──────────────────────────
        public async Task<int> RegisterExpenseAsync(GastoFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Gastos_Registrar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@CuentaId", SqlDbType.Int).Value = model.CuentaId;
            command.Parameters.Add("@Fecha", SqlDbType.Date).Value = model.Fecha.Date;
            command.Parameters.Add("@Monto", SqlDbType.Decimal).Value = model.Monto;
            command.Parameters["@Monto"].Precision = 18;
            command.Parameters["@Monto"].Scale = 2;
            command.Parameters.Add("@Concepto", SqlDbType.NVarChar, 200).Value = model.Concepto.Trim();
            command.Parameters.Add("@Proveedor", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(model.Proveedor) ? DBNull.Value : model.Proveedor.Trim();
            command.Parameters.Add("@Comprobante", SqlDbType.NVarChar, 60).Value = string.IsNullOrWhiteSpace(model.Comprobante) ? DBNull.Value : model.Comprobante.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        // ── CU-222 Listado de gastos ────────────────────────
        public async Task<List<GastoListItemViewModel>> GetExpensesAsync(int anio, int mes, int? cuentaId)
        {
            var lista = new List<GastoListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Gastos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = mes;
            command.Parameters.Add("@CuentaId", SqlDbType.Int).Value = cuentaId.HasValue && cuentaId.Value > 0 ? cuentaId.Value : DBNull.Value;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new GastoListItemViewModel
                {
                    GastoId = reader.GetInt32(0),
                    Fecha = reader.GetDateTime(1),
                    Monto = reader.GetDecimal(2),
                    Concepto = reader.GetString(3),
                    Proveedor = reader.GetString(4),
                    Comprobante = reader.GetString(5),
                    RegistradoPorNombre = reader.GetString(6),
                    CuentaId = reader.GetInt32(7),
                    CuentaCodigo = reader.GetString(8),
                    CuentaNombre = reader.GetString(9)
                });
            }
            return lista;
        }

        // ── CU-222 Resumen presupuestario (afectación de cuentas) ──
        public async Task<List<PresupuestoResumenViewModel>> GetBudgetSummaryAsync(int anio, int mes)
        {
            var lista = new List<PresupuestoResumenViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Presupuesto_Resumen", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = mes;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new PresupuestoResumenViewModel
                {
                    CuentaId = reader.GetInt32(0),
                    Codigo = reader.GetString(1),
                    Nombre = reader.GetString(2),
                    PresupuestoMensual = reader.GetDecimal(3),
                    Gastado = reader.GetDecimal(4),
                    Disponible = reader.GetDecimal(5),
                    PorcentajeEjecucion = reader.IsDBNull(6) ? null : reader.GetDecimal(6)
                });
            }
            return lista;
        }
    }
}
