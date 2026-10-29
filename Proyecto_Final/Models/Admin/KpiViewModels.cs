using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-211/213 — ViewModels de metas mensuales por vendedor y reporte de KPIs.

    public class VendedorOptionViewModel
    {
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
    }

    public class MetaListItemViewModel
    {
        public int MetaId { get; set; }
        public int VendedorUsuarioId { get; set; }
        public string VendedorNombre { get; set; } = string.Empty;
        public int Anio { get; set; }
        public int Mes { get; set; }
        public decimal MontoMeta { get; set; }
        public decimal VentasReales { get; set; }
        public decimal PorcentajeCumplimiento { get; set; }
        public string Observaciones { get; set; } = string.Empty;
    }

    public class MetaFormViewModel
    {
        [Required(ErrorMessage = "Seleccione el vendedor.")]
        [Display(Name = "Vendedor")]
        public int VendedorUsuarioId { get; set; }

        [Range(2000, 2100, ErrorMessage = "Año inválido.")]
        public int Anio { get; set; } = DateTime.Now.Year;

        [Range(1, 12, ErrorMessage = "Mes inválido.")]
        public int Mes { get; set; } = DateTime.Now.Month;

        [Range(0.01, 999999999, ErrorMessage = "El monto de la meta debe ser mayor que cero.")]
        [Display(Name = "Meta de ingresos (₡)")]
        public decimal MontoMeta { get; set; }

        [StringLength(300, ErrorMessage = "Las observaciones no pueden superar los 300 caracteres.")]
        public string? Observaciones { get; set; }
    }

    // Modelo de la pantalla de gestión de metas (CU-211): filtro de período + tabla + formulario.
    public class MetasIndexViewModel
    {
        public int Anio { get; set; } = DateTime.Now.Year;
        public int Mes { get; set; } = DateTime.Now.Month;
        public List<MetaListItemViewModel> Metas { get; set; } = new();
        public List<VendedorOptionViewModel> Vendedores { get; set; } = new();
        public MetaFormViewModel Nueva { get; set; } = new();
    }

    public class KpiReportItemViewModel
    {
        public int VendedorUsuarioId { get; set; }
        public string VendedorNombre { get; set; } = string.Empty;
        public decimal MontoMeta { get; set; }
        public decimal VentasReales { get; set; }
        public int Facturas { get; set; }
        public decimal? PorcentajeCumplimiento { get; set; }
        public string Clasificacion { get; set; } = "SinMeta";
    }

    // CU-213 — Reporte de cumplimiento global de KPIs.
    public class KpiReportViewModel
    {
        public int Anio { get; set; } = DateTime.Now.Year;
        public int Mes { get; set; } = DateTime.Now.Month;
        public List<KpiReportItemViewModel> Items { get; set; } = new();
        public decimal MetaGlobal { get; set; }
        public decimal VentaGlobal { get; set; }
        public int VendedoresConMeta { get; set; }

        public decimal PorcentajeGlobal => MetaGlobal > 0 ? Math.Round(VentaGlobal / MetaGlobal * 100, 2) : 0m;
        public bool HayDatos => Items.Any();
    }

    // CU-212 — Panel de progreso individual del vendedor sobre su meta del mes.
    public class MetaProgresoViewModel
    {
        public int Anio { get; set; } = DateTime.Now.Year;
        public int Mes { get; set; } = DateTime.Now.Month;
        public decimal MontoMeta { get; set; }
        public decimal VentasReales { get; set; }
        public decimal PorcentajeCumplimiento { get; set; }
        public decimal MontoPendiente { get; set; }
        public bool SinMetaDefinida { get; set; }

        // Evita que la barra de progreso se pase de 100% visualmente.
        public decimal PorcentajeBarra => Math.Min(PorcentajeCumplimiento, 100m);
    }
}
