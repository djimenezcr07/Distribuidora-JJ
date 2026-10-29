namespace Proyecto_Final.Models.Admin
{
    // ── Portal del chofer: listado de rutas ─────────────────
    public class DriverRouteItemViewModel
    {
        public int RutaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Zona { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string VehiculoPlaca { get; set; } = string.Empty;
        public DateTime? FechaDespacho { get; set; }
        public int TotalPedidos { get; set; }
        public int Pendientes { get; set; }
        public int Entregados { get; set; }
    }

    // ── Portal del chofer: una entrega ──────────────────────
    public class DriverDeliveryItemViewModel
    {
        public int RutaPedidoId { get; set; }
        public int PedidoId { get; set; }
        public int Secuencia { get; set; }
        public string EstadoEntrega { get; set; } = string.Empty;
        public string MotivoFallo { get; set; } = string.Empty;
        public DateTime? FechaEntrega { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public string Telefono { get; set; } = string.Empty;
        public string DireccionEntrega { get; set; } = string.Empty;
        public decimal Total { get; set; }
        public int TotalEvidencias { get; set; }
        public decimal? Latitud { get; set; }
        public decimal? Longitud { get; set; }
    }

    public class DriverRouteViewModel
    {
        public int RutaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Zona { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string VehiculoPlaca { get; set; } = string.Empty;
        public DateTime? FechaDespacho { get; set; }
        public List<DriverDeliveryItemViewModel> Entregas { get; set; } = new();
    }

    // ── Resultado de actualizar estado (también respuesta JSON) ──
    public class UpdateDeliveryStatusResultViewModel
    {
        public int RutaPedidoId { get; set; }
        public string EstadoEntrega { get; set; } = string.Empty;
        public int PedidoId { get; set; }
        public string ClienteCorreo { get; set; } = string.Empty;
        public string ClienteNombre { get; set; } = string.Empty;
        public bool Notificar { get; set; }
        public bool RutaCompletada { get; set; }
        public bool Duplicado { get; set; }
    }

    // ── Evidencias (CU-083) ─────────────────────────────────
    public class EvidenceItemViewModel
    {
        public bool HasPrivateFile => !string.IsNullOrWhiteSpace(StorageKey);
        public int EvidenciaId { get; set; }
        public int PedidoId { get; set; }
        public int? RutaId { get; set; }
        public string TipoEvidencia { get; set; } = string.Empty;
        public string StorageKey { get; set; } = string.Empty;
        public string MimeType { get; set; } = string.Empty;
        public string Observaciones { get; set; } = string.Empty;
        public string RegistradoPorNombre { get; set; } = string.Empty;
        public DateTime FechaRegistro { get; set; }
    }

    public class RouteEvidenceSummaryViewModel
    {
        public int PedidoId { get; set; }
        public string EstadoEntrega { get; set; } = string.Empty;
        public string Cliente { get; set; } = string.Empty;
        public int TotalEvidencias { get; set; }
        public bool SinEvidencia { get; set; }
    }

    public class RouteEvidencesViewModel
    {
        public RouteHeaderViewModel Cabecera { get; set; } = new();
        public List<RouteEvidenceSummaryViewModel> Resumen { get; set; } = new();
        public List<EvidenceItemViewModel> Evidencias { get; set; } = new();
    }

    public sealed class AuthorizedEvidenceViewModel
    {
        public string? Sha256 { get; set; }
        public long? LengthBytes { get; set; }
        public int EvidenciaId { get; set; }
        public int PedidoId { get; set; }
        public string StorageKey { get; set; } = string.Empty;
        public string MimeType { get; set; } = string.Empty;
        public string TipoEvidencia { get; set; } = string.Empty;
    }
}
