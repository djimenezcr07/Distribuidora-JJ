using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Chat;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services
{
    public class AdminDbService
    {
        private readonly string _connectionString;
        private readonly IPasswordHashService _passwordHashes;

        public AdminDbService(IConfiguration configuration, IPasswordHashService passwordHashes)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
            _passwordHashes = passwordHashes;
        }

        public async Task<DashboardSummaryViewModel> GetDashboardSummaryAsync()
        {
            var model = new DashboardSummaryViewModel();

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            await using (var command = new SqlCommand("dbo.sp_Admin_DashboardSummary", connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    model.TotalProductos = reader.IsDBNull(0) ? 0 : reader.GetInt32(0);
                    model.ProductosActivos = reader.IsDBNull(1) ? 0 : reader.GetInt32(1);
                    model.StockBajo = reader.IsDBNull(2) ? 0 : reader.GetInt32(2);
                    model.ProductosAgotados = reader.IsDBNull(3) ? 0 : reader.GetInt32(3);
                    model.TotalPedidos = reader.IsDBNull(4) ? 0 : reader.GetInt32(4);
                    model.PedidosPendientes = reader.IsDBNull(5) ? 0 : reader.GetInt32(5);
                    model.PedidosEnProceso = reader.IsDBNull(6) ? 0 : reader.GetInt32(6);
                    model.PedidosEntregados = reader.IsDBNull(7) ? 0 : reader.GetInt32(7);
                    model.VentasTotales = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8);
                    model.VentasMesActual = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9);
                }
            }

            await using (var command = new SqlCommand("dbo.sp_Admin_DashboardLowStock", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.ProductosCriticos.Add(new LowStockProductViewModel
                    {
                        ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                        Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                        Stock = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                        EstadoStock = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                        StockMinimo = reader.FieldCount > 5 && !reader.IsDBNull(5) ? reader.GetInt32(5) : 5
                    });
                }
            }

            await using (var command = new SqlCommand("dbo.sp_Admin_DashboardRecentOrders", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.PedidosRecientes.Add(new RecentOrderViewModel
                    {
                        PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        Cliente = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                        FechaPedido = reader.IsDBNull(2) ? DateTime.MinValue : reader.GetDateTime(2),
                        Estado = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        Total = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4)
                    });
                }
            }

            return model;
        }

        public async Task<List<ProductAdminViewModel>> GetProductsAsync(string? filtro)
        {
            var products = new List<ProductAdminViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetProducts", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Filtro", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(filtro) ? DBNull.Value : filtro.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                products.Add(new ProductAdminViewModel
                {
                    ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Descripcion = reader.IsDBNull(3) ? null : reader.GetString(3),
                    Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                    Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    EstadoStock = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    Activo = !reader.IsDBNull(7) && reader.GetBoolean(7),
                    FechaCreacion = reader.IsDBNull(8) ? DateTime.MinValue : reader.GetDateTime(8),
                    ImagenUrl = reader.FieldCount > 9 && !reader.IsDBNull(9) ? reader.GetString(9) : string.Empty,
                    EsDestacado = reader.FieldCount > 10 && !reader.IsDBNull(10) && reader.GetBoolean(10),
                    StockMinimo = reader.FieldCount > 11 && !reader.IsDBNull(11) ? reader.GetInt32(11) : 5
                });
            }
            return products;
        }

        public async Task<List<ProductAdminViewModel>> GetActiveProductsForSelectAsync()
        {
            var products = new List<ProductAdminViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetActiveProductsForSelect", connection);
            command.CommandType = CommandType.StoredProcedure;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                products.Add(new ProductAdminViewModel
                {
                    ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Descripcion = reader.IsDBNull(3) ? null : reader.GetString(3),
                    Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                    Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    EstadoStock = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    Activo = !reader.IsDBNull(7) && reader.GetBoolean(7),
                    FechaCreacion = reader.IsDBNull(8) ? DateTime.MinValue : reader.GetDateTime(8),
                    ImagenUrl = reader.FieldCount > 9 && !reader.IsDBNull(9) ? reader.GetString(9) : string.Empty,
                    EsDestacado = reader.FieldCount > 10 && !reader.IsDBNull(10) && reader.GetBoolean(10),
                    StockMinimo = reader.FieldCount > 11 && !reader.IsDBNull(11) ? reader.GetInt32(11) : 5
                });
            }
            return products;
        }

        public async Task<ProductFormViewModel?> GetProductByIdAsync(int productoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetProductById", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ProductoId", productoId);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return null;
            return new ProductFormViewModel
            {
                ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Descripcion = reader.IsDBNull(3) ? null : reader.GetString(3),
                Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                Activo = !reader.IsDBNull(6) && reader.GetBoolean(6),
                ImagenUrl = reader.FieldCount > 7 && !reader.IsDBNull(7) ? reader.GetString(7) : string.Empty,
                EsDestacado = reader.FieldCount > 8 && !reader.IsDBNull(8) && reader.GetBoolean(8),
                StockMinimo = reader.FieldCount > 9 && !reader.IsDBNull(9) ? reader.GetInt32(9) : 5
            };
        }

        public async Task CreateProductAsync(ProductFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            try
            {
                int productoId;
                await using (var command = new SqlCommand("dbo.sp_Admin_CreateProduct", connection, (SqlTransaction)transaction))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.AddWithValue("@Nombre", model.Nombre.Trim());
                    command.Parameters.AddWithValue("@Categoria", model.Categoria.Trim());
                    command.Parameters.AddWithValue("@Descripcion", string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim());
                    command.Parameters.AddWithValue("@Precio", model.Precio);
                    command.Parameters.AddWithValue("@Stock", model.Stock);
                    command.Parameters.AddWithValue("@StockMinimo", model.StockMinimo);
                    command.Parameters.AddWithValue("@Activo", model.Activo);
                    command.Parameters.AddWithValue("@ImagenUrl", string.IsNullOrWhiteSpace(model.ImagenUrl) ? DBNull.Value : model.ImagenUrl.Trim());
                    command.Parameters.AddWithValue("@EsDestacado", model.EsDestacado);
                    productoId = Convert.ToInt32(await command.ExecuteScalarAsync());
                }

                await using (var syncCategoria = new SqlCommand("UPDATE dbo.Productos SET CategoriaId = (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre = @Categoria) WHERE ProductoId = @ProductoId;", connection, (SqlTransaction)transaction))
                {
                    syncCategoria.Parameters.AddWithValue("@Categoria", model.Categoria.Trim());
                    syncCategoria.Parameters.AddWithValue("@ProductoId", productoId);
                    await syncCategoria.ExecuteNonQueryAsync();
                }
                if (model.Stock > 0)
                {
                    await CreateMovementInternalAsync(connection, (SqlTransaction)transaction, productoId, "Entrada", model.Stock, 0, model.Stock, "Registro inicial del producto.", usuarioId, usuarioNombre);
                }
                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task UpdateProductAsync(ProductFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            try
            {
                int previousStock;
                await using (var selectCommand = new SqlCommand("dbo.sp_Admin_GetProductStock", connection, (SqlTransaction)transaction))
                {
                    selectCommand.CommandType = CommandType.StoredProcedure;
                    selectCommand.Parameters.AddWithValue("@ProductoId", model.ProductoId);
                    var result = await selectCommand.ExecuteScalarAsync();
                    if (result is null) throw new InvalidOperationException("El producto no existe.");
                    previousStock = Convert.ToInt32(result);
                }

                await using (var updateCommand = new SqlCommand("dbo.sp_Admin_UpdateProduct", connection, (SqlTransaction)transaction))
                {
                    updateCommand.CommandType = CommandType.StoredProcedure;
                    updateCommand.Parameters.AddWithValue("@ProductoId", model.ProductoId);
                    updateCommand.Parameters.AddWithValue("@Nombre", model.Nombre.Trim());
                    updateCommand.Parameters.AddWithValue("@Categoria", model.Categoria.Trim());
                    updateCommand.Parameters.AddWithValue("@Descripcion", string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim());
                    updateCommand.Parameters.AddWithValue("@Precio", model.Precio);
                    updateCommand.Parameters.AddWithValue("@Stock", model.Stock);
                    updateCommand.Parameters.AddWithValue("@StockMinimo", model.StockMinimo);
                    updateCommand.Parameters.AddWithValue("@Activo", model.Activo);
                    updateCommand.Parameters.AddWithValue("@ImagenUrl", string.IsNullOrWhiteSpace(model.ImagenUrl) ? DBNull.Value : model.ImagenUrl.Trim());
                    updateCommand.Parameters.AddWithValue("@EsDestacado", model.EsDestacado);
                    await updateCommand.ExecuteNonQueryAsync();

                    await using (var syncCategoria = new SqlCommand("UPDATE dbo.Productos SET CategoriaId = (SELECT TOP 1 CategoriaId FROM dbo.Categorias WHERE Nombre = @Categoria) WHERE ProductoId = @ProductoId;", connection, (SqlTransaction)transaction))
                    {
                        syncCategoria.Parameters.AddWithValue("@Categoria", model.Categoria.Trim());
                        syncCategoria.Parameters.AddWithValue("@ProductoId", model.ProductoId);
                        await syncCategoria.ExecuteNonQueryAsync();
                    }
                }

                if (previousStock != model.Stock)
                {
                    var cantidad = Math.Abs(model.Stock - previousStock);
                    var tipo = model.Stock > previousStock ? "AjusteEntrada" : "AjusteSalida";
                    await CreateMovementInternalAsync(connection, (SqlTransaction)transaction, model.ProductoId, tipo, cantidad, previousStock, model.Stock, "Ajuste realizado desde edición de producto.", usuarioId, usuarioNombre);
                }

                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task UpdateProductImageAsync(int productoId, string? imageUrl)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("UPDATE dbo.Productos SET ImagenUrl = @ImagenUrl WHERE ProductoId = @ProductoId;", connection);
            command.Parameters.AddWithValue("@ProductoId", productoId);
            command.Parameters.AddWithValue("@ImagenUrl", string.IsNullOrWhiteSpace(imageUrl) ? DBNull.Value : imageUrl.Trim());
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<bool> ToggleProductStatusAsync(int productoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_ToggleProductStatus", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ProductoId", productoId);
            await connection.OpenAsync();

            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value && Convert.ToBoolean(result);
        }

        public async Task<string> DeleteProductPermanentlyAsync(int productoId)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_DeleteProductPermanently", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@ProductoId", productoId);
                await connection.OpenAsync();

                var result = await command.ExecuteScalarAsync();
                return Convert.ToString(result) ?? $"Producto #{productoId}";
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task<List<InventoryMovementViewModel>> GetInventoryMovementsAsync()
        {
            var movements = new List<InventoryMovementViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetInventoryMovements", connection);
            command.CommandType = CommandType.StoredProcedure;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                movements.Add(new InventoryMovementViewModel
                {
                    MovimientoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    ProductoId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                    Producto = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    TipoMovimiento = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Cantidad = reader.IsDBNull(4) ? 0 : reader.GetInt32(4),
                    StockAnterior = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    StockNuevo = reader.IsDBNull(6) ? 0 : reader.GetInt32(6),
                    Motivo = reader.IsDBNull(7) ? null : reader.GetString(7),
                    Usuario = reader.IsDBNull(8) ? string.Empty : reader.GetString(8),
                    FechaMovimiento = reader.IsDBNull(9) ? DateTime.MinValue : reader.GetDateTime(9)
                });
            }
            return movements;
        }

        public async Task RegisterInventoryMovementAsync(InventoryMovementFormViewModel model, int usuarioId, string usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            try
            {
                string productoNombre;
                int stockAnterior;
                await using (var selectCommand = new SqlCommand("dbo.sp_Admin_GetActiveProductForMovement", connection, (SqlTransaction)transaction))
                {
                    selectCommand.CommandType = CommandType.StoredProcedure;
                    selectCommand.Parameters.AddWithValue("@ProductoId", model.ProductoId);
                    await using var reader = await selectCommand.ExecuteReaderAsync();
                    if (!await reader.ReadAsync()) throw new InvalidOperationException("El producto seleccionado no existe o está inactivo.");
                    productoNombre = reader.IsDBNull(0) ? "Producto" : reader.GetString(0);
                    stockAnterior = reader.IsDBNull(1) ? 0 : reader.GetInt32(1);
                }

                int nuevoStock = model.TipoMovimiento switch
                {
                    "Entrada" => stockAnterior + model.Cantidad,
                    "Salida" => stockAnterior - model.Cantidad,
                    "Ajuste" => model.Cantidad,
                    _ => throw new InvalidOperationException("Tipo de movimiento no válido.")
                };

                if (nuevoStock < 0) throw new InvalidOperationException("El movimiento deja el stock en negativo.");
                await UpdateProductStockInternalAsync(connection, (SqlTransaction)transaction, model.ProductoId, nuevoStock);
                await CreateMovementInternalAsync(connection, (SqlTransaction)transaction, model.ProductoId, model.TipoMovimiento, model.Cantidad, stockAnterior, nuevoStock, model.Motivo, usuarioId, usuarioNombre, productoNombre);

                if (model.TipoMovimiento == "Entrada" && model.GeneraGasto)
                {
                    if (!model.CostoUnitario.HasValue || model.CostoUnitario.Value <= 0)
                    {
                        throw new InvalidOperationException(
                            "Debe indicar un costo unitario válido para registrar el gasto.");
                    }

                    decimal montoTotal = model.Cantidad * model.CostoUnitario.Value;

                    const string gastoQuery = """
        INSERT INTO dbo.Gastos
        (
            Fecha,
            Concepto,
            Categoria,
            Monto,
            RegistradoPorUsuarioId,
            Observaciones
        )
        VALUES
        (
            SYSDATETIME(),
            @Concepto,
            @Categoria,
            @Monto,
            @UsuarioId,
            @Observaciones
        );
        """;

                    await using var gastoCommand = new SqlCommand(
                        gastoQuery,
                        connection,
                        (SqlTransaction)transaction);

                    gastoCommand.Parameters.Add("@Concepto", SqlDbType.NVarChar, 200).Value =
                        $"Compra de inventario - {productoNombre}";

                    gastoCommand.Parameters.Add("@Categoria", SqlDbType.NVarChar, 100).Value =
                        string.IsNullOrWhiteSpace(model.CategoriaGasto)
                            ? "Compra de inventario"
                            : model.CategoriaGasto.Trim();

                    gastoCommand.Parameters.Add("@Monto", SqlDbType.Decimal).Value = montoTotal;
                    gastoCommand.Parameters["@Monto"].Precision = 18;
                    gastoCommand.Parameters["@Monto"].Scale = 2;

                    gastoCommand.Parameters.Add("@UsuarioId", SqlDbType.Int).Value =
                        usuarioId > 0 ? usuarioId : DBNull.Value;

                    gastoCommand.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 500).Value =
                        string.IsNullOrWhiteSpace(model.Motivo)
                            ? DBNull.Value
                            : model.Motivo.Trim();

                    await gastoCommand.ExecuteNonQueryAsync();
                }


                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<List<OrderAdminListItemViewModel>> GetOrdersAsync(string? estado)
        {
            var pedidos = new List<OrderAdminListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetOrders", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                pedidos.Add(new OrderAdminListItemViewModel
                {
                    PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Cliente = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    FechaPedido = reader.IsDBNull(3) ? DateTime.MinValue : reader.GetDateTime(3),
                    Estado = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    TipoEntrega = reader.IsDBNull(5) ? null : reader.GetString(5),
                    DireccionEntrega = reader.IsDBNull(6) ? null : reader.GetString(6),
                    Total = reader.IsDBNull(7) ? 0 : reader.GetDecimal(7),
                    TotalLineas = reader.IsDBNull(8) ? 0 : reader.GetInt32(8)
                });
            }
            return pedidos;
        }

        public async Task<OrderDetailViewModel?> GetOrderDetailAsync(int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            var model = await GetOrderDetailInternalAsync(connection, null, pedidoId);
            if (model is not null)
            {
                await using var command = new SqlCommand("SELECT InventarioDescontado FROM dbo.Pedidos WHERE PedidoId=@PedidoId;", connection);
                command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
                model.InventoryDebited = await command.ExecuteScalarAsync() is true;
            }
            return model;
        }

        public async Task UpdateOrderStatusAsync(int pedidoId, string nuevoEstado, int usuarioId, string usuarioNombre, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_UpdateOrderStatusV2", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@PedidoId", pedidoId);
            command.Parameters.AddWithValue("@NuevoEstado", nuevoEstado);
            command.Parameters.AddWithValue("@UsuarioId", usuarioId);
            command.Parameters.AddWithValue("@UsuarioNombre", usuarioNombre);
            await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, usuarioId, "PEDIDOS_CAMBIAR_ESTADO", async () =>
            {
            await command.ExecuteNonQueryAsync();
                return 0;
            });
        }

        public async Task<bool> CancelClientPendingOrderAsync(int pedidoId, int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Client_CancelPendingOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value && Convert.ToBoolean(result);
        }

        public async Task<bool> OrderHasInvoiceAsync(int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_OrderHasInvoice", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value && Convert.ToBoolean(result);
        }

        public async Task<int?> GetInvoiceIdByOrderAsync(int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetInvoiceByOrderId", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            if (result == null || result == DBNull.Value)
            {
                return null;
            }

            return Convert.ToInt32(result);
        }

        public async Task<GenerateInvoiceResultViewModel> GenerateInvoiceFromOrderAsync(int pedidoId, int usuarioId, string usuarioNombre, OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Stage2_GenerateInvoiceAmountsV2", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre)
                ? DBNull.Value
                : usuarioNombre.Trim();

            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, usuarioId, "FACTURACION_GENERAR", async () =>
            {
            await using var reader = await command.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                throw new InvalidOperationException("No fue posible generar la factura del pedido.");
            }

            return new GenerateInvoiceResultViewModel
            {
                FacturaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                PedidoId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                NumeroFactura = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                EstadoPedido = reader.IsDBNull(3) ? string.Empty : reader.GetString(3)
            };
            });
        }

        public async Task<SalesReportViewModel> GetSalesReportAsync()
        {
            var model = new SalesReportViewModel();
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            await using (var command = new SqlCommand("dbo.sp_Admin_SalesSummary", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    model.VentasTotales = reader.IsDBNull(0) ? 0 : reader.GetDecimal(0);
                    model.VentasMesActual = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1);
                    model.TotalFacturas = reader.IsDBNull(2) ? 0 : reader.GetInt32(2);
                    model.FacturasMesActual = reader.IsDBNull(3) ? 0 : reader.GetInt32(3);
                    model.PedidosEntregados = reader.IsDBNull(4) ? 0 : reader.GetInt32(4);
                }
            }

            await using (var command = new SqlCommand("dbo.sp_Admin_GetInvoices", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.Facturas.Add(new InvoiceListItemViewModel
                    {
                        FacturaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        PedidoId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        NumeroFactura = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                        Cliente = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        FechaFactura = reader.IsDBNull(4) ? DateTime.MinValue : reader.GetDateTime(4),
                        Subtotal = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5),
                        Impuesto = reader.IsDBNull(6) ? 0 : reader.GetDecimal(6),
                        Total = reader.IsDBNull(7) ? 0 : reader.GetDecimal(7),
                        Estado = reader.IsDBNull(8) ? string.Empty : reader.GetString(8)
                    });
                }
            }

            await using (var command = new SqlCommand("""
                SELECT TOP(10) d.ProductoNombre,SUM(d.Cantidad) AS CantidadVendida,
                  SUM(COALESCE(a.Neto,d.Subtotal)) AS MontoVendido
                FROM dbo.FacturaDetalle d JOIN dbo.Facturas f ON f.FacturaId=d.FacturaId
                LEFT JOIN dbo.Stage2OrderAmountLines a ON a.PedidoId=f.PedidoId AND a.LineKind=N'Producto'
                  AND a.ProductoId=d.ProductoId AND a.Cantidad=d.Cantidad AND d.PrecioUnitario>0
                WHERE f.Estado=N'Generada' GROUP BY d.ProductoNombre
                ORDER BY CantidadVendida DESC,MontoVendido DESC;
                """, connection))
            {
                command.CommandType = CommandType.Text;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.ProductosMasVendidos.Add(new TopSellingProductViewModel
                    {
                        Producto = reader.IsDBNull(0) ? string.Empty : reader.GetString(0),
                        CantidadVendida = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        MontoVendido = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2)
                    });
                }
            }

            await using (var command = new SqlCommand("dbo.sp_Admin_GetMonthlySales", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.VentasPorMes.Add(new MonthlySalesViewModel
                    {
                        Periodo = reader.IsDBNull(0) ? string.Empty : reader.GetString(0),
                        Total = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1)
                    });
                }
            }

            return model;
        }

        public async Task<InvoiceDetailViewModel?> GetInvoiceDetailAsync(int facturaId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            InvoiceDetailViewModel? model = null;
            await using (var command = new SqlCommand("dbo.sp_Admin_GetInvoiceHeader", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@FacturaId", facturaId);
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    model = new InvoiceDetailViewModel
                    {
                        FacturaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        PedidoId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        NumeroFactura = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                        Cliente = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        Correo = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                        FechaFactura = reader.IsDBNull(5) ? DateTime.MinValue : reader.GetDateTime(5),
                        Subtotal = reader.IsDBNull(6) ? 0 : reader.GetDecimal(6),
                        Impuesto = reader.IsDBNull(7) ? 0 : reader.GetDecimal(7),
                        Total = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8),
                        Estado = reader.IsDBNull(9) ? string.Empty : reader.GetString(9)
                    };
                }
            }

            if (model == null) return null;

            await using (var command = new SqlCommand("dbo.sp_Stage2_GetInvoiceLinesV2", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@FacturaId", facturaId);
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.Detalles.Add(new InvoiceDetailLineViewModel
                    {
                        Producto = reader.IsDBNull(0) ? string.Empty : reader.GetString(0),
                        Cantidad = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        PrecioUnitario = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2),
                        Subtotal = reader.IsDBNull(3) ? 0 : reader.GetDecimal(3)
                    });
                }
            }

            return model;
        }

        public async Task<ClientPortalInvoiceViewModel?> GetClientInvoiceByOrderAsync(int pedidoId, int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            int facturaId;
            ClientPortalInvoiceViewModel? model = null;

            await using (var command = new SqlCommand("dbo.sp_Client_GetInvoiceHeaderByOrder", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

                await using var reader = await command.ExecuteReaderAsync();
                if (!await reader.ReadAsync())
                {
                    return null;
                }

                facturaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0);
                model = new ClientPortalInvoiceViewModel
                {
                    PedidoId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                    NumeroFactura = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Cliente = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Correo = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    FechaFactura = reader.IsDBNull(5) ? DateTime.MinValue : reader.GetDateTime(5),
                    Subtotal = reader.IsDBNull(6) ? 0 : reader.GetDecimal(6),
                    Impuesto = reader.IsDBNull(7) ? 0 : reader.GetDecimal(7),
                    Total = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8),
                    Estado = reader.IsDBNull(9) ? string.Empty : reader.GetString(9)
                };
            }

            if (facturaId <= 0 || model == null)
            {
                return null;
            }

            await using (var command = new SqlCommand("dbo.sp_Stage2_GetClientInvoiceLinesV2", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.Lineas.Add(new ClientPortalInvoiceLineViewModel
                    {
                        Producto = reader.IsDBNull(0) ? string.Empty : reader.GetString(0),
                        Cantidad = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        PrecioUnitario = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2),
                        Subtotal = reader.IsDBNull(3) ? 0 : reader.GetDecimal(3)
                    });
                }
            }

            return model;
        }



        public async Task<List<RoleListItemViewModel>> GetRolesAsync(string? buscar)
        {
            var roles = new List<RoleListItemViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetRoles", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                roles.Add(new RoleListItemViewModel
                {
                    PerfilId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Descripcion = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Activo = !reader.IsDBNull(3) && reader.GetBoolean(3),
                    FechaCreacion = reader.IsDBNull(4) ? DateTime.MinValue : reader.GetDateTime(4),
                    TotalUsuarios = reader.IsDBNull(5) ? 0 : reader.GetInt32(5)
                });
            }

            return roles;
        }

        public async Task<RoleFormViewModel?> GetRoleByIdAsync(int perfilId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetRoleById", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@PerfilId", perfilId);

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            return new RoleFormViewModel
            {
                PerfilId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Descripcion = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Activo = !reader.IsDBNull(3) && reader.GetBoolean(3),
                FechaCreacion = reader.IsDBNull(4) ? DateTime.MinValue : reader.GetDateTime(4),
                TotalUsuarios = reader.IsDBNull(5) ? 0 : reader.GetInt32(5)
            };
        }

        public async Task<int> CreateRoleAsync(RoleFormViewModel model)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_CreateRole", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 50).Value = model.Nombre.Trim();
                command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
                command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;

                await connection.OpenAsync();
                var result = await command.ExecuteScalarAsync();
                return Convert.ToInt32(result);
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task UpdateRoleAsync(RoleFormViewModel model)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_UpdateRole", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = model.PerfilId;
                command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 50).Value = model.Nombre.Trim();
                command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
                command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task ToggleRoleStatusAsync(int perfilId)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_ToggleRoleStatus", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = perfilId;

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task<RolePermissionAssignmentViewModel?> GetRolePermissionAssignmentAsync(int perfilId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetRolePermissions", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = perfilId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            var model = new RolePermissionAssignmentViewModel
            {
                PerfilId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                RolNombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                RolDescripcion = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                RolActivo = !reader.IsDBNull(3) && reader.GetBoolean(3)
            };

            await reader.NextResultAsync();

            var permisos = new List<PermissionItemViewModel>();
            while (await reader.ReadAsync())
            {
                permisos.Add(new PermissionItemViewModel
                {
                    PermisoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Codigo = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Modulo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Nombre = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Descripcion = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    Activo = !reader.IsDBNull(5) && reader.GetBoolean(5),
                    Asignado = !reader.IsDBNull(6) && reader.GetBoolean(6)
                });
            }

            model.PermisosSeleccionados = permisos
                .Where(p => p.Asignado)
                .Select(p => p.PermisoId)
                .ToList();

            model.Modulos = permisos
                .GroupBy(p => p.Modulo)
                .Select(g => new PermissionModuleGroupViewModel
                {
                    Modulo = g.Key,
                    Permisos = g.ToList()
                })
                .ToList();

            return model;
        }

        public async Task UpdateRolePermissionsAsync(int perfilId, List<int> permisosSeleccionados, int? usuarioId, string? usuarioNombre)
        {
            try
            {
                var permisosCsv = permisosSeleccionados == null || permisosSeleccionados.Count == 0
                    ? string.Empty
                    : string.Join(",", permisosSeleccionados.Distinct().OrderBy(x => x));

                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_UpdateRolePermissions", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = perfilId;
                command.Parameters.Add("@PermisosCsv", SqlDbType.NVarChar, -1).Value = permisosCsv;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId.HasValue && usuarioId.Value > 0 ? usuarioId.Value : DBNull.Value;
                command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }


        public async Task<List<AuditLogViewModel>> GetAuditLogsAsync(string? modulo, string? accion, string? buscar)
        {
            var registros = new List<AuditLogViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetAuditLogs", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Modulo", SqlDbType.NVarChar, 80).Value = string.IsNullOrWhiteSpace(modulo) ? DBNull.Value : modulo.Trim();
            command.Parameters.Add("@Accion", SqlDbType.NVarChar, 80).Value = string.IsNullOrWhiteSpace(accion) ? DBNull.Value : accion.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                registros.Add(new AuditLogViewModel
                {
                    AuditoriaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    UsuarioId = reader.IsDBNull(1) ? null : reader.GetInt32(1),
                    UsuarioNombre = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    UsuarioCorreo = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Rol = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    Accion = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    Modulo = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    Descripcion = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                    DireccionIp = reader.IsDBNull(8) ? null : reader.GetString(8),
                    UserAgent = reader.IsDBNull(9) ? null : reader.GetString(9),
                    FechaRegistro = reader.IsDBNull(10) ? DateTime.MinValue : reader.GetDateTime(10)
                });
            }

            return registros;
        }

        public async Task CreateAuditLogAsync(int? usuarioId, string? usuarioNombre, string? usuarioCorreo, string? rol, string accion, string modulo, string descripcion, string? direccionIp, string? userAgent)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_CreateAuditLog", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId.HasValue && usuarioId.Value > 0 ? usuarioId.Value : DBNull.Value;
                command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? "Usuario no identificado" : usuarioNombre.Trim();
                command.Parameters.Add("@UsuarioCorreo", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioCorreo) ? "No disponible" : usuarioCorreo.Trim();
                command.Parameters.Add("@Rol", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(rol) ? "No disponible" : rol.Trim();
                command.Parameters.Add("@Accion", SqlDbType.NVarChar, 80).Value = accion.Trim();
                command.Parameters.Add("@Modulo", SqlDbType.NVarChar, 80).Value = modulo.Trim();
                command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value = descripcion.Trim();
                command.Parameters.Add("@DireccionIp", SqlDbType.NVarChar, 80).Value = string.IsNullOrWhiteSpace(direccionIp) ? DBNull.Value : direccionIp.Trim();
                command.Parameters.Add("@UserAgent", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(userAgent) ? DBNull.Value : userAgent.Trim();

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch
            {
                // La auditoría no debe bloquear las acciones principales del sistema.
            }
        }

        public async Task<List<string>> GetStoreCategoriesAsync()
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

        public async Task<List<StoreProductViewModel>> GetStoreProductsAsync(string? categoria, string? buscar)
        {
            var productos = new List<StoreProductViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Store_GetProducts", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Categoria", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(categoria) ? DBNull.Value : categoria.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                productos.Add(new StoreProductViewModel
                {
                    ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Descripcion = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                    Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    ImagenUrl = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    EsDestacado = reader.FieldCount > 7 && !reader.IsDBNull(7) && reader.GetBoolean(7)
                });
            }
            return productos;
        }

        private async Task<OrderDetailViewModel?> GetOrderDetailInternalAsync(SqlConnection connection, SqlTransaction? transaction, int pedidoId)
        {
            OrderDetailViewModel? model = null;

            await using (var command = new SqlCommand("dbo.sp_Admin_GetOrderHeader", connection, transaction))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@PedidoId", pedidoId);
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    model = new OrderDetailViewModel
                    {
                        PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        UsuarioId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1),
                        Cliente = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                        Correo = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        FechaPedido = reader.IsDBNull(4) ? DateTime.MinValue : reader.GetDateTime(4),
                        Estado = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                        TipoEntrega = reader.IsDBNull(6) ? null : reader.GetString(6),
                        DireccionEntrega = reader.IsDBNull(7) ? null : reader.GetString(7),
                        Observaciones = reader.IsDBNull(8) ? null : reader.GetString(8),
                        Total = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9),
                        MetodoPago = reader.FieldCount > 10 && !reader.IsDBNull(10) ? reader.GetString(10) : string.Empty,
                        EstadoPago = reader.FieldCount > 11 && !reader.IsDBNull(11) ? reader.GetString(11) : string.Empty,
                        ReferenciaPago = reader.FieldCount > 12 && !reader.IsDBNull(12) ? reader.GetString(12) : null,
                        FechaPago = reader.FieldCount > 13 && !reader.IsDBNull(13) ? reader.GetDateTime(13) : null,
                        MotivoRechazo = reader.FieldCount > 14 && !reader.IsDBNull(14) ? reader.GetString(14) : null
                    };
                }
            }

            if (model == null) return null;

            await using (var command = new SqlCommand("dbo.sp_Stage2_GetOrderDetailLinesV2", connection, transaction))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@PedidoId", pedidoId);
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    model.Detalles.Add(new OrderDetailLineViewModel
                    {
                        PedidoDetalleId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        Producto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                        ProductoId = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                        Cantidad = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                        PrecioUnitario = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                        Subtotal = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5),
                        StockActual = reader.IsDBNull(6) ? 0 : reader.GetInt32(6),
                        IsCombo = reader.FieldCount > 7 && !reader.IsDBNull(7) && reader.GetBoolean(7)
                    });
                }
            }

            return model;
        }


        public async Task ToggleFeaturedAsync(int productoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("UPDATE dbo.Productos SET EsDestacado = CASE WHEN ISNULL(EsDestacado,0)=1 THEN 0 ELSE 1 END WHERE ProductoId = @ProductoId;", connection);
            command.Parameters.AddWithValue("@ProductoId", productoId);
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<List<StoreProductViewModel>> GetFeaturedProductsAsync(int maxItems)
        {
            var productos = new List<StoreProductViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("SELECT TOP (@Top) ProductoId, Nombre, Categoria, ISNULL(Descripcion,''), Precio, Stock, ISNULL(ImagenUrl,'') AS ImagenUrl, ISNULL(EsDestacado,0) FROM dbo.Productos WHERE Activo = 1 AND ISNULL(EsDestacado,0)=1 ORDER BY ProductoId DESC;", connection);
            command.Parameters.AddWithValue("@Top", maxItems);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                productos.Add(new StoreProductViewModel
                {
                    ProductoId = reader.GetInt32(0),
                    Nombre = reader.GetString(1),
                    Categoria = reader.GetString(2),
                    Descripcion = reader.GetString(3),
                    Precio = reader.GetDecimal(4),
                    Stock = reader.GetInt32(5),
                    ImagenUrl = reader.GetString(6),
                    EsDestacado = !reader.IsDBNull(7) && reader.GetBoolean(7)
                });
            }
            return productos;
        }


        public async Task<List<ClientListItemViewModel>> GetClientsAsync(string? buscar, string? estado)
        {
            var clientes = new List<ClientListItemViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetClients", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                clientes.Add(new ClientListItemViewModel
                {
                    UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Telefono = reader.IsDBNull(3) ? null : reader.GetString(3),
                    Direccion = reader.IsDBNull(4) ? null : reader.GetString(4),
                    Activo = !reader.IsDBNull(5) && reader.GetBoolean(5),
                    FechaRegistro = reader.IsDBNull(6) ? DateTime.MinValue : reader.GetDateTime(6),
                    TotalPedidos = reader.IsDBNull(7) ? 0 : reader.GetInt32(7),
                    TotalComprado = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8),
                    UltimoPedido = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                    MotivoInactivacion = reader.IsDBNull(10) ? null : reader.GetString(10),
                    FechaInactivacion = reader.IsDBNull(11) ? null : reader.GetDateTime(11)
                });
            }

            return clientes;
        }

        public async Task<ClientFormViewModel?> GetClientByIdAsync(int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetClientById", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            return new ClientFormViewModel
            {
                UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Telefono = reader.IsDBNull(3) ? null : reader.GetString(3),
                Direccion = reader.IsDBNull(4) ? null : reader.GetString(4),
                Activo = !reader.IsDBNull(5) && reader.GetBoolean(5),
                FechaRegistro = reader.IsDBNull(6) ? DateTime.MinValue : reader.GetDateTime(6),
                TotalPedidos = reader.IsDBNull(7) ? 0 : reader.GetInt32(7),
                TotalComprado = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8),
                UltimoPedido = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                MotivoInactivacion = reader.IsDBNull(10) ? null : reader.GetString(10),
                FechaInactivacion = reader.IsDBNull(11) ? null : reader.GetDateTime(11)
            };
        }

        public async Task<ClientDetailViewModel?> GetClientDetailAsync(int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetClientDetail", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            var model = new ClientDetailViewModel
            {
                UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Telefono = reader.IsDBNull(3) ? null : reader.GetString(3),
                Direccion = reader.IsDBNull(4) ? null : reader.GetString(4),
                Activo = !reader.IsDBNull(5) && reader.GetBoolean(5),
                FechaRegistro = reader.IsDBNull(6) ? DateTime.MinValue : reader.GetDateTime(6),
                TotalPedidos = reader.IsDBNull(7) ? 0 : reader.GetInt32(7),
                TotalComprado = reader.IsDBNull(8) ? 0 : reader.GetDecimal(8),
                UltimoPedido = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                MotivoInactivacion = reader.IsDBNull(10) ? null : reader.GetString(10),
                FechaInactivacion = reader.IsDBNull(11) ? null : reader.GetDateTime(11)
            };

            await reader.NextResultAsync();

            while (await reader.ReadAsync())
            {
                model.Pedidos.Add(new ClientOrderSummaryViewModel
                {
                    PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    FechaPedido = reader.IsDBNull(1) ? DateTime.MinValue : reader.GetDateTime(1),
                    Estado = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    TipoEntrega = reader.IsDBNull(3) ? null : reader.GetString(3),
                    DireccionEntrega = reader.IsDBNull(4) ? null : reader.GetString(4),
                    Total = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5),
                    Observaciones = reader.IsDBNull(6) ? null : reader.GetString(6)
                });
            }

            return model;
        }

        public async Task<int> CreateClientAsync(ClientFormViewModel model)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_CreateClient", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@NombreCompleto", SqlDbType.NVarChar, 150).Value = model.NombreCompleto.Trim();
                command.Parameters.Add("@Correo", SqlDbType.NVarChar, 150).Value = model.Correo.Trim();
                command.Parameters.Add("@ContrasenaHash", SqlDbType.NVarChar, 512).Value = _passwordHashes.Hash(model.Contrasena ?? string.Empty);
                command.Parameters.Add("@Telefono", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(model.Telefono) ? DBNull.Value : model.Telefono.Trim();
                command.Parameters.Add("@Direccion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.Direccion) ? DBNull.Value : model.Direccion.Trim();
                command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
                command.Parameters.Add("@MotivoInactivacion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.MotivoInactivacion) ? DBNull.Value : model.MotivoInactivacion.Trim();

                await connection.OpenAsync();
                var result = await command.ExecuteScalarAsync();
                return Convert.ToInt32(result);
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task UpdateClientAsync(ClientFormViewModel model)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_UpdateClient", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = model.UsuarioId;
                command.Parameters.Add("@NombreCompleto", SqlDbType.NVarChar, 150).Value = model.NombreCompleto.Trim();
                command.Parameters.Add("@Correo", SqlDbType.NVarChar, 150).Value = model.Correo.Trim();
                command.Parameters.Add("@Telefono", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(model.Telefono) ? DBNull.Value : model.Telefono.Trim();
                command.Parameters.Add("@Direccion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.Direccion) ? DBNull.Value : model.Direccion.Trim();
                command.Parameters.Add("@ContrasenaHash", SqlDbType.NVarChar, 512).Value = string.IsNullOrWhiteSpace(model.Contrasena)
                    ? DBNull.Value
                    : _passwordHashes.Hash(model.Contrasena);
                command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
                command.Parameters.Add("@MotivoInactivacion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.MotivoInactivacion) ? DBNull.Value : model.MotivoInactivacion.Trim();

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task<bool> ToggleClientStatusAsync(int usuarioId, string? motivo)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_ToggleClientStatus", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
                command.Parameters.Add("@MotivoInactivacion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(motivo) ? DBNull.Value : motivo.Trim();

                await connection.OpenAsync();
                var result = await command.ExecuteScalarAsync();
                return Convert.ToBoolean(result);
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task<int> CreateConsultationAsync(string nombre, string correo, string asunto, string mensaje)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_CreateConsultation", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@Nombre", nombre.Trim());
            command.Parameters.AddWithValue("@Correo", correo.Trim());
            command.Parameters.AddWithValue("@Asunto", asunto.Trim());
            command.Parameters.AddWithValue("@Mensaje", mensaje.Trim());

            await connection.OpenAsync();
            return Convert.ToInt32(await command.ExecuteScalarAsync());
        }

        public async Task<List<ConsultationViewModel>> GetConsultationsAsync(string? estado, string? buscar)
        {
            var consultas = new List<ConsultationViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetConsultations", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                consultas.Add(new ConsultationViewModel
                {
                    ConsultaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Asunto = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Mensaje = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    Estado = reader.IsDBNull(5) ? "Pendiente" : reader.GetString(5),
                    RespuestaInterna = reader.IsDBNull(6) ? null : reader.GetString(6),
                    AtendidoPorUsuarioId = reader.IsDBNull(7) ? null : reader.GetInt32(7),
                    AtendidoPorNombre = reader.IsDBNull(8) ? null : reader.GetString(8),
                    FechaAtencion = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                    FechaCreacion = reader.IsDBNull(10) ? DateTime.MinValue : reader.GetDateTime(10)
                });
            }

            return consultas;
        }

        public async Task<ConsultationDetailViewModel?> GetConsultationByIdAsync(int consultaId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetConsultationById", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ConsultaId", consultaId);

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
            {
                return null;
            }

            return new ConsultationDetailViewModel
            {
                ConsultaId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                Asunto = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                Mensaje = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                Estado = reader.IsDBNull(5) ? "Pendiente" : reader.GetString(5),
                RespuestaInterna = reader.IsDBNull(6) ? null : reader.GetString(6),
                AtendidoPorUsuarioId = reader.IsDBNull(7) ? null : reader.GetInt32(7),
                AtendidoPorNombre = reader.IsDBNull(8) ? null : reader.GetString(8),
                FechaAtencion = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                FechaCreacion = reader.IsDBNull(10) ? DateTime.MinValue : reader.GetDateTime(10)
            };
        }

        public async Task UpdateConsultationStatusAsync(int consultaId, string estado, string? respuestaInterna, int? usuarioId, string? usuarioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_UpdateConsultationStatus", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ConsultaId", consultaId);
            command.Parameters.AddWithValue("@Estado", estado.Trim());
            command.Parameters.Add("@RespuestaInterna", SqlDbType.NVarChar, 1000).Value = string.IsNullOrWhiteSpace(respuestaInterna) ? DBNull.Value : respuestaInterna.Trim();
            command.Parameters.Add("@AtendidoPorUsuarioId", SqlDbType.Int).Value = usuarioId.HasValue ? usuarioId.Value : DBNull.Value;
            command.Parameters.Add("@AtendidoPorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }



        public async Task<List<ClientCreditListItemViewModel>> GetClientCreditsAsync(string? buscar, string? estadoCredito)
        {
            var clientes = new List<ClientCreditListItemViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetClientCredits", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@EstadoCredito", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(estadoCredito) ? DBNull.Value : estadoCredito.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                clientes.Add(new ClientCreditListItemViewModel
                {
                    UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Telefono = reader.IsDBNull(3) ? null : reader.GetString(3),
                    ClienteActivo = !reader.IsDBNull(4) && reader.GetBoolean(4),
                    LimiteCredito = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5),
                    CreditoActivo = !reader.IsDBNull(6) && reader.GetBoolean(6),
                    CreditoBloqueado = !reader.IsDBNull(7) && reader.GetBoolean(7),
                    MotivoBloqueo = reader.IsDBNull(8) ? null : reader.GetString(8),
                    DeudaActual = reader.IsDBNull(9) ? 0 : reader.GetDecimal(9),
                    CreditoDisponible = reader.IsDBNull(10) ? 0 : reader.GetDecimal(10),
                    TotalMovimientos = reader.IsDBNull(11) ? 0 : reader.GetInt32(11),
                    UltimoMovimiento = reader.IsDBNull(12) ? null : reader.GetDateTime(12),
                    FechaActualizacion = reader.IsDBNull(13) ? null : reader.GetDateTime(13)
                });
            }

            return clientes;
        }

        public async Task<ClientCreditDetailViewModel?> GetClientCreditDetailAsync(int usuarioId)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_GetClientCreditDetail", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

                await connection.OpenAsync();
                await using var reader = await command.ExecuteReaderAsync();

                if (!await reader.ReadAsync()) return null;

                var model = new ClientCreditDetailViewModel
                {
                    UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Telefono = reader.IsDBNull(3) ? null : reader.GetString(3),
                    Direccion = reader.IsDBNull(4) ? null : reader.GetString(4),
                    ClienteActivo = !reader.IsDBNull(5) && reader.GetBoolean(5),
                    LimiteCredito = reader.IsDBNull(6) ? 0 : reader.GetDecimal(6),
                    CreditoActivo = !reader.IsDBNull(7) && reader.GetBoolean(7),
                    CreditoBloqueado = !reader.IsDBNull(8) && reader.GetBoolean(8),
                    MotivoBloqueo = reader.IsDBNull(9) ? null : reader.GetString(9),
                    DeudaActual = reader.IsDBNull(10) ? 0 : reader.GetDecimal(10),
                    CreditoDisponible = reader.IsDBNull(11) ? 0 : reader.GetDecimal(11),
                    TotalCargos = reader.IsDBNull(12) ? 0 : reader.GetDecimal(12),
                    TotalAbonos = reader.IsDBNull(13) ? 0 : reader.GetDecimal(13),
                    FechaActualizacion = reader.IsDBNull(14) ? null : reader.GetDateTime(14)
                };

                model.SettingsForm = new ClientCreditSettingsViewModel
                {
                    UsuarioId = model.UsuarioId,
                    LimiteCredito = model.LimiteCredito,
                    CreditoActivo = model.CreditoActivo,
                    CreditoBloqueado = model.CreditoBloqueado,
                    MotivoBloqueo = model.MotivoBloqueo
                };

                model.MovementForm = new ClientCreditMovementFormViewModel
                {
                    UsuarioId = model.UsuarioId,
                    TipoMovimiento = "Abono"
                };

                await reader.NextResultAsync();

                while (await reader.ReadAsync())
                {
                    model.Movimientos.Add(new ClientCreditMovementViewModel
                    {
                        CreditoMovimientoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        TipoMovimiento = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                        Monto = reader.IsDBNull(2) ? 0 : reader.GetDecimal(2),
                        Descripcion = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                        Referencia = reader.IsDBNull(4) ? null : reader.GetString(4),
                        RegistradoPorUsuarioId = reader.IsDBNull(5) ? null : reader.GetInt32(5),
                        RegistradoPorNombre = reader.IsDBNull(6) ? null : reader.GetString(6),
                        FechaMovimiento = reader.IsDBNull(7) ? DateTime.MinValue : reader.GetDateTime(7)
                    });
                }

                return model;
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task UpdateClientCreditSettingsAsync(ClientCreditSettingsViewModel model, int? usuarioId, string? usuarioNombre)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_UpdateClientCreditSettings", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = model.UsuarioId;
                command.Parameters.Add("@LimiteCredito", SqlDbType.Decimal).Value = model.LimiteCredito;
                command.Parameters["@LimiteCredito"].Precision = 18;
                command.Parameters["@LimiteCredito"].Scale = 2;
                command.Parameters.Add("@CreditoActivo", SqlDbType.Bit).Value = model.CreditoActivo;
                command.Parameters.Add("@CreditoBloqueado", SqlDbType.Bit).Value = model.CreditoBloqueado;
                command.Parameters.Add("@MotivoBloqueo", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.MotivoBloqueo) ? DBNull.Value : model.MotivoBloqueo.Trim();
                command.Parameters.Add("@RegistradoPorUsuarioId", SqlDbType.Int).Value = usuarioId.HasValue ? usuarioId.Value : DBNull.Value;
                command.Parameters.Add("@RegistradoPorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();

                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        public async Task<int> RegisterClientCreditMovementAsync(ClientCreditMovementFormViewModel model, int? usuarioId, string? usuarioNombre)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Admin_RegisterClientCreditMovement", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = model.UsuarioId;
                command.Parameters.Add("@TipoMovimiento", SqlDbType.NVarChar, 30).Value = model.TipoMovimiento.Trim();
                command.Parameters.Add("@Monto", SqlDbType.Decimal).Value = model.Monto;
                command.Parameters["@Monto"].Precision = 18;
                command.Parameters["@Monto"].Scale = 2;
                command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value = model.Descripcion.Trim();
                command.Parameters.Add("@Referencia", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(model.Referencia) ? DBNull.Value : model.Referencia.Trim();
                command.Parameters.Add("@RegistradoPorUsuarioId", SqlDbType.Int).Value = usuarioId.HasValue ? usuarioId.Value : DBNull.Value;
                command.Parameters.Add("@RegistradoPorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre.Trim();

                await connection.OpenAsync();
                var result = await command.ExecuteScalarAsync();
                return Convert.ToInt32(result);
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }


        public async Task<List<SellerOrderClientViewModel>> GetSellerOrderClientsAsync(string? buscar = null)
        {
            CommercialAssignmentGuard.RequireAccreditedRelations();
            var clientes = new List<SellerOrderClientViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Seller_GetClientsForOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                clientes.Add(new SellerOrderClientViewModel
                {
                    UsuarioId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    NombreCompleto = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Telefono = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Direccion = reader.IsDBNull(4) ? string.Empty : reader.GetString(4)
                });
            }

            return clientes;
        }

        public async Task<List<SellerOrderProductViewModel>> GetSellerOrderProductsAsync(string? buscar = null)
        {
            var productos = new List<SellerOrderProductViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Seller_GetProductsForOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                productos.Add(new SellerOrderProductViewModel
                {
                    ProductoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Nombre = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Categoria = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    Descripcion = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Precio = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                    Stock = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                    ImagenUrl = reader.IsDBNull(6) ? string.Empty : reader.GetString(6)
                });
            }

            return productos;
        }

        public async Task<SellerOrderResultViewModel> CreateSellerOrderAsync(
            SellerOrderCreateViewModel model,
            int vendedorUsuarioId,
            string vendedorNombre,
            Guid? pedidoOfflineGuid = null,
            string? canalPedido = null)
        {
            CommercialAssignmentGuard.RequireAccreditedRelations();
            var itemsPayload = model.Productos
                .Where(x => x.Cantidad > 0)
                .Select(x => new { productoId = x.ProductoId, cantidad = x.Cantidad });

            var itemsJson = System.Text.Json.JsonSerializer.Serialize(itemsPayload);

            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Seller_CreateOrder", connection);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.Add("@ClienteUsuarioId", SqlDbType.Int).Value = model.ClienteUsuarioId;
                command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = vendedorUsuarioId;
                command.Parameters.Add("@VendedorNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(vendedorNombre) ? "Vendedor" : vendedorNombre.Trim();
                command.Parameters.Add("@TipoEntrega", SqlDbType.NVarChar, 100).Value = model.TipoEntrega.Trim();
                command.Parameters.Add("@DireccionEntrega", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.DireccionEntrega) ? DBNull.Value : model.DireccionEntrega.Trim();
                command.Parameters.Add("@Observaciones", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.Observaciones) ? DBNull.Value : model.Observaciones.Trim();
                command.Parameters.Add("@IdentificacionCliente", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(model.IdentificacionCliente) ? DBNull.Value : Proyecto_Final.Validation.CostaRicanIdentificationAttribute.Normalize(model.IdentificacionCliente);
                command.Parameters.Add("@ItemsJson", SqlDbType.NVarChar, -1).Value = itemsJson;
                command.Parameters.Add("@PedidoOfflineGuid", SqlDbType.UniqueIdentifier).Value = pedidoOfflineGuid.HasValue ? pedidoOfflineGuid.Value : DBNull.Value;
                command.Parameters.Add("@CanalPedido", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(canalPedido) ? "Venta móvil" : canalPedido.Trim();

                await connection.OpenAsync();
                await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();
                command.Transaction = transaction;
                await using var reader = await command.ExecuteReaderAsync();

                if (await reader.ReadAsync())
                {
                    var result = SellerOrderResultReader.Read(reader);
                    await reader.DisposeAsync();
                    await transaction.CommitAsync();
                    return result;
                }

                throw new InvalidOperationException("El procedimiento no devolvió resultado.");
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException("No fue posible registrar el pedido con el contrato SQL vigente.", ex);
            }
        }

        public async Task<List<RetainedOrderListItemViewModel>> GetRetainedOrdersAsync(string? buscar)
        {
            CommercialAssignmentGuard.RequireAccreditedRelations();
            var pedidos = new List<RetainedOrderListItemViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Manager_GetRetainedOrders", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                pedidos.Add(new RetainedOrderListItemViewModel
                {
                    PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Cliente = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    Correo = reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
                    FechaPedido = reader.IsDBNull(3) ? DateTime.MinValue : reader.GetDateTime(3),
                    VendedorNombre = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    Total = reader.IsDBNull(5) ? 0 : reader.GetDecimal(5),
                    TipoEntrega = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    CanalPedido = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                    TotalLineas = reader.IsDBNull(8) ? 0 : reader.GetInt32(8)
                });
            }
            return pedidos;
        }

        public async Task<ManagerApproveResultViewModel> ApproveRetainedOrderAsync(int pedidoId, int usuarioId, string usuarioNombre)
        {
            CommercialAssignmentGuard.RequireAccreditedRelations();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Manager_ApproveOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? "Gerente" : usuarioNombre.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return new ManagerApproveResultViewModel
                {
                    PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Estado = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    FacturaId = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                    NumeroFactura = reader.IsDBNull(3) ? string.Empty : reader.GetString(3)
                };
            }

            throw new InvalidOperationException("No fue posible aprobar el pedido.");
        }

        public async Task RejectRetainedOrderAsync(int pedidoId, string motivoRechazo, int usuarioId, string usuarioNombre)
        {
            CommercialAssignmentGuard.RequireAccreditedRelations();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Manager_RejectOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@MotivoRechazo", SqlDbType.NVarChar, 500).Value = motivoRechazo.Trim();
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? "Gerente" : usuarioNombre.Trim();

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<List<SellerMyOrderViewModel>> GetSellerMyOrdersAsync(int vendedorUsuarioId, int top = 20)
        {
            var pedidos = new List<SellerMyOrderViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Seller_GetMyOrders", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = vendedorUsuarioId;
            command.Parameters.Add("@Top", SqlDbType.Int).Value = top;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                pedidos.Add(new SellerMyOrderViewModel
                {
                    PedidoId = reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                    Cliente = reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                    FechaPedido = reader.IsDBNull(2) ? DateTime.MinValue : reader.GetDateTime(2),
                    Estado = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    Total = reader.IsDBNull(4) ? 0 : reader.GetDecimal(4),
                    MotivoRechazo = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    NumeroFactura = reader.IsDBNull(6) ? string.Empty : reader.GetString(6),
                    FechaActualizacion = reader.IsDBNull(7) ? null : reader.GetDateTime(7)
                });
            }
            return pedidos;
        }

        public async Task<bool> SellerOwnsOrderAsync(int pedidoId, int vendedorUsuarioId)
        {
            if (pedidoId <= 0 || vendedorUsuarioId <= 0)
            {
                return false;
            }

            const string sql = """
                SELECT CAST(CASE WHEN EXISTS (
                    SELECT 1
                    FROM dbo.Pedidos
                    WHERE PedidoId = @PedidoId
                      AND VendedorUsuarioId = @VendedorUsuarioId
                ) THEN 1 ELSE 0 END AS bit);
                """;

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand(sql, connection);
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@VendedorUsuarioId", SqlDbType.Int).Value = vendedorUsuarioId;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is not null and not DBNull && Convert.ToBoolean(result);
        }

        public async Task<(int FacturaId, string NumeroFactura)?> GetInvoiceSummaryByOrderAsync(int pedidoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetInvoiceSummaryByOrder", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
                return (reader.IsDBNull(0) ? 0 : reader.GetInt32(0),
                        reader.IsDBNull(1) ? string.Empty : reader.GetString(1));
            return null;
        }


        public async Task<bool> TienePermisoAsync(int perfilId, string modulo)
        {
            if (perfilId <= 0 || string.IsNullOrWhiteSpace(modulo))
            {
                return false;
            }

            var aliasModulo = ObtenerAliasModulo(modulo);
            var prefijosCodigo = ObtenerPrefijosCodigo(modulo);

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand();
            command.Connection = connection;

            var condiciones = new List<string>();

            for (var i = 0; i < aliasModulo.Count; i++)
            {
                var parameterName = $"@Modulo{i}";
                condiciones.Add($"pe.Modulo = {parameterName}");
                command.Parameters.Add(parameterName, SqlDbType.NVarChar, 80).Value = aliasModulo[i];
            }

            for (var i = 0; i < prefijosCodigo.Count; i++)
            {
                var parameterName = $"@Codigo{i}";
                condiciones.Add($"pe.Codigo LIKE {parameterName}");
                command.Parameters.Add(parameterName, SqlDbType.NVarChar, 100).Value = prefijosCodigo[i] + "%";
            }

            if (condiciones.Count == 0)
            {
                return false;
            }

            command.CommandText = $@"
                SELECT COUNT(1)
                FROM dbo.PerfilPermisos pp
                INNER JOIN dbo.Permisos pe ON pe.PermisoId = pp.PermisoId
                WHERE pp.PerfilId = @PerfilId
                  AND pe.Activo = 1
                  AND ({string.Join(" OR ", condiciones)});";

            command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = perfilId;

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result ?? 0) > 0;
        }

        public async Task<bool> TienePermisoPorRolAsync(string? nombreRol, string modulo)
        {
            if (string.IsNullOrWhiteSpace(nombreRol) || string.IsNullOrWhiteSpace(modulo))
            {
                return false;
            }

            if (string.Equals(nombreRol.Trim(), "Administrador", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            var aliasModulo = ObtenerAliasModulo(modulo);
            var prefijosCodigo = ObtenerPrefijosCodigo(modulo);

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand();
            command.Connection = connection;

            var condiciones = new List<string>();

            for (var i = 0; i < aliasModulo.Count; i++)
            {
                var parameterName = $"@Modulo{i}";
                condiciones.Add($"pe.Modulo = {parameterName}");
                command.Parameters.Add(parameterName, SqlDbType.NVarChar, 80).Value = aliasModulo[i];
            }

            for (var i = 0; i < prefijosCodigo.Count; i++)
            {
                var parameterName = $"@Codigo{i}";
                condiciones.Add($"pe.Codigo LIKE {parameterName}");
                command.Parameters.Add(parameterName, SqlDbType.NVarChar, 100).Value = prefijosCodigo[i] + "%";
            }

            if (condiciones.Count == 0)
            {
                return false;
            }

            command.CommandText = $@"
                SELECT COUNT(1)
                FROM dbo.Perfiles p
                INNER JOIN dbo.PerfilPermisos pp ON pp.PerfilId = p.PerfilId
                INNER JOIN dbo.Permisos pe ON pe.PermisoId = pp.PermisoId
                WHERE p.Nombre = @NombreRol
                  AND p.Activo = 1
                  AND pe.Activo = 1
                  AND ({string.Join(" OR ", condiciones)});";

            command.Parameters.Add("@NombreRol", SqlDbType.NVarChar, 100).Value = nombreRol.Trim();

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result ?? 0) > 0;
        }

        public async Task<bool> TienePermisoCodigoPorRolAsync(string nombreRol, string codigoPermiso)
        {
            if (string.IsNullOrWhiteSpace(nombreRol) || string.IsNullOrWhiteSpace(codigoPermiso))
            {
                return false;
            }

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_HasPermissionByCode", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.Add("@NombreRol", SqlDbType.NVarChar, 100).Value = nombreRol.Trim();
            command.Parameters.Add("@Codigo", SqlDbType.NVarChar, 100).Value = codigoPermiso.Trim();

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value && Convert.ToBoolean(result);
        }

        public async Task<HashSet<string>> GetPermissionCodesByRoleAsync(string? roleName)
        {
            var permissions = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (string.IsNullOrWhiteSpace(roleName))
                return permissions;

            const string sql = """
                SELECT permission.Codigo
                FROM dbo.Perfiles profile
                INNER JOIN dbo.PerfilPermisos assignment ON assignment.PerfilId = profile.PerfilId
                INNER JOIN dbo.Permisos permission ON permission.PermisoId = assignment.PermisoId
                WHERE profile.Nombre = @NombreRol
                  AND profile.Activo = 1
                  AND permission.Activo = 1;
                """;

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand(sql, connection);
            command.Parameters.Add("@NombreRol", SqlDbType.NVarChar, 100).Value = roleName.Trim();
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                if (!reader.IsDBNull(0))
                    permissions.Add(reader.GetString(0));
            }

            return permissions;
        }

        public async Task<bool> IsEmployeeUserAsync(int userId)
        {
            if (userId <= 0)
                return false;

            const string sql = """
                SELECT CAST(CASE WHEN EXISTS (
                    SELECT 1
                    FROM dbo.Empleados employee
                    INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId = employee.UsuarioId
                    WHERE employee.UsuarioId = @UsuarioId
                      AND employee.Activo = 1
                      AND userAccount.Activo = 1
                ) THEN 1 ELSE 0 END AS bit);
                """;

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand(sql, connection);
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            await connection.OpenAsync();
            var value = await command.ExecuteScalarAsync();
            return value is not null and not DBNull && Convert.ToBoolean(value);
        }

        private static List<string> ObtenerAliasModulo(string modulo)
        {
            var clave = NormalizarModulo(modulo);

            return clave switch
            {
                "admin" or "dashboard" => new List<string> { "Dashboard", "Admin" },
                "facturacion" => new List<string> { "Facturación", "Facturacion" },
                "auditoria" => new List<string> { "Auditoría", "Auditoria" },
                "creditos" => new List<string> { "Créditos", "Creditos" },
                "seguridad" => new List<string> { "Seguridad", "Roles", "Permisos" },
                "ventamovil" => new List<string> { "Venta móvil", "Venta movil", "VentaMovil" },
                "clientes" => new List<string> { "Clientes" },
                "consultas" => new List<string> { "Consultas" },
                "inventario" => new List<string> { "Inventario" },
                "pedidos" => new List<string> { "Pedidos" },
                _ => new List<string> { modulo.Trim() }
            };
        }

        private static List<string> ObtenerPrefijosCodigo(string modulo)
        {
            var clave = NormalizarModulo(modulo);

            return clave switch
            {
                "admin" or "dashboard" => new List<string> { "DASHBOARD_" },
                "facturacion" => new List<string> { "FACTURACION_" },
                "auditoria" => new List<string> { "AUDITORIA_" },
                "creditos" => new List<string> { "CREDITOS_" },
                "seguridad" => new List<string> { "ROLES_", "PERMISOS_" },
                "ventamovil" => new List<string> { "VENTA_MOVIL_" },
                "clientes" => new List<string> { "CLIENTES_" },
                "consultas" => new List<string> { "CONSULTAS_" },
                "inventario" => new List<string> { "INVENTARIO_" },
                "pedidos" => new List<string> { "PEDIDOS_" },
                _ => new List<string>()
            };
        }

        private static string NormalizarModulo(string modulo)
        {
            return modulo
                .Trim()
                .ToLowerInvariant()
                .Replace("á", "a")
                .Replace("é", "e")
                .Replace("í", "i")
                .Replace("ó", "o")
                .Replace("ú", "u")
                .Replace(" ", string.Empty)
                .Replace("-", string.Empty)
                .Replace("_", string.Empty);
        }

        private static async Task CreateMovementInternalAsync(SqlConnection connection, SqlTransaction transaction, int productoId, string tipoMovimiento, int cantidad, int stockAnterior, int stockNuevo, string? motivo, int usuarioId, string usuarioNombre, string? productoNombre = null)
        {
            if (string.IsNullOrWhiteSpace(productoNombre))
            {
                await using var commandName = new SqlCommand("dbo.sp_Admin_GetProductNameById", connection, transaction);
                commandName.CommandType = CommandType.StoredProcedure;
                commandName.Parameters.AddWithValue("@ProductoId", productoId);
                productoNombre = Convert.ToString(await commandName.ExecuteScalarAsync()) ?? "Producto";
            }
            await using var command = new SqlCommand("dbo.sp_Admin_CreateInventoryMovement", connection, transaction);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ProductoId", productoId);
            command.Parameters.AddWithValue("@ProductoNombre", productoNombre);
            command.Parameters.AddWithValue("@TipoMovimiento", tipoMovimiento);
            command.Parameters.AddWithValue("@Cantidad", cantidad);
            command.Parameters.AddWithValue("@StockAnterior", stockAnterior);
            command.Parameters.AddWithValue("@StockNuevo", stockNuevo);
            command.Parameters.AddWithValue("@Motivo", string.IsNullOrWhiteSpace(motivo) ? DBNull.Value : motivo.Trim());
            command.Parameters.AddWithValue("@UsuarioId", usuarioId);
            command.Parameters.AddWithValue("@UsuarioNombre", usuarioNombre);
            await command.ExecuteNonQueryAsync();
        }

        private static async Task UpdateProductStockInternalAsync(SqlConnection connection, SqlTransaction transaction, int productoId, int nuevoStock)
        {
            await using var command = new SqlCommand("dbo.sp_Admin_UpdateProductStock", connection, transaction);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ProductoId", productoId);
            command.Parameters.AddWithValue("@NuevoStock", nuevoStock);
            await command.ExecuteNonQueryAsync();
        }

        public async Task<FinancialReportViewModel> GetFinancialReportAsync(
            DateTime? fechaInicio,
            DateTime? fechaFin)
        {
            var modelo = new FinancialReportViewModel
            {
                FechaInicio = fechaInicio,
                FechaFin = fechaFin
            };

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            const string ingresosQuery = """
        SELECT
            PedidoId,
            FechaPago,
            MetodoPago,
            Total
        FROM dbo.Pedidos
        WHERE EstadoPago = N'Confirmado simulado'
          AND (@FechaInicio IS NULL OR FechaPago >= @FechaInicio)
          AND (@FechaFin IS NULL OR FechaPago < DATEADD(DAY, 1, @FechaFin))
        ORDER BY FechaPago DESC;
        """;

            await using (var command = new SqlCommand(ingresosQuery, connection))
            {
                command.Parameters.Add("@FechaInicio", SqlDbType.DateTime2).Value =
                    fechaInicio.HasValue
                        ? fechaInicio.Value.Date
                        : DBNull.Value;

                command.Parameters.Add("@FechaFin", SqlDbType.DateTime2).Value =
                    fechaFin.HasValue
                        ? fechaFin.Value.Date
                        : DBNull.Value;

                await using var reader = await command.ExecuteReaderAsync();

                while (await reader.ReadAsync())
                {
                    var pedidoId = reader.GetInt32(reader.GetOrdinal("PedidoId"));
                    var monto = reader.GetDecimal(reader.GetOrdinal("Total"));
                    var metodoPago = reader.GetString(reader.GetOrdinal("MetodoPago"));

                    modelo.Movimientos.Add(new FinancialMovementViewModel
                    {
                        MovimientoId = pedidoId,
                        Fecha = reader.GetDateTime(reader.GetOrdinal("FechaPago")),
                        Tipo = "Ingreso",
                        Descripcion = "Venta realizada",
                        Referencia = $"Pedido #{pedidoId} - {metodoPago}",
                        Monto = monto
                    });

                    modelo.TotalIngresos += monto;
                }
            }

            const string egresosQuery = """
        SELECT
            GastoId,
            Fecha,
            Concepto,
            Categoria,
            Monto
        FROM dbo.Gastos
        WHERE (@FechaInicio IS NULL OR Fecha >= @FechaInicio)
          AND (@FechaFin IS NULL OR Fecha < DATEADD(DAY, 1, @FechaFin))
        ORDER BY Fecha DESC;
        """;

            await using (var command = new SqlCommand(egresosQuery, connection))
            {
                command.Parameters.Add("@FechaInicio", SqlDbType.DateTime2).Value =
                    fechaInicio.HasValue
                        ? fechaInicio.Value.Date
                        : DBNull.Value;

                command.Parameters.Add("@FechaFin", SqlDbType.DateTime2).Value =
                    fechaFin.HasValue
                        ? fechaFin.Value.Date
                        : DBNull.Value;

                await using var reader = await command.ExecuteReaderAsync();

                while (await reader.ReadAsync())
                {
                    var gastoId = reader.GetInt32(reader.GetOrdinal("GastoId"));
                    var monto = reader.GetDecimal(reader.GetOrdinal("Monto"));
                    var concepto = reader.GetString(reader.GetOrdinal("Concepto"));

                    var categoriaOrdinal = reader.GetOrdinal("Categoria");

                    var categoria = reader.IsDBNull(categoriaOrdinal)
                        ? "Sin categoría"
                        : reader.GetString(categoriaOrdinal);

                    modelo.Movimientos.Add(new FinancialMovementViewModel
                    {
                        MovimientoId = gastoId,
                        Fecha = reader.GetDateTime(reader.GetOrdinal("Fecha")),
                        Tipo = "Egreso",
                        Descripcion = concepto,
                        Referencia = $"Gasto #{gastoId} - {categoria}",
                        Monto = monto
                    });

                    modelo.TotalEgresos += monto;
                }
            }

            modelo.Movimientos = modelo.Movimientos
                .OrderByDescending(x => x.Fecha)
                .ToList();

            return modelo;
        }


        public async Task<List<WarrantyRequestViewModel>> GetWarrantyRequestsAsync()
        {
            var warranties = new List<WarrantyRequestViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand(WarrantyRequestReader.ListSql, connection);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                warranties.Add(WarrantyRequestReader.Read(reader));
            return warranties;
        }

        public async Task UpdateWarrantyStatusAsync(
            int garantiaId,
            string estado,
            string? resolucion,
            int actorUsuarioId,
            string actorNombre,
            OriginalLoginContext originalLogin)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_UpdateWarrantyStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@GarantiaId", SqlDbType.Int).Value = garantiaId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = estado.Trim();
            command.Parameters.Add("@Resolucion", SqlDbType.NVarChar, 1000).Value =
                string.IsNullOrWhiteSpace(resolucion) ? DBNull.Value : resolucion.Trim();
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUsuarioId;
            command.Parameters.Add("@ActorNombre", SqlDbType.NVarChar, 150).Value = actorNombre;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;
            await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, actorUsuarioId, "GARANTIAS_GESTIONAR", async () =>
            {
                await command.ExecuteNonQueryAsync();
                return 0;
            });
        }

        public async Task<OrderDetailLineViewModel?> GetOrderDetailLineAsync(int pedidoDetalleId)
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand(@"
        SELECT
            pd.PedidoDetalleId,
            pd.PedidoId,
            p.UsuarioId,
            pr.Nombre AS Producto,
            CONVERT(bit,CASE WHEN pd.PedidoComboId IS NULL AND pd.EsRegalo=0
                AND EXISTS(SELECT 1 FROM dbo.Stage2PhysicalDeliveries e WHERE e.PedidoId=p.PedidoId)
                AND NOT EXISTS(SELECT 1 FROM dbo.Garantias g WHERE g.PedidoDetalleId=pd.PedidoDetalleId
                    AND g.Estado IN(N'Pendiente',N'En revisión')) THEN 1 ELSE 0 END) AS CanRequestWarranty
        FROM PedidoDetalle pd
        INNER JOIN Pedidos p
            ON p.PedidoId = pd.PedidoId
        INNER JOIN Productos pr
            ON pr.ProductoId = pd.ProductoId
        WHERE pd.PedidoDetalleId = @PedidoDetalleId;", connection);

            command.Parameters.AddWithValue("@PedidoDetalleId", pedidoDetalleId);

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
            {
                return null;
            }

            return new OrderDetailLineViewModel
            {
                PedidoDetalleId = reader.GetInt32(reader.GetOrdinal("PedidoDetalleId")),
                PedidoId = reader.GetInt32(reader.GetOrdinal("PedidoId")),
                UsuarioId = reader.GetInt32(reader.GetOrdinal("UsuarioId")),
                Producto = reader.GetString(reader.GetOrdinal("Producto")),
                CanRequestWarranty = reader.GetBoolean(reader.GetOrdinal("CanRequestWarranty"))
            };
        }
        public async Task<HashSet<int>> GetWarrantyEligibleLineIdsAsync(int pedidoId, int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("""
                SELECT d.PedidoDetalleId FROM dbo.PedidoDetalle d
                INNER JOIN dbo.Pedidos o ON o.PedidoId=d.PedidoId
                INNER JOIN dbo.Stage2PhysicalDeliveries e ON e.PedidoId=o.PedidoId
                WHERE o.PedidoId=@PedidoId AND o.UsuarioId=@UsuarioId
                  AND d.PedidoComboId IS NULL AND d.EsRegalo=0
                  AND NOT EXISTS(SELECT 1 FROM dbo.Garantias g WHERE g.PedidoDetalleId=d.PedidoDetalleId
                      AND g.Estado IN(N'Pendiente',N'En revisión'));
                """, connection);
            command.Parameters.Add("@PedidoId", SqlDbType.Int).Value = pedidoId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            var eligible = new HashSet<int>();
            while (await reader.ReadAsync()) eligible.Add(reader.GetInt32(0));
            return eligible;
        }

        public async Task<bool> CreateWarrantyRequestAsync(
            int pedidoDetalleId,
            int usuarioId,
            string motivo,
            string? descripcion,
            OriginalLoginContext originalLogin)
        {
            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "dbo.sp_Client_CreateWarrantyRequest",
                connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add("@PedidoDetalleId", SqlDbType.Int).Value = pedidoDetalleId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 250).Value = motivo;
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 1000).Value =
                string.IsNullOrWhiteSpace(descripcion) ? DBNull.Value : descripcion;
            command.Parameters.Add("@ExpectedSecurityStamp", SqlDbType.UniqueIdentifier).Value = originalLogin.SecurityStamp;

            return await OriginalLoginTransaction.ExecuteAsync(connection, command, originalLogin, usuarioId, null, async () =>
            {

                var result = await command.ExecuteScalarAsync();

                return result != null;
            });
        }

        public async Task<List<ClientWarrantyListItemViewModel>>
            GetClientWarrantyRequestsAsync(int usuarioId)
        {
            var solicitudes = new List<ClientWarrantyListItemViewModel>();

            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(@"
        SELECT
            g.GarantiaId,
            pd.PedidoId,
            g.PedidoDetalleId,
            p.Nombre AS Producto,
            g.FechaSolicitud,
            g.Motivo,
            g.Descripcion,
            g.Estado,
            g.Resolucion,
            g.FechaResolucion
        FROM Garantias g
        INNER JOIN PedidoDetalle pd
            ON pd.PedidoDetalleId = g.PedidoDetalleId
        INNER JOIN Productos p
            ON p.ProductoId = pd.ProductoId
        WHERE g.UsuarioId = @UsuarioId
        ORDER BY g.FechaSolicitud DESC;",
                connection);

            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                solicitudes.Add(new ClientWarrantyListItemViewModel
                {
                    GarantiaId = reader.GetInt32(
                        reader.GetOrdinal("GarantiaId")),

                    PedidoId = reader.GetInt32(
                        reader.GetOrdinal("PedidoId")),

                    PedidoDetalleId = reader.GetInt32(
                        reader.GetOrdinal("PedidoDetalleId")),

                    Producto = reader.GetString(
                        reader.GetOrdinal("Producto")),

                    FechaSolicitud = reader.GetDateTime(
                        reader.GetOrdinal("FechaSolicitud")),

                    Motivo = reader.GetString(
                        reader.GetOrdinal("Motivo")),

                    Descripcion = reader.IsDBNull(
                        reader.GetOrdinal("Descripcion"))
                            ? null
                            : reader.GetString(
                                reader.GetOrdinal("Descripcion")),

                    Estado = reader.GetString(
                        reader.GetOrdinal("Estado")),

                    Resolucion = reader.IsDBNull(
                        reader.GetOrdinal("Resolucion"))
                            ? null
                            : reader.GetString(
                                reader.GetOrdinal("Resolucion")),

                    FechaResolucion = reader.IsDBNull(
                        reader.GetOrdinal("FechaResolucion"))
                            ? null
                            : reader.GetDateTime(
                                reader.GetOrdinal("FechaResolucion"))
                });
            }

            return solicitudes;
        }

        public async Task<List<ChatUserViewModel>> GetChatUsersAsync(
            int usuarioIdActual)
        {
            var usuarios = new List<ChatUserViewModel>();

            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_GetUsers",
                connection
            );

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(
                "@UsuarioIdActual",
                SqlDbType.Int
            ).Value = usuarioIdActual;

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                usuarios.Add(new ChatUserViewModel
                {
                    UsuarioId = reader.GetInt32(
                        reader.GetOrdinal("UsuarioId")
                    ),

                    NombreCompleto = reader.GetString(
                        reader.GetOrdinal("NombreCompleto")
                    ),

                    Correo = reader.GetString(
                        reader.GetOrdinal("Correo")
                    )
                });
            }

            return usuarios;
        }


        public async Task<int> GetOrCreateChatConversationAsync(
            int usuarioActualId,
            int otroUsuarioId)
        {
            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_GetOrCreateConversation",
                connection
            );

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(
                "@UsuarioActualId",
                SqlDbType.Int
            ).Value = usuarioActualId;

            command.Parameters.Add(
                "@OtroUsuarioId",
                SqlDbType.Int
            ).Value = otroUsuarioId;

            await connection.OpenAsync();

            var result = await command.ExecuteScalarAsync();

            return Convert.ToInt32(result);
        }

        public async Task<ChatMessageViewModel?> SendChatMessageAsync(
            int conversacionId,
            int remitenteId,
            string contenido)
        {
            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_SendMessage",
                connection
            );

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(
                "@ConversacionId",
                SqlDbType.Int
            ).Value = conversacionId;

            command.Parameters.Add(
                "@RemitenteId",
                SqlDbType.Int
            ).Value = remitenteId;

            command.Parameters.Add(
                "@Contenido",
                SqlDbType.NVarChar,
                1000
            ).Value = contenido;

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
            {
                return null;
            }

            return new ChatMessageViewModel
            {
                MensajeId = reader.GetInt32(
                    reader.GetOrdinal("MensajeId")
                ),

                ConversacionId = reader.GetInt32(
                    reader.GetOrdinal("ConversacionId")
                ),

                RemitenteId = reader.GetInt32(
                    reader.GetOrdinal("RemitenteId")
                ),

                Contenido = reader.GetString(
                    reader.GetOrdinal("Contenido")
                ),

                FechaEnvio = reader.GetDateTime(
                    reader.GetOrdinal("FechaEnvio")
                ),

                Leido = reader.GetBoolean(
                    reader.GetOrdinal("Leido")
                )
            };
        }

        public async Task<List<ChatMessageViewModel>> GetChatMessagesAsync(
            int conversacionId,
            int usuarioId)
        {
            var mensajes = new List<ChatMessageViewModel>();

            using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_GetMessages",
                connection
            );

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(
                "@ConversacionId",
                SqlDbType.Int
            ).Value = conversacionId;

            command.Parameters.Add(
                "@UsuarioId",
                SqlDbType.Int
            ).Value = usuarioId;

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                mensajes.Add(new ChatMessageViewModel
                {
                    MensajeId = reader.GetInt32(
                        reader.GetOrdinal("MensajeId")
                    ),

                    ConversacionId = reader.GetInt32(
                        reader.GetOrdinal("ConversacionId")
                    ),

                    RemitenteId = reader.GetInt32(
                        reader.GetOrdinal("RemitenteId")
                    ),

                    Contenido = reader.GetString(
                        reader.GetOrdinal("Contenido")
                    ),

                    FechaEnvio = reader.GetDateTime(
                        reader.GetOrdinal("FechaEnvio")
                    ),

                    Leido = reader.GetBoolean(
                        reader.GetOrdinal("Leido")
                    )
                });
            }

            return mensajes;
        }
        public async Task<List<ChatDepartmentViewModel>> GetChatDepartmentsAsync()
        {
            var departamentos = new List<ChatDepartmentViewModel>();

            await using var connection = new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_GetDepartments",
                connection);

            command.CommandType = CommandType.StoredProcedure;

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                departamentos.Add(new ChatDepartmentViewModel
                {
                    PerfilId = Convert.ToInt32(reader["PerfilId"]),
                    Nombre = reader["Nombre"]?.ToString() ?? "",
                    Descripcion = reader["Descripcion"]?.ToString(),
                    TotalUsuarios = Convert.ToInt32(reader["TotalUsuarios"])
                });
            }

            return departamentos;
        }

        public async Task<ChatDepartmentMessageViewModel?>
            SendDepartmentMessageAsync(
                int perfilId,
                int remitenteId,
                string contenido)
        {
            using var connection =
                new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_SendDepartmentMessage",
                connection
            );

            command.CommandType =
                CommandType.StoredProcedure;

            command.Parameters.Add(
                "@PerfilId",
                SqlDbType.Int
            ).Value = perfilId;

            command.Parameters.Add(
                "@RemitenteId",
                SqlDbType.Int
            ).Value = remitenteId;

            command.Parameters.Add(
                "@Contenido",
                SqlDbType.NVarChar,
                1000
            ).Value = contenido;

            await connection.OpenAsync();

            using var reader =
                await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
            {
                return null;
            }

            return new ChatDepartmentMessageViewModel
            {
                MensajeId = reader.GetInt32(
                    reader.GetOrdinal("MensajeId")
                ),

                PerfilId = reader.GetInt32(
                    reader.GetOrdinal("PerfilId")
                ),

                RemitenteId = reader.GetInt32(
                    reader.GetOrdinal("RemitenteId")
                ),

                Contenido = reader.GetString(
                    reader.GetOrdinal("Contenido")
                ),

                FechaEnvio = reader.GetDateTime(
                    reader.GetOrdinal("FechaEnvio")
                ),

                RemitenteNombre = reader.GetString(
                    reader.GetOrdinal("RemitenteNombre")
                )
            };
        }

        public async Task<List<ChatDepartmentMessageViewModel>>
            GetDepartmentMessagesAsync(int perfilId)
        {
            var mensajes =
                new List<ChatDepartmentMessageViewModel>();

            using var connection =
                new SqlConnection(_connectionString);

            using var command = new SqlCommand(
                "sp_Chat_GetDepartmentMessages",
                connection
            );

            command.CommandType =
                CommandType.StoredProcedure;

            command.Parameters.Add(
                "@PerfilId",
                SqlDbType.Int
            ).Value = perfilId;

            await connection.OpenAsync();

            using var reader =
                await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                mensajes.Add(
                    new ChatDepartmentMessageViewModel
                    {
                        MensajeId = reader.GetInt32(
                            reader.GetOrdinal("MensajeId")
                        ),

                        PerfilId = reader.GetInt32(
                            reader.GetOrdinal("PerfilId")
                        ),

                        RemitenteId = reader.GetInt32(
                            reader.GetOrdinal("RemitenteId")
                        ),

                        Contenido = reader.GetString(
                            reader.GetOrdinal("Contenido")
                        ),

                        FechaEnvio = reader.GetDateTime(
                            reader.GetOrdinal("FechaEnvio")
                        ),

                        RemitenteNombre = reader.GetString(
                            reader.GetOrdinal("RemitenteNombre")
                        )
                    }
                );
            }

            return mensajes;
        }

    }
}






