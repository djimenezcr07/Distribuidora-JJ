using Microsoft.Data.SqlClient;
using Proyecto_FinalAPI.Models;
using System.Data;

namespace Proyecto_FinalAPI.Services
{
    public class ProductsApiDbService
    {
        private readonly string _connectionString;

        public ProductsApiDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
        }

        public async Task<List<ProductApiItem>> GetProductsAsync(string? categoria, string? buscar)
        {
            var productos = new List<ProductApiItem>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Store_GetProducts", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Categoria", SqlDbType.NVarChar, 100).Value = GetNullableText(categoria);
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = GetNullableText(buscar);

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                productos.Add(ReadProduct(reader));
            }

            return productos;
        }

        public async Task<ProductApiItem?> GetProductByIdAsync(int productoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Store_GetProductById", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@ProductoId", SqlDbType.Int).Value = productoId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
                return null;

            return ReadProduct(reader);
        }

        public async Task<List<string>> GetCategoriesAsync()
        {
            var categorias = new List<string>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Store_GetCategories", connection);
            command.CommandType = CommandType.StoredProcedure;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                if (!reader.IsDBNull(0))
                {
                    var categoria = reader.GetString(0).Trim();
                    if (!string.IsNullOrWhiteSpace(categoria))
                    {
                        categorias.Add(categoria);
                    }
                }
            }

            return categorias;
        }

        public async Task<List<ProductApiItem>> GetFeaturedProductsAsync(int take)
        {
            var limit = Math.Clamp(take, 1, 24);
            var productos = await GetProductsAsync(null, null);

            return productos
                .Where(producto => producto.EsDestacado)
                .Take(limit)
                .ToList();
        }

        private static ProductApiItem ReadProduct(SqlDataReader reader)
        {
            return new ProductApiItem
            {
                ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Descripcion = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                ImagenUrl = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                EsDestacado = reader.FieldCount > 7 && !reader.IsDBNull(7) && reader.GetBoolean(7)
            };
        }

        private static object GetNullableText(string? value)
        {
            return string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
        }
    }
}
