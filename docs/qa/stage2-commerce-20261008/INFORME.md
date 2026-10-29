# Stage 2 — Bloque 5: Combos y Promotions

Fecha: 2026-10-08. Trabajo local en `codex/stage2-design-system`.

**Resultado: implementación completa y gate técnico verde. Bloque 5 cerrado con las dos excepciones de QA aceptadas expresamente por el usuario el 2026-10-08. Checkpoint exclusivamente local autorizado.**

## 1. SHA inicial

`5b9d424ee5a30caee262159b286354cdb774a54c`. HEAD coincide y contiene el commit solicitado. Se revisaron status, rama, doce commits, diff completo e índice vacío antes de editar. No se integró ninguna rama.

## 2. Vistas y contratos auditados

Siete rutas: Combos/Index, Create, Detail; Promotions/Index, Create, Edit, Segments. Parcial existente `_PromotionFields`; nuevos `_ComboNavigation` y `_PromotionNavigation`. Se revisaron ambos controllers, view models, servicios, procedimientos de combos de migración 0012 y promociones CU-171/174, permisos, pruebas existentes, layout, CSS y mecanismo `data-djj-confirm`. Home/ComboDetail se mantuvo fuera del alcance administrativo.

## 3. Funcionalidad histórica identificada

Se comparó Combos/Index con su versión anterior a `3f7729b` y se revisaron commits `fce562f`, `09eef1a`, `6c1d36f` y el historial de Promotions. Las vistas de Promotions no tenían diferencias frente a su origen histórico `0a5a2b8`: seguían legacy. Se conservaron fecha/autor, precio, componentes, stock y cobertura; descuentos por producto estratégico, regalías por volumen, mínimos, prioridades, segmentos y vigencia. El contrato de descripción del combo estaba disponible y ahora se presenta en el listado. No había total de precios individuales en ComboDetail: no se inventó.

## 4. Funcionalidad preservada

Sin cambios en controllers, servicios, modelos de dominio, rutas, actions, SQL, permisos ni reglas comerciales. Se preservaron antiforgery, nombres y campos indexados, IDs, hidden fields, tipos, límites y normalización del servidor. Create/Edit usan exactamente el mismo parcial. El estado técnico continúa controlando las acciones; no se confunde con el estado comercial derivado. Los mensajes TempData los presenta el layout existente.

## 5. Combos

Tabla operativa con descripción, trazabilidad, precio alineado, cantidad de componentes, unidades disponibles, estado técnico y disponibilidad. Acciones condicionadas a COMBOS_GESTIONAR. Create separa identidad/precio, tabla de selección y revisión; conserva 26 productos activos disponibles en este entorno y sus campos indexados. Detail conserva las cinco columnas de composición/cobertura y trazabilidad. Se corrigió el error de presentación de componentes: antes ModelOnly excluía errores de Productos y no existía un span para ellos; ahora summary All y mensajes de componentes/cantidad son visibles.

## 6. Promotions

Listado con nombre, prioridad, tipo/beneficio, producto, segmento, fechas completas, estado comercial y técnico. Filtros GET buscar/estado conservados. Próxima/Vencida se derivan únicamente como presentación; Vigente de SQL conserva autoridad y no se habilitan acciones con base en la etiqueta comercial. Las tres promociones locales están técnicamente Activa y vencidas por fecha: esa diferencia se muestra explícitamente. Create/Edit separan datos, beneficio, producto/condiciones, vigencia, segmento y revisión.

## 7. Segments

Listado, correo, segmento actual, destino y contrato SetSegment intactos. Filtro GET y empty state claros; confirmación agregada antes del cambio de asignación. El contrato existente es una asignación Minorista/Mayorista sobre usuarios: no hay catálogo CRUD independiente de segmentos ni campo de estado que agregar sin cambiar negocio.

## 8. Partials

_PromotionFields conserva doce campos con validación y hooks promoTipo/promo-descuento/promo-regalia. Label de Tipo asociado explícitamente a promoTipo. Los dos parciales de navegación comparten contexto de dominio; inventario filtra enlaces con los permisos reales de sus endpoints. Ninguno declara layout propio.

## 9. CSS y layout compartidos

workspace.css agrega composición de formularios de comercio en dos columnas desktop y una móvil, espaciado por tokens y soporte hidden. No se modificaron tokens, base, components, storefront, field ni utilities. _WorkspaceLayout agrega acceso a Promotions por PROMOCIONES_GESTIONAR y acceso directo a Combos para quien tiene COMBOS_VER sin INVENTARIO_VER. No se cargan Bootstrap, Font Awesome ni custom-theme en las vistas migradas.

## 10. JavaScript

promotions.js sustituye los dos scripts inline duplicados. Alterna grupos con hidden conservando valores y contratos de envío; no deshabilita ni borra campos. Se reutiliza layouts.js sin modificarlo para confirmaciones. Siete regresiones JS cubren ambas variantes, cambios, ausencia de formulario y cancelación del submit para los tres contratos de estado/asignación.

## 11. Responsive

28 combinaciones: siete rutas en 1440, 1280, 768 y 390 px. Todas con un h1, etiquetas asociadas, imágenes correctas y sin assets legacy. documentElement.scrollWidth no supera clientWidth en ninguna; controles dentro de sus tarjetas. Tablas con scroll local, caption y región enfocables. Create/Edit fueron visitadas en los cuatro anchos; además se abrió una edición de regalía existente para confirmar la otra variante. Overrides de viewport y movimiento reducido restaurados al finalizar.

## 12. Accesibilidad focalizada

Jerarquía h1/h2 y h3 solo para estados vacíos; nombres visibles y específicos para acciones; selección/cantidad de productos con label; captions y scope col. Tab y teclado en tipo de beneficio; flecha derecha mueve la tabla sin mover la página. Drawer móvil abre y cierra con Escape y restaura el foco. Foco en Descripcion con outline visible y sombra de 3px. Movimiento reducido: transiciones de 0.00001s. Muestra de contraste: CTA 9.67:1, info 6.33:1, neutral 5.94:1 y acción danger-outline 5.90:1. No equivale a certificación WCAG.

## 13. Console

Cero errores o advertencias relevantes en la aplicación durante las rutas revisadas. La incidencia del control del navegador se registra por separado y no se oculta como resultado verde del QA.

## 14. Network

Auditoría final por ventanas cortas de captura: 28 navegaciones, todas con documento HTTP 200, sin truncamiento de eventos, sin solicitudes POST ni errores de carga/HTTP >=400. Incluye scripts de validación, promociones, layout, CSS, logos y fuentes. La primera pasada tenía ventanas susceptibles de truncamiento; se sustituyó por esta medición completa. Esta pasada posterior no elimina el POST accidental anterior.

## 15. Build

`dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: correcto, cero advertencias y cero errores. MVC/API se detuvieron para evitar bloqueo de binarios y después se levantaron con sus perfiles existentes, sin cambios de configuración. Probe de solo lectura confirmó Development y TrilogiaDev en ambos; API responde HTTP 200. La primera compilación detectó una advertencia xUnit sobre conteo y se corrigió antes del build definitivo.

## 16. Pruebas .NET

`dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: 358 correctas, cero fallidas y cero omitidas. Dieciocho nuevas regresiones cubren rutas/layouts/tablas, binding, antiforgery, permisos, campos y autoridad SQL de estados de presentación.

## 17. Pruebas JS

Foundations: 11 correctas. Comercio: 7 correctas. Cero fallidas/omitidas/canceladas. Se carga el script real de confirmación en runtime aislado: devolver false cancela submit en ToggleStatus, Inactivate y SetSegment.

## 18. Diff check

`git diff --check`: correcto. Hashes SHA-256 de las cuatro vistas del usuario intactos.

## 19. Diff stat

Diff de los diez archivos ya rastreados de este bloque: 222 inserciones, 485 eliminaciones. Se añaden helper de presentación, dos parciales de navegación, script, pruebas .NET/JS e informe. El diff de flota no forma parte del bloque. El checkpoint incluye únicamente los 17 archivos de este bloque; la estadística total se revisa en el índice antes del commit.

## 20. SHA del checkpoint local

El usuario autorizó expresamente el checkpoint `feat(stage2): modernize combos and promotions` el 2026-10-08, aceptando ambas excepciones documentadas. El SHA completo se reporta después de crear el commit y puede consultarse con `git log -1 --format=%H`. No se declara certificación E2E de cancelación nativa.

## 21. Estado local

Rama codex/stage2-design-system. Se verificó HEAD inicial e índice vacío antes del staging explícito de los 17 archivos del bloque. Las cuatro modificaciones del usuario permanecen fuera del checkpoint. Artefactos privados de QA en .git/codex-checkpoints/20261008-commerce, fuera de versionado.

## 22. Exclusiones deliberadas

Fleet/Mileage y Vehicles/Create/Edit/Index no se modificaron ni deben stagearse. Chat, DriverDeliveries, SellerOrders, ManagerOrders, Storefront, SQL, secrets y connection strings no se tocaron. Se preservaron todos los archivos personales y .agents no rastreados; capturas autenticadas, huellas SQL y logs privados no se incluyen en Git.

## 23. Incidencia y limitaciones reales

Durante el intento de abrir/cancelar la confirmación del combo #1, la interacción del navegador con el diálogo nativo terminó con un timeout y el combo quedó Inactivo. Se confirmó la modificación por interfaz y comparación SQL de solo lectura. No se ha establecido si la aceptación ocurrió en el puente de automatización o por otra interacción; no se atribuye sin evidencia a una regla de negocio. Se detuvo inmediatamente el QA de acciones de escritura y se informó al usuario.

El usuario autorizó expresamente restituir **solo el combo #1 a Activo**. Se ejecutó una actualización local condicionada a ID, nombre y estado previo, en transacción, comprobando exactamente una fila. Estado Activo confirmado. Se conservaron los metadatos de actualización y la entrada InventarioOperacionAuditoria creada por la operación original: la huella completa de Combos no coincide con la inicial por esa trazabilidad. No se borró ni se manipuló auditoría. Promociones y asignaciones conservan sus huellas iniciales; después de la restitución no hubo más cambios en las tres huellas.

La cancelación de confirmaciones pasó en pruebas aisladas del JS real, pero no se acredita como QA nativo completado para las tres operaciones. No se volvieron a pulsar botones de estado/asignación. No se probó crear combos, guardar promociones ni guardar segmentos. Validación vacía de Create de ambas familias mantuvo la ruta y produjo errores sin guardar; Combos registró cero POST. El mensaje mínimo de precio de jQuery aparece en inglés, como en el contrato previo; no se modificaron validadores globales. No se sembraron estados comerciales activos/próximos/inactivos; esas ramas se cubren mediante pruebas unitarias.

## 24. Límites y cierre

Sin push, PR, escritura remota, merge, migraciones, cambios de User Secrets o connection strings. **No puede afirmarse NO CAMBIOS DE DATOS:** ocurrió la incidencia descrita y se realizó la restitución específicamente autorizada. El usuario aceptó expresamente la escritura accidental y su restitución conservando auditoría, así como la cobertura aislada del JavaScript real sin certificación E2E del diálogo nativo. Autorizó cerrar el Bloque 5 y crear únicamente el checkpoint local. No se repiten acciones destructivas, no se modifican nuevamente datos y no se inicia el siguiente bloque. El informe preserva las excepciones sin presentar el QA original como completamente libre de escrituras.
