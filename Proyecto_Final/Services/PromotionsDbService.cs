using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;
using System.Data.Common;

namespace Proyecto_Final.Services
{
    // CU-171/172/173/174 — Motor de promociones (configuración, segmentación e inactivación).
    public class PromotionsDbService
    {
        private readonly string _connectionString;

        public PromotionsDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        // ── CU-171/172 Listado ──────────────────────────────
        public async Task<List<PromotionListItemViewModel>> GetPromotionsAsync(string? estado, string? buscar)
        {
            var lista = new List<PromotionListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Promociones_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new PromotionListItemViewModel
                {
                    PromocionId = reader.GetInt32(0),
                    Nombre = reader.GetString(1),
                    Tipo = reader.GetString(2),
                    SegmentoCliente = reader.GetString(3),
                    Estado = reader.GetString(4),
                    FechaInicio = reader.GetDateTime(5),
                    FechaFin = reader.GetDateTime(6),
                    CantidadMinima = reader.GetInt32(7),
                    PorcentajeDescuento = reader.IsDBNull(8) ? null : reader.GetDecimal(8),
                    CantidadRegalo = reader.IsDBNull(9) ? null : reader.GetInt32(9),
                    Prioridad = reader.GetInt32(10),
                    ProductoNombre = reader.GetString(11),
                    ProductoRegaloNombre = reader.IsDBNull(12) ? null : reader.GetString(12),
                    Vigente = reader.GetInt32(13) == 1
                });
            }
            return lista;
        }

        public async Task<PromotionFormViewModel?> GetPromotionByIdAsync(int promocionId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Promociones_GetById", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PromocionId", SqlDbType.Int).Value = promocionId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new PromotionFormViewModel
                {
                    PromocionId = reader.GetInt32(0),
                    Nombre = reader.GetString(1),
                    Descripcion = reader.GetString(2),
                    Tipo = reader.GetString(3),
                    ProductoId = reader.GetInt32(4),
                    CantidadMinima = reader.GetInt32(5),
                    PorcentajeDescuento = reader.IsDBNull(6) ? null : reader.GetDecimal(6),
                    ProductoRegaloId = reader.IsDBNull(7) ? null : reader.GetInt32(7),
                    CantidadRegalo = reader.IsDBNull(8) ? null : reader.GetInt32(8),
                    SegmentoCliente = reader.GetString(9),
                    FechaInicio = reader.GetDateTime(10),
                    FechaFin = reader.GetDateTime(11),
                    Prioridad = reader.GetInt32(13)
                };
            }
            return null;
        }

        public async Task<int> CreatePromotionAsync(PromotionFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Promociones_Create", connection) { CommandType = CommandType.StoredProcedure };
            AddPromotionParams(command, model);
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@NombreUsr", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is int id ? id : Convert.ToInt32(result);
        }

        public async Task UpdatePromotionAsync(PromotionFormViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Promociones_Update", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PromocionId", SqlDbType.Int).Value = model.PromocionId;
            AddPromotionParams(command, model);
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        private static void AddPromotionParams(SqlCommand command, PromotionFormViewModel model)
        {
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = model.Nombre.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
            command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 25).Value = model.Tipo;
            command.Parameters.Add("@ProductoId", SqlDbType.Int).Value = model.ProductoId;
            command.Parameters.Add("@CantidadMinima", SqlDbType.Int).Value = model.CantidadMinima;
            command.Parameters.Add("@PorcentajeDescuento", SqlDbType.Decimal).Value = model.PorcentajeDescuento.HasValue ? model.PorcentajeDescuento.Value : DBNull.Value;
            command.Parameters["@PorcentajeDescuento"].Precision = 5;
            command.Parameters["@PorcentajeDescuento"].Scale = 2;
            command.Parameters.Add("@ProductoRegaloId", SqlDbType.Int).Value = model.ProductoRegaloId.HasValue ? model.ProductoRegaloId.Value : DBNull.Value;
            command.Parameters.Add("@CantidadRegalo", SqlDbType.Int).Value = model.CantidadRegalo.HasValue ? model.CantidadRegalo.Value : DBNull.Value;
            command.Parameters.Add("@SegmentoCliente", SqlDbType.NVarChar, 20).Value = model.SegmentoCliente;
            command.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = model.FechaInicio.Date;
            command.Parameters.Add("@FechaFin", SqlDbType.Date).Value = model.FechaFin.Date;
            command.Parameters.Add("@Prioridad", SqlDbType.Int).Value = model.Prioridad;
        }

        // ── CU-174 Inactivar ────────────────────────────────
        public async Task InactivatePromotionAsync(int promocionId, string? motivo, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Promociones_Inactivar", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@PromocionId", SqlDbType.Int).Value = promocionId;
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(motivo) ? DBNull.Value : motivo.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // ── CU-173 Promociones vigentes (motor del carrito) ──
        public async Task<List<ActivePromotionViewModel>> GetActivePromotionsAsync(string segmento)
            => (await GetActivePromotionSnapshotAsync(segmento)).Promotions;

        public sealed record ActivePromotionSnapshot(DateTime EvaluationDate, List<ActivePromotionViewModel> Promotions);

        public async Task<ActivePromotionSnapshot> GetActivePromotionSnapshotAsync(string segmento, CancellationToken cancellationToken = default)
        {
            if (segmento is not ("Minorista" or "Mayorista"))
                throw new ArgumentException("El segmento de cliente no está acreditado.", nameof(segmento));
            var lista = new List<ActivePromotionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateActivePromotionCommand(connection, segmento);
            await connection.OpenAsync(cancellationToken);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
                throw new InvalidOperationException("No se recibió el día de evaluación de promociones.");
            var evaluationDate = reader.GetDateTime(reader.GetOrdinal("EvaluationDate"));
            if (!await reader.NextResultAsync(cancellationToken))
                throw new InvalidOperationException("No se recibió el conjunto de promociones.");
            while (await reader.ReadAsync(cancellationToken))
            {
                lista.Add(ReadActivePromotion(reader));
            }
            return new(evaluationDate, lista);
        }

        internal static SqlCommand CreateActivePromotionCommand(SqlConnection connection, string segmento)
        {
            // Preserve the historical eligibility/gift projection and add original
            // dates/segment. This is cart presentation, not an issued price quote.
            var command = new SqlCommand("""
                DECLARE @Hoy date = CONVERT(date, SYSDATETIME());
                SELECT @Hoy AS EvaluationDate;
                SELECT pr.PromocionId, pr.Nombre, pr.Tipo, pr.ProductoId, pr.CantidadMinima,
                       pr.PorcentajeDescuento, pr.ProductoRegaloId, pg.Nombre AS ProductoRegaloNombre,
                       pg.Precio AS ProductoRegaloPrecio, pg.Stock AS ProductoRegaloStock,
                       pr.CantidadRegalo, pr.Prioridad, pr.SegmentoCliente, pr.FechaInicio, pr.FechaFin
                FROM dbo.Promociones AS pr
                LEFT JOIN dbo.Productos AS pg ON pg.ProductoId = pr.ProductoRegaloId
                WHERE pr.Estado = N'Activa' AND @Hoy BETWEEN pr.FechaInicio AND pr.FechaFin
                  AND (pr.SegmentoCliente = N'Todos' OR pr.SegmentoCliente = @SegmentoCliente)
                ORDER BY pr.Prioridad DESC, pr.PromocionId;
                """, connection);
            command.Parameters.Add("@SegmentoCliente", SqlDbType.NVarChar, 20).Value = segmento;
            return command;
        }

        internal static ActivePromotionViewModel ReadActivePromotion(DbDataReader reader) => new()
        {
            PromocionId = reader.GetInt32(reader.GetOrdinal("PromocionId")),
            Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
            Tipo = reader.GetString(reader.GetOrdinal("Tipo")),
            ProductoId = reader.GetInt32(reader.GetOrdinal("ProductoId")),
            CantidadMinima = reader.GetInt32(reader.GetOrdinal("CantidadMinima")),
            PorcentajeDescuento = Nullable<decimal>(reader, "PorcentajeDescuento"),
            ProductoRegaloId = Nullable<int>(reader, "ProductoRegaloId"),
            ProductoRegaloNombre = reader.IsDBNull(reader.GetOrdinal("ProductoRegaloNombre")) ? null : reader.GetString(reader.GetOrdinal("ProductoRegaloNombre")),
            ProductoRegaloPrecio = Nullable<decimal>(reader, "ProductoRegaloPrecio") ?? 0m,
            ProductoRegaloStock = Nullable<int>(reader, "ProductoRegaloStock") ?? 0,
            CantidadRegalo = Nullable<int>(reader, "CantidadRegalo"),
            Prioridad = reader.GetInt32(reader.GetOrdinal("Prioridad")),
            SegmentoCliente = reader.GetString(reader.GetOrdinal("SegmentoCliente")),
            FechaInicio = reader.GetDateTime(reader.GetOrdinal("FechaInicio")),
            FechaFin = reader.GetDateTime(reader.GetOrdinal("FechaFin"))
        };

        private static T? Nullable<T>(DbDataReader reader, string name) where T : struct =>
            reader.IsDBNull(reader.GetOrdinal(name)) ? null : reader.GetFieldValue<T>(reader.GetOrdinal(name));

        // ── CU-172 Segmentos de cliente ─────────────────────
        public async Task<List<ClientSegmentViewModel>> GetClientSegmentsAsync(string? buscar)
        {
            var lista = new List<ClientSegmentViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Clientes_Segmentos_List", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ClientSegmentViewModel
                {
                    UsuarioId = reader.GetInt32(0),
                    NombreCompleto = reader.GetString(1),
                    Correo = reader.GetString(2),
                    SegmentoCliente = reader.GetString(3)
                });
            }
            return lista;
        }

        public async Task SetClientSegmentAsync(int usuarioId, string segmento)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Cliente_SetSegmento", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@Segmento", SqlDbType.NVarChar, 20).Value = segmento;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        // Productos para los combos del formulario de promoción.
        public async Task<List<ProductOptionViewModel>> GetProductOptionsAsync()
        {
            var lista = new List<ProductOptionViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Productos_Options", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new ProductOptionViewModel
                {
                    ProductoId = reader.GetInt32(0),
                    Nombre = reader.GetString(1),
                    Precio = reader.GetDecimal(2)
                });
            }
            return lista;
        }
    }
}
