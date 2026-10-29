# Diagnostico de autenticacion API futura

## Resumen ejecutivo

`Proyecto_FinalAPI` ya expone autenticacion basica y endpoints publicos de productos/categorias, pero todavia no tiene un mecanismo formal de autorizacion para endpoints protegidos.

El login actual valida credenciales y devuelve datos del usuario, pero no emite JWT, API key, cookie compartida ni otro token de autorizacion. Por ese motivo, el API debe mantenerse limitado a endpoints publicos de solo lectura hasta que se apruebe una fase especifica de autenticacion API.

La recomendacion principal es mantener productos y categorias como publicos, no exponer pedidos, facturacion, inventario administrativo ni datos sensibles por API todavia, e implementar JWT solo en una fase futura aprobada.

## Estado actual del API

Actualmente `Proyecto_FinalAPI` tiene endpoints para:

- Autenticacion:
  - `POST /api/auth/login`
  - `POST /api/auth/register`
  - `POST /api/auth/forgot-password`
  - `POST /api/auth/reset-password`
- Productos publicos:
  - `GET /api/products`
  - `GET /api/products?categoria=`
  - `GET /api/products?buscar=`
  - `GET /api/products/{id}`
  - `GET /api/products/categories`
  - `GET /api/products/featured?take=`

El API no registra todavia:

- `AddAuthentication`
- `AddAuthorization`
- `UseAuthentication`
- esquema Bearer
- JWT
- filtros `[Authorize]`

Los endpoints de productos son publicos y de solo lectura. No exponen costos internos, datos de clientes, pedidos, facturas, permisos ni informacion administrativa.

## Flujo actual de login API

El endpoint `POST /api/auth/login` recibe correo y contrasena.

Flujo actual:

1. Valida que el request incluya correo y contrasena.
2. Aplica rate-limit por correo e IP.
3. Consulta `AccountApiDbService.ValidateUserAsync`.
4. Si las credenciales no coinciden, registra intento fallido y responde `401`.
5. Si las credenciales son validas, reinicia el contador de intentos.
6. Devuelve un resultado con:
   - `success`
   - `message`
   - `userId`
   - `fullName`
   - `email`
   - `role`

Importante: esta respuesta no incluye JWT ni token de autorizacion.

## Uso del login API desde MVC

El MVC consume el API mediante `AccountApiService`.

Flujo actual:

1. `AccountController.Login` recibe el formulario MVC.
2. `AccountApiService.LoginAsync` llama a `POST /api/auth/login`.
3. Si el API responde correctamente, el MVC crea su propia sesion local.
4. La sesion MVC guarda:
   - `UserId`
   - `UserEmail`
   - `UserFullName`
   - `UserRole`
5. Los filtros MVC (`AdminAuthorizeAttribute` y `SessionAuthorizeAttribute`) usan esa sesion local para proteger rutas MVC.

El API no participa en la autorizacion MVC despues del login. Su funcion actual es validar credenciales y devolver datos basicos.

## Riesgos de exponer endpoints protegidos sin token

Agregar endpoints protegidos sin JWT ni mecanismo equivalente generaria riesgos altos:

- Un cliente podria llamar endpoints administrativos directamente.
- Un usuario podria enviar un `UsuarioId` ajeno y consultar pedidos o comprobantes de otra persona.
- No habria forma estandar de aplicar `[Authorize]`.
- No habria expiracion de credenciales API.
- No se podrian validar roles de forma confiable por request.
- No se podrian validar permisos granulares en endpoints administrativos.
- El API podria terminar confiando en parametros manipulables por el cliente.

Por eso, cualquier endpoint futuro de pedidos, facturacion, inventario, clientes, creditos, roles o permisos debe esperar una estrategia de autenticacion y autorizacion API.

## Opciones evaluadas

### JWT

Ventajas:

- Es el enfoque mas adecuado para una API REST.
- Permite usar `Authorization: Bearer`.
- Permite aplicar `[Authorize]`.
- Permite incluir claims como `UserId`, correo y rol.
- Permite expiracion controlada del token.
- Facilita proteger endpoints cliente y admin.

Desventajas:

- Requiere configurar issuer, audience, key y expiracion.
- Requiere proteger correctamente la clave.
- Requiere pruebas de expiracion, rol y acceso a datos propios.
- Puede romper el login MVC si se cambia el contrato actual en vez de extenderlo.

Veredicto: recomendado para una fase futura aprobada.

### API Key

Ventajas:

- Simple para integraciones servidor a servidor.
- Facil de validar en middleware o filtro.

Desventajas:

- No representa bien usuarios finales.
- No resuelve propiedad de datos por `UsuarioId`.
- No modela roles ni permisos de forma natural.
- No es suficiente para pedidos de cliente, facturacion o administracion.

Veredicto: no recomendado como autenticacion principal para este proyecto.

### Cookie o sesion compartida

Ventajas:

- Podria parecer natural porque MVC ya usa sesion.

Desventajas:

- MVC y API son proyectos separados.
- Complica SameSite, CORS, dominio, expiracion y despliegue.
- Aumenta acoplamiento entre MVC y API.
- No es ideal para clientes externos tipo Postman, mobile o integraciones.

Veredicto: no recomendado por complejidad y fragilidad.

### Mantener API publica solamente

Ventajas:

- Bajo riesgo.
- Mantiene productos/categorias disponibles sin exponer datos sensibles.
- No requiere tocar appsettings ni login MVC.

Desventajas:

- El API queda limitado.
- No cubre pedidos, facturacion ni administracion.

Veredicto: recomendado por ahora hasta aprobar JWT.

## Recomendacion principal

La recomendacion para el estado actual es:

1. Mantener `GET /api/products` y endpoints relacionados como publicos.
2. Mantener autenticacion actual sin token para no romper MVC.
3. No exponer todavia endpoints protegidos.
4. Implementar JWT solo en una fase futura aprobada.
5. Si se implementa JWT, agregar el token como campo adicional sin eliminar ni renombrar los campos actuales.

La respuesta actual del login debe conservar compatibilidad con MVC:

- `success`
- `message`
- `userId`
- `fullName`
- `email`
- `role`

En una fase futura se podria agregar:

- `token`
- `expiresAt`

Pero no se deben quitar ni cambiar los campos actuales.

## Endpoints futuros que podrian protegerse con JWT

Con JWT implementado y probado, se podrian considerar:

- Cliente:
  - `GET /api/client/orders`
  - `GET /api/client/orders/{id}`
  - `GET /api/client/orders/{id}/invoice`
  - `POST /api/client/orders/{id}/cancel`
- Admin:
  - `GET /api/admin/orders`
  - `GET /api/admin/orders/{id}`
  - `POST /api/admin/orders/{id}/status`
  - `POST /api/admin/orders/{id}/invoice`
  - `GET /api/admin/inventory`
  - `GET /api/admin/billing`
  - `GET /api/admin/customers`

Los endpoints cliente deben validar propiedad por `UserId` desde claims, no por parametros libres enviados por el cliente.

Los endpoints admin deben validar rol y, si aplica, permisos granulares.

## Endpoints que no deben exponerse todavia

No se deben exponer en el estado actual:

- Pedidos de cliente.
- Comprobantes de cliente.
- Cancelacion de pedidos.
- Pedidos admin.
- Generacion de facturas.
- Inventario admin.
- Clientes y creditos.
- Roles y permisos.
- Auditoria.

Estos endpoints manejan datos sensibles o acciones criticas y requieren autenticacion API real.

## Archivos que se tocarian si se implementa JWT

Una implementacion futura de JWT probablemente tocaria:

- `Proyecto_FinalAPI/Program.cs`
- `Proyecto_FinalAPI/Controllers/AuthController.cs`
- `Proyecto_FinalAPI/Models/AuthModels.cs`
- nuevo servicio `Proyecto_FinalAPI/Services/JwtTokenService.cs`
- posiblemente un modelo de opciones JWT
- `appsettings.json`
- `appsettings.Development.json`

Solo se deberia tocar MVC si se decide que MVC tambien usara el token para llamadas protegidas al API. En ese caso, el cambio probable estaria en:

- `Proyecto_Final/Services/AccountApiService.cs`

Pero no se recomienda tocar MVC en la primera fase de JWT salvo aprobacion explicita.

## Riesgos de tocar appsettings

JWT requiere configuracion sensible:

- issuer
- audience
- key secreta
- minutos de expiracion

Riesgos:

- Exponer una clave secreta en el repositorio.
- Romper entornos locales si se cambia configuracion existente.
- Usar una clave debil o fija para todos los entornos.
- Bloquear login/API si falta configuracion en alguna maquina.

Por eso, no se debe tocar `appsettings.json` ni `appsettings.Development.json` sin aprobacion explicita y sin definir como manejar secretos por entorno.

## Riesgos de romper login MVC

El login MVC depende de la forma actual de la respuesta del API.

Riesgos principales:

- Renombrar `userId`, `fullName`, `email` o `role`.
- Cambiar `success` o `message`.
- Cambiar el codigo HTTP esperado.
- Reemplazar la respuesta por un objeto solo con token.
- Cambiar la ruta `POST /api/auth/login`.
- Cambiar mensajes de error que MVC espera mostrar.

Mitigacion:

- Mantener el contrato actual.
- Agregar campos nuevos de forma aditiva.
- Probar login MVC inmediatamente despues de cualquier cambio.

## Plan futuro por bloques

### Bloque JWT-1: diagnostico y diseno final

- Definir claims minimos.
- Definir expiracion.
- Definir si MVC usara token o seguira con sesion local.
- Definir manejo de secretos.

### Bloque JWT-2: infraestructura JWT en API

- Configurar autenticacion Bearer.
- Crear servicio de emision de token.
- Mantener respuesta actual de login y agregar token como campo nuevo.
- Build y pruebas de login API/MVC.

### Bloque JWT-3: endpoint protegido piloto de cliente

- Crear un endpoint simple de pedidos propios.
- Validar `UserId` desde claims.
- Confirmar que un cliente no ve datos ajenos.

### Bloque JWT-4: endpoint protegido piloto admin

- Crear un endpoint de consulta admin de solo lectura.
- Validar rol `Administrador`.
- Evaluar permisos granulares si aplica.

### Bloque JWT-5: QA de seguridad API

- Probar sin token.
- Probar token invalido.
- Probar token vencido.
- Probar rol incorrecto.
- Probar acceso a recurso ajeno.

## Pruebas necesarias para una futura implementacion JWT

Pruebas de autenticacion:

- Login API correcto devuelve datos actuales y token.
- Login API incorrecto devuelve `401`.
- Login MVC sigue funcionando.
- Registro MVC sigue funcionando.
- Recuperacion de contrasena sigue funcionando.

Pruebas de autorizacion:

- Endpoint protegido sin token devuelve `401`.
- Endpoint protegido con token invalido devuelve `401`.
- Endpoint admin con rol cliente devuelve `403`.
- Endpoint cliente usa `UserId` desde token.
- Cliente no puede consultar pedido ajeno.
- Admin puede consultar endpoints admin autorizados.

Pruebas tecnicas:

- Build con 0 errores.
- Sin cambios accidentales en MVC.
- Sin appsettings con secretos reales.
- Sin endpoints sensibles publicos.

## Veredicto final

El API debe mantenerse por ahora con productos/categorias publicos y autenticacion basica existente.

No se deben exponer endpoints protegidos hasta implementar una estrategia formal, preferiblemente JWT. Cualquier implementacion futura debe ser aditiva y compatible con el login MVC actual para no romper la creacion de sesion local.
