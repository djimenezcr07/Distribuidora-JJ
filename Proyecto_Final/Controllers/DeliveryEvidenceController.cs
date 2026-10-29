using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers
{
    [SessionAuthorize]
    public sealed class DeliveryEvidenceController : Controller
    {
        private readonly LogisticsDbService _logistics;
        private readonly IEvidenceStorageService _storage;
        private readonly ILogger<DeliveryEvidenceController> _logger;

        public DeliveryEvidenceController(
            LogisticsDbService logistics,
            IEvidenceStorageService storage,
            ILogger<DeliveryEvidenceController> logger)
        {
            _logistics = logistics;
            _storage = storage;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> View(int id, CancellationToken cancellationToken)
        {
            var userId = HttpContext.Session.GetInt32("UserId") ?? 0;
            if (id <= 0 || userId <= 0) return NotFound();

            try
            {
                var evidence = await _logistics.GetAuthorizedEvidenceAsync(id, userId);
                if (evidence is null) return NotFound();

                var stream = await _storage.OpenReadAsync(evidence.StorageKey, cancellationToken);
                if (stream is null)
                {
                    _logger.LogWarning("No se encontró el archivo de la evidencia autorizada {EvidenceId}.", id);
                    return NotFound();
                }
                if (evidence.Sha256 is not null && (!evidence.LengthBytes.HasValue
                    || !await EvidenceIntegrity.VerifyAsync(stream, evidence.Sha256, evidence.LengthBytes.Value, cancellationToken)))
                {
                    await stream.DisposeAsync();
                    _logger.LogWarning("Integridad no acreditada para evidencia {EvidenceId}.", id);
                    return NotFound();
                }

                Response.Headers.CacheControl = "private, no-store, max-age=0";
                Response.Headers.Pragma = "no-cache";
                Response.Headers["X-Content-Type-Options"] = "nosniff";
                return File(stream, evidence.MimeType, enableRangeProcessing: false);
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Error al servir la evidencia {EvidenceId} al usuario {UserId}.", id, userId);
                return NotFound();
            }
        }
    }
}
