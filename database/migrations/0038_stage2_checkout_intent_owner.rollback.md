# Propiedad original del UUID de checkout

Evolución aditiva dependiente del hash exacto de 0037. No altera SQL0012, tokens
históricos ni registros comerciales durante instalación. Requiere respaldo actual
restaurado, prueba SQL/HTTP aislada y `sqlcmd -I -b -f 65001` con hash final.

Antes del checkout, el servicio conserva una reserva inmutable del UUID, login original,
actor y huella normalizada de IDs/cantidades/entrega/pago. La reserva confirma en su propia
transacción validada: un fallo comercial posterior no entrega el UUID a otra sesión.
La transacción comercial vuelve a comprobar login y reserva antes de ejecutar SQL0012.
La huella no confía en precios del navegador ni incluye cuerpos o credenciales en SQL.
Los intentos sin propietario original históricos no se adoptan. Logout/regrant/vencimiento
niegan el contexto. Otra sesión de la misma cuenta no recupera el recibo de este intento.

MVC conserva una instantánea del cuerpo únicamente en su sesión del servidor. Refresh
y respuesta HTTP perdida reutilizan UUID y contenido; una repetición confirmada no vuelve
a enviar correo. Una compra nueva retira la instantánea completada cuando agrega productos.
No hay persistencia de cuerpos en localStorage/sessionStorage/IndexedDB ni recuperación
en otra sesión. No se crean credenciales nuevas ni se prolonga el login.

No certifica cotizaciones emitidas por una identidad técnica separada, paridad monetaria
completa, retención/facturación automática del checkout ni SQL0012 como contrato 6B.
Conserva esos consumidores y sus validaciones de combos/regalías, sin adaptadores parciales.

Para compensar, detener los consumidores y preparar una evolución revisada que preserve
reservas y auditoría. No borrar propietarios/ledger ni permitir que otro login adopte UUID.
Una restauración principal requiere autorización específica y análisis de escrituras.

El guard adicional C# reutiliza PromotionEngine sobre las fuentes canónicas bajo la
transacción 0012. Una discrepancia de aplicaciones/neto, cambio de día comercial o
importe final superior al umbral sin aprobación acreditada revierte el pedido y
stock, conservando solamente la reserva original. No sustituye la evolución monetaria
pendiente ni publica una cotización en nombre de una autoridad ausente.
