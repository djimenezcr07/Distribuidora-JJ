using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services
{
    // CU-173 — Evalúa y aplica automáticamente las promociones vigentes al carrito.
    // Lógica pura (sin BD) para poder usarse tanto en la vista del carrito como en el checkout.
    public static class PromotionEngine
    {
        public sealed class Result
        {
            public List<CartItemViewModel> Gifts { get; } = new();
            public List<AppliedPromotion> Applied { get; } = new();
        }

        // Muta 'items' (fija MontoDescuento/PromocionNombre por línea) y devuelve regalías + registros aplicados.
        // Regla acordada: el descuento porcentual aplica SOLO a la línea del producto estratégico.
        public static Result Apply(
            List<CartItemViewModel> items,
            IEnumerable<ActivePromotionViewModel> promociones,
            string segmento = "Minorista",
            DateTime? evaluationDate = null)
        {
            var result = new Result();
            if (items == null || items.Count == 0) return result;

            // Un solo beneficio por producto (mayor prioridad primero).
            var yaPromocionados = new HashSet<int>();

            var date = (evaluationDate ?? DateTime.UtcNow).Date;
            foreach (var promo in promociones
                         .Where(p => p.FechaInicio.Date <= date && p.FechaFin.Date >= date)
                         .Where(p => string.Equals(p.SegmentoCliente, "Todos", StringComparison.OrdinalIgnoreCase) ||
                                     string.Equals(p.SegmentoCliente, segmento, StringComparison.OrdinalIgnoreCase))
                         .OrderByDescending(p => p.Prioridad)
                         .ThenBy(p => p.PromocionId))
            {
                var linea = items.FirstOrDefault(i => i.ProductoId == promo.ProductoId && !i.EsRegalo);
                if (linea is null) continue;
                if (linea.Cantidad < promo.CantidadMinima) continue;
                if (yaPromocionados.Contains(promo.ProductoId)) continue;

                if (promo.Tipo == "DescuentoPorcentual" && promo.PorcentajeDescuento.HasValue)
                {
                    var descuento = Math.Round(linea.Subtotal * (promo.PorcentajeDescuento.Value / 100m), 2, MidpointRounding.AwayFromZero);
                    if (descuento <= 0) continue;

                    linea.MontoDescuento = descuento;
                    linea.PromocionNombre = promo.Nombre;
                    yaPromocionados.Add(promo.ProductoId);

                    result.Applied.Add(new AppliedPromotion
                    {
                        PromocionId = promo.PromocionId,
                        ProductoId = promo.ProductoId,
                        TipoBeneficio = "Descuento",
                        MontoDescontado = descuento
                    });
                }
                else if (promo.Tipo == "RegaliaPorVolumen" && promo.ProductoRegaloId.HasValue && promo.CantidadRegalo.HasValue)
                {
                    var multiplicador = linea.Cantidad / promo.CantidadMinima; // regalía por volumen
                    var unidades = promo.CantidadRegalo.Value * multiplicador;
                    unidades = Math.Min(unidades, Math.Max(promo.ProductoRegaloStock, 0));
                    if (unidades <= 0) continue;

                    linea.PromocionNombre = promo.Nombre;
                    yaPromocionados.Add(promo.ProductoId);

                    result.Gifts.Add(new CartItemViewModel
                    {
                        ProductoId = promo.ProductoRegaloId.Value,
                        Nombre = promo.ProductoRegaloNombre ?? "Regalía",
                        Precio = 0m,
                        Cantidad = unidades,
                        EsRegalo = true,
                        PromocionNombre = promo.Nombre
                    });

                    result.Applied.Add(new AppliedPromotion
                    {
                        PromocionId = promo.PromocionId,
                        ProductoId = promo.ProductoId,
                        TipoBeneficio = "Regalia",
                        UnidadesRegalo = unidades,
                        ProductoRegaloId = promo.ProductoRegaloId.Value
                    });
                }
            }

            return result;
        }
    }
}
