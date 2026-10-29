using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    // CU-131 — Tablero gerencial de indicadores (solo lectura).
    public class ReportsDbService
    {
        private readonly string _connectionString;

        public ReportsDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        public async Task<ManagementDashboardViewModel> GetDashboardAsync(DateTime desde, DateTime hasta, string rango)
        {
            var model = new ManagementDashboardViewModel
            {
                Desde = desde,
                Hasta = hasta,
                Rango = rango
            };

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            await using (var command = new SqlCommand("dbo.sp_Reportes_DashboardKpis", connection) { CommandType = CommandType.StoredProcedure })
            {
                command.Parameters.Add("@Desde", SqlDbType.Date).Value = desde.Date;
                command.Parameters.Add("@Hasta", SqlDbType.Date).Value = hasta.Date;
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    model.Desde = reader.IsDBNull(0) ? desde : reader.GetDateTime(0);
                    model.Hasta = reader.IsDBNull(1) ? hasta : reader.GetDateTime(1);
                    model.VentasPeriodo = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2);
                    model.FacturasPeriodo = reader.IsDBNull(3) ? 0 : reader.GetInt32(3);
                    model.PedidosPeriodo = reader.IsDBNull(4) ? 0 : reader.GetInt32(4);
                    model.TicketPromedio = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5);
                    model.StockBajo = reader.IsDBNull(6) ? 0 : reader.GetInt32(6);
                    model.ProductosAgotados = reader.IsDBNull(7) ? 0 : reader.GetInt32(7);
                    model.PedidosEnRuta = reader.IsDBNull(8) ? 0 : reader.GetInt32(8);
                    model.CobrosPendientes = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9);
                    model.HayDatos = !reader.IsDBNull(10) && reader.GetBoolean(10);
                }
            }

            await using (var command = new SqlCommand("dbo.sp_Reportes_DashboardVentasSerie", connection) { CommandType = CommandType.StoredProcedure })
            {
                command.Parameters.Add("@Desde", SqlDbType.Date).Value = desde.Date;
                command.Parameters.Add("@Hasta", SqlDbType.Date).Value = hasta.Date;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.Serie.Add(new SalesSeriePointViewModel
                    {
                        Dia = reader.GetDateTime(0),
                        Total = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1),
                        Facturas = reader.IsDBNull(2) ? 0 : reader.GetInt32(2)
                    });
                }
            }

            return model;
        }

        public async Task<DetailedSalesReportViewModel> GetSalesReportAsync(
            SalesReportFilterViewModel filter,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_ReportSalesAmountsV2", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Desde", SqlDbType.Date).Value = filter.Desde.Date;
            command.Parameters.Add("@Hasta", SqlDbType.Date).Value = filter.Hasta.Date;
            command.Parameters.Add("@Agrupacion", SqlDbType.NVarChar, 20).Value = filter.Agrupacion;
            command.Parameters.Add("@Categoria", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(filter.Categoria) ? DBNull.Value : filter.Categoria.Trim();
            await connection.OpenAsync(cancellationToken);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            decimal total = 0, average = 0;
            int invoices = 0, orders = 0;
            if (await reader.ReadAsync(cancellationToken))
            {
                total = reader.GetDecimal(reader.GetOrdinal("TotalVentas"));
                invoices = reader.GetInt32(reader.GetOrdinal("Facturas"));
                orders = reader.GetInt32(reader.GetOrdinal("Pedidos"));
                average = reader.GetDecimal(reader.GetOrdinal("TicketPromedio"));
            }

            var rows = new List<SalesReportRowViewModel>();
            if (await reader.NextResultAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    rows.Add(new SalesReportRowViewModel
                    {
                        Clave = reader.GetString(reader.GetOrdinal("GrupoClave")),
                        Etiqueta = reader.GetString(reader.GetOrdinal("GrupoNombre")),
                        Fecha = NullableDate(reader, "FechaGrupo"),
                        Categoria = NullableString(reader, "Categoria"),
                        TotalVentas = reader.GetDecimal(reader.GetOrdinal("TotalVentas")),
                        Facturas = reader.GetInt32(reader.GetOrdinal("Facturas")),
                        Pedidos = reader.GetInt32(reader.GetOrdinal("Pedidos")),
                        TicketPromedio = reader.GetDecimal(reader.GetOrdinal("TicketPromedio")),
                        Unidades = reader.GetInt32(reader.GetOrdinal("Unidades"))
                    });
                }
            }

            var categories = new List<string>();
            if (await reader.NextResultAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken)) categories.Add(reader.GetString(0));
            }

            return new DetailedSalesReportViewModel
            {
                Filtro = filter,
                TotalVentas = total,
                Facturas = invoices,
                Pedidos = orders,
                TicketPromedio = average,
                Filas = rows,
                Categorias = categories
            };
        }

        public async Task<SellerPerformanceViewModel> GetSellerPerformanceAsync(
            SellerPerformanceFilterViewModel filter,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Reportes_DesempenoVendedores", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Desde", SqlDbType.Date).Value = filter.Desde.Date;
            command.Parameters.Add("@Hasta", SqlDbType.Date).Value = filter.Hasta.Date;
            command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = filter.VendedorUsuarioId.HasValue ? filter.VendedorUsuarioId.Value : DBNull.Value;
            command.Parameters.Add("@Orden", SqlDbType.NVarChar, 30).Value = filter.Orden;
            await connection.OpenAsync(cancellationToken);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            var rows = new List<SellerPerformanceRowViewModel>();
            while (await reader.ReadAsync(cancellationToken))
            {
                rows.Add(new SellerPerformanceRowViewModel
                {
                    VendedorUsuarioId = reader.GetInt32(reader.GetOrdinal("VendedorUsuarioId")),
                    VendedorNombre = reader.GetString(reader.GetOrdinal("VendedorNombre")),
                    Ventas = reader.GetDecimal(reader.GetOrdinal("Ventas")),
                    Pedidos = reader.GetInt32(reader.GetOrdinal("Pedidos")),
                    Facturas = reader.GetInt32(reader.GetOrdinal("Facturas")),
                    TicketPromedio = reader.GetDecimal(reader.GetOrdinal("TicketPromedio")),
                    ClientesAtendidos = reader.GetInt32(reader.GetOrdinal("ClientesAtendidos")),
                    Meta = NullableDecimal(reader, "Meta"),
                    CumplimientoPorcentual = NullableDecimal(reader, "CumplimientoPorcentual")
                });
            }

            var sellers = new List<VendedorOptionViewModel>();
            if (await reader.NextResultAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    sellers.Add(new VendedorOptionViewModel
                    {
                        UsuarioId = reader.GetInt32(reader.GetOrdinal("UsuarioId")),
                        NombreCompleto = reader.GetString(reader.GetOrdinal("NombreCompleto")),
                        Correo = reader.IsDBNull(reader.GetOrdinal("Correo")) ? string.Empty : reader.GetString(reader.GetOrdinal("Correo"))
                    });
                }
            }

            return new SellerPerformanceViewModel { Filtro = filter, Filas = rows, Vendedores = sellers };
        }

        private static string? NullableString(SqlDataReader reader, string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
        }

        private static DateTime? NullableDate(SqlDataReader reader, string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
        }

        private static decimal? NullableDecimal(SqlDataReader reader, string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetDecimal(ordinal);
        }

    }
}
