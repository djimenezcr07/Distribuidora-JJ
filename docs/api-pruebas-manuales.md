# Pruebas manuales del API

## Objetivo

Este documento define las pruebas manuales para validar el alcance actual de `Proyecto_FinalAPI`: autenticacion basica existente y endpoints publicos de productos/categorias.

El API no emite JWT actualmente. Por eso no existen endpoints protegidos de cliente/admin en esta fase.

## Pruebas previas a publicar en Azure App Service

Antes de publicar `Proyecto_FinalAPI` en Azure App Service, validar localmente:

| ID | Modulo | Metodo | URL | Resultado esperado | Codigo HTTP esperado |
|---|---|---|---|---|---|
| API-PRE-001 | Swagger | GET | `/swagger` | Abre Swagger UI. | 200 |
| API-PRE-002 | Diagnostico | GET | `/health` | Devuelve estado simple `OK`. | 200 |
| API-PRE-003 | Productos | GET | `/api/productos` | Devuelve productos reales desde la base configurada. | 200 |
| API-PRE-004 | Auth | POST | `/api/auth/login` | Login valido devuelve datos basicos de usuario sin JWT. | 200 |

Estas pruebas deben ejecutarse con `ConnectionStrings__DefaultConnection` configurado por variable de entorno, sin modificar `appsettings`.

## Matriz de pruebas

| ID | Modulo | Metodo | URL | Datos de prueba | Resultado esperado | Codigo HTTP esperado | Estado | Observaciones |
|---|---|---|---|---|---|---|---|---|
| API-000 | Swagger | GET | `/swagger` | N/A | Abre Swagger UI. | 200 | Pendiente | En Azure DEV requiere Swagger habilitado por configuracion. |
| API-000A | Swagger | GET | `/swagger/v1/swagger.json` | N/A | Devuelve documento OpenAPI JSON. | 200 | Pendiente | No debe exponer secretos. |
| API-000B | Diagnostico | GET | `/` | N/A | Devuelve estado general de la API. | 200 | Pendiente | No debe exponer connection strings. |
| API-000C | Diagnostico | GET | `/health` | N/A | Devuelve estado simple `OK`. | 200 | Pendiente | No debe modificar base de datos. |
| API-001 | Productos | GET | `/api/products` | N/A | Devuelve lista de productos activos. | 200 | Pendiente | Puede devolver lista vacia si no hay productos activos. |
| API-001A | Productos | GET | `/api/productos` | N/A | Devuelve lista de productos activos. | 200 | Pendiente | Alias en espanol de `/api/products`. |
| API-002 | Productos | GET | `/api/products?categoria=Whisky` | Categoria existente. | Devuelve productos filtrados por categoria. | 200 | Pendiente | Si no hay coincidencias, devuelve lista vacia. |
| API-003 | Productos | GET | `/api/products?buscar=ron` | Texto de busqueda. | Devuelve productos que coincidan con la busqueda. | 200 | Pendiente | Si no hay coincidencias, devuelve lista vacia. |
| API-004 | Productos | GET | `/api/products/{id valido}` | ProductoId existente. | Devuelve detalle del producto. | 200 | Pendiente | Reemplazar con un ID real de la base local. |
| API-005 | Productos | GET | `/api/products/999999` | ID inexistente. | Devuelve mensaje de producto no encontrado. | 404 | Pendiente | No debe exponer detalles tecnicos. |
| API-006 | Productos | GET | `/api/products/0` | ID invalido. | Devuelve mensaje de identificador invalido. | 400 | Pendiente | No debe consultar base de datos. |
| API-007 | Productos | GET | `/api/products/-1` | ID invalido. | Devuelve mensaje de identificador invalido. | 400 | Pendiente | No debe consultar base de datos. |
| API-008 | Productos | GET | `/api/products/categories` | N/A | Devuelve lista de categorias activas. | 200 | Pendiente | Puede devolver lista vacia si no hay categorias activas. |
| API-008A | Productos | GET | `/api/productos/categories` | N/A | Devuelve lista de categorias activas. | 200 | Pendiente | Alias en espanol de `/api/products/categories`. |
| API-009 | Productos | GET | `/api/products/featured?take=4` | `take=4`. | Devuelve hasta 4 productos destacados. | 200 | Pendiente | Puede devolver menos si hay menos destacados. |
| API-010 | Productos | GET | `/api/products/featured?take=0` | `take=0`. | Devuelve mensaje de cantidad invalida. | 400 | Pendiente | No debe consultar base de datos. |
| API-011 | Productos | GET | `/api/products/featured?take=-1` | `take=-1`. | Devuelve mensaje de cantidad invalida. | 400 | Pendiente | No debe consultar base de datos. |
| API-012 | Productos | GET | `/api/products/featured?take=100` | `take=100`. | Devuelve 200 con maximo 24 productos destacados. | 200 | Pendiente | El limite maximo queda aplicado por el controlador. |
| API-013 | Auth | POST | `/api/auth/login` | Credencial temporal valida. | Devuelve datos basicos de usuario sin JWT. | 200 | Pendiente | Solicitar una credencial temporal al responsable del entorno por un canal privado. |
| API-014 | Auth | POST | `/api/auth/login` | Credenciales invalidas. | Devuelve credenciales invalidas. | 401 | Pendiente | Puede activar rate-limit tras varios intentos. |
| API-015 | Auth | POST | `/api/auth/register` | Datos validos no duplicados. | Crea cuenta o devuelve validacion segun estado de la base. | 200/409/400 | Pendiente | No usar correo real sensible. |
| API-016 | Auth | POST | `/api/auth/forgot-password` | Correo de prueba. | Devuelve mensaje generico de recuperacion. | 200/400/429 | Pendiente | No debe revelar si el correo existe. |
| API-017 | Auth | POST | `/api/auth/reset-password` | Token de prueba. | Actualiza si el token es valido; rechaza si es invalido o vencido. | 200/400/429 | Pendiente | Requiere token generado por el flujo de recuperacion. |

## Criterios de aceptacion

- Los endpoints publicos de productos no requieren autenticacion.
- Los endpoints de productos no exponen costos, margenes, proveedores ni datos internos.
- Los parametros invalidos responden `400` cuando corresponde.
- El producto inexistente responde `404`.
- Los errores internos responden mensajes genericos.
- El login API mantiene la respuesta actual y no emite JWT.
- Swagger UI y OpenAPI JSON no exponen secretos.
- `/health` no modifica base de datos.
- No existen endpoints protegidos de pedidos, facturacion, inventario, clientes, creditos, roles o permisos en esta fase.
