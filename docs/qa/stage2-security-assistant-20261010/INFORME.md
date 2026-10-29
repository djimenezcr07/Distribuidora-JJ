# Stage 2 — Bloque 11: Roles, Permissions, Audit y Assistant

Fecha: 2026-10-10. Trabajo local de presentación. La autorización, los contratos SQL y los datos no se modifican. No se certifican mutaciones reales.

## 1. SHA inicial y protección

HEAD inicial `adc5b851bf6acbd484ac003169177256b262d43d`, rama `codex/stage2-design-system`, ahead 9 / behind 0 frente a la referencia local `origin/codex/stage2-design-system`. Sin fetch. Checkpoint privado previo con estado, diff, vistas originales y hashes de las cuatro vistas protegidas. Baseline 501 pruebas .NET y 77 JS.

## 2. Contratos auditados

Se revisaron RolesController, PermissionsController, AuditController, AssistantController, sus modelos, AdminDbService, RolePermissionService, AssistantService, AdminAuthorizeAttribute y filtros, catálogo de capacidades, tests, scripts e historia Git. Referencias históricas consultadas: `0a5a2b8`, `3a38036`, `c6e1ed7`, `9d246cf` y `9ad1df9`. SQL fuente en `database/`, migraciones y `database_Esteban/Fase3_3-3.sql`; metadata local consultada únicamente mediante SELECT.

Están instalados `sp_Admin_GetRoles`, `sp_Admin_GetRoleById`, `sp_Admin_GetRolePermissions`, `sp_Admin_GetAuditLogs`, `sp_Asistente_Metricas` y `sp_Asistente_Log`. La definición instalada de auditoría recibe Modulo (80), Accion (80) y Buscar (200); la firma histórica con Filtro/Desde/Hasta no sustituye este contrato. Inspección textual de metadata: los cinco procedimientos de consulta no contienen tokens INSERT/UPDATE/DELETE; Asistente_Log sí. Esto no equivale a una certificación general de efectos de todos los objetos SQL.

## 3. Roles Index

Tabla con id, nombre, descripción, usuarios asociados, fecha, estado y acciones. Conserva GET `buscar`, POST Toggle `perfilId`/`buscar`, antiforgery, protección de roles base y confirmación mediante foundation Stage 2. No se añade un resumen de permisos que el modelo no entregue.

## 4. Roles Create

Formulario Workspace con Nombre, Descripcion y Activo; conserva asp-for, validación, límites 50/255 y antiforgery. No asigna permisos automáticamente. No se creó ningún rol.

## 5. Roles Edit

Conserva PerfilId, FechaCreacion y TotalUsuarios ocultos, Nombre/Descripcion/Activo y errores por campo. Roles base conservan nombre de solo lectura; Administrador y Cliente conservan estado protegido. La asignación de permisos permanece como operación separada. El contrato existente no aporta un token de concurrencia. No se guardó ningún rol.

## 6. Permissions Index

El contrato real entrega roles, no un catálogo plano de capacidades. La página muestra descripción, usuarios y estado del rol, con acceso a su catálogo. Las etiquetas Administrar/Consultar reflejan el permiso de escritura. No se inventan asignaciones ni métricas.

## 7. Permissions Edit

Catálogo por módulos ya entregados por el modelo. Muestra código literal, nombre, descripción y estado; contador de asignados/total calculado sobre ese mismo modelo. Conserva `perfilId`, `permisosSeleccionados`, valores PermisoId, checked Asignado, antiforgery y endpoint. No se incorporan selección masiva, filtros que descarten selecciones, renombrado de códigos ni reactivación implícita. El catálogo del rol Administrador es de consulta incluso para el Administrador; los usuarios sin PERMISOS_ASIGNAR tampoco pueden guardar.

## 8. Audit

Tabla con AuditoriaId, fecha, UsuarioId, actor/correo, rol, módulo, acción, descripción, IP y UserAgent desplegable. Mantiene los filtros disponibles y el máximo existente de 200 registros. No incorpora fechas ni paginación inexistentes. Los timestamps se formatean sin conversión UTC. Texto técnico con encoding Razor y redacción presentacional de patrones conocidos de credenciales, hashes y tokens; no se altera el registro almacenado.

## 9. Assistant

Workspace independiente, conversación, sugerencias, pregunta etiquetada y estado de procesamiento. Mantiene su descripción oficial: Asistente conversacional basado en reglas e interpretación de intenciones. No se modifica AssistantService ni su interpretación de preguntas/respuestas.

## 10. Permisos

Servidor sin cambios. GET Roles/Permissions usa módulo Seguridad, Audit usa Auditoria; las mutaciones siguen ROLES_CREAR_EDITAR/PERMISOS_ASIGNAR. Se conserva el bypass existente de Administrador. Navegación reutiliza HasModulePermissionAsync, sin sustituirlo por permisos inventados. Assistant mantiene SessionAuthorize y el filtrado de categorías por capacidades dentro del servicio.

Inconsistencia preexistente documentada: AssistantService reconoce `VENTA_MOVIL_CREAR_PEDIDO` en operaciones; otras superficies actuales utilizan `VENTA_MOVIL_CREAR`. No se corrige ni se amplía la autorización en este bloque.

## 11. Antiforgery

Se preservan los tokens de formularios y atributos del servidor. Ask mantiene el token enviado como `__RequestVerificationToken`. Reflection verifica todos los POST de los controllers implicados; no se ejecutan esos endpoints reales.

## 12. Encoding / XSS

Audit no utiliza Html.Raw. Roles y capacidades usan encoding Razor. Assistant usa createElement/textContent y fragmentos; no innerHTML, outerHTML, insertAdjacentHTML ni DOMParser. Conserva exclusivamente strong/em/ul/li/br sin atributos como vocabulario de formato. Etiquetas desconocidas y entidades decodificadas quedan como nodos de texto. Tests cubren script, img/onerror, comillas, ampersand, Unicode, títulos, respuestas y sugerencias. La redacción de auditoría cubre patrones conocidos y no constituye un detector universal de secretos arbitrarios.

## 13. JS extraído

Presentación e interacción A/B pasan a `wwwroot/js/stage2/assistant.js`. C conserva POST Ask, Content-Type, pregunta/contexto, token y JSON. D permanece en servidor/sesión; el navegador no obtiene nuevos privilegios. E conserva el logging del servicio y el error de consola del cliente. Previene solicitudes duplicadas mientras carga y restaura controles/foco.

## 14. Métricas Assistant

Solo se presentan resultados del servicio existente; no hay KPIs, porcentajes, scoring ni recomendaciones añadidos. El contexto sigue actualizándose únicamente con respuestas tipo metrica. Rate limit existente: 20 solicitudes/minuto/usuario, sin cambios. AskAsync registra incluso respuestas de ayuda o capacidades mediante sp_Asistente_Log: no se consultó Assistant real mediante POST.

## 15. Navegación

Partial `_SecurityNavigation` para Roles/Permisos/Auditoría, condicionado por los módulos reales. Sidebar separa Roles y permisos de Auditoría. Migas Workspace llevan a un destino permitido de la sección actual; Assistant permanece independiente. Fixtures de lectura, asignación parcial y solo auditoría verifican los destinos visibles.

## 16. Estados

Activo/Inactivo siguen los booleanos reales, con texto visible y tonos success/neutral. Acciones de auditoría desconocidas son literales y neutrales. Capacidades desconocidas mantienen su código. No se deducen nuevas transiciones.

## 17. Responsive

Objetivo: 1440, 1280, 768 y 390 px. Cierre final real: **28/28 combinaciones correctas** sobre el Razor definitivo, con documentElement.scrollWidth igual a clientWidth en todas. Las 28 combinaciones sintéticas también pasaron sobre el Razor final. Tablas con scroll local; documento sin overflow horizontal. El fixture incluye 125 capacidades, nombres sin espacios, descripciones largas y contexto de auditoría extenso. Assistant loading/success/error se comprueba además en los cuatro anchos mediante transporte sustituido localmente, sin peticiones POST.

| Página real final | 1440 | 1280 | 768 | 390 |
|---|---|---|---|---|
| Roles/Index | OK | OK | OK | OK |
| Roles/Create | OK | OK | OK | OK |
| Roles/Edit de rol descubierto en Index | OK | OK | OK | OK |
| Permissions/Index | OK | OK | OK | OK |
| Permissions/Edit Administrador | OK | OK | OK | OK |
| Audit/Index | OK | OK | OK | OK |
| Assistant/Index, saludo local sin Ask | OK | OK | OK | OK |

Dos hallazgos corregidos durante QA: contenedor de tabla sin overflow local y clase de checkbox aplicada a su etiqueta. Las etiquetas finales usan djj-choice y los inputs djj-checkbox; controles y texto quedan visibles.

## 18. Accesibilidad

Un h1 por página, etiquetas vinculadas, fieldsets/legends para formularios y módulos, captions y scope, regiones de tablas enfocables, foco visible, errores por campo y estados con texto. Assistant utiliza role log/status, aria-live polite y aria-busy. Fixture comprueba teclado Space y foco en checkbox sin envío. En cierre real, las 28 combinaciones no tuvieron inputs sin etiqueta ni errores de semántica de tablas/fieldset; los checkboxes utilizan input djj-checkbox y etiqueta asociada djj-choice. Tab recorrió el catálogo de otro rol sin cambiar ninguna selección, con outline visible. Sidebar móvil abrió con Enter, cerró con Escape y devolvió el foco visible al botón Abrir navegación. Se conserva reduced-motion de foundations. No se declara conformidad WCAG completa ni prueba con lector de pantalla.

UI UX Pro Max y documentación Stage 2 aplicados. La búsqueda de guidance sobre checkbox groups no devolvió una coincidencia específica verificable; no se atribuye a la skill una regla inexistente.

## 19. QA real

Sesión Administrador iniciada manualmente y confirmada para el cierre final. Solo GET: siete vistas finales, Roles/Edit de un rol descubierto desde Index, Permissions/Edit Administrador y de otro rol descubierto desde Permissions/Index. El catálogo Administrador muestra sus 97 capacidades deshabilitadas en los cuatro anchos; el otro catálogo muestra las 97 capacidades según su asignación existente. Búsqueda de Roles sin coincidencias y filtros GET módulo/acción/buscar de auditoría conservan sus valores y devuelven el estado vacío correspondiente. Audit muestra 200 contextos con UserAgent disponible; apertura local de Ver contexto sin overflow. Assistant/Index muestra exclusivamente el saludo local, sin solicitud Ask.

Durante este cierre no se ejecutaron Create role, Edit role, Toggle role, Save permissions, Assistant Ask ni escrituras funcionales. No se cambiaron selecciones de permisos reales. No se modificó código productivo ni SQL: únicamente se actualizó este informe. Las mutaciones siguen sin certificarse E2E; el login manual puede generar el logging normal de autenticación existente.

## 20. QA sintético

Fixture privado Razor compilado contra vistas productivas, sin configuración SQL ni servicios de base de datos. Solo acepta GET; las rutas de controllers son exclusivamente para generar enlaces y no ejecutan acciones. Modelos vacíos/extensos, error Nombre, rol base, lectura, capacidades parciales/desconocidas/inactivas, auditoría con payloads y fecha Unspecified. El fetch sustituido del Assistant responde en memoria o mantiene loading; ninguna petición POST llega al servidor. JS aislado cubre también empty, HTTP error, contexto y recuperación de controles.

## 21. Console

Sin errores/warnings relevantes en el QA real final: consultas de consola por navegación y comprobación posterior al teclado/sidebar. El error HTTP sintético del test JS genera deliberadamente el console.error existente y verifica recuperación; se mantiene separado del QA real.

## 22. Network

Cierre final real: captura CDP por página sin truncamiento ni páginas de eventos pendientes en las 28 combinaciones y las pruebas adicionales de filtros/teclado. **0 HTTP >=400 inesperados, 0 loadingFailed y 0 POST**; ninguna petición distinta de GET. Assistant/Index exclusivamente GET, sin Ask ni sp_Asistente_Log provocado por el agente. No se navegaron rutas deliberadamente denegadas ni se certifica el comportamiento de toda la aplicación fuera del alcance.

## 23. Build

Build Debug de Proyecto_Final.Tests y dependencias correcto: 0 advertencias / 0 errores. El primer intento encontró apphost API bloqueado por su proceso activo; se detuvieron los procesos locales identificados y se recompiló correctamente. API/MVC reiniciados con sus puertos existentes y sin cambiar configuración. Este cierre solo cambió el informe; los últimos resultados completos de build y tests siguen vigentes, sin recompilar ni invalidar otra vez la sesión.

## 24. .NET

524 pruebas correctas: baseline 501 + 23 regresiones. 0 fallos / 0 omitidas. Cobertura nueva: siete layouts, semántica de tablas/POST, redacción de auditoría, trace fields/filtros, reflection de políticas y antiforgery/rate limit, binding de formularios/checkboxes, protección de roles base, navegación y extracción segura del JS.

## 25. JavaScript

88 pruebas correctas: 77 previas + 11 del Assistant. 0 fallos / 0 omitidas. Se ejecutan las suites foundations, commerce, orders, logistics, assets, documents, customer-service y security-assistant. Los payloads y tokens de tests son sintéticos.

## 26. Legacy post-bloque

Revisión limitada a las siete páginas del bloque: Workspace, sin Bootstrap real, Font Awesome, custom-theme.css, _Layout, estilos inline ni JS funcional inline. Solo queda referencia al script externo Assistant y partial de validación donde corresponde.

## 27. Diff y secretos

git diff --check y revisión explícita del diff. Scan del repositorio correcto: 956 archivos rastreados, 913 de texto. Los nuevos archivos se revisan también explícitamente antes del commit. No se incluyen datos de QA reales, secretos, SQL, configuración ni fixtures. Staging por lista cerrada de 15 archivos; sin git add . ni git add -A.

## 28. Checkpoint

Gate final de lectura cerrado. Checkpoint local autorizado con mensaje `feat(stage2): modernize security and assistant workspace`, sin nueva solicitud de aprobación. El SHA completo se entrega después del commit; no puede incluirse dentro del mismo documento que determina ese hash.

## 29. Git status

Lista cerrada de 15 archivos del bloque para el checkpoint. Las cuatro modificaciones previas protegidas y los untracked ajenos quedan fuera. Estado exacto, staging vacío y ahead/behind se comprueban y reportan después del commit frente a la referencia local de origin, sin operaciones remotas.

## 30. Exclusiones

Fleet/Mileage y Vehicles/Create/Edit/Index permanecen fuera del staging, con los mismos hashes previos. Excluidos 6B, 10C, candidates SQL, checkpoints, fixtures/logs/capturas, .agents, .cache, documentos personales, reportes Azure y auxiliares.

## 31. Limitaciones

No se certifican creación/edición/activación de roles, asignación/revocación de permisos ni Ask/log reales. La cuenta restringida se prueba mediante fixture; QA real solo Administrador. No se cambian códigos preexistentes ni divergencias SQL históricas. Redacción presentacional de patrones conocidos no sanea registros de origen ni garantiza reconocer cualquier secreto con formato arbitrario. No se inicia el siguiente bloque.

## 32. Confirmación

NO PUSH. NO PR. NO ESCRITURA REMOTA. NO MIGRACIONES. NO CAMBIOS DE DATOS mediante acciones del agente. El inicio de sesión manual del usuario puede generar el logging normal de autenticación de la aplicación; no se presenta como una mutación de negocio probada por el agente.
