# Presentación ejecutiva y demo en vivo — Supermercado Mayoreo

**Fecha de preparación:** 12 de agosto de 2026  
**Duración objetivo:** 14:00 minutos (máximo permitido: 14:30)  
**Entorno único de demostración:** hosting Azure; no usar localhost.

## Validación y decisión de alcance

- **Nombre comercial que debe usarse en toda la exposición:** **Supermercado Mayoreo**. El subtítulo visible es “Licorera - Distribuidora”. No presentar el sistema como “Trilogia-Cursos”, “Proyecto_Final” ni “Licorera La Bodega”; esos son nombres internos o históricos.
- **URL MVC confirmada:** <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/>
- **API / evidencia técnica pública:** <https://api-trilogia-cursos-dev-cr01-haefhbgrd8dvcvc5.centralus-01.azurewebsites.net/swagger/index.html>
- En esta revisión de solo lectura, el 12 de agosto de 2026, MVC, API, catálogo, detalle, carrito vacío, login y Swagger respondieron HTTP 200. Ambos health checks reportaron el build `232ca3e6c15bf83da3094bb0410280211eb3f4f4`, que corresponde al commit disponible en `origin/main`.
- Las rutas autenticadas `/Admin`, `/Inventory`, `/ClientPortal`, `/OrdersAdmin`, `/Payroll` y `/Chat` están publicadas y, sin sesión, redirigen correctamente a `/Account/Login`. Esto confirma despliegue y protección de acceso, **no** una validación autenticada completa.

### Estado de acceso de prueba

No existe en el repositorio ni en la documentación una credencial QA vigente que pueda publicarse o verificarse. La documentación activa deja el QA autenticado pendiente de una cuenta temporal autorizada. Antes de exponer, el responsable del entorno debe entregar por un canal privado:

- una cuenta temporal de **Cliente** que ya tenga un pedido propio y, si se mostrará factura, una factura/comprobante asociado;
- una cuenta temporal de **Administrador** con acceso a Inventario;
- confirmación explícita de si se autoriza crear un pedido QA durante la exposición.

No pegar esas credenciales en esta guía, diapositivas, navegador compartido, chat o repositorio. En esta preparación no se inició sesión, no se creó pedido, no se modificó inventario ni se alteró Azure o la base de datos.

### Semáforo para la demo

| Bloque | Estado en hosting | Decisión |
| --- | --- | --- |
| Catálogo, filtros, detalle y carrito de sesión | **Verificado públicamente** | Aprobado. |
| Checkout y creación de pedido | Código y ruta publicados; falta cuenta QA y prueba real actual | Condicional: usar solo con autorización de cuenta/dato QA. |
| Portal del cliente, detalle y comprobante | Ruta publicada y protegida; falta prueba autenticada actual | Condicional: usar solo con pedido propio preexistente. |
| Administración e inventario de consulta | Rutas publicadas y protegidas; revisión Azure previa de lectura | Condicional: mostrar exclusivamente pantallas de consulta tras preflight privado. |

Si no se reciben y prueban las dos cuentas antes de iniciar la exposición, la única funcionalidad aprobada sin reservas es el bloque público de catálogo/detalle/carrito. No afirmar que los otros tres flujos “funcionan en Azure” sin ese preflight.

## A. Resumen ejecutivo

### Problema y contexto de empresa

**Supermercado Mayoreo** es una licorera y distribuidora en San José, Costa Rica. El proyecto centraliza la exhibición de productos, la preparación de compras, el seguimiento de pedidos del cliente y la consulta administrativa de inventario. Busca reducir la dependencia de catálogos dispersos y dar visibilidad controlada sobre disponibilidad, pedidos y operación.

### Sistema propuesto

Una aplicación web con tienda pública, carrito y checkout; portal para que cada cliente consulte exclusivamente sus pedidos y comprobantes propios; y un área administrativa con módulos protegidos por rol, módulo y, para acciones sensibles, permiso específico. El valor demostrable hoy debe ser la trazabilidad del recorrido producto → carrito → pedido → consulta del cliente, más la consulta de inventario por el administrador.

### Arquitectura y tecnologías confirmadas

- **ASP.NET Core 9 MVC:** aplicación web `Proyecto_Final`, con vistas Razor, rutas MVC convencionales y sesiones de servidor.
- **ASP.NET Core 9 Web API:** aplicación `Proyecto_FinalAPI`, con Swagger y endpoints públicos de catálogo; el MVC configura un `HttpClient` para consumir la API de autenticación.
- **SQL Server / Azure SQL DEV:** los servicios MVC y API usan `Microsoft.Data.SqlClient`, `DefaultConnection` y procedimientos almacenados. La documentación de despliegue confirma Azure SQL DEV para el entorno publicado.
- **Azure App Service:** MVC y API están publicados como servicios separados; los health checks de ambos están activos.
- **Autenticación y autorización:** sesión con cookie segura en producción, antiforgery en operaciones POST, rate limiting y filtros por rol/módulo/permiso. El portal del cliente verifica propiedad con el `UserId` de sesión.

No declarar JWT, pagos reales, facturación electrónica oficial, IA generativa, microservicios, Key Vault, identidad administrada, SMTP operativo ni almacenamiento Azure Blob como tecnologías implementadas: no están confirmadas para este flujo de demo.

## B. Cuatro funcionalidades core para la exposición

### 1. Integrante 1 — Catálogo y detalle de productos

- **Estado:** aprobado en hosting.
- **Valor de negocio:** permite al cliente encontrar productos activos, consultar precio/disponibilidad y decidir su compra sin intervención manual.
- **Rutas exactas:**
  - Catálogo: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Home/Shop>
  - Ejemplo verificado al preparar esta guía: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Home/Detail/54>
- **Rol requerido:** visitante; no requiere inicio de sesión.
- **Dato de prueba seguro:** el producto público que esté disponible al iniciar la presentación. Al preparar esta guía, el ID 54 era “Absolut Vodka 1 L”; confirmar disponibilidad cinco minutos antes, porque catálogo y stock son dinámicos.
- **Pasos en vivo:**
  1. Abrir la ruta del catálogo desde una pestaña limpia.
  2. Aplicar una categoría o la búsqueda; usar el filtro que devuelva resultados en ese momento.
  3. Abrir **Ver** de un producto disponible.
  4. Señalar nombre, categoría, precio, disponibilidad e imagen.
  5. Volver al catálogo y, solo si se requiere enlazar con el siguiente bloque, pulsar **Agregar al carrito** una vez.
- **Resultado esperado:** catálogo, filtros y detalle cargan desde hosting; el producto se muestra como disponible y el carrito mantiene el artículo en la sesión del navegador.
- **Plan B:** abrir directamente el detalle público verificado `/Home/Detail/54`; si cambió, volver a `/Home/Shop` y escoger una tarjeta visible. No usar capturas locales como sustituto.

### 2. Integrante 2 — Carrito, checkout, validación de stock y creación de pedido

- **Estado:** condicional a preflight autenticado y autorización explícita de crear un pedido QA.
- **Valor de negocio:** concentra la compra y revalida en el servidor precio, producto y disponibilidad; el código confirma el pedido e inventario dentro de la operación SQL autoritativa.
- **Rutas exactas:**
  - Carrito: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Cart>
  - Checkout: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Cart/Checkout>
  - Confirmación: `/Cart/Confirmation` (solo se habilita inmediatamente después de un pedido confirmado).
- **Rol requerido:** cuenta temporal autorizada de **Cliente**. El checkout exige sesión; usar Cliente evita presentar una operación administrativa como compra de consumidor.
- **Datos de prueba seguros:** cuenta QA privada, un producto público con stock suficiente y datos ficticios acordados para identificación, teléfono y dirección. Nunca usar datos personales, tarjeta real, SINPE real ni una referencia de pago real.
- **Pasos en vivo:**
  1. Con el producto ya agregado, abrir **Carrito** y explicar que muestra el estado vigente de la sesión.
  2. Iniciar sesión con la cuenta Cliente en una pestaña privada; no mostrar ni leer la contraseña.
  3. Abrir **Finalizar compra**; comprobar que se cargan artículo, correo de sesión y total.
  4. Completar únicamente los datos QA acordados y seleccionar un método **simulado** o efectivo contra entrega, según autorización.
  5. Explicar que el servidor vuelve a validar stock, precio y total al confirmar.
  6. Pulsar **Confirmar pedido** solo si el responsable autorizó la escritura QA. Mostrar el número de pedido y la pantalla de confirmación; no mostrar correo ni datos sensibles.
- **Resultado esperado:** con sesión, datos válidos y stock suficiente se genera “Pedido #… creado correctamente”; un fallo de correo no debe revertir el pedido ya confirmado. Si falta stock, debe aparecer una validación sin crear un pedido parcial.
- **Plan B:** no pulsar **Confirmar pedido**. Mostrar carrito y el formulario de checkout ya cargado, explicar la revalidación, y enlazar el bloque 3 a un pedido QA existente. No simular una confirmación ni decir que se creó un pedido.

### 3. Integrante 3 — Portal del cliente: pedidos, comprobante y acciones disponibles

- **Estado:** condicional a cuenta Cliente y pedido propio preexistente; no se validó autenticadamente en esta revisión.
- **Valor de negocio:** el cliente consulta su historial sin depender de soporte y el servidor impide consultar pedidos, comprobantes y garantías de otras personas alterando una URL.
- **Rutas exactas:**
  - Portal / pedidos propios: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/ClientPortal>
  - Estado de cuenta: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/ClientPortal/Statement>
  - Detalle: `/ClientPortal/Detail/{pedidoId-propio}`
  - Comprobante: `/ClientPortal/Invoice/{pedidoId-propio}`
  - Garantías: `/ClientPortal/Warranties`
- **Rol requerido:** **Cliente**.
- **Datos de prueba seguros:** misma cuenta Cliente QA y un pedido propio ya existente. Si se muestra comprobante, elegir un pedido QA con comprobante asociado. Ocultar dirección, identificación, correo, teléfono y cualquier dato de un tercero antes de compartir pantalla.
- **Pasos en vivo:**
  1. Con sesión Cliente ya iniciada, abrir **Mi cuenta / Mis pedidos**.
  2. Seleccionar el pedido QA previamente identificado; no probar IDs ajenos.
  3. Abrir el detalle y mostrar estado, artículos y total.
  4. Si el pedido tiene comprobante, abrir **Comprobante** y explicar que es una consulta del pedido propio. No llamarlo factura electrónica oficial.
  5. Opcional: abrir **Estado de cuenta** solo si no revela información que el equipo haya decidido ocultar.
- **Resultado esperado:** se listan solo pedidos de esa sesión; el detalle y comprobante se cargan únicamente para el pedido propio. La cancelación solo está disponible para pedido propio pendiente y no facturado; **no ejecutarla** en la demo.
- **Plan B:** mostrar exclusivamente el listado del portal y el detalle de un pedido QA ya conocido. Si no existe comprobante asociado, decir “comprobante no disponible para este pedido” y no abrir facturación administrativa.

### 4. Integrante 4 — Administración: consulta de productos e inventario

- **Estado:** condicional a cuenta Administrador y preflight privado. La ruta está publicada y protegida; el manual de revisión anterior registra consulta Azure, pero esta preparación no inició sesión ni ejecutó escrituras.
- **Valor de negocio:** da al equipo operativo visibilidad de productos e inventario desde un área protegida, manteniendo separadas las acciones de creación, edición y movimiento.
- **Rutas exactas:**
  - Panel: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Admin>
  - Inventario: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Inventory>
  - Movimientos: <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/Inventory/Movements>
- **Rol requerido:** **Administrador**; para escrituras el sistema además usa permisos de inventario. En esta demo, usar solo lectura.
- **Datos de prueba seguros:** cuenta Administrador temporal; filtro por categoría o nombre de un producto público. No crear, editar, destacar, activar/inactivar, transformar, eliminar ni registrar movimientos.
- **Pasos en vivo:**
  1. Abrir `/Admin` con la sesión Administrador preparada y señalar los indicadores sin entrar a datos sensibles.
  2. Ir a **Administración > Inventario** o abrir `/Inventory`.
  3. Aplicar un filtro por un producto/categoría disponible y señalar disponibilidad, stock y estado.
  4. Como evidencia de control, explicar que las acciones de modificación son POST protegidos por antiforgery y permiso, pero no pulsarlas.
- **Resultado esperado:** el administrador consulta el panel y la lista de inventario desde hosting; no se altera ningún registro.
- **Plan B:** permanecer en `/Admin` y mostrar el menú de Inventario, o volver al catálogo público y explicar que el detalle administrativo requiere la sesión autorizada. No intentar acceder con rutas o IDs de terceros y no usar Venta móvil/offline.

## C. Guion de exposición — 14:00 minutos

| Tiempo | Responsable | Guion |
| --- | --- | --- |
| 0:00–0:25 | Integrante 1 | **Portada.** “Supermercado Mayoreo: catálogo, compra y gestión con acceso por rol.” Confirmar que la demo se ejecuta en Azure. |
| 0:25–1:20 | Integrante 1 | **Introducción.** Presentar el problema: visibilidad de productos y seguimiento de la compra sin depender de procesos dispersos. |
| 1:20–2:15 | Integrante 1 | **Contexto de empresa.** Licorera y distribuidora; clientes y operación necesitan información actual y acceso controlado. |
| 2:15–3:05 | Integrante 1 | **Sistema y arquitectura.** MVC y API ASP.NET Core 9, SQL Server/Azure SQL, sesiones y autorización. Mostrar la página publicada, no código ni paneles Azure. |
| 3:05–5:05 | Integrante 1 | **Demo 1.** Catálogo, filtro y detalle. Cerrar con “este es el punto de partida de la compra”. |
| 5:05–7:05 | Integrante 2 | **Demo 2.** Carrito y checkout. Solo confirmar pedido si la autorización QA está disponible; si no, aplicar el Plan B declarado. |
| 7:05–9:05 | Integrante 3 | **Demo 3.** Portal con pedido propio y comprobante disponible. Resaltar propiedad del recurso y no mostrar datos personales. |
| 9:05–11:05 | Integrante 4 | **Demo 4.** Panel e inventario en modo consulta. Resaltar separación entre consulta y escrituras protegidas. |
| 11:05–13:05 | Integrante 4 | **Lecciones y retos.** QA autenticado con cuentas temporales, pruebas de concurrencia/stock, SMTP pendiente y principio de mínimo privilegio. No ocultar las limitaciones. |
| 13:05–14:00 | Integrante 4 | **Cierre.** “Hoy demostramos el recorrido publicado y controlado; los siguientes pasos son completar QA autenticado y formalizar las pruebas de escritura.” Dejar 30 segundos de margen. |

## D. Checklist previo a la presentación

- [ ] Abrir la URL MVC de hosting; confirmar `200` y el catálogo visible.
- [ ] Abrir los health checks de MVC y API en pestañas separadas, solo como respaldo técnico; no mostrarlos salvo que falle la interfaz.
- [ ] Confirmar por canal privado las cuentas temporales Cliente y Administrador; no escribirlas en este archivo ni en diapositivas.
- [ ] Hacer un preflight privado de máximo cinco minutos con cada cuenta: login, ruta del bloque asignado y salida segura.
- [ ] Confirmar si está autorizado crear **un** pedido QA. Si no hay autorización, seleccionar el Plan B del bloque 2 antes de comenzar.
- [ ] Confirmar que existe un pedido QA propio y, si se mostrará, un comprobante asociado para el bloque 3.
- [ ] Elegir un producto disponible desde `/Home/Shop` justo antes de la presentación.
- [ ] Iniciar las sesiones Cliente y Administrador en perfiles de navegador separados; verificar que no queda una sesión personal abierta.
- [ ] Usar navegador limpio, zoom legible, pestañas ordenadas y notificaciones desactivadas.
- [ ] Cámara encendida si la modalidad de exposición lo requiere.
- [ ] No usar localhost, IP de red local, Visual Studio, Swagger para POST, SSMS, Azure Portal ni GitHub durante la demo.
- [ ] No mostrar secretos, connection strings, claves, tokens, contraseñas, paneles sensibles, datos personales ni comprobantes reales.
- [ ] No ejecutar altas, bajas, ediciones, movimientos de inventario, cancelaciones, garantías, pagos ni ventas offline.

## E. Módulos que no deben mostrarse

No presentar como funcionalidad core los siguientes módulos, porque no tienen QA autenticado actual en Azure, requieren escrituras no autorizadas o se documentan como pendientes:

- **Venta móvil/offline y sincronización:** está explícitamente pendiente de confirmación con perfil Vendedor en Azure; no proponerla como funcionalidad core.
- **Recuperación de contraseña y SMTP:** correo real pendiente; no ejecutar registro, recuperación ni reset durante la presentación.
- **Facturación administrativa / factura electrónica:** el comprobante del portal no equivale a factura electrónica oficial; no generar ni reenviar facturas.
- **Chat, documentos, alertas, presupuestos, gastos, comparativa, planilla, rutas, entregas, flota, compras, devoluciones, activos, reclamos, garantías y reportes avanzados:** existen en código en distintos grados, pero su QA de entorno y de permisos sigue pendiente.
- **Promociones, combos, transformaciones, inteligencia de inventario y recomendaciones de venta cruzada:** no declarar finalizadas para Azure sin preflight específico; la documentación indica migraciones/QA pendientes en varios de estos flujos.
- **API de autenticación:** no presenta JWT ni autorización de API para pedidos, inventario, facturación, clientes, roles o permisos. No usar Swagger para operaciones POST.

## Resumen final para el equipo

- **Hosting confirmado:** <https://web-trilogia-cursos-dev-cr01-bbeyeedbfjejcgau.centralus-01.azurewebsites.net/>
- **Módulo aprobado para demo sin credenciales:** catálogo, filtros, detalle y vista de carrito.
- **Módulos aprobables solo tras preflight privado:** checkout/pedido QA, portal de pedidos/comprobante propio e inventario administrativo en consulta.
- **Módulos excluidos:** venta offline, SMTP/recuperación, facturación administrativa y los módulos sin QA Azure autenticado listados arriba.
- **Riesgos principales:** falta de credenciales QA autorizadas, ausencia de pedido/comprobante QA propio, stock dinámico, autorización pendiente para crear pedido, y potencial exposición de datos personales si no se prepara el navegador.

