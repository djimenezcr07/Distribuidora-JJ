namespace Proyecto_Final.Models.Admin;

public sealed class PaySlipListItemViewModel
{
    public long CalculoId { get; set; }
    public string Periodo { get; set; } = string.Empty;
    public string Empleado { get; set; } = string.Empty;
    public decimal TotalBruto { get; set; }
    public decimal TotalDeducciones { get; set; }
    public decimal TotalNeto { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? UltimoEnvio { get; set; }
}

public sealed class PaySlipLineViewModel
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public decimal Monto { get; set; }
}

public sealed class PaySlipViewModel
{
    public long CalculoId { get; set; }
    public int PropietarioUsuarioId { get; set; }
    public string Empleado { get; set; } = string.Empty;
    public string Periodo { get; set; } = string.Empty;
    public decimal SalarioBase { get; set; }
    public decimal HorasOrdinarias { get; set; }
    public decimal HorasExtra { get; set; }
    public decimal Comisiones { get; set; }
    public decimal TotalBruto { get; set; }
    public decimal TotalDeducciones { get; set; }
    public decimal TotalNeto { get; set; }
    public string Estado { get; set; } = string.Empty;
    public DateTime? FechaPagoUtc { get; set; }
    public List<PaySlipLineViewModel> Lineas { get; set; } = [];
}

public sealed record PaySlipDeliveryPreparation(long EnvioId, string Destinatario, string Empleado, bool DebeEnviar);

public sealed class PaySlipSendViewModel
{
    public long CalculoId { get; set; }
    public Guid IdempotencyKey { get; set; }
}
