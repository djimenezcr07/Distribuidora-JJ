# 0039 — recuperación controlada

No modifica 0012 ni 0030–0038 ni reescribe pedidos/facturas históricos. Los nuevos procedimientos y snapshots V2 distinguen bruto, descuento agregado, neto, impuesto y total final. No existe reparto de descuentos por unidad. Los lectores versionados mantienen fallback histórico, sin inferir V2 de precios o fechas.

El checkout conserva su alcance académico Pendiente; este contrato no habilita aprobación supervisora, emisión de cotizaciones ni facturación automática integral. CheckoutPricingGuard sigue comprobando PromotionEngine y el umbral final. No usar este despliegue como prueba de identidades técnicas separadas.

Antes de aplicar se exige backup CHECKSUM/VERIFYONLY, restauración real y prueba en copia. Ante una operación fallida, la transacción revierte snapshots, pedido y stock; la reserva original del UUID permanece por diseño.

No ejecutar DROP/down automático. Si ya existen pedidos V2, sus snapshots y lectores deben conservarse. Recuperar fuentes y base mediante una restauración aprobada y coordinada, sin perder operaciones posteriores ni reutilizar el respaldo de forma automática. No borrar ledger ni convertir importes históricos.
