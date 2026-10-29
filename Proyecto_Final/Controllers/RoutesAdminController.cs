using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;
using Microsoft.Extensions.Options;

namespace Proyecto_Final.Controllers
{
    // CU-081 (rutas de entrega) + CU-083 E3 (consulta de evidencias por ruta).
    [AdminAuthorize("Rutas", "RUTAS_GESTIONAR", allowAdministratorBypass: false)]
    public class RoutesAdminController : Controller
    {
        private readonly LogisticsDbService _logistics;
        private readonly AdminDbService _adminDbService;
        private readonly EmailService _emailService;
        private readonly ILogger<RoutesAdminController> _logger;
        private readonly CompanyOptions _company;

        public RoutesAdminController(
            LogisticsDbService logistics,
            AdminDbService adminDbService,
            EmailService emailService,
            ILogger<RoutesAdminController> logger,
            IOptions<CompanyOptions> company)
        {
            _logistics = logistics;
            _adminDbService = adminDbService;
            _emailService = emailService;
            _logger = logger;
            _company = company.Value;
        }

        [HttpGet]
        public async Task<IActionResult> Index(string? estado, string? buscar)
        {
            ViewBag.Estado = estado;
            ViewBag.Buscar = buscar;
            var rutas = await _logistics.GetRoutesAsync(estado, buscar);
            return View(rutas);
        }

        [HttpGet]
        public async Task<IActionResult> Create()
        {
            var vm = await BuildCreateViewModelAsync();
            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(RouteCreateViewModel model)
        {
            model.PedidosSeleccionados ??= new List<int>();

            if (model.PedidosSeleccionados.Count == 0)
            {
                ModelState.AddModelError(nameof(model.PedidosSeleccionados), "Debe seleccionar al menos un pedido para la ruta.");
            }

            if (!ModelState.IsValid)
            {
                await PopulateCreateOptionsAsync(model);
                return View(model);
            }

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                var (rutaId, codigo) = await _logistics.CreateRouteAsync(
                    model.Zona, model.ChoferUsuarioId, model.VehiculoId, model.Observaciones,
                    model.PedidosSeleccionados, usuarioId, usuarioNombre);

                TempData["SuccessMessage"] = $"Ruta {codigo} creada correctamente.";
                return RedirectToAction(nameof(Detail), new { id = rutaId });
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                ModelState.AddModelError(string.Empty, "No fue posible completar la operación solicitada.");
                await PopulateCreateOptionsAsync(model);
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al crear ruta de entrega.");
                ModelState.AddModelError(string.Empty, "No fue posible crear la ruta en este momento.");
                await PopulateCreateOptionsAsync(model);
                return View(model);
            }
        }

        [HttpGet]
        public async Task<IActionResult> Detail(int id)
        {
            var cabecera = await _logistics.GetRouteHeaderAsync(id);
            if (cabecera == null)
            {
                TempData["ErrorMessage"] = "No se encontró la ruta solicitada.";
                return RedirectToAction(nameof(Index));
            }

            var vm = new RouteDetailViewModel
            {
                Cabecera = cabecera,
                Pedidos = await _logistics.GetRouteOrdersAsync(id)
            };

            // Solo se pueden agregar pedidos mientras la ruta está en planificación.
            if (cabecera.Estado == "Planificada")
            {
                vm.PedidosDisponibles = await _logistics.GetAssignableOrdersAsync(null);
            }

            return View(vm);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AddOrder(int rutaId, int pedidoId)
        {
            try
            {
                await _logistics.AddOrderToRouteAsync(rutaId, pedidoId);
                TempData["SuccessMessage"] = "Pedido agregado a la ruta.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al agregar pedido a ruta.");
                TempData["ErrorMessage"] = "No fue posible agregar el pedido a la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RemoveOrder(int rutaId, int pedidoId)
        {
            try
            {
                await _logistics.RemoveOrderFromRouteAsync(rutaId, pedidoId);
                TempData["SuccessMessage"] = "Pedido quitado de la ruta.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al quitar pedido de ruta.");
                TempData["ErrorMessage"] = "No fue posible quitar el pedido de la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Dispatch(int rutaId)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                var destinatarios = await _logistics.DispatchRouteAsync(rutaId, usuarioId, usuarioNombre);

                // CU-082 E3: notificación al cliente (mejor esfuerzo, no bloquea el despacho).
                foreach (var (pedidoId, nombre, correo) in destinatarios)
                {
                    NotificarClienteSeguro(correo, nombre, pedidoId, "En ruta");
                }

                TempData["SuccessMessage"] = "Ruta despachada. Los pedidos están En ruta.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al despachar ruta.");
                TempData["ErrorMessage"] = "No fue posible despachar la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Cancel(int rutaId, string? motivo)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                await _logistics.CancelRouteAsync(rutaId, motivo, usuarioId, usuarioNombre);
                TempData["SuccessMessage"] = "Ruta cancelada correctamente.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al cancelar ruta.");
                TempData["ErrorMessage"] = "No fue posible cancelar la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        // CU-251 E1 — Secuenciar automáticamente los puntos de entrega.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Sequence(int rutaId)
        {
            try
            {
                var (puntos, sinCoord) = await _logistics.SequenceRouteAsync(rutaId);
                if (puntos == 0)
                {
                    TempData["ErrorMessage"] = "No hay pedidos pendientes para secuenciar en esta ruta.";
                }
                else
                {
                    if (sinCoord > 0)
                    {
                        TempData["ErrorMessage"] = $"{sinCoord} de {puntos} punto(s) no tienen coordenada y quedaron al final. Ubícalos en el mapa para que aparezcan en la app del chofer.";
                    }
                    else
                    {
                        TempData["SuccessMessage"] = $"Ruta secuenciada automáticamente ({puntos} punto(s)). Puede reordenar manualmente antes de despachar.";
                    }
                }
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al secuenciar ruta.");
                TempData["ErrorMessage"] = "No fue posible secuenciar la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        // CU-251 E3 — Guardar el orden manual y las coordenadas.
        // Las coordenadas se reciben como texto y se parsean con InvariantCulture:
        // los <input type="number"> siempre envían punto decimal, independientemente
        // de la cultura regional del servidor.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SaveSequence(int rutaId, List<int> rutaPedidoId, List<int> secuencia, List<string?> lat, List<string?> lng)
        {
            try
            {
                var inv = System.Globalization.CultureInfo.InvariantCulture;
                const System.Globalization.NumberStyles styles = System.Globalization.NumberStyles.Float | System.Globalization.NumberStyles.AllowLeadingSign;

                var items = new List<object>();
                for (int i = 0; i < rutaPedidoId.Count; i++)
                {
                    decimal? latVal = i < lat.Count && decimal.TryParse(lat[i], styles, inv, out var la) ? la : (decimal?)null;
                    decimal? lngVal = i < lng.Count && decimal.TryParse(lng[i], styles, inv, out var lo) ? lo : (decimal?)null;
                    items.Add(new
                    {
                        rutaPedidoId = rutaPedidoId[i],
                        secuencia = i < secuencia.Count ? secuencia[i] : i + 1,
                        lat = latVal,
                        lng = lngVal
                    });
                }
                var json = System.Text.Json.JsonSerializer.Serialize(items);
                await _logistics.SaveSequenceAsync(rutaId, json);
                TempData["SuccessMessage"] = "Orden de entregas actualizado.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al guardar secuencia de ruta.");
                TempData["ErrorMessage"] = "No fue posible guardar el orden de la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        // CU-253 — Recalcular la ruta en tiempo real ante un imprevisto.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Recalculate(int rutaId, int? excluirRutaPedidoId, string? motivoFallo)
        {
            try
            {
                var puntos = await _logistics.RecalculateRouteAsync(rutaId, excluirRutaPedidoId, motivoFallo);
                if (puntos == 0)
                {
                    TempData["ErrorMessage"] = "No es posible recalcular: no quedan puntos por recalcular. Contacte al chofer manualmente.";
                }
                else
                {
                    TempData["SuccessMessage"] = $"Ruta recalculada. {puntos} punto(s) reordenados. El chofer verá la ruta actualizada.";
                }
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al recalcular ruta.");
                TempData["ErrorMessage"] = "No fue posible recalcular la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        // CU-105 — Liquidar la ruta al final del día (reingresa inventario no entregado).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Liquidate(int rutaId)
        {
            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Administrador";

            try
            {
                var (pedidos, unidades) = await _logistics.LiquidateRouteAsync(rutaId, usuarioId, usuarioNombre);
                TempData["SuccessMessage"] = pedidos > 0
                    ? $"Ruta liquidada. Se reingresaron {unidades} unidad(es) de {pedidos} pedido(s) no entregado(s)."
                    : "Ruta liquidada. No había mercadería pendiente por reingresar.";
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                _logger.LogWarning(ex, "La base de datos rechazó una operación de negocio.");
                TempData["ErrorMessage"] = "No fue posible completar la operación solicitada.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al liquidar ruta.");
                TempData["ErrorMessage"] = "No fue posible liquidar la ruta.";
            }
            return RedirectToAction(nameof(Detail), new { id = rutaId });
        }

        // CU-083 E3 — historial de evidencias por ruta.
        [HttpGet]
        [AdminAuthorize("Entregas", "ENTREGAS_EVIDENCIA_VER", allowAdministratorBypass: false)]
        public async Task<IActionResult> Evidences(int id)
        {
            var cabecera = await _logistics.GetRouteHeaderAsync(id);
            if (cabecera == null)
            {
                TempData["ErrorMessage"] = "No se encontró la ruta solicitada.";
                return RedirectToAction(nameof(Index));
            }

            var vm = await _logistics.GetRouteEvidencesAsync(id, cabecera);
            return View(vm);
        }

        // ── Helpers ─────────────────────────────────────────
        private async Task<RouteCreateViewModel> BuildCreateViewModelAsync()
        {
            var vm = new RouteCreateViewModel();
            await PopulateCreateOptionsAsync(vm);
            return vm;
        }

        private async Task PopulateCreateOptionsAsync(RouteCreateViewModel vm)
        {
            vm.PedidosDisponibles = await _logistics.GetAssignableOrdersAsync(null);
            vm.Choferes = await _logistics.GetAvailableDriversAsync();
            vm.Vehiculos = await _logistics.GetAvailableVehiclesAsync();
        }

        private void NotificarClienteSeguro(string correo, string nombre, int pedidoId, string estado)
        {
            if (string.IsNullOrWhiteSpace(correo)) return;

            try
            {
                var asunto = $"Actualización de su pedido #{pedidoId} - {estado}";
                var cuerpo =
                    $"<p>Hola {System.Net.WebUtility.HtmlEncode(nombre)},</p>" +
                    $"<p>Le informamos que su pedido <strong>#{pedidoId}</strong> ahora está en estado " +
                    $"<strong>{System.Net.WebUtility.HtmlEncode(estado)}</strong>.</p>" +
                    $"<p>Gracias por su preferencia.<br/>{System.Net.WebUtility.HtmlEncode(_company.BrandName)}</p>";
                _emailService.SendEmail(correo, asunto, cuerpo);
            }
            catch (Exception ex)
            {
                // Mejor esfuerzo: un fallo de correo no debe afectar la operación.
                _logger.LogWarning(ex, "No se pudo enviar la notificación de entrega al cliente del pedido #{PedidoId}.", pedidoId);
            }
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
