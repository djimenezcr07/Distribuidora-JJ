# E2E de saneamiento Stage 1

La suite Playwright valida el login normal sin `returnUrl` para Administrador, Cliente, Vendedor y Chofer; además comprueba un `returnUrl` público seguro, contacto, destinos por perfil, consola, logout y limpieza offline. Si se proporcionan IDs ajenos sintéticos, también prueba respuestas 404 de ownership para cliente y vendedor.

```powershell
$env:E2E_BASE_URL = 'https://<mvc-dev>'
$env:E2E_REQUIRE_AUTH = 'true'
$env:E2E_BROWSER_CHANNEL = 'chrome' # opcional si el runner usa Chrome instalado
# Definir mediante secretos del runner E2E_ADMIN_EMAIL/PASSWORD,
# E2E_CLIENT_EMAIL/PASSWORD, E2E_SELLER_EMAIL/PASSWORD y E2E_DRIVER_EMAIL/PASSWORD.
pnpm --dir e2e install --frozen-lockfile
pnpm --dir e2e test
```

Nunca guardar credenciales ni IDs con datos personales en el repositorio. Si no hay credenciales autorizadas, la suite ejecuta solo el tramo público y el reporte QA debe marcar los recorridos autenticados como pendientes.
