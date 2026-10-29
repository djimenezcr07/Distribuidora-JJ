using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-222 — ViewModels de gastos operativos y cuentas presupuestarias.

    public class CuentaOptionViewModel
    {
        public int CuentaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public decimal PresupuestoMensual { get; set; }
    }

    public class CuentaViewModel
    {
        public int CuentaId { get; set; }

        [Required(ErrorMessage = "El código es obligatorio.")]
        [StringLength(20, ErrorMessage = "El código no puede superar los 20 caracteres.")]
        public string Codigo { get; set; } = string.Empty;

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(120, ErrorMessage = "El nombre no puede superar los 120 caracteres.")]
        public string Nombre { get; set; } = string.Empty;

        [StringLength(300, ErrorMessage = "La descripción no puede superar los 300 caracteres.")]
        public string? Descripcion { get; set; }

        [Range(0, 999999999, ErrorMessage = "El presupuesto no puede ser negativo.")]
        [Display(Name = "Presupuesto mensual (₡)")]
        public decimal PresupuestoMensual { get; set; }

        public bool Activo { get; set; } = true;
    }

    public class GastoListItemViewModel
    {
        public int GastoId { get; set; }
        public DateTime Fecha { get; set; }
        public decimal Monto { get; set; }
        public string Concepto { get; set; } = string.Empty;
        public string Proveedor { get; set; } = string.Empty;
        public string Comprobante { get; set; } = string.Empty;
        public string RegistradoPorNombre { get; set; } = string.Empty;
        public int CuentaId { get; set; }
        public string CuentaCodigo { get; set; } = string.Empty;
        public string CuentaNombre { get; set; } = string.Empty;
    }

    public class GastoFormViewModel
    {
        [Required(ErrorMessage = "Seleccione la cuenta presupuestaria.")]
        [Display(Name = "Cuenta presupuestaria")]
        public int CuentaId { get; set; }

        [DataType(DataType.Date)]
        public DateTime Fecha { get; set; } = DateTime.Today;

        [Range(0.01, 999999999, ErrorMessage = "El monto debe ser mayor que cero.")]
        [Display(Name = "Monto (₡)")]
        public decimal Monto { get; set; }

        [Required(ErrorMessage = "El concepto es obligatorio.")]
        [StringLength(200, ErrorMessage = "El concepto no puede superar los 200 caracteres.")]
        public string Concepto { get; set; } = string.Empty;

        [StringLength(150)]
        public string? Proveedor { get; set; }

        [StringLength(60)]
        [Display(Name = "N.º de comprobante")]
        public string? Comprobante { get; set; }
    }

    public class PresupuestoResumenViewModel
    {
        public int CuentaId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public decimal PresupuestoMensual { get; set; }
        public decimal Gastado { get; set; }
        public decimal Disponible { get; set; }
        public decimal? PorcentajeEjecucion { get; set; }
    }

    // Pantalla principal de gastos (CU-222): filtro de período + resumen presupuestario + registro + listado.
    public class ExpensesIndexViewModel
    {
        public int Anio { get; set; } = DateTime.Now.Year;
        public int Mes { get; set; } = DateTime.Now.Month;
        public int? CuentaId { get; set; }
        public List<GastoListItemViewModel> Gastos { get; set; } = new();
        public List<PresupuestoResumenViewModel> Resumen { get; set; } = new();
        public List<CuentaOptionViewModel> Cuentas { get; set; } = new();
        public GastoFormViewModel Nuevo { get; set; } = new();

        public decimal TotalPresupuesto => Resumen.Sum(r => r.PresupuestoMensual);
        public decimal TotalGastado => Resumen.Sum(r => r.Gastado);
        public decimal TotalDisponible => TotalPresupuesto - TotalGastado;
    }

    public class AccountsViewModel
    {
        public List<CuentaViewModel> Cuentas { get; set; } = new();
        public CuentaViewModel Nueva { get; set; } = new();
    }
}
