# Facturación versionada y estado manual

Requiere 0036 por hash y módulos instalados 0012 acreditados. Agrega dos SP; no altera
los históricos ni reescribe pedidos durante instalación. Respaldo actual restaurado,
ensayo SQL/HTTP aislado, `sqlcmd -I -b -f 65001` y hash de bytes finales obligatorios.

El consumidor MVC exige capacidad explícita y login original dentro de la transacción.
Facturar usa exclusivamente el neto persistido según 0012 e impuesto del 13 % agregado;
no es un motor de precios ni vuelve a cotizar históricos. Registra Liberado y termina
en Facturado, con factura/detalles/auditoría atómicos. PedidoId es la clave natural de
idempotencia de la factura; el reintento devuelve la existente sin cambiarla ni alterar
el estado histórico. La conexión exterior conserva locks hasta comprobar vigencia.

Este incremento solo factura pedidos cuyo descuento de inventario ya está acreditado
por InventarioDescontado=1. No vuelve a descontar stock. Los que no lo acreditan quedan
bloqueados; requiere integración futura del checkout/6B para un nuevo débito atómico.
Importes superiores a 2.000.000 no se aprueban ni facturan sin la relación supervisora.
No modifica sus estados automáticamente. Entregado y Retenido no se facturan por este
consumidor; la actualización manual no libera retenidos ni acredita entrega.

No certifica el cálculo original de promociones de un pedido histórico, cotizaciones
separadas, checkout automático completo ni asignaciones comerciales. Los SP históricos
siguen presentes para conservar evidencia; MVC usa exclusivamente los nuevos contratos.

Para compensar, detener los consumidores y preparar una evolución revisada que conserve
facturas, auditoría y ledger. No volver al procedimiento histórico que marca Entregado,
ni borrar facturas o restaurar principal sin autorización y análisis de escrituras.
