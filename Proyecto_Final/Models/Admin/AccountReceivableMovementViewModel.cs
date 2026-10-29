namespace Proyecto_Final.Models.Admin
{
    public class AccountReceivableSettingsViewModel
    {
        public int MovimientoId { get; set; }

        public string TipoMovimiento { get; set; } = string.Empty;

        public decimal Monto { get; set; }

        public string? Descripcion { get; set; }

        public string? Referencia { get; set; }

        public string? RegistradoPor { get; set; }

        public DateTime FechaMovimiento { get; set; }
    }
}