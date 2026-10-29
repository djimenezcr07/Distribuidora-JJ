# Stage 2.6 — Inventario de ventas y logística

Fecha de revisión: 31 de agosto de 2026  
Alcance: presentación y experiencia. Los contratos de controladores, servicios, permisos, ownership, sincronización y almacenamiento permanecen sin cambios.

## Fuentes revisadas

- Controladores: `SellerOrders`, `DriverDeliveries`, `DeliveryBoard`, `DeliveryEvidence`, `RoutesAdmin`, `Vehicles`, `Fleet`, `SellerPerformance`, `SalesReports` y `MyGoal`.
- Modelos reales: `SellerOrderViewModels`, `DeliveryViewModels`, `RouteViewModels`, `VehicleViewModels`, `FleetViewModels` y `SalesReportViewModels`.
- Vistas, `_FieldLayout`, los estilos Stage 2 existentes, `driver-deliveries.js` y el almacenamiento offline ya implementado.

## Inventario funcional

| Dominio | Controlador y acciones | Superficie / modelo | Acceso y ownership | Contrato que no se altera |
|---|---|---|---|---|
| Venta móvil | `SellerOrders.Index`, `Create`, `SyncOffline`, `Confirmation`, `RetainedConfirmation`, `MyOrders` | `SellerOrderCreateViewModel`, productos, clientes y confirmaciones | `VENTA_MOVIL_CREAR`; detalle y confirmaciones sólo si `SellerOwnsOrderAsync` | `Create` y `SyncOffline` conservan anti-forgery, IDs/names, stock, precios, promociones, identificación, `OperationToken`/GUID y POST offline. |
| Meta propia | `MyGoal.Index` | progreso de meta del vendedor | `METAS_PROPIAS_VER`; usuario de sesión | Sólo expone el resultado propio que devuelve el servicio. |
| Rendimiento / ventas | `SellerPerformance.Index/Print/ExportCsv`, `SalesReports.Index/Print/ExportCsv` | filtros y reportes de lectura | `REPORTES_VENDEDORES_VER` / `REPORTES_VENTAS_VER` | Filtros, exportación y modo impresión existentes; no se agregan KPIs ni gráficos no respaldados por el modelo. |
| Rutas de chofer | `DriverDeliveries.Index`, `Route` | `DriverRouteItemViewModel`, `DriverRouteViewModel` | sesión `Chofer` o `Administrador`; ruta consultada con usuario actual | La vista es Field mobile-first; una ruta no autorizada sigue la respuesta definida por controlador. |
| Entregas / offline | `DriverDeliveries.UpdateStatus` | tarjetas por `RutaPedidoId` | mismo acceso de chofer; operación idempotente por `syncGuid` | POST anti-forgery, cola cifrada/local existente, estados reales y llamada `UpdateDeliveryStatusAsync`. |
| Evidencia | `DriverDeliveries.RegisterEvidence`; `DeliveryEvidence.View` | foto/firma, observaciones y archivo | sesión, ownership validado por servicio; lectura autorizada | `multipart`, tamaño/rate limit, `pedidoId`, `rutaId`, `tipo`, firma y flujo stage/commit no cambian. No se crean archivos ni rutas ficticias. |
| Tablero | `DeliveryBoard.Index`, `Snapshot` | `DeliveryBoardViewModel` | `ENTREGAS_TABLERO_VER` | Snapshot sin caché y rate limit conservados. |
| Rutas administrativas | `RoutesAdmin.Index/Create/Detail/AddOrder/RemoveOrder/Dispatch/Cancel/Sequence/SaveSequence/Recalculate/Liquidate/Evidences` | cabecera, órdenes asignables, evidencias | `RUTAS_GESTIONAR`; evidencias `ENTREGAS_EVIDENCIA_VER` | Todos los POST continúan con anti-forgery, los estados los decide la lógica existente y las notificaciones/auditoría no se modifican. |
| Vehículos | `Vehicles.Index/Create/Edit/ToggleStatus` | `Vehicle*ViewModel` | `RUTAS_GESTIONAR` | CRUD y toggle existentes, binding y anti-forgery intactos. |
| Flota | `Fleet.Mileage/OpenMileage/CloseMileage`, `Maintenance/CreateMaintenance/CompleteMaintenance`, `Alerts/CreateDocument` | kilometraje, mantenimiento y alertas | `FLOTA_KILOMETRAJE` / `FLOTA_MANTENIMIENTO` | Concurrencia, ownership, unidades, documentos y POST actuales permanecen intactos. |

## Estado de presentación previo

Todas las vistas inventariadas heredaban el layout histórico mediante `_ViewStart`; varias cargaban `custom-theme.css`, incluían Font Awesome, Bootstrap visual e inline styles. `DriverDeliveries.Route` contiene la cola offline real de `driver-deliveries.js`, almacenamiento local con TTL y mapa Leaflet existente; el rediseño debe mantener dirección textual y no puede simular mapas ni offline inexistentes.

## Pre-gate UI UX Pro Max

| Criterio | Decisión verificable |
|---|---|
| Objetivo / acción primaria | Venta móvil prioriza cliente → productos → cantidades → resumen → confirmar. Chofer prioriza la siguiente entrega, estado y evidencia; administración prioriza lista, filtro y acción real. |
| Jerarquía y densidad | Workspace usa encabezado, filtros y tablas/cards compactos; Field usa tarjetas operativas, sin gráficas ornamentales ni tablas anchas. |
| Navegación | Vendedor permanece en Workspace. Chofer usa Field con destinos reales y un máximo de cuatro accesos; no se inventa una pantalla de evidencias inexistente. |
| Responsive y touch | Controles Field de 44 px o más, información de dirección siempre visible, formularios de evidencia/cantidad con etiquetas nativas y scroll local para tablas. |
| Estados / prevención | StatusBadge textual, avisos de cola pendiente y validación inline; “Entregado” sigue siendo la acción dominante y una incidencia queda como acción secundaria. |
| Accesibilidad | landmarks, skip link, foco visible, encabezados secuenciales, iconos decorativos ocultos y controles con nombre accesible. |
| Conectividad | El indicador se limita al mecanismo de cola y eventos de red que ya posee `driver-deliveries.js`; no se presenta como capacidad de servidor ni se sustituye la sincronización existente. |

## Evidencia UI UX Pro Max usada

Se consultaron `ui-reasoning.csv` mediante `search.py` para captura de pedido móvil, selección táctil de productos, operación de entrega/ruta, conectividad offline, formularios Field y tablas operativas. Hallazgos aplicados: jerarquía funcional antes que decoración, objetivos táctiles de 44–48 px, separación de acciones destructivas, feedback contextual de sincronización y adaptación de tablas mediante scroll local o tarjetas. Las búsquedas de iconografía específica de navegación no devolvieron resultados; se reutiliza el sprite Phosphor autocontenido aprobado.

## Criterio de salida 2.6

La fase sólo se marcará PASS tras migrar las superficies activas al layout correcto, retirar dependencias visuales legacy de esas vistas, revisar formularios/tabla/Field y ejecutar la suite contractual. Cualquier dependencia externa real (Leaflet/tiles, credenciales o QA autenticado) quedará como WARN documentado, nunca como capacidad simulada.
