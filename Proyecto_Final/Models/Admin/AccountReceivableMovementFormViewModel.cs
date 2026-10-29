namespace Proyecto_Final.Models.Admin
{
    public class AccountReceivableMovementFormViewModel
    {
        public int UsuarioId { get; set; }

        public string TipoMovimiento { get; set; } = "Abono";

        public decimal Monto { get; set; }

        public string? Referencia { get; set; }

        public string? Descripcion { get; set; }
    }
}