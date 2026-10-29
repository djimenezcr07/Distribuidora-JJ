using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-211/213 — Acceso a datos de metas mensuales por vendedor y KPIs.
    public class KpiDbService
    {
        private readonly string _connectionString;

        public KpiDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ── Vendedores disponibles ──────────────────────────
        public async Task<List<VendedorOptionViewModel>> GetSellerOptionsAsync()
        {
            var lista = new List<VendedorOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Metas_Vendedores_Options", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new VendedorOptionViewModel
                {
                    UsuarioId = reader.GetInt32(0),
                    NombreCompleto = reader.GetString(1),
                    Correo = reader.GetString(2)
                });
            }
            return lista;
        }

        // ── CU-211 Definir/actualizar meta ──────────────────
        public async Task UpsertMetaAsync(MetaFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Metas_Upsert", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = model.VendedorUsuarioId;
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = model.Anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = model.Mes;
            command.Parameters.Add("@MontoMeta", SqlDbType.Decimal).Value = model.MontoMeta;
            command.Parameters["@MontoMeta"].Precision = 18;
            command.Parameters["@MontoMeta"].Scale = 2;
            command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-211 Listado de metas del período ─────────────
        public async Task<List<MetaListItemViewModel>> GetMetasAsync(int anio, int mes)
        {
            var lista = new List<MetaListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Metas_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = mes;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new MetaListItemViewModel
                {
                    MetaId = reader.GetInt32(0),
                    VendedorUsuarioId = reader.GetInt32(1),
                    VendedorNombre = reader.GetString(2),
                    Anio = reader.GetInt32(3),
                    Mes = reader.GetInt32(4),
                    MontoMeta = reader.GetDecimal(5),
                    VentasReales = reader.GetDecimal(6),
                    PorcentajeCumplimiento = reader.GetDecimal(7),
                    Observaciones = reader.GetString(8)
                });
            }
            return lista;
        }

        // ── CU-212 Progreso individual del vendedor autenticado ─
        public async Task<MetaProgresoViewModel> GetMiProgresoAsync(int vendedorUsuarioId, int anio, int mes)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Metas_MiProgreso", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = vendedorUsuarioId;
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = mes;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new MetaProgresoViewModel
                {
                    Anio = reader.GetInt32(reader.GetOrdinal("Anio")),
                    Mes = reader.GetInt32(reader.GetOrdinal("Mes")),
                    MontoMeta = reader.GetDecimal(reader.GetOrdinal("MontoMeta")),
                    VentasReales = reader.GetDecimal(reader.GetOrdinal("VentasReales")),
                    PorcentajeCumplimiento = reader.GetDecimal(reader.GetOrdinal("PorcentajeCumplimiento")),
                    MontoPendiente = reader.GetDecimal(reader.GetOrdinal("MontoPendiente")),
                    SinMetaDefinida = reader.GetBoolean(reader.GetOrdinal("SinMetaDefinida"))
                };
            }
            return new MetaProgresoViewModel { Anio = anio, Mes = mes, SinMetaDefinida = true };
        }

        // ── CU-213 Reporte de cumplimiento global ───────────
        public async Task<KpiReportViewModel> GetGlobalKpiAsync(int anio, int mes)
        {
            var model = new KpiReportViewModel { Anio = anio, Mes = mes };
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Kpi_CumplimientoGlobal", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Anio", SqlDbType.Int).Value = anio;
            command.Parameters.Add("@Mes", SqlDbType.Int).Value = mes;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                model.Items.Add(new KpiReportItemViewModel
                {
                    VendedorUsuarioId = reader.GetInt32(0),
                    VendedorNombre = reader.GetString(1),
                    MontoMeta = reader.GetDecimal(2),
                    VentasReales = reader.GetDecimal(3),
                    Facturas = reader.GetInt32(4),
                    PorcentajeCumplimiento = reader.IsDBNull(5) ? null : reader.GetDecimal(5),
                    Clasificacion = reader.GetString(6)
                });
            }

            // Segunda tabla: resumen global.
            if (await reader.NextResultAsync() && await reader.ReadAsync())
            {
                model.MetaGlobal = reader.GetDecimal(0);
                model.VentaGlobal = reader.GetDecimal(1);
                model.VendedoresConMeta = reader.GetInt32(2);
            }
            return model;
        }
    }
}
