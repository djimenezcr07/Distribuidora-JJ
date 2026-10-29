using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    // CU-261 (métricas por lenguaje natural) y CU-263 (ayuda por módulo).
    // Acceso amplio a roles operativos; los datos que ve cada rol se filtran
    // dentro de AssistantService (p. ej. finanzas ocultas a bodega/chofer).
    [SessionAuthorize]
    public class AssistantController : Controller
    {
        private readonly AssistantService _assistant;
        private readonly ILogger<AssistantController> _logger;

        public AssistantController(AssistantService assistant, ILogger<AssistantController> logger)
        {
            _assistant = assistant;
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Index() => View();

        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("assistant")]
        public async Task<IActionResult> Ask(string pregunta, string? contexto)
        {
            pregunta = pregunta?.Trim() ?? string.Empty;

            if (pregunta.Length == 0)
                return Json(new { ok = false, message = "Escribe una pregunta." });

            if (pregunta.Length > 500)
                return Json(new { ok = false, message = "La pregunta no puede superar 500 caracteres." });

            var usuarioId = HttpContext.Session.GetInt32("UserId") ?? 0;
            var usuarioNombre = HttpContext.Session.GetString("UserFullName") ?? "Usuario";
            var rol = HttpContext.Session.GetString("UserRole");

            try
            {
                var r = await _assistant.AskAsync(pregunta, rol, contexto, usuarioId, usuarioNombre);
                return Json(new
                {
                    ok = true,
                    tipo = r.Tipo,
                    intent = r.Intent,
                    interpretado = r.Interpretado,
                    titulo = r.Titulo,
                    respuesta = r.Respuesta,
                    sugerencias = r.Sugerencias
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error en el asistente virtual.");
                return Json(new { ok = false, message = "No fue posible procesar la consulta en este momento." });
            }
        }
    }
}
