# Seguridad del navegador y configuración de producción

## CSP

La aplicación emite `Content-Security-Policy` en modo obligatorio. El inventario actual contiene scripts Razor en 19 vistas y dependencias CDN históricas; por compatibilidad, la directiva conserva temporalmente `unsafe-inline` para scripts y estilos. Esto ya evita que la política quede solo en reporte, pero la retirada de `unsafe-inline` exige mover los 35 bloques de script a archivos estáticos o aplicar nonces a todos en un cambio coordinado y validado en navegador.

## Configuración obligatoria

En producción, MVC falla al iniciar si falta la conexión SQL, la conexión Redis compartida, el destinatario de contacto, una URL HTTPS no local para la API, una identidad empresarial o un `AllowedHosts` restringido. La API aplica controles equivalentes para SQL, recuperación de contraseña, host e identidad.

Desarrollo local conserva caché de sesión en memoria. Producción usa Redis mediante `ConnectionStrings:DistributedCache`; por ello no depende de afinidad de sesión entre instancias.
