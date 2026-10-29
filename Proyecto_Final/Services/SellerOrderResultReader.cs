using System.Data.Common;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

internal static class SellerOrderResultReader
{
    internal static SellerOrderResultViewModel Read(DbDataReader reader)
    {
        foreach (var (name, type) in new[] { ("PedidoId", typeof(int)), ("Estado", typeof(string)),
                     ("FacturaId", typeof(int)), ("NumeroFactura", typeof(string)) })
        {
            var ordinal = Enumerable.Range(0, reader.FieldCount)
                .FirstOrDefault(i => string.Equals(reader.GetName(i), name, StringComparison.OrdinalIgnoreCase), -1);
            if (ordinal < 0 || reader.GetFieldType(ordinal) != type)
                throw new InvalidOperationException("El contrato SQL de pedidos no es compatible.");
        }

        var result = new SellerOrderResultViewModel
        {
            PedidoId = reader.GetInt32(reader.GetOrdinal("PedidoId")),
            Estado = reader.GetString(reader.GetOrdinal("Estado")),
            FacturaId = reader.IsDBNull(reader.GetOrdinal("FacturaId")) ? 0 : reader.GetInt32(reader.GetOrdinal("FacturaId")),
            NumeroFactura = reader.IsDBNull(reader.GetOrdinal("NumeroFactura")) ? string.Empty : reader.GetString(reader.GetOrdinal("NumeroFactura"))
        };
        if (result.PedidoId <= 0
            || (result.EsRetenido && (result.FacturaId != 0 || !string.IsNullOrEmpty(result.NumeroFactura)))
            || (!result.EsRetenido && (!string.Equals(result.Estado, "Facturado", StringComparison.Ordinal)
                || result.FacturaId <= 0 || string.IsNullOrWhiteSpace(result.NumeroFactura))))
            throw new InvalidOperationException("El resultado SQL del pedido no cumple el contrato comercial.");
        return result;
    }
}
