using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // ── Listado de rutas ────────────────────────────────────
    public class RouteListItemViewModel
    {
        public int RutaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Zona { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string Chofer { get; set; } = string.Empty;
        public string VehiculoPlaca { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; }
        public DateTime? FechaDespacho { get; set; }
        public int TotalPedidos { get; set; }
        public int Entregados { get; set; }
        public int Fallidos { get; set; }
        public int Pendientes { get; set; }
    }

    // ── Cabecera de la ruta ─────────────────────────────────
    public class RouteHeaderViewModel
    {
        public int RutaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Zona { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public int ChoferUsuarioId { get; set; }
        public string Chofer { get; set; } = string.Empty;
        public int VehiculoId { get; set; }
        public string VehiculoPlaca { get; set; } = string.Empty;
        public string VehiculoDescripcion { get; set; } = string.Empty;
        public string Observaciones { get; set; } = string.Empty;
        public string CreadaPorNombre { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; }
        public DateTime? FechaDespacho { get; set; }
        public DateTime? FechaCierre { get; set; }
    }

    // ── Pedido dentro de una ruta ───────────────────────────
    public class RouteOrderItemViewModel
    {
        public int RutaPedidoId { get; set; }
        public int PedidoId { get; set; }
        public int Secuencia { get; set; }
        public string EstadoEntrega { get; set; } = string.Empty;
        public string MotivoFallo { get; set; } = string.Empty;
        public DateTime? FechaEntrega { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public string ClienteCorreo { get; set; } = string.Empty;
        public string DireccionEntrega { get; set; } = string.Empty;
        public decimal Total { get; set; }
        public string EstadoPedido { get; set; } = string.Empty;
        public int TotalEvidencias { get; set; }
        public decimal? Latitud { get; set; }
        public decimal? Longitud { get; set; }
    }

    // ── Pedido asignable a una ruta ─────────────────────────
    public class AssignableOrderViewModel
    {
        public int PedidoId { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public DateTime FechaPedido { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string TipoEntrega { get; set; } = string.Empty;
        public string DireccionEntrega { get; set; } = string.Empty;
        public decimal Total { get; set; }
        public int TotalLineas { get; set; }
    }

    // ── Opciones de recursos para asignar ───────────────────
    public class DriverOptionViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string Telefono { get; set; } = string.Empty;
        public int RutasAbiertas { get; set; }
    }

    public class VehicleOptionViewModel
    {
        public int VehiculoId { get; set; }
        public string Placa { get; set; } = string.Empty;
        public string Descripcion { get; set; } = string.Empty;
        public int Capacidad { get; set; }
        public int RutasAbiertas { get; set; }
    }

    // ── Formulario de creación de ruta ──────────────────────
    public class RouteCreateViewModel
    {
        [Required(ErrorMessage = "La zona es obligatoria.")]
        [StringLength(120, ErrorMessage = "La zona no puede exceder 120 caracteres.")]
        public string Zona { get; set; } = string.Empty;

        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un chofer disponible.")]
        public int ChoferUsuarioId { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "Debe seleccionar un vehículo disponible.")]
        public int VehiculoId { get; set; }

        [StringLength(300, ErrorMessage = "Las observaciones no pueden exceder 300 caracteres.")]
        public string? Observaciones { get; set; }

        public List<int> PedidosSeleccionados { get; set; } = new();

        // Datos para poblar el formulario
        public List<AssignableOrderViewModel> PedidosDisponibles { get; set; } = new();
        public List<DriverOptionViewModel> Choferes { get; set; } = new();
        public List<VehicleOptionViewModel> Vehiculos { get; set; } = new();

        public bool HayRecursos => Choferes.Count > 0 && Vehiculos.Count > 0;
    }

    // ── Detalle de ruta ─────────────────────────────────────
    public class RouteDetailViewModel
    {
        public RouteHeaderViewModel Cabecera { get; set; } = new();
        public List<RouteOrderItemViewModel> Pedidos { get; set; } = new();
        public List<AssignableOrderViewModel> PedidosDisponibles { get; set; } = new();
    }

    public sealed class DeliveryBoardRowViewModel
    {
        public int RutaId { get; init; }
        public string Codigo { get; init; } = string.Empty;
        public string Zona { get; init; } = string.Empty;
        public string Estado { get; init; } = string.Empty;
        public string Chofer { get; init; } = string.Empty;
        public string VehiculoPlaca { get; init; } = string.Empty;
        public int TotalPedidos { get; init; }
        public int Entregados { get; init; }
        public int Fallidos { get; init; }
        public int Pendientes { get; init; }
        public DateTime? FechaDespacho { get; init; }
    }

    public sealed class DeliveryBoardViewModel
    {
        public DateTimeOffset GeneradoUtc { get; init; }
        public int RutasActivas { get; init; }
        public int EntregasPendientes { get; init; }
        public int EntregasCompletadas { get; init; }
        public int EntregasFallidas { get; init; }
        public IReadOnlyList<DeliveryBoardRowViewModel> Rutas { get; init; } = [];
    }
}
