using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-141 (registrar devoluciones) y CU-142 (cuarentena de productos).
    [AdminAuthorize("Inventario", "DEVOLUCIONES_GESTIONAR")]
    public class ReturnsController : Controller
    {
        private readonly WarehouseDbService _warehouse;
        private readonly AdminDbService _adminDbService;
        private readonly ILogger<ReturnsController> _logger;

        public ReturnsController(WarehouseDbService warehouse, AdminDbService adminDbService, ILogger<ReturnsController> logger)
        {
            _warehouse = warehouse;
            _adminDbService = adminDbService;
            _logger = logger;
        }

        // CU-141 — Listado + formulario de registro de devoluciones.
        [HttpGet]
        public async Task<IActionResult> Index(string? estado, string? buscar)
        {
            await PopulateProductsAsync();
            var vm = new ReturnsIndexViewModel
            {
                Estado = estado,
                Buscar = buscar,
                Devoluciones = await _warehouse.GetReturnsAsync(estado, buscar)
            };
            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(ReturnFormViewModel nueva)
        {
            if (!ModelState.IsValid)
            {
                await PopulateProductsAsync();
                var vm = new ReturnsIndexViewModel
                {
                    Nueva = nueva,
                    Devoluciones = await _warehouse.GetReturnsAsync(null, null)
                };
                return View(nameof(Index), vm);
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                await _warehouse.CreateReturnAsync(nueva, usuarioId, usuarioNombre);
                await RegistrarAuditoriaAsync("Registrar devolución", "Inventario",
                    $"Devolución registrada: {nueva.Cantidad} unidad(es) del producto #{nueva.ProductoId}. En cuarentena.");
                TempData["SuccessMessage"] = "Devolución registrada. El producto quedó en cuarentena.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al registrar devolución.");
                TempData["ErrorMessage"] = "No fue posible registrar la devolución.";
            }
            return RedirectToAction(nameof(Index));
        }

        // CU-142 — Bandeja de cuarentena.
        [HttpGet]
        [AdminAuthorize("Inventario", "CUARENTENA_GESTIONAR")]
        public async Task<IActionResult> Quarantine(string? buscar)
        {
            ViewBag.Buscar = buscar;
            var enCuarentena = await _warehouse.GetReturnsAsync("EnCuarentena", buscar);
            return View(enCuarentena);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "CUARENTENA_GESTIONAR")]
        public async Task<IActionResult> Release(int devolucionId, string? observacion)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                await _warehouse.ReleaseFromQuarantineAsync(devolucionId, usuarioId, usuarioNombre, observacion);
                await RegistrarAuditoriaAsync("Liberar cuarentena", "Inventario",
                    $"Devolución #{devolucionId} liberada y reintegrada al inventario.");
                TempData["SuccessMessage"] = "Producto liberado y reintegrado al inventario.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al liberar de cuarentena.");
                TempData["ErrorMessage"] = "No fue posible liberar el producto.";
            }
            return RedirectToAction(nameof(Quarantine));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [AdminAuthorize("Inventario", "CUARENTENA_GESTIONAR")]
        public async Task<IActionResult> Discard(int devolucionId, string? observacion)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";
            try
            {
                await _warehouse.DiscardFromQuarantineAsync(devolucionId, usuarioId, usuarioNombre, observacion);
                await RegistrarAuditoriaAsync("Descartar cuarentena", "Inventario",
                    $"Devolución #{devolucionId} descartada (no reingresa al inventario).");
                TempData["SuccessMessage"] = "Producto descartado. No se reintegró al inventario.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al descartar de cuarentena.");
                TempData["ErrorMessage"] = "No fue posible descartar el producto.";
            }
            return RedirectToAction(nameof(Quarantine));
        }

        private async Task PopulateProductsAsync()
        {
            var productos = await _adminDbService.GetActiveProductsForSelectAsync();
            ViewBag.Productos = productos.Select(p => new SelectListItem
            {
                Value = p.ProductoId.ToString(),
                Text = p.Nombre
            }).ToList();
        }

        private async Task RegistrarAuditoriaAsync(string accion, string modulo, string descripcion)
        {
            await _adminDbService.CreateAuditLogAsync(
                HttpContext.Session.GetInt32("UserId"),
                HttpContext.Session.GetString("UserFullName"),
                HttpContext.Session.GetString("UserEmail"),
                HttpContext.Session.GetString("UserRole"),
                accion, modulo, descripcion,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                Request.Headers.UserAgent.ToString());
        }
    }
}
