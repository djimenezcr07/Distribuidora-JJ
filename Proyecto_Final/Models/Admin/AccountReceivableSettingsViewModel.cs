namespace Proyecto_Final.Models.Admin
{
    public class AccountReceivableMovementViewModel
    {
        public int UsuarioId { get; set; }

        public decimal LimiteCredito { get; set; }

        public bool CreditoActivo { get; set; }

        public bool CreditoBloqueado { get; set; }

        public string? MotivoBloqueo { get; set; }
    }
}