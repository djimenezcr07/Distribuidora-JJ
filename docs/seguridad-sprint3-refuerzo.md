# Refuerzo de seguridad posterior al Sprint 3

Este bloque aplica mejoras pequenas y sin cambios SQL para reducir exposicion de datos tecnicos y reforzar controles existentes en MVC.

## Alcance

- Mensajes visibles para usuario: los errores genericos evitan mostrar `ex.Message`, nombres de procedimientos, errores SQL, stack trace o detalles internos.
- Rutas internas sin cache: `SecurityHeadersMiddleware` ya cubre rutas administrativas y de empleados como `/Employees`, `/EmployeePortal`, `/Admin`, `/Inventory`, `/Clients`, `/Credits`, `/Roles`, `/Permissions`, `/Audit`, `/OrdersAdmin` y `/SellerOrders`.
- Formularios sensibles: se agregaron tokens antiforgery explicitos en recuperacion y restablecimiento de contrasena.
- Imagenes de inventario: la subida valida tamano maximo, extension permitida, content-type basico y conserva nombres finales generados con GUID.

## Pruebas sugeridas

1. Contacto, perfil, pedidos administrativos y venta movil: provocar un error controlado y confirmar que la pantalla muestra un mensaje generico.
2. Recuperacion de contrasena: enviar `ForgotPassword` y `ResetPassword` desde la vista y verificar que el formulario mantiene token antiforgery.
3. Inventario: subir una imagen JPG, PNG o WEBP valida menor a 2 MB y confirmar que se guarda correctamente.
4. Inventario: intentar subir un archivo no permitido o mayor a 2 MB y confirmar que se muestra un mensaje claro sin detalle tecnico.
5. Logout y cache: entrar a rutas internas, cerrar sesion y usar atras del navegador para confirmar que no quedan paginas internas reutilizables desde cache.

## Restricciones respetadas

- No se modifico SQL.
- No se modifico `appsettings`.
- No se instalaron paquetes NuGet.
- No se cambiaron hashes, permisos ni reglas de autorizacion.
