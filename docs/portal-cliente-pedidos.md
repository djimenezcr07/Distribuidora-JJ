# Portal del cliente, pedidos e inventario

## Reglas vigentes

- El portal requiere rol `Cliente` y usa el `UserId` de la sesión para todas las lecturas/mutaciones.
- Historial, detalle, comprobante, garantía y evidencias comprueban pertenencia en servidor/base; un ID de URL no concede acceso.
- El comprobante se consulta por `PedidoId` propio y no sustituye una factura electrónica oficial.

## Checkout autoritativo

- El carrito de sesión se refresca contra productos vigentes antes de mostrar y comprar.
- La migración 0005 ejecuta pedido, descuento/regalía e inventario dentro de una sola transacción.
- SQL vuelve a comprobar precio, stock, segmento, vigencia y prioridad con bloqueos de concurrencia.
- Si falla stock, promoción o pedido, no persiste un pedido parcial ni un descuento desconectado.
- La confirmación usa total y regalías retornados por la base, no cálculos confiados al navegador.

## Cancelación

- Solo un pedido propio, `Pendiente` y no facturado puede cancelarse.
- Como el checkout descuenta inventario al crear el pedido, la cancelación restaura stock exactamente una vez.
- La facturación no descuenta stock nuevamente.

## Garantías

- El cliente solo solicita garantía sobre un detalle de pedido propio entregado.
- No puede existir otra solicitud abierta para el mismo detalle.
- El administrador necesita el permiso funcional, registra estado/resolución y deja auditoría.

## QA pendiente de entorno

Aplicar migraciones, probar concurrencia de stock, cancelación/restauración, comprobantes propios/ajenos y el flujo completo de garantía. Los tests automatizados cubren el motor de promociones, no sustituyen una prueba transaccional contra SQL Server.
