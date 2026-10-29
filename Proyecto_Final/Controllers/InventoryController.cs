using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [AdminAuthorize("Inventario", "INVENTARIO_VER")]
    public class InventoryController : Controller
    {
        private readonly AdminDbService _adminDbService;
        private readonly IProductImageStorageService _images;
        private readonly IInventoryTransformationService _transformations;
        private readonly ILogger<InventoryController> _logger;

        public InventoryController(
            AdminDbService adminDbService,
            IProductImageStorageService images,
            IInventoryTransformationService transformations,
            ILogger<InventoryController> logger)
        {
            _adminDbService = adminDbService;
            _images = images;
            _transformations = transformations;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? filtro)
        {
            ViewBag.Filtro = filtro;
            var productos = await _adminDbService.GetProductsAsync(filtro);
            return View(productos);
        }

        [HttpGet]
        [AdminAuthorize("Inventario", "INVENTARIO_CREAR")]
        public async Task<IActionResult> Create()
        {
            ViewBag.Categorias = await _adminDbService.GetStoreCategoriesAsync();
            return View(new ProductFormViewModel
            {
                Activo = true,
                StockMinimo = 5
            });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("private-file-upload")]
        [AdminAuthorize("Inventario", "INVENTARIO_CREAR")]
        public async Task<IActionResult> Create(ProductFormViewModel model)
        {
            ViewBag.Categorias = await _adminDbService.GetStoreCategoriesAsync();
            if (!ModelState.IsValid) return View(model);

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            StagedProductImage? staged = null;
            try
            {
                staged = await _images.StageAsync(model.ImagenArchivo, HttpContext.RequestAborted);
                model.ImagenUrl = staged?.PublicUrl;
                await _adminDbService.CreateProductAsync(model, usuarioId, usuarioNombre);
            }
            catch (ProductImageValidationException ex)
            {
                ModelState.AddModelError(nameof(model.ImagenArchivo), ex.UserMessage);
                return View(model);
            }
            catch
            {
                await TryDeleteImageAsync(staged?.PublicUrl, "revertir una creación fallida", 0);
                throw;
            }

            await RegistrarAuditoriaAsync(
                "Crear",
                "Inventario",
                $"Se creó el producto {model.Nombre} con stock inicial {model.Stock} y stock mínimo {model.StockMinimo}.");

            TempData["SuccessMessage"] = "Producto creado correctamente.";
            return RedirectToAction(nameof(Index));
        }

        [HttpGet]
        [AdminAuthorize("Inventario", "INVENTARIO_EDITAR")]
        public async Task<IActionResult> Edit(int id)
        {
            ViewBag.Categorias = await _adminDbService.GetStoreCategoriesAsync();
            var model = await _adminDbService.GetProductByIdAsync(id);
            if (model == null) return RedirectToAction(nameof(Index));
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("private-file-upload")]
        [AdminAuthorize("Inventario", "INVENTARIO_EDITAR")]
        public async Task<IActionResult> Edit(ProductFormViewModel model)
        {
            ViewBag.Categorias = await _adminDbService.GetStoreCategoriesAsync();
            if (!ModelState.IsValid) return View(model);

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            var current = await _adminDbService.GetProductByIdAsync(model.ProductoId);
            if (current is null) return NotFound();

            StagedProductImage? staged = null;
            try
            {
                staged = await _images.StageAsync(model.ImagenArchivo, HttpContext.RequestAborted);
                model.ImagenUrl = staged?.PublicUrl ?? current.ImagenUrl;
                await _adminDbService.UpdateProductAsync(model, usuarioId, usuarioNombre);
            }
            catch (ProductImageValidationException ex)
            {
                model.ImagenUrl = current.ImagenUrl;
                ModelState.AddModelError(nameof(model.ImagenArchivo), ex.UserMessage);
                return View(model);
            }
            catch
            {
                await TryDeleteImageAsync(staged?.PublicUrl, "revertir una edición fallida", model.ProductoId);
                throw;
            }

            if (staged is not null) await TryDeleteImageAsync(current.ImagenUrl, "reemplazar", model.ProductoId);

            await RegistrarAuditoriaAsync(
                "Editar",
                "Inventario",
                $"Se actualizó el producto {model.Nombre}. Stock actual: {model.Stock}. Stock mínimo: {model.StockMinimo}.");

            TempData["SuccessMessage"] = "Producto actualizado correctamente.";
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_EDITAR")]
        public async Task<IActionResult> RemoveImage(int productoId)
        {
            var current = await _adminDbService.GetProductByIdAsync(productoId);
            if (current is null) return NotFound();
            await _adminDbService.UpdateProductImageAsync(productoId, null);
            await TryDeleteImageAsync(current.ImagenUrl, "retirar", productoId);
            await RegistrarAuditoriaAsync("Editar", "Inventario", $"Se retiró la imagen administrada del producto #{productoId}.");
            TempData["SuccessMessage"] = "Imagen retirada correctamente.";
            return RedirectToAction(nameof(Edit), new { id = productoId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_EDITAR")]
        public async Task<IActionResult> ToggleFeatured(int productoId, string? filtro)
        {
            await _adminDbService.ToggleFeaturedAsync(productoId);

            await RegistrarAuditoriaAsync(
                "Editar",
                "Inventario",
                $"Se cambió el estado destacado del producto #{productoId}.");

            return RedirectToAction(nameof(Index), new { filtro });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_EDITAR")]
        public async Task<IActionResult> ToggleStatus(int productoId, string? filtro)
        {
            var activo = await _adminDbService.ToggleProductStatusAsync(productoId);

            await RegistrarAuditoriaAsync(
                activo ? "Activar" : "Inactivar",
                "Inventario",
                activo
                    ? $"Se reactivó el producto #{productoId}."
                    : $"Se inactivó el producto #{productoId} para ocultarlo del catálogo.");

            TempData["SuccessMessage"] = activo
                ? "Producto reactivado correctamente."
                : "Producto inactivado correctamente.";

            return RedirectToAction(nameof(Index), new { filtro });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_ELIMINAR")]
        public async Task<IActionResult> DeletePermanent(int productoId, string? filtro)
        {
            try
            {
                var current = await _adminDbService.GetProductByIdAsync(productoId);
                if (current is null) return NotFound();
                var productoNombre = await _adminDbService.DeleteProductPermanentlyAsync(productoId);
                await TryDeleteImageAsync(current.ImagenUrl, "eliminar el producto", productoId);

                await RegistrarAuditoriaAsync(
                    "Eliminar",
                    "Inventario",
                    $"Se eliminó permanentemente el producto {productoNombre}.");

                TempData["SuccessMessage"] = "Producto eliminado permanentemente.";
            }
            catch (InvalidOperationException)
            {
                TempData["ErrorMessage"] = "No se pudo eliminar el producto.";
            }

            return RedirectToAction(nameof(Index), new { filtro });
        }

        [HttpGet]
        public async Task<IActionResult> Movements()
        {
            var movimientos = await _adminDbService.GetInventoryMovementsAsync();
            return View(movimientos);
        }

        [HttpGet]
        [AdminAuthorize("Inventario", "INVENTARIO_MOVIMIENTOS")]
        public async Task<IActionResult> RegisterMovement()
        {
            var productos = await _adminDbService.GetActiveProductsForSelectAsync();
            ViewBag.Productos = productos.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
            {
                Value = p.ProductoId.ToString(),
                Text = $"{p.Nombre} (Stock actual: {p.Stock})"
            }).ToList();
            return View(new InventoryMovementFormViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_MOVIMIENTOS")]
        public async Task<IActionResult> RegisterMovement(InventoryMovementFormViewModel model)
        {
            if (!ModelState.IsValid)
            {
                var productos = await _adminDbService.GetActiveProductsForSelectAsync();
                ViewBag.Productos = productos.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
                {
                    Value = p.ProductoId.ToString(),
                    Text = $"{p.Nombre} (Stock actual: {p.Stock})"
                }).ToList();
                return View(model);
            }

            try
            {
                var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
                var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
                await _adminDbService.RegisterInventoryMovementAsync(model, usuarioId, usuarioNombre);

                await RegistrarAuditoriaAsync(
                    "Movimiento",
                    "Inventario",
                    $"Se registró movimiento de inventario tipo {model.TipoMovimiento} para el producto #{model.ProductoId} con cantidad {model.Cantidad}.");

                TempData["SuccessMessage"] = "Movimiento registrado correctamente.";
                return RedirectToAction(nameof(Movements));
            }
            catch (InvalidOperationException)
            {
                ModelState.AddModelError(string.Empty, "No se pudo registrar el movimiento de inventario. Revise los datos e intente nuevamente.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Ocurrió un error al registrar el movimiento. Intente nuevamente.");
            }

            var productosRetry = await _adminDbService.GetActiveProductsForSelectAsync();
            ViewBag.Productos = productosRetry.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
            {
                Value = p.ProductoId.ToString(),
                Text = $"{p.Nombre} (Stock actual: {p.Stock})"
            }).ToList();
            return View(model);
        }

        [HttpGet]
        [AdminAuthorize("Inventario", "INVENTARIO_TRANSFORMAR")]
        public async Task<IActionResult> TransformStock()
        {
            var productos = await _adminDbService.GetActiveProductsForSelectAsync();
            ViewBag.Productos = productos.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
            {
                Value = p.ProductoId.ToString(),
                Text = $"{p.Nombre} (Stock actual: {p.Stock})"
            }).ToList();
            return View(new StockTransformationFormViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "INVENTARIO_TRANSFORMAR")]
        public async Task<IActionResult> TransformStock(StockTransformationFormViewModel model)
        {
            if (!ModelState.IsValid)
            {
                var productos = await _adminDbService.GetActiveProductsForSelectAsync();
                ViewBag.Productos = productos.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
                {
                    Value = p.ProductoId.ToString(),
                    Text = $"{p.Nombre} (Stock actual: {p.Stock})"
                }).ToList();
                return View(model);
            }

            try
            {
                var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
                var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
                var result = await _transformations.TransformAsync(model, usuarioId, usuarioNombre, HttpContext.RequestAborted);
                TempData["SuccessMessage"] = $"Transformación registrada correctamente. Referencia {result.Reference:N}.";
                return RedirectToAction(nameof(Movements));
            }
            catch (SqlException exception)
            {
                _logger.LogWarning(
                    exception,
                    "La transformación de inventario fue rechazada para el usuario {UserId}. Código SQL {SqlNumber}.",
                    HttpContext.Session.GetInt32("UserId"),
                    exception.Number);
                ModelState.AddModelError(
                    string.Empty,
                    exception.Number == 54405
                        ? "No hay stock suficiente en el producto de origen."
                        : "No fue posible completar la transformación. Revise los datos.");
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error inesperado al transformar inventario para el usuario {UserId}.", HttpContext.Session.GetInt32("UserId"));
                ModelState.AddModelError(string.Empty, "Ocurrió un error al registrar la transformación. Intente nuevamente.");
            }

            var productosRetry = await _adminDbService.GetActiveProductsForSelectAsync();
            ViewBag.Productos = productosRetry.Select(p => new Microsoft.AspNetCore.Mvc.Rendering.SelectListItem
            {
                Value = p.ProductoId.ToString(),
                Text = $"{p.Nombre} (Stock actual: {p.Stock})"
            }).ToList();
            return View(model);
        }

        private async Task RegistrarAuditoriaAsync(string accion, string modulo, string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                HttpContext.Session.GetInt32("UserId"),
                HttpContext.Session.GetString("UserFullName"),
                HttpContext.Session.GetString("UserEmail"),
                HttpContext.Session.GetString("UserRole"),
                accion,
                modulo,
                descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }

        private async Task TryDeleteImageAsync(string? imageUrl, string operation, int productId)
        {
            try
            {
                await _images.DeleteAsync(imageUrl, HttpContext.RequestAborted);
            }
            catch (Exception exception)
            {
                _logger.LogWarning(exception, "No se pudo limpiar la imagen administrada al {Operation} para el producto {ProductId}.", operation, productId);
            }
        }
    }
}
