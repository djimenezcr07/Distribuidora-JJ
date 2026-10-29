using Microsoft.AspNetCore.Mvc;
using Proyecto_FinalAPI.Services;

namespace Proyecto_FinalAPI.Controllers
{
    [ApiController]
    [Route("api/products")]
    [Route("api/productos")]
    public class ProductsController : ControllerBase
    {
        private readonly ProductsApiDbService _productsApiDbService;

        public ProductsController(ProductsApiDbService productsApiDbService)
        {
            _productsApiDbService = productsApiDbService;
        }

        [HttpGet]
        public async Task<IActionResult> GetProducts([FromQuery] string? categoria, [FromQuery] string? buscar)
        {
            try
            {
                var productos = await _productsApiDbService.GetProductsAsync(categoria, buscar);
                return Ok(productos);
            }
            catch
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = "No se pudo cargar el catálogo de productos."
                });
            }
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetProductById(int id)
        {
            if (id <= 0)
            {
                return BadRequest(new
                {
                    message = "El identificador del producto debe ser mayor a cero."
                });
            }

            try
            {
                var producto = await _productsApiDbService.GetProductByIdAsync(id);

                if (producto == null)
                {
                    return NotFound(new
                    {
                        message = "Producto no encontrado."
                    });
                }

                return Ok(producto);
            }
            catch
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = "No se pudo cargar el producto solicitado."
                });
            }
        }

        [HttpGet("categories")]
        public async Task<IActionResult> GetCategories()
        {
            try
            {
                var categorias = await _productsApiDbService.GetCategoriesAsync();
                return Ok(categorias);
            }
            catch
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = "No se pudieron cargar las categorías."
                });
            }
        }

        [HttpGet("featured")]
        public async Task<IActionResult> GetFeatured([FromQuery] int take = 8)
        {
            if (take <= 0)
            {
                return BadRequest(new
                {
                    message = "La cantidad solicitada debe ser mayor a cero."
                });
            }

            try
            {
                var productos = await _productsApiDbService.GetFeaturedProductsAsync(Math.Min(take, 24));
                return Ok(productos);
            }
            catch
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = "No se pudieron cargar los productos destacados."
                });
            }
        }
    }
}
