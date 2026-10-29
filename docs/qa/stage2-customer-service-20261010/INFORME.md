# Stage 2 — Bloque 10: servicio al cliente

Fecha: 2026-10-10. Implementación local preservada mediante checkpoint expresamente autorizado por el usuario; gate SQL/E2E de Reclamos y Garantías **pendiente**. El checkpoint no certifica integración ni mutaciones reales.

## 1. Punto de partida

HEAD inicial: `a0f4283caf4a6d2e735f4ab1028804e2ef4f3ef3`. Rama `codex/stage2-design-system`; al inicio, ahead 8 / behind 0 frente a la referencia **local** de `origin/codex/stage2-design-system`, sin fetch ni escritura remota. Baseline: 470 pruebas .NET y 69 JS.

## 2. Contratos auditados e historia

Se revisaron los tres controllers, sus seis vistas anteriores, modelos de consultas/reclamos/garantías, AdminDbService, ReclamosDbService, AdminAuthorizeAttribute, creación de consultas en Home/Contact, permisos y antiforgery. SQL revisado como fuente, sin ejecución ni cambios:

- `database/cu033_consultas_patch.sql`: contrato histórico básico de consultas.
- `database_Esteban/Fase3_2-3.sql`: atención con observación interna, actor y fecha.
- `database_Esteban/cu191_192_reclamos.sql`: creación, búsqueda, detalle, clientes, facturas y estados de reclamos.
- `database/migrations/0006_warranty_workflow.sql`: solicitudes, consulta administrativa, resolución terminal y auditoría de garantías.
- Catálogo y permisos granulares de las migraciones 0028/0029, únicamente como evidencia de los códigos existentes.

Historia consultada: `f45f7fd` (historial de consultas), `d8eb978` (garantías), `14e2a5e` (reclamos), `8de776d` y `3a38036` (integración y seguridad). La información recuperada está respaldada por modelos y servicios actuales. No se recuperan estilos legacy ni se cambian reglas de negocio.

## 3–8. Las seis páginas

| Página | Resultado de presentación |
|---|---|
| Consultations/Index | Bandeja compacta con asunto/id, cliente/correo, registro, estado literal, última atención/responsable y detalle. Conserva filtros GET `estado`/`buscar` y contador. |
| Consultations/Details | Identidad, asunto, mensaje, correo, fechas y actor. Observación interna existente visible en lectura; edición únicamente con permiso de atención. |
| Reclamos/Index | Bandeja compacta con asunto/id, contacto, categoría/prioridad, factura disponible, registro/cierre, estado y detalle. Conserva filtros GET y creación autorizada. |
| Reclamos/Create | Workspace administrativo confirmado por controller. Mantiene UsuarioId, FacturaId, Categoria, Prioridad, Asunto y Descripcion; conserva PedidoId oculto si el modelo lo aporta. Fieldsets, errores por campo y resumen enfocable. |
| Reclamos/Details | Recupera relaciones opcionales, importe/fecha de factura, contacto, agente de registro, actualización, cierre/responsable y resolución existente. No inventa historial de eventos. |
| WarrantyRequestsAdmin/Index | Bandeja independiente de garantías: solicitud/fecha, pedido/producto, cliente, motivo/descripción, estado, resolución/fecha y gestión permitida. |

Todas usan `_WorkspaceLayout`, un h1 y `_CustomerServiceNavigation`. No se añadieron productos a reclamos: el modelo no proporciona una asociación de producto. No se añadió un selector de pedido inexistente en la vista anterior.

## 9. Estados

| Dominio | Estados exactos | Presentación |
|---|---|---|
| Consulta | Pendiente, Atendida, Cerrada | info, success, neutral |
| Reclamo | Abierto, EnProceso, Cerrado | info, warning, neutral |
| Prioridad de reclamo | Baja, Media, Alta | neutral, warning, danger |
| Garantía | Pendiente, En revisión, Aprobada, Rechazada | info, warning, success, danger |

Los desconocidos se muestran literalmente en neutral. La presentación no define transiciones ni SLA. Cerrada no se transforma en una prohibición de editar consultas: el contrato auditado no la exige. Reclamo Cerrado y garantías Aprobada/Rechazada sí conservan la terminalidad del SQL fuente. Los detalles de consulta/reclamo con estado desconocido requieren elegir una opción existente antes de enviar.

## 10. Respuestas y resoluciones

Consulta: `RespuestaInterna` es información administrativa; UpdateStatus no envía correo al cliente. Se muestra separadamente del mensaje original. Reclamo: `Resolucion` de POST conserva `ResolucionDescripcion`; SQL exige contenido al cerrar y registra actor/fecha. Garantía: `resolucion` es obligatoria al aprobar/rechazar. No se fusionaron campos ni se modificó contenido almacenado.

## 11. Pedido y factura

Reclamo admite asociaciones opcionales ya existentes, con validación de pertenencia al cliente en el SQL fuente. El listado solo dispone de NumeroFactura; el detalle dispone también de PedidoId/FacturaId/fecha/total. Garantía se origina desde un detalle de pedido entregado perteneciente al solicitante; se muestra pedido y producto devueltos por el servicio. AdminDbService no llena PedidoDetalleId, por lo que no se presenta un identificador ficticio. Sin dependencia nueva del gate 6B ni operaciones sobre pedidos, facturación o stock.

## 12–15. Permisos, antiforgery, confirmaciones y navegación

- Consultas GET: `CONSULTAS_VER`. Atención POST: `CONSULTAS_ATENDER`. La política de acción reemplaza la del controller según el filtro existente.
- Reclamos, incluyendo GET, creación y resolución: `RECLAMOS_GESTIONAR`; no existe un permiso de lectura separado en estos endpoints.
- Garantías administrativas GET/POST: `GARANTIAS_GESTIONAR`.
- Administrador conserva el bypass existente. Sin códigos nuevos ni cambios de autorización.
- Sidebar y navegación contextual muestran únicamente enlaces respaldados por esos permisos. «Ver cliente» en garantías requiere `CLIENTES_VER`.
- Todos los POST conservan antiforgery y sus nombres de binding. Las pruebas revisan los atributos de los endpoints y los formularios.
- Atención, resolución y actualización usan `data-djj-confirm` y el comportamiento global ya probado. No se enviaron esos formularios reales. Cancelación de confirmación cubierta por las regresiones JS de foundations; no se certifica mediante una mutación E2E.

## 16. JavaScript migrado

El JS inline de Reclamos era B/C: obligatoriedad de resolución al cerrar e interacción GET de facturas por cliente. Se extrajo a `customer-service.js` manteniendo IDs `EstadoSelect`, `ResolucionReq`, `ResolucionTxt`, `UsuarioId`, `FacturaId`, endpoint `InvoicesByClient`, parámetro `usuarioId` y JSON `facturaId`/`texto`. Se añadió control de resultados obsoletos y feedback accesible de carga/error, sin POST. Garantías sincroniza la obligatoriedad con sus estados terminales existentes. La validación de creación usa el partial existente y enfoca el resumen de errores. No hay JS inline ni onclick nuevos.

## 17–18. Responsive y accesibilidad

Fixture: seis páginas × 1440, 1280, 768 y 390 = **24 combinaciones válidas**, incluyendo textos de 150 y más de 1000 caracteres, sin overflow horizontal de documento, imágenes rotas ni controles visibles sin label. Revisión final tras ajuste de badges: scrollWidth 1425/1265/753/375 respectivamente; tablas desplazables dentro de su región, no en la página. Badges conservan estado completo sin partirlo.

Se verificaron h1 único, jerarquía de headings, labels, fieldsets/legends, captions y scope=col en las tres tablas, nombres de acciones, regiones desplazables con tabindex=0, resumen de errores activo y errores por campo. Escape cierra el sidebar móvil y devuelve foco a «Abrir navegación». Movimiento reducido: transiciones 0.00001s. Contraste medido de badges: info 6.33:1; warning 6.76:1; success 4.93:1; danger 5.51:1; neutral 5.94:1. Esto no constituye una certificación WCAG completa.

## 19. QA real — lectura

API/MVC levantados con configuración local existente de TrilogiaDev, sin editar secretos/configuración. Administrador autenticado manualmente.

- Consultations Index y un Details descubierto desde su listado: **8 combinaciones reales válidas** a los cuatro anchos; h1, labels e imágenes correctos, sin overflow. Filtro GET Pendiente conservó selección y devolvió resultados.
- Reclamos Index: GET falla con HTTP 503; SqlException 2812, falta `dbo.sp_Reclamos_List`.
- Reclamos Create: GET falla con HTTP 503; SqlException 2812, falta `dbo.sp_Reclamos_Clientes_Buscar`.
- Reclamos Details: no se obtuvo un enlace real desde el listado bloqueado; no se adivinaron IDs. Cubierto sintéticamente.
- WarrantyRequestsAdmin Index: GET falla con HTTP 503 por `IndexOutOfRangeException` en `AdminDbService.GetWarrantyRequestsAsync`, al leer el resultset. El servicio espera once columnas posicionales (0–10); no se certifica la forma instalada del procedimiento ni se modifica para tolerarla silenciosamente.

Se observaron las pantallas de error de Create/Garantías en cuatro anchos, pero **no cuentan como QA de las vistas de negocio**. La pantalla de error legacy presenta overflow desktop y usa inicialización automática de Chat; queda fuera de este bloque.

## 20. QA sintético

Fixture Razor privado, fuera de staging/versionado, con servicios sintéticos y sin conexión SQL; rechaza métodos diferentes de GET. Cubre vacíos de los tres listados, texto largo, estados conocidos/desconocidos, respuesta presente/ausente, relaciones pedido/factura opcionales, reclamo cerrado, garantías terminales y ModelState inválido.

Permiso de solo consulta: mantiene respuesta existente visible, cero formularios mutantes y solo enlace Consultas. Permiso exclusivo de garantía: solo enlace Garantías y cero enlaces Clients/Details. Reclamo cerrado: cero formularios de seguimiento. La presentación de reclamos sin permiso oculta acciones; esto no simula una autorización real a sus endpoints. JSON de facturas sintéticas cargado mediante GET; creación incompleta muestra dos errores y enfoca resumen sin POST. Resolución requerida al cerrar/aprobar comprobada sin guardar.

## 21–22. Console y network

Fixture responsive inicial: cero excepciones Runtime, cero loadingFailed, cero >=400 y cero POST; capturas de eventos sin truncación. Interacción de facturas/validación cliente: solo un GET al endpoint sintético, cero POST.

Consultas reales: cero errores relevantes, cero >=400 inesperados, cero loadingFailed y cero POST de negocio en las combinaciones medidas. Rutas reales bloqueadas: HTTP 503 confirmado, por lo que el gate network global **no está verde**. Las páginas de error disparan automáticamente `POST /chatHub/negotiate?negotiateVersion=1` por su layout existente; no fueron envíos de formularios ni acciones de atención/resolución, y no se atribuyen al fixture ni a las vistas migradas. No se cambiaron Chat ni el layout de errores.

## 23–25. Build y regresiones

- `dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: 0 errores, 0 advertencias.
- `dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: **501 correctas**, 0 failed, 0 skipped (31 nuevas sobre baseline 470).
- Siete scripts JS: foundations, commerce, orders, logistics, assets, documents y customer-service: **77 correctas**, 0 failed, 0 skipped (8 nuevas sobre baseline 69).
- Fixture aislado compilado sin errores/advertencias. No se versiona.

Las regresiones cubren layout, eliminación legacy, permisos y antiforgery reales por reflection, bindings, contratos de respuesta y relaciones opcionales, estados desconocidos/terminales, interacción GET, carrera de facturas, errores y foco. No snapshots completos ni aserciones hexadecimales.

## 26–27. Legacy, diff y seguridad

Detector limitado a Consultations/Reclamos/WarrantyRequestsAdmin: seis páginas Workspace; cero Bootstrap real, Font Awesome legacy, custom-theme.css, dependencia de `_Layout`, estilo inline ni script inline. No se realizó auditoría global de vistas.

`git diff --check` correcto. Revisión de diff de las seis vistas, componentes compartidos y archivos nuevos; sin cambios a controllers, servicios, contratos SQL ni configuración. Staging explícito de únicamente los 14 archivos del bloque para revisión, `git diff --cached --stat`, diff completo y `--check` correctos. Escaneo de secretos correcto: 950 archivos tracked, 907 de texto, 13 placeholders/valores vacíos aprobados. Sin secretos, configuración privada ni datos personales reales en staging. Tras revisión se retiran únicamente esos archivos del index para dejar staging vacío, conservando todos los cambios de trabajo. No se incluye contenido real de QA en este informe.

## 28–29. Checkpoint y estado Git

La primera revisión dejó los cambios sin commit porque el gate real no estaba verde. Posteriormente, el usuario autorizó expresamente el checkpoint local `feat(stage2): modernize customer service workflows`, aceptando que no certifica integración SQL/E2E de Reclamos ni Garantías, QA real pendiente ni mutaciones reales. Se incluyen exclusivamente los 14 archivos del bloque; las exclusiones y hashes protegidos se vuelven a verificar. El SHA completo y el estado exacto posterior al commit se entregan en el cierre, con evidencia privada. No se inicia el Bloque 11.

Archivos del bloque (14): las seis vistas; `_WorkspaceLayout.cshtml`; `_CustomerServiceNavigation.cshtml`; `CustomerServicePresentation.cs`; `workspace.css`; `customer-service.js`; `CustomerServicePresentationTests.cs`; `stage2-customer-service.test.cjs`; este informe.

## 30. Exclusiones y hashes protegidos

Las cuatro vistas previamente modificadas permanecen intactas respecto del inicio y fuera de staging/commit:

| Archivo | SHA256 |
|---|---|
| Fleet/Mileage.cshtml | 0A20E875E8386C50AC9C4CEFBF285F946F0205D1B272DDA97C28084543D71DDE |
| Vehicles/Create.cshtml | B65C4D23B7760AC7BEC558592E8BCE539417E29966A68BFCF1AF5C330A25B514 |
| Vehicles/Edit.cshtml | 37C71BAA326A9D06857838EEE0B14E6CD635219CFE1515F967E7D7FE66F0538E |
| Vehicles/Index.cshtml | 0E34243AC79C09AC24E356D9A04FD3CF320175CBE3BB65EBFAAB6B370F594E47 |

Excluidos: .agents, .cache, archivos personales, DOCX/PDF/PPTX, reportes Azure, capturas y logs privados, fixture/checkpoints bajo .git, Documents, Chat, Roles/Permissions, Bloque 6B y candidate.sql. Los untracked ajenos no se añadieron ni eliminaron.

## 31. Limitaciones y siguiente acción segura

La presentación está validada con modelos aislados; no está certificado E2E el ciclo SQL de reclamos/garantías, las mutaciones reales ni todos los perfiles reales. No se conoce aún el inventario completo de objetos faltantes o la definición instalada exacta de garantías. Los fallos observados ocurren en servicios que no se modificaron en este bloque, antes del render de las vistas nuevas.

Para desbloquear: realizar una auditoría SQL de solo lectura separada de los contratos instalados de Reclamos y `sp_Admin_GetWarrantyRequests`; comparar con las fuentes históricas y con el lector C#. Diseñar una corrección compatible y su rollback antes de autorizar cualquier escritura. Después repetir QA real GET y evaluar el gate funcional de forma independiente de este checkpoint de presentación. No se inicia esa reparación ni el siguiente bloque desde este trabajo.

## 32. Restricciones

**NO PUSH / NO PR / NO ESCRITURA REMOTA / NO MIGRACIONES / NO CAMBIOS DE DATOS.** No se crearon reclamos, respondieron consultas, resolvieron reclamos ni actualizaron garantías reales. Tampoco se modificaron pedidos/facturas/stock. No merge, rebase ni cambios a User Secrets o connection strings.
