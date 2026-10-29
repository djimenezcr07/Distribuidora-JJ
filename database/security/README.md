# Auditoria de cuentas demo

`p0_audit_demo_accounts.sql` es un inventario estrictamente de solo lectura para localizar cuentas demo o de prueba.

- No ejecuta inserciones, actualizaciones, eliminaciones ni procedimientos que cambien datos.
- Nunca muestra contrasenas; los correos se devuelven parcialmente enmascarados.
- No compartir la salida si contiene informacion sensible.
- Las cuentas demo activas deben rotarse o desactivarse antes de conectar colaboradores.
- Cualquier cambio de cuentas requiere un bloque Azure aprobado.
- El sistema todavia usa contrasenas en texto plano; su migracion se resolvera en una fase posterior.
