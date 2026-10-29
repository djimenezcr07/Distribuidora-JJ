using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin
{
    // CU-106 — Liquidación financiera de cobros de ruta.
    public class CashSettlementListItemViewModel
    {
        public int LiquidacionCobrosId { get; set; }
        public int RutaId { get; set; }
        public string RutaCodigo { get; set; } = string.Empty;
        public decimal MontoEsperadoEfectivo { get; set; }
        public decimal MontoEsperadoOtros { get; set; }
        public decimal MontoEfectivoRecibido { get; set; }
        public decimal MontoComprobantes { get; set; }
        public decimal Diferencia { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string LiquidadoPorNombre { get; set; } = string.Empty;
        public DateTime FechaLiquidacion { get; set; }
    }

    // Encabezado que devuelve sp_LiquidacionCobros_Preparar.
    public class CashSettlementPrepareViewModel
    {
        public int RutaId { get; set; }
        public string RutaCodigo { get; set; } = string.Empty;
        public string EstadoRuta { get; set; } = string.Empty;
        public bool Liquidada { get; set; }
        public bool YaLiquidadaFinanciera { get; set; }
        public decimal EsperadoEfectivo { get; set; }
        public decimal EsperadoOtros { get; set; }
        public List<CashSettlementOrderLine> Pedidos { get; set; } = new();
    }

    public class CashSettlementOrderLine
    {
        public int PedidoId { get; set; }
        public decimal Total { get; set; }
        public string MetodoPago { get; set; } = string.Empty;
        public string EstadoPago { get; set; } = string.Empty;
        public string Cliente { get; set; } = string.Empty;
    }

    // Formulario de registro (CU-106).
    public class CashSettlementFormViewModel
    {
        public int RutaId { get; set; }
        public string RutaCodigo { get; set; } = string.Empty;
        public decimal EsperadoEfectivo { get; set; }
        public decimal EsperadoOtros { get; set; }

        [Display(Name = "Efectivo recibido")]
        [Range(0, 99999999, ErrorMessage = "El efectivo recibido no puede ser negativo.")]
        public decimal MontoEfectivoRecibido { get; set; }

        [Display(Name = "Total en comprobantes")]
        [Range(0, 99999999, ErrorMessage = "El monto de comprobantes no puede ser negativo.")]
        public decimal MontoComprobantes { get; set; }

        [Display(Name = "Observaciones")]
        [StringLength(400)]
        public string? Observaciones { get; set; }

        // Comprobantes capturados (opcional).
        public List<CashSettlementVoucher> Comprobantes { get; set; } = new();
    }

    public class CashSettlementVoucher
    {
        public string? Tipo { get; set; }
        public string? Referencia { get; set; }
        public decimal Monto { get; set; }
    }
}
