namespace Proyecto_Final.Models.Admin
{
    public class FinancialReportViewModel
    {
        public decimal TotalIngresos { get; set; }

        public decimal TotalEgresos { get; set; }

        public decimal Balance => TotalIngresos - TotalEgresos;

        public DateTime? FechaInicio { get; set; }

        public DateTime? FechaFin { get; set; }

        public List<FinancialMovementViewModel> Movimientos { get; set; } = new();
    }

    public class FinancialMovementViewModel
    {
        public int MovimientoId { get; set; }

        public DateTime Fecha { get; set; }

        public string Tipo { get; set; } = string.Empty;

        public string Descripcion { get; set; } = string.Empty;

        public decimal Monto { get; set; }

        public string Referencia { get; set; } = string.Empty;
    }
}