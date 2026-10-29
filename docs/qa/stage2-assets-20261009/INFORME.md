# Stage 2 — Bloque 8: Assets y Comodatos

Fecha: 2026-10-09. Trabajo exclusivamente local sobre `codex/stage2-design-system`.
Gate de presentación, contratos de formularios y lectura real aprobado. Las operaciones de escritura no se ejecutaron ni se certifican E2E.

## 1. SHA inicial y protección del estado

HEAD inicial: `0f37885ff9a0bb0803920093291835ec0e90f049`.
Referencia local de `origin/codex/stage2-design-system`: ahead 6 / behind 0 antes del checkpoint.
Se inspeccionaron status, rama, historia, diff e índice; el índice estaba vacío.
Se preservaron patch y hashes anteriores en un checkpoint privado bajo `.git/codex-checkpoints/stage2-assets/20261009`, fuera del versionado.
No se hizo fetch ni operación remota.

## 2. Vistas y dependencias auditadas

Assets: Index, Create, Edit, Details y `_AssetFields`.
Comodatos: Index, Assign y Profitability.
También `_WorkspaceLayout`, `_ValidationScriptsPartial`, servicios MVC, modelos Admin, controllers, `AdminAuthorizeAttribute`/filtro, catálogo de permisos, JS de confirmación del layout y estilos Stage 2. SQL histórico leído: database_Esteban/cu152_153_154_161_flota_activos.sql, cu162_163_164_comodatos.sql y cu165_activos_ajustes.sql; sin ejecutar SQL.
Se leyeron AGENTS.md, referencias, sistema Stage 2 y guía de marca; se aplicó el workflow obligatorio UI UX Pro Max y su búsqueda local de recomendaciones de accesibilidad para tablas y formularios.

## 3. Contratos identificados

Un Asset es un equipo físico de la distribuidora: código/placa, nombre, tipo, descripción, estado y cliente del préstamo. El listado aporta además fecha de registro y bandera Activo.
No hay inversión, costo, valor contable, serial independiente, documentos, responsable de personal ni token de concurrencia en estos view models. No se inventaron campos.
Create/Edit envían código, nombre, tipo y descripción; Edit conserva ActivoId. El servicio de edición descriptiva no cambia estado ni cliente.
Comodatos conserva equipo, cliente, identificación, ubicación, fechas, condición y observaciones. Return conserva ComodatoId, Destino y CondicionDevolucion.
ClienteUsuarioId es nullable en el modelo/SQL; la pantalla histórica Assign no lo captura. No se creó un selector de usuarios ni una relación nueva.
Se preservaron rutas, métodos, binding y antiforgery de todos los POST; controllers, servicios, autorización y SQL permanecen sin cambios.

## 4. Historia recuperada

`cf69b5b` (2026-07-16): formularios iniciales permitían editar estado y cliente.
`0a5a2b8885a15064ba9ecd7da297ef8aa50937bc` (2026-07-19): separó la edición descriptiva y los flujos de comodato; incorporó detalle e historial.
Se conservaron los contratos posteriores. No se recuperaron los editores obsoletos de estado/préstamo, Bootstrap, Font Awesome, gradientes ni CSS inline.
Se expuso información útil ya disponible en los modelos que las vistas anteriores omitían: registro/Activo y descripción del listado, identificación y devolución en Comodatos, ID/observaciones del historial y tipo/fecha de asignación/vinculación de cliente en Rentabilidad.

## 5. Assets Index

Tabla Stage 2 compacta con código/nombre, tipo/descripción, estado, préstamo actual, fecha/registro activo o inactivo y acciones con texto y nombre accesible.
Filtros GET buscar/estado conservados. Ver, Editar y Dar de baja conservan sus rutas e identificadores.
Dar de baja reutiliza la confirmación nativa compartida y antiforgery; no se pulsó durante QA real.

## 6. Assets Create

Formulario Workspace con grupos Identificación y Clasificación/descripción, resumen de errores, validación por campo, Cancelar/Volver y explicación de la gestión del préstamo.
No se creó ningún activo.

## 7. Assets Edit

Reutiliza el mismo partial, conserva ActivoId hidden, código/nombre/tipo/descripción y antiforgery.
Un tipo histórico que no esté en Nevera/Exhibidor/Otro conserva su valor seleccionado mediante una opción literal.
No se guardaron cambios.

## 8. Assets Details

Identidad y préstamo actual mediante pares etiqueta/valor; nombre, código, tipo, descripción, estado y cliente permanecen visibles.
Historial tabular con ID del comodato, cliente, asignación, devolución, estado, destino y observaciones, con mensajes explícitos para datos ausentes.
No se ocultó información para reducir la pantalla.

## 9. Partial `_AssetFields`

Sin layout, Bootstrap, Font Awesome ni estilos inline. Mantiene asp-for e IDs generados para CodigoActivo, Nombre, Tipo y Descripcion.
Create/Edit comparten markup y mensajes de validación. No incorpora inputs de Estado o ClientePrestamo.
Los campos se alinean arriba y no estiran el select al alto del textarea.

## 10. Comodatos Index

Bandeja tabular con ID/equipo/tipo, cliente/identificación, ubicación, fechas/días, estado, destino y acciones.
Filtros GET originales conservados. Solo Estado Activo expone Devolver.
El panel local tiene aria-controls/aria-expanded, foco inicial en Destino y cierre Escape que devuelve foco al botón. Ocultarlo conserva los valores y nunca envía el formulario.

## 11. Comodatos Assign

Grupos Equipo/fecha, Cliente/ubicación y Condición/observaciones. Conserva todos los inputs históricos, mensajes, fechas, opciones de activos disponibles y antiforgery.
Sin activos disponibles muestra aviso y deshabilita Registrar comodato. No se asignó ningún equipo.
La validación de identificación sigue siendo responsabilidad del modelo/servidor; se agregó su mensaje visible.

## 12. Comodatos Profitability

La consulta histórica `sp_Comodato_Rentabilidad` mide compras del cliente desde la asignación para comodatos activos. Usa pedidos Entregado/Aprobado/EnProceso y cruza por ClienteUsuarioId; no mide ingreso propio del equipo, utilidad ni ROI.
Facturado no integra ese filtro histórico; este bloque no cambia el contrato SQL ni resuelve discrepancias de pedidos del Bloque 6B.
Tabla con comodato/equipo/tipo, cliente y advertencia de usuario no vinculado, fecha/días, pedidos, total comprado y última compra.
Tres métricas exactas del resultado: comodatos consultados, filas sin pedidos y filas sin usuario vinculado.
No se suman compras entre equipos: el mismo cliente puede repetir su importe en más de un comodato. No se inventan inversión, margen, payback, depreciación ni gráficos sin una serie semánticamente válida.

## 13. Navegación

Partial `_AssetsNavigation`: Activos, Comodatos y Rentabilidad según permisos reales.
Sidebar con sección Activos y comodatos y destinos de gestión/consulta, sin duplicar destinos del Workspace. Migas de pan conducen a una ruta autorizada del dominio, incluyendo consulta de rentabilidad para perfiles sin gestión.
El enlace corto Rentabilidad evita agregar una etiqueta extensa al sidebar.

## 14. Permisos

Assets y Comodatos de gestión requieren ACTIVOS_GESTIONAR; Profitability declara COMODATOS_CONSULTAR a nivel action.
El filtro real reemplaza la política del controller cuando la action tiene política propia; no acumula ambos códigos. No se cambió este comportamiento.
Fixture Razor: solo gestión muestra Activos/Comodatos; solo consulta muestra Rentabilidad y su miga autorizada; sin códigos oculta la navegación del dominio. Esto prueba presentación, no ejecución del filtro con usuarios reales de esos perfiles.
Tests comprueban los atributos reales, protección POST y regresión existente del reemplazo de política; QA real usa Administrador autenticado manualmente por el usuario.

## 15. Estados

Assets: Disponible success, Prestado info, Mantenimiento warning, Baja neutral.
Comodatos: Activo info, Devuelto success, Retirado warning.
Desconocidos mantienen texto literal y tono neutral. Activo bool del registro se presenta por separado; no se equipara inactividad a daño o devolución.

## 16. Importes

AssetPresentation usa decimal, CultureInfo es-CR y dos decimales con símbolo ₡, independiente de CurrentCulture.
Razor/DOM: alineación derecha, tabular-nums y nowrap. Caso sintético grande: ₡123 456 789,90; cero y negativos cubiertos en tests .NET.
No se recalculan importes de negocio en JavaScript.

## 17. Responsive

Matriz final: siete rutas por 1440, 1280, 768 y 390 px, tanto reales como sintéticas: 28 + 28 combinaciones.
Se verificó innerWidth efectivo y documentElement.scrollWidth == clientWidth en cada caso. Cuando hay scrollbar vertical, clientWidth resta 15 px al viewport; esto no es overflow horizontal.

| Ruta | 1440 | 1280 | 768 | 390 |
| --- | --- | --- | --- | --- |
| Assets/Index | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Assets/Create | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Assets/Edit | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Assets/Details | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Comodatos/Index | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Comodatos/Assign | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |
| Comodatos/Profitability | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK | Real/Sintético OK |

En móvil el documento mide 375 px para viewport de 390 px; tablas con contenedor de 350 px y scroll local según columnas. No se recortan columnas ni convierten los equipos en cards gigantes.
La primera pasada real detectó que el viewport del navegador se aplicaba a la pestaña sintética. Se descartó esa pasada y se repitió la matriz con emulación específica y verificación de innerWidth en la pestaña real.
Se revisaron capturas de formularios, detalle y rentabilidad; viewport y emulación de movimiento se restituyeron al terminar.

## 18. Accesibilidad

Un h1 por pantalla; agrupación fieldset/legend, labels asociados, cero controles sin etiqueta y cero botones sin nombre en las matrices.
Tablas con caption, scope en todas las cabeceras y contenedor desplazable con nombre/foco.
Foco visible medido en Nombre al avanzar con Tab: outline rojo de aproximadamente 2 px. Sidebar móvil abre con foco en cerrar y Escape devuelve el foco al disparador.
Panel de devolución probado con teclado en fixture y datos reales sin submit.
Contraste del botón primario heredado: blanco sobre rgb(139,14,22), 9,67:1. Estados conservan texto además del tono.
Emulación prefers-reduced-motion comprobó transiciones de sidebar/main de 0,00001 s. No se declara certificación WCAG completa ni QA exhaustivo con lectores de pantalla.

## 19. QA real

Siete rutas accesibles con Administrador, usando exclusivamente GET y controles locales que no envían operaciones de negocio. Edit/Details se abrieron desde enlaces de un activo existente, sin IDs adivinados.
Resultado observado: 2 activos, 3 comodatos (2 activos y 1 devuelto), 2 filas de rentabilidad sin usuario vinculado y sin pedidos; ningún equipo disponible para asignar.
Filtro Disponible en Assets devuelve vacío y conserva selección. Filtro Devuelto en Comodatos devuelve una fila y no expone Devolver.
No se versionan nombres, identificaciones, ubicaciones, capturas ni logs de registros reales.

## 20. QA sintético

Host Razor privado que renderiza las vistas compiladas reales, sin servicios SQL. Solo GET; middleware rechaza otros métodos y controllers operativos no participan en matching.
28 combinaciones finales y variantes de vacíos, historial ausente, errores de ModelState, tipo histórico, estado desconocido, baja/registro inactivo, importes grandes, compras repetidas y permisos separados.
Assign con equipo disponible y sin disponibles; mensajes por campo/resumen comprobados. Los POST no se ejecutaron ni siquiera en el fixture.
Fixture/checkpoint/logs quedan fuera del commit. El host de fixture se detiene al cerrar el trabajo.

## 21. Console

Matrices finales reales y sintéticas: cero Runtime.exceptionThrown y cero console.error relevantes.
Lectura CDP por navegación, con cursores y sin eventos truncados. Los errores de automatización por locator ambiguo se resolvieron acotando el botón de cierre al dialog; no fueron errores de la aplicación.

## 22. Network

Matrices finales reales y sintéticas: cero respuestas >=400 inesperadas y cero Network.loadingFailed; no hubo paginación pendiente/truncamiento de eventos.
La pestaña del fixture tuvo conexión rechazada al intentar abrir antes de que el host terminara de arrancar; se recuperó con pestaña nueva una vez confirmado el listener. No se atribuye ese intento al QA productivo.
API/MVC reiniciados con sus perfiles existentes, sin cambiar secretos/configuración. La API escucha en el puerto esperado por MVC.

## 23. Build

`dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`: build definitivo correcto, 0 advertencias / 0 errores.
Un intento inicial se bloqueó por apphost de API en uso; se detuvieron los procesos locales correspondientes y se repitió. Otro intento con nombre .sln inexistente se corrigió usando el csproj solicitado. No eran defectos de código.
El fixture privado también compila con 0 advertencias / 0 errores; no integra la suite productiva.

## 24. Tests .NET

`dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug --no-build`: 433 passed, 0 failed, 0 skipped.
27 regresiones nuevas: siete vistas, permisos/antiforgery, binding/partial, contratos operativos, opciones disponibles, estados conocidos/desconocidos, montos y semántica de rentabilidad sin suma duplicada.
OrdersIntegrationContractTests no está en la compilación productiva; el experimento privado del Bloque 6B no se modificó ni se usó como gate.

## 25. Tests JavaScript

| Suite real | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| stage2-foundations.test.cjs | 11 | 0 | 0 |
| stage2-commerce.test.cjs | 7 | 0 | 0 |
| stage2-orders.test.cjs | 13 | 0 | 0 |
| stage2-logistics.test.cjs | 25 | 0 | 0 |
| stage2-assets.test.cjs | 8 | 0 | 0 |
| Total | 64 | 0 | 0 |

Assets ejecuta el JavaScript real en VM/DOM aislado: abrir/foco, cerrar/preservar, Escape, escritura local, nodos ausentes y cancelaciones Delete/Return con layouts.js real, sin enviar POST. No se declara E2E nativo de confirmaciones destructivas.

## 26. Diff check y secretos

`git diff --check` correcto; warnings LF/CRLF documentados y sin normalizar archivos ajenos.
Antes del commit se revisaron diff completo del índice, stat, `git diff --cached --check` y lista explícita. Scan final de secretos correcto: 937 archivos rastreados revisados, 894 textos analizados. No se detectaron secretos, configuración privada ni datos personales en staging.
No hay cambios de controllers, services, SQL, configuración ni secretos entre los archivos del bloque.

## 27. Alcance del diff / archivos del checkpoint

16 archivos del Bloque 8:

- Views/Assets: Index, Create, Edit, Details, `_AssetFields` (5).
- Views/Comodatos: Index, Assign, Profitability (3).
- Views/Shared: `_WorkspaceLayout`, `_AssetsNavigation` (2).
- Models/Presentation/AssetPresentation.cs.
- wwwroot/css/stage2/workspace.css y wwwroot/js/stage2/assets-ui.js.
- Proyecto_Final.Tests/AssetsPresentationTests.cs.
- scripts/ui/stage2-assets.test.cjs.
- Este informe.

Las rutas de vistas/modelos/wwwroot son relativas a Proyecto_Final. Staging explícito: 16 archivos, 648 inserciones y 523 eliminaciones; ninguno de los cuatro archivos protegidos está incluido.

## 28. SHA del commit local

Checkpoint autorizado: `feat(stage2): modernize assets and comodatos`.
El SHA completo se entrega después de crear el commit. Este informe forma parte de ese commit; no se intenta incluir su propio hash dentro de su contenido.

## 29. Git status final

Se entrega el `git status --short` real después del commit. Se conserva una copia privada del estado anterior y posterior.
Los cuatro cambios previos de Fleet/Vehicles permanecen modificados fuera del índice/commit; los untracked ajenos permanecen fuera.
Ahead esperado tras un único commit del bloque: 7 / behind 0 frente a la referencia local, a confirmar sin fetch.

## 30. Archivos excluidos y hashes

Hashes SHA256 anteriores/posteriores comprobados iguales:

| Archivo protegido | SHA256 |
| --- | --- |
| Views/Fleet/Mileage.cshtml | 0A20E875E8386C50AC9C4CEFBF285F946F0205D1B272DDA97C28084543D71DDE |
| Views/Vehicles/Create.cshtml | B65C4D23B7760AC7BEC558592E8BCE539417E29966A68BFCF1AF5C330A25B514 |
| Views/Vehicles/Edit.cshtml | 37C71BAA326A9D06857838EEE0B14E6CD635219CFE1515F967E7D7FE66F0538E |
| Views/Vehicles/Index.cshtml | 0E34243AC79C09AC24E356D9A04FD3CF320175CBE3BB65EBFAAB6B370F594E47 |

También fuera: experimento 6B/candidate.sql/contratos SQL, fixtures/checkpoints/capturas/logs, .agents, .cache, documentos personales, archivos auxiliares y reportes Azure. No se usa git add . ni git add -A.

## 31. Limitaciones

No se certifican operaciones reales de crear/editar/asignar/devolver/dar de baja, concurrencia ni efectos SQL. Sus contratos se verifican por código, markup y pruebas aisladas.
No se dispone de compras no cero ni activos disponibles en el resultado real; se cubren esos casos con modelos sintéticos claramente separados.
La vinculación de ClienteUsuarioId ausente explica la cobertura cero de las filas consultadas; no se corrigen relaciones ni datos en este bloque.
La consulta histórica de rentabilidad no incorpora Facturado; esa decisión de integración se conserva pendiente fuera del bloque visual.
Permisos de perfiles parciales comprobados con fixture/código, sin cambiar asignaciones reales. No se certifica WCAG completa, SQL/E2E de pedidos ni otro bloque.

## 32. Restricciones respetadas

NO PUSH. NO PR. NO ESCRITURA REMOTA. NO MERGE/REBASE. NO MIGRACIONES. NO SQL DE ESCRITURA. NO CAMBIOS DE DATOS POR EL AGENTE. NO CAMBIOS DE USER SECRETS NI CONNECTION STRINGS.
Solo presentación, pruebas aisladas, documentación y checkpoint local del Bloque 8. No se inicia el siguiente bloque.
