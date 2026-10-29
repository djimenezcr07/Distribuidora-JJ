# Stage 2 — Bloque 6: Seller Orders + Manager Orders

Fecha: 2026-10-08. Estado: implementación local terminada; gate de integración real pendiente. El usuario autorizó expresamente un checkpoint local para preservar la implementación técnicamente validada. El checkpoint NO certifica integración SQL/E2E; las limitaciones del punto 28 permanecen pendientes.

## 1. SHA inicial

`facafb917431ddd40e154d06734ea47caa0d532f`, rama `codex/stage2-design-system`. HEAD permanece igual. Frente al ref local guardado `origin/codex/stage2-design-system`: ahead 4 / behind 0; no fetch ni escritura remota.

## 2. Vistas auditadas

Las siete vistas SellerOrders/Index, MyOrders, Confirmation, RetainedConfirmation y ManagerOrders/Index, Review, ApproveConfirmation; layouts Workspace, parciales de mensajes/validación, contratos MVC y servicios existentes. Se añadieron tres parciales de resumen, líneas y enlace autorizado al detalle administrativo. Se revisaron AGENTS.md y documentación Stage 2.

## 3. Contratos funcionales identificados

Se preservan las acciones, binding indexado de productos, IDs de DOM, prefijo RechazarForm, pedidoId, ModelState, antiforgery, permisos y ownership. Los totales definitivos proceden del servidor; la estimación del formulario permanece separada. No cambios en controladores, servicios, SQL ni reglas. Retención es condición de negocio; aprobación libera, revalida stock, descuenta y factura; rechazo exige motivo sin descontar inventario, según el contrato versionado CU098. Ese contrato no coincide completamente con la instalación local actual; ver punto 28.

## 4. Información histórica recuperada

Comparación de las vistas anteriores en Git y scripts versionados CU098/CU102 para conservar cliente/correo, fecha, entrega/dirección, observaciones, líneas, cantidades, precios, total, factura, actualización y motivo de rechazo cuando el modelo los aporta. No se inventan umbrales, métricas, vendedor de cabecera, motivo de retención, impuestos ni subtotales ausentes del contrato. Estados desconocidos se muestran literalmente con tono neutral.

## 5. SellerOrders/Index

Workspace; cliente y entrega, productos con cantidades, estimación y cola offline legibles; etiquetas, validación y resumen de errores enfocable. Se mantiene el JavaScript operativo existente. Cola y acciones envuelven en móvil sin recortar badges. Sin footer fijo que tape campos.

## 6. SellerOrders/MyOrders

Tabla compacta con cliente, fecha, total, estado, factura, actualización y acciones. Motivo de rechazo y retención disponibles cuando corresponde; vacío explícito. «Ver estado» utiliza confirmación propia según estado; enlace administrativo solo autorizado. La cuenta real Vendedor probada no tiene pedidos; no se crearon para cubrir estados.

## 7. Confirmation

Resumen y líneas compartidos; muestra estado actual y factura únicamente cuando HasInvoice y número son válidos. No atribuye aprobación ni factura a una consulta sin esos datos. Integración real limitada por procedimiento faltante de factura.

## 8. RetainedConfirmation

Advertencia únicamente para estado Retenido; si cambió, comunica estado actual. Informa el significado contractual de retención sin umbral inventado. Observaciones y motivo de rechazo condicionales. Corrección móvil de avisos de texto y contención de tablas.

## 9. ManagerOrders/Index

Bandeja retenida conservando búsqueda GET, cliente/correo, vendedor, fecha, canal/entrega, cantidad de líneas, total, estado y revisión. Sin estadísticas inventadas. Apariencia comprobada con datos sintéticos; integración real bloqueada por procedimiento faltante.

## 10. ManagerOrders/Review

Resumen, líneas, disponibilidad con texto suficiente/insuficiente y valor; alerta de revalidación. Formularios separados de aprobación y rechazo, motivo visible, validación, tokens y confirmaciones. Ninguna decisión real se ejecutó. Sin pedido retenido elegible en la base local.

## 11. ApproveConfirmation

Solo resultado recibido por TempData: pedido, estado y factura. Enlace al detalle sujeto al permiso real. Casos con/sin TempData comprobados por prueba directa del controlador sin SQL; vista con modelo sintético en navegador. No confirmación operacional real.

## 12. Permisos

Navegación SellerOrders por VENTA_MOVIL_CREAR y ManagerOrders por PEDIDOS_AUTORIZAR_RECHAZAR. Enlace OrdersAdmin sujeto a Administrador o permiso del módulo Pedidos, siguiendo su filtro existente. No cambios de autorización. Vendedor real muestra Venta móvil y oculta revisión gerencial. Miga Workspace vuelve a la bandeja de la familia autorizada. Fixture utiliza permisos simulados y no demuestra permisos reales.

## 13. Antiforgery

Tokens preservados en creación, aprobación y rechazo; contrato de token en sincronización preservado y comprobado en mock. No se enviaron formularios operativos reales.

## 14. Offline

Storage privado existente por usuario; TTL 24 h; GUID de idempotencia, payload mínimo, reintento, manejo de error y sincronización al recuperar conexión preservados. Pruebas ejecutan JavaScript real con almacenamiento/fetch simulados. No E2E real de creación ni sincronización; no se guardaron pedidos de prueba.

## 15. Confirmaciones

Aprobar/rechazar usan data-djj-confirm y el layouts.js real. Aceptar/cancelar comprobados aisladamente; cancelación impide submit. No se certifica diálogo nativo E2E. No se pulsaron botones operativos para demostrar cobertura.

## 16. Responsive

1440/1280/768/390 px: 28 combinaciones finales de las siete vistas en host privado que ejecuta Razor de producción con datos sintéticos y bloquea métodos distintos de GET. Sin desbordamiento de página, imágenes rotas ni botones sin etiqueta; un h1 por vista. Tablas mantienen scroll local. Dos vistas reales de vendedor: ocho combinaciones finales correctas. También hubo ocho comprobaciones previas con Administrador. Se corrigieron cola móvil, min-width de tarjetas y avisos de texto en grid. La última corrección es exclusivamente CSS estático y fue verificada en navegador después del build definitivo.

## 17. Accesibilidad

H1 único, jerarquía, labels, captions y scope en tablas, importes es-CR, estados con texto, alertas y resumen de errores enfocable. Menú móvil abre, enfoca Cerrar navegación, cierra con Escape y devuelve foco al botón Abrir navegación, comprobado en sesión real. Sin certificación exhaustiva de lector de pantalla ni medición integral WCAG de contraste.

## 18. Console

Lectura final de warnings/errors en pestaña real: ninguno. Los errores de invocación de herramientas no son errores de consola de la aplicación. No se extiende este resultado a rutas gerenciales sin integración real disponible.

## 19. Network

Captura final completa sin truncamiento de recarga GET MyOrders: documento 200, cero métodos distintos de GET, cero loadingFailed y cero respuestas >=400. Las navegaciones reales SellerOrders/MyOrders observadas también respondieron 200. No se atribuye ese resultado a ManagerOrders ni a operaciones POST. Las autenticaciones fueron manuales del usuario.

## 20. Build

`dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: 0 errores, 0 advertencias. MVC/API reiniciados después de la compilación; el usuario restauró sesión Vendedor. Ajuste posterior solo de CSS servido estáticamente, sin modificación de C#/Razor/JS compilados.

## 21. Tests .NET

`dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: 382 correctos, 0 fallidos, 0 omitidos (baseline 358 + 24). Incluyen presentación, contratos, binding, permisos, tokens y confirmación TempData sin base de datos.

## 22. Tests JS

Foundations 11 + commerce 7 + orders 13 = 31 correctos, 0 fallidos/omitidos. Nuevo `scripts/ui/stage2-orders.test.cjs`: estimación, validación, cola/TTL/GUID/payload, retry, transporte/token simulados, conexión, disclosure/escape y cancelación/aceptación con el JavaScript real. No hacen POST a aplicaciones reales.

## 23. Diff --check

`git diff --check` correcto antes del staging; `git diff --cached --check` se verifica antes del commit. Avisos LF/CRLF son normalización de Git, sin errores whitespace.

## 24. Diff stat y archivos del bloque

Nueve archivos tracked modificados y siete nuevos previstos, incluido este informe. El stat de Git no contabiliza archivos untracked. Las cuatro vistas previamente modificadas se excluyen del stat siguiente.

```text
 .../Views/ManagerOrders/ApproveConfirmation.cshtml |  63 +---
 .../Views/ManagerOrders/Index.cshtml               | 120 +------
 .../Views/ManagerOrders/Review.cshtml              | 187 +----------
 .../Views/SellerOrders/Confirmation.cshtml         | 105 +-----
 .../Proyecto_Final/Views/SellerOrders/Index.cshtml | 366 ++++-----------------
 .../Views/SellerOrders/MyOrders.cshtml             | 157 +--------
 .../Views/SellerOrders/RetainedConfirmation.cshtml | 110 +------
 .../Views/Shared/_WorkspaceLayout.cshtml           |  16 +-
 .../wwwroot/css/stage2/workspace.css               |  28 ++
 9 files changed, 146 insertions(+), 1006 deletions(-)
```

Rutas explícitas del bloque:

- `Proyecto_Final/Views/SellerOrders/Index.cshtml`
- `Proyecto_Final/Views/SellerOrders/MyOrders.cshtml`
- `Proyecto_Final/Views/SellerOrders/Confirmation.cshtml`
- `Proyecto_Final/Views/SellerOrders/RetainedConfirmation.cshtml`
- `Proyecto_Final/Views/ManagerOrders/Index.cshtml`
- `Proyecto_Final/Views/ManagerOrders/Review.cshtml`
- `Proyecto_Final/Views/ManagerOrders/ApproveConfirmation.cshtml`
- `Proyecto_Final/Views/Shared/_WorkspaceLayout.cshtml`
- `Proyecto_Final/Views/Shared/_OrderWorkflowSummary.cshtml`
- `Proyecto_Final/Views/Shared/_OrderWorkflowLines.cshtml`
- `Proyecto_Final/Views/Shared/_OrderWorkflowDetailLink.cshtml`
- `Proyecto_Final/Models/Presentation/OrderStatusPresentation.cs`
- `Proyecto_Final/wwwroot/css/stage2/workspace.css`
- `Proyecto_Final.Tests/OrderWorkflowPresentationTests.cs`
- `scripts/ui/stage2-orders.test.cjs`
- `docs/qa/stage2-orders-20261008/INFORME.md`

## 25. SHA del commit

El usuario autorizó el commit local `feat(stage2): modernize order workflows` pese al gate de integración pendiente. Este informe se incluye en ese checkpoint; el SHA resultante se comunica después de crearlo. No certifica integración SQL/E2E ni autoriza corregir SQL, datos o iniciar otro bloque.

## 26. Git status final

Snapshot previo al checkpoint: nueve archivos tracked del bloque modificados, siete archivos nuevos del bloque y cuatro vistas previas modificadas. Los archivos personales y auxiliares ajenos permanecen fuera. El estado posterior exacto se entrega después del commit, sin copiar nombres de documentos personales al informe versionado.

## 27. Archivos excluidos

Fleet/Mileage.cshtml y Vehicles/Create.cshtml, Edit.cshtml, Index.cshtml permanecen modificados por el trabajo previo y fuera de este bloque. SHA256 de los cuatro coincide con el snapshot previo: 4/4 intactos. Se excluyen .agents, cachés, documentos personales, capturas/logs privados, fixture y demás untracked ajenos. Evidencias privadas bajo .git/codex-checkpoints/20261008-orders, fuera de versionado. No secretos, configuración privada ni datos operativos añadidos por el bloque. El staging autorizado queda limitado a las 16 rutas enumeradas.

## 28. Limitaciones reales y datos

Base local de desarrollo verificada por metadatos de solo lectura, usando la configuración existente sin versionarla. Faltan sp_Manager_GetRetainedOrders, sp_Manager_ApproveOrder, sp_Manager_RejectOrder y sp_Admin_GetInvoiceSummaryByOrder. La versión instalada sp_Seller_CreateOrder no contiene el contrato de retención/facturación automático esperado por MVC. Hay cero pedidos Retenido. No se ejecutaron scripts históricos para repararlo. El fixture no sustituye E2E real ni evidencia de stock/facturación. Permanece pendiente validar integración en un entorno compatible con datos ya existentes y autorización específica si se requiere cualquier cambio de entorno.

Comparación SHA256 de JSON ordenado antes/después: Pedidos (70), Productos (27), Facturas (40), PedidoDetalle (153): los cuatro hashes idénticos. Evidencia de integridad de esos datos operativos; no afirmación de igualdad de todas las tablas, pues el usuario inició sesión manualmente y puede existir auditoría de autenticación. Fixture privado detenido y pestaña cerrada; MVC/API disponibles, sesión real conservada.

## 29. Confirmaciones de alcance

NO PUSH. NO PR. NO ESCRITURA REMOTA. NO MIGRACIONES. NO CAMBIOS DE DATOS OPERATIVOS POR EL AGENTE. No siguiente bloque iniciado. Checkpoint local autorizado con staging explícito de las 16 rutas del bloque; sin certificación de integración SQL/E2E. No SQL de escritura, aprobación/rechazo, creación, retención, liberación ni facturación real.
