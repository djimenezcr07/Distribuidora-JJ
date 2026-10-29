# Stage 2.5 — Inventario de RRHH, personal y planilla

Fecha de revisión: 2026-08-21. Fuente de verdad: controladores, modelos y vistas del commit `a3e741f3ca35f9df8a42ea838a5054d7448331a3`.

## Alcance y contratos reales

| Dominio | Controller / autorización | Acciones y vistas | ViewModel / información real | Formularios y contratos preservados |
| --- | --- | --- | --- | --- |
| Empleados | `EmployeesController`; módulo `Empleados`; lectura `EMPLEADOS_VER`, alta `EMPLEADOS_CREAR`, edición/estado `EMPLEADOS_EDITAR` | `Index(buscar, estado)`, `Create` GET/POST, `Edit` GET/POST, `Details(id)`, `ToggleStatus` POST | `EmployeeFilterViewModel`, `EmployeeFormViewModel`, `EmployeeDetailViewModel`; identidad, contacto, rol, puesto, departamento, salario, responsabilidades, observaciones, tareas, solicitudes e historial salarial | antiforgery en todos los POST; `EmpleadoId`, `UsuarioId` y `RowVersionBase64` ocultos en edición; filtros `buscar`/`estado`; confirmación de cambio de estado; no se cambia concurrencia ni relación Employee/User |
| Tareas y supervisión | `EmployeesController`; hereda módulo `Empleados` | `CreateTask`, `UpdateTaskStatus` POST dentro de `Employees/Details` | `EmployeeTaskFormViewModel`, `EmployeeTaskStatusViewModel`, `EmployeeTaskViewModel`; título, descripción, prioridad, estado, asignador y fecha límite | antiforgery; `EmpleadoId` y `TareaId` ocultos; valores reales de prioridad `Baja`, `Media`, `Alta`, `Urgente` y estados `Pendiente`, `En proceso`, `Completada`; lista operativa, no Kanban |
| Solicitudes administrativas | `EmployeesController`; hereda módulo `Empleados` | `LeaveRequests(estado)` GET y `UpdateLeaveRequest` POST; resumen adicional en `Employees/Details` | `EmployeeLeaveRequestViewModel`, `EmployeeLeaveRequestDecisionViewModel`; solicitante, puesto, período, días, tipo, motivo, estado, respuesta y responsable | antiforgery; `SolicitudId` y `estadoFiltro` ocultos; estados existentes `Pendiente`, `Aprobada`, `Rechazada`, `Cancelada`; respuesta máxima 500 caracteres; la decisión conserva el POST actual |
| Portal del empleado | `EmployeePortalController`; `SessionAuthorize` + `EmployeeRelationshipAuthorize` | `Index`, `RequestTimeOff` POST, `UpdateMyTaskStatus` POST; vista `EmployeePortal/Index` | `EmployeePortalViewModel`; perfil propio, responsabilidades, tareas, solicitudes y nueva solicitud | antiforgery; nombres planos requeridos por POST (`FechaInicio`, `FechaFin`, `TipoSolicitud`, `Motivo`, `tareaId`, `estado`); ownership por relación activa; no comparte la vista administrativa |
| Jornadas propias | `MyAttendanceController`; `SessionAuthorize` + `EmployeeRelationshipAuthorize` | `Index(desde, hasta)` y `Save(model, submit)` POST; vista `MyAttendance/Index` | `MyAttendanceIndexViewModel`, `AttendanceFormViewModel`; fecha, horas ordinarias/extra/ausencia, observaciones, estado y respuesta | antiforgery generado por form tag helper; `IdempotencyKey`; los nombres planos `Fecha`, `HorasOrdinarias`, `HorasExtra`, `HorasAusencia`, `Observaciones`; `submit=false/true`; validación de 0–24 h y suma máxima 24 |
| Aprobación de jornadas | `AttendanceController`; módulo `RRHH`, permiso `RRHH_JORNADAS_APROBAR` | `Index(desde, hasta)` y `Decide` POST; vista `Attendance/Index` | `AttendanceEntryViewModel`, `AttendanceDecisionViewModel`; empleado, fecha, tres tipos de horas, observación, estado y respuesta | antiforgery; `JornadaId` y `RowVersionBase64` ocultos; `Decision` solo `Aprobada` o `Rechazada`; `RespuestaSupervisor` máxima 500; filtros reales de fecha deben conservarse |
| Planilla | `PayrollController`; lectura `PLANILLA_VER`; configuración `PLANILLA_CONFIGURAR`; período `PLANILLA_GESTIONAR`; cálculo `PLANILLA_CALCULAR`; estados `PLANILLA_APROBAR`, `PLANILLA_PAGAR`, `PLANILLA_REVERTIR` | `Index`, `ConfigureRule`, `CreatePeriod`, `Calculate`, `Approve`, `Pay`, `Revert`; vista `Payroll/Index` | `PayrollIndexViewModel`; regla versionada, período, solicitud de cálculo y lista de cálculos con bruto, deducciones, neto, estado y rowversion | antiforgery; `IdempotencyKey`; `CalculoId` y `RowVersionBase64`; motivo obligatorio en UI para revertir; no existe detalle independiente ni filtros; no se mueve ningún cálculo a Razor/JavaScript |
| Gestión de boletas | `PaySlipsController`; `PLANILLA_BOLETAS_GESTIONAR` | `Index`, `Details(id)`, `Download(id)`, `Send` POST; vista `PaySlips/Index`; detalle reutiliza `MyPaySlips/Details` | `PaySlipListItemViewModel`, `PaySlipViewModel`, `PaySlipSendViewModel`; empleado, período, bruto, deducciones, neto, estado, envío y líneas | antiforgery por form tag helper; `CalculoId`, `IdempotencyKey`; notificar solo cuando el estado es `Pagada`; descarga HTML privada; el desglose no viaja por correo |
| Boletas propias | `MyPaySlipsController`; `SessionAuthorize` + `EmployeeRelationshipAuthorize` | `Index`, `Details(id)`, `Download(id)`; vistas `MyPaySlips/Index` y `MyPaySlips/Details` | lista y desglose del propietario: salario base, horas, comisiones, ingresos/deducciones por línea y totales | servicio filtra por propietario; descarga HTML privada; la vista web y la descarga son superficies separadas; no existe POST |

## Superficies y dependencias previas

- Vistas en alcance: 13 archivos Razor: 12 superficies de página y el parcial `Employees/_EmployeeForm`.
- Layout previo: todas heredan `_Layout` desde `_ViewStart`; ninguna declara aún `_WorkspaceLayout`.
- CSS previo: `sprint3-employees.css`, `brand-overrides.css`, Bootstrap, Font Awesome, namespaces `s3` y estilos embebidos de `Payroll/Index`.
- JavaScript previo: validación unobtrusive en alta/edición; confirmación `data-s3-confirm` en estado de empleado; script embebido de doble envío en planilla. Los contratos funcionales se conservan y la presentación migra a Stage 2.
- Datos sensibles: salario, dirección, observaciones internas, historial salarial y netos. El listado general de empleados dejará de exponer salario, teléfono y correo; el detalle autorizado conserva los datos que ya entrega el modelo, agrupados y con contexto.
- Fechas: se conserva `dd/MM/yyyy` en lectura y los inputs `type=date`; fecha/hora del historial salarial permanece `dd/MM/yyyy HH:mm`. No existen entrada, salida ni duración calculada en los modelos de jornada.
- Montos: CRC visible con `₡`, dos decimales, alineación derecha y cifras tabulares. No se alteran reglas, factores, snapshot ni estados de planilla.

## Superficies no existentes o fuera del dominio

- No hay módulo de horarios, turnos, hora de entrada o hora de salida; jornadas registran cantidades de horas.
- No existe una vista de detalle del cálculo de planilla separada de la lista. El detalle disponible es la boleta derivada del snapshot.
- Tareas y solicitudes no tienen controladores/vistas independientes: la gestión vive en `Employees` y la autogestión en `EmployeePortal`.
- El histórico salarial forma parte de `Employees/Details`; no existe índice independiente.
- `MyGoal/Index` es progreso comercial del vendedor (`Metas y KPIs`), no expediente, desempeño de RRHH ni evaluación laboral. Queda fuera de Stage 2.5.
- No existen datos bancarios, identificación personal, supervisor directo, evidencia adjunta de solicitud, calendario ni exportación de planilla en estos ViewModels; la UI no los inventará.

## Navegación Personal basada en permisos reales

| Destino | Visibilidad administrativa | Observación |
| --- | --- | --- |
| Empleados / tareas | `EMPLEADOS_VER` | `Employees/Index`; tareas son contextuales al expediente |
| Solicitudes | permiso real `EMPLEADOS_SOLICITUDES` usado por la navegación heredada | `Employees/LeaveRequests`; el controlador hereda el módulo `Empleados` |
| Jornadas | `RRHH_JORNADAS_APROBAR` | `Attendance/Index` |
| Planilla | `PLANILLA_VER` | `Payroll/Index`; las acciones siguen validando permisos más específicos |
| Boletas | `PLANILLA_BOLETAS_GESTIONAR` | `PaySlips/Index`; no se debe inferir de `PLANILLA_VER` |

Los accesos propios (`EmployeePortal`, `MyAttendance`, `MyPaySlips`) dependen de sesión y relación Employee/User activa, no de permisos administrativos. No se añaden al sidebar administrativo para evitar mezclar objetivos y autorización.

## Gate UI UX Pro Max — preimplementación

| Dominio | Objetivo e información prioritaria | Patrón, densidad y acciones | Riesgos, responsive y accesibilidad |
| --- | --- | --- | --- |
| Empleados | Identificar persona por nombre, puesto, departamento y estado; entrar a su expediente | FilterBar real + tabla compacta; ver como acción frecuente, editar/estado contextuales; formulario por identidad/contacto/relación laboral/configuración | Minimizar PII y salario en lista; labels permanentes; resumen de error enfocable; scroll local y acciones touch |
| Expediente y tareas | Comprender relación laboral, contacto y actividad sin fragmentar en tarjetas por dato | Header humano + secciones estándar; lista operativa de tareas porque el modelo y acciones no justifican Kanban | Salario, dirección y notas solo en detalle autorizado; prioridad/estado con texto, no solo color; apilar formulario y listas en móvil |
| Jornadas | Registrar/revisar fecha y cantidades de horas; distinguir borrador, envío y decisión | Formulario estándar propio; tabla compacta para historial y aprobación; aprobar success y rechazar danger con contexto | Números tabulares; no inventar entrada/salida; estado textual; observación etiquetada; scroll local |
| Solicitudes | Comparar solicitante, período, tipo, motivo resumido y estado antes de decidir | Lista/tablas compactas; respuesta visible; aprobación y rechazo diferenciados sin convertir la fila en texto completo | Decisión sensible con consecuencia comprensible; motivo legible y contenido ajustable; controles apilados en 320–390 px |
| Planilla | Configurar con fuente, abrir período, calcular y transicionar resultados sin reinterpretar importes | Tres formularios agrupados y tabla compacta; una acción principal por formulario; montos a la derecha | Información financiera sensible; no gráficas; no cálculos cliente; confirmación contextual al aprobar/pagar/revertir; recuperación de errores |
| Boletas | Localizar, consultar, descargar y, con permiso, notificar una boleta pagada; empleado consulta solo la propia | Tabla compacta administrativa o personal; detalle imprimible con ingresos/deducciones y total neto | Ownership y permiso siguen en backend; ocultar acciones de pantalla al imprimir; marca Stage 2; contraste y tabla legible a 200% |

## Hallazgos de datasets UI UX Pro Max

- `task management operational list` recomienda jerarquía funcional, colores de estado y microinteracciones sobrias; se elige lista operativa en lugar de Kanban.
- `dense data table responsive` exige scroll horizontal local o adaptación, nunca desbordamiento global.
- `long form validation error summary` exige resumen superior enfocable, errores inline y anuncio con `role=alert`.
- `mobile responsive enterprise form` exige base mobile-first y controles/tablas adaptables.
- `approval rejection confirmation` refuerza feedback de éxito y confirmación de acciones sensibles.
- `time input` exige tipos de input correctos y etiquetas visibles.
- No hubo coincidencias verificables, incluso tras reintento, para HR/employee management, attendance/timesheet, leave approval, payroll/payslip, sensitive-data UX, iconos de asistencia ni la consulta de stack HTML responsive. Se aplican las heurísticas generales comprobadas, las guías de accesibilidad y responsive de las skills y el Design System Stage 2; no se atribuyen resultados inexistentes al dataset.

## Gate UI UX Pro Max — postimplementación

| Dominio | Jerarquía / prioridad | Tabla / formulario | Estado / prevención | Privacidad | Responsive / accesibilidad | Resultado |
| --- | --- | --- | --- | --- | --- | --- |
| Empleados y expediente | PASS | PASS | PASS | PASS: listado sin salario, correo ni teléfono | PASS estático; WARN smoke autenticado | WARN |
| Tareas y portal propio | PASS: lista operativa, no Kanban | PASS | PASS: prioridad y estado con texto | PASS: solo perfil propio o expediente autorizado | PASS estático; WARN smoke autenticado | WARN |
| Jornadas | PASS | PASS: horas tabulares y filtros reales | PASS: aprobar/rechazar con contexto | PASS | PASS estático; WARN smoke autenticado | WARN |
| Solicitudes | PASS | PASS: motivo resumido en tabla | PASS: aprobar/rechazar/cancelar diferenciados; cuatro estados preservados | PASS | PASS estático; WARN smoke autenticado | WARN |
| Planilla | PASS | PASS: formularios agrupados y montos alineados | PASS: permisos y confirmaciones por transición | PASS: no se expone en navegación sin permiso | PASS estático; WARN smoke autenticado | WARN |
| Boletas | PASS | PASS | PASS: notificación solo pagada | PASS: ownership/permiso y enlace privado preservados | PASS estático e impresión; WARN smoke autenticado | WARN |

No quedaron `FAIL` dentro del alcance. Los `WARN` corresponden exclusivamente a QA de entorno: la aplicación local inició y `/Employees` sin sesión redirigió correctamente a `/Account/Login`, pero no había una sesión QA autenticada disponible para renderizar datos de RRHH en 1440/1024/390. No se introdujeron credenciales ni se modificó el firewall. El bloqueo histórico Azure SQL 40615 para `152.231.188.125` no se asume vigente ni resuelto sin una nueva prueba autenticada.

## Validación Stage 2.5

- Restore: aprobado.
- Build Release: aprobado, 0 errores y 0 advertencias. Un primer intento durante el smoke local registró reintentos de copia por el proceso en ejecución; tras detenerlo, el build final quedó limpio.
- Tests: 309/309 aprobados; 19 pruebas focalizadas del Design System Stage 2.
- Cobertura Cobertura XML: 8.36% de líneas (1,406/16,808) y 5.43% de ramas (702/12,923).
- Secret scan: 879 archivos rastreados, 845 de texto, 12 placeholders aprobados, 0 hallazgos.
- ScriptDom: 130 archivos, 1,032 lotes, 0 errores.
- SVG: 10 archivos válidos, 0 errores. Referencias de assets del Workspace: 0 faltantes.
- CSS Stage 2: 7 archivos, 1,124 líneas, 78,726 bytes; 0 `!important`, 0 hex fuera de `tokens.css` y 0 tokens indefinidos, excluyendo las propiedades dinámicas declaradas en markup.
- Stage 2.5: 12 vistas de página y el parcial de formulario migrados. Acumulado por asignación explícita de layout: 70 de 154 archivos Razor; 84 vistas, parciales o layouts sin asignación Stage 2 explícita.
- Dependencias legacy en las 12 páginas migradas: 0 `s3`, 0 `s4`, 0 Font Awesome, 0 CSS legacy, 0 logos legacy y 0 estilos embebidos.
