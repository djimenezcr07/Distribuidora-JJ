# Stage 2.4 — Inventario de finanzas, clientes y crédito

Fecha de revisión: 2026-08-21. Fuente de verdad: controladores, modelos y vistas del commit `3ae1f11a89ca584cf604a2f31d90ae1af434a7e8`.

## Alcance y contratos reales

| Dominio | Controller / permiso | Acciones y vistas | ViewModel / datos principales | Contratos que se preservan |
| --- | --- | --- | --- | --- |
| Liquidaciones | `FinanceController`; módulo `Finanzas`, permiso `LIQUIDACION_FINANCIERA` | `Index(estado)` → `Finance/Index`; `Liquidate(rutaId)` GET/POST → `Finance/Liquidate` | `CashSettlementListItemViewModel`, `CashSettlementFormViewModel`; ruta, efectivo esperado/recibido, comprobantes, diferencia, estado, responsable y fecha | POST `Liquidate`, antiforgery, nombres de colección `Comprobantes[i].Tipo/Referencia/Monto`, filtros por `estado` |
| Crédito (resumen por cliente) | `CreditsController`; módulo `Creditos` | `Index(buscar, estadoCredito)` → `Credits/Index`; `Details(id)` → `Credits/Details`; POST `UpdateSettings`, `RegisterMovement` | `ClientCreditFilterViewModel`, `ClientCreditDetailViewModel`, formularios de configuración y movimiento | antiforgery; `UsuarioId`, `LimiteCredito`, `CreditoActivo`, `CreditoBloqueado`, `MotivoBloqueo`, `TipoMovimiento`, `Monto`, `Referencia`, `Descripcion` |
| Cuentas por cobrar | `AccountsReceivableAdminController`; módulo `Creditos` | `Index(buscar, estado, desde, hasta, soloVencidas)` → `AccountsReceivableAdmin/Index`; `Detail(id)` → `AccountsReceivableAdmin/Detail`; POST `UpdateSettings`, `RegisterMovement` | cartera por factura, cliente, emisión, vencimiento, total, pagado, pendiente; detalle con límite/disponible, cargos, abonos, configuración y movimientos | filtros existentes, antiforgery, formularios y selectores JS existentes; no se introduce cálculo de aging ni estados nuevos |
| Clientes administrativos | `ClientsController`; `CLIENTES_VER`; creación `CLIENTES_CREAR`, edición `CLIENTES_EDITAR`, estado `CLIENTES_INACTIVAR` | `Index(buscar, estado)`, `Create`, `Edit`, `Details(id)`, POST `ToggleStatus` | `ClientFilterViewModel`, `ClientFormViewModel`, `ClientDetailViewModel`; identidad, contacto, dirección, estado, pedidos y relación comercial | antiforgery; campos `UsuarioId`, identificación, nombre, email, teléfono, dirección, contraseña/estado; `motivo`, `buscar`, `estado`, `returnTo` |
| Presupuestos | `BudgetsController`; `PRESUPUESTOS_VER`; gestión `PRESUPUESTOS_GESTIONAR`; aprobación `PRESUPUESTOS_APROBAR`; cierre `PRESUPUESTOS_CERRAR` | `Index`, `Create`, `Edit`, `Details`/`Detail`; POST `SaveDetail`, `UpdateDraft`, `Distribute`, `Submit`, `Approve`, `Reject`, `Close`, `Copy` | filtros, encabezado anual, líneas mensuales, auditoría y catálogos de departamento/categoría | antiforgery; nombres e IDs de presupuesto/línea; estados reales Borrador, Presentado, Aprobado, Rechazado, Cerrado e Inactivo; reglas de distribución intactas |
| Gastos | `ExpensesController`; `GASTOS_VER`; registro `GASTOS_REGISTRAR`; edición `GASTOS_EDITAR`; aprobación `GASTOS_APROBAR`; pago `GASTOS_PAGAR`; anulación `GASTOS_ANULAR`; legado `GASTOS_LEGADO_VER` | `Index`, `Create`, `Edit`, `Details`/`Detail`, `Receipt`, `Accounts`; POST `Approve`, `Reject`, `Pay`, `Cancel` | dashboard y filtro, formulario operativo, impacto presupuestario, comprobante privado y auditoría | `OperationToken`, carga multipart, antiforgery, inputs monetarios `data-expense-money`, salida `data-expense-total`, estados Registrado/Aprobado/Pagado/Rechazado/Anulado |
| Comparativa presupuestaria | `BudgetComparisonController`; `PRESUPUESTOS_COMPARAR` | `Index`, `Print`, `ExportCsv` | `BudgetComparisonDashboardViewModel`; presupuesto, real, pendiente, disponible, ejecución, proyección, cortes y serie mensual | filtros Year/DepartmentId/Month/CategoryId/ExpenseStatus/Page, enlaces Print/CSV y reporte imprimible sin JavaScript de negocio |
| Facturación administrativa | `BillingController`; módulo `Facturacion`; generación/reenvío `FACTURACION_GENERAR` | `Index`, `Detail(id)`; POST `GenerateFromOrder`, `ResendEmail` | `SalesReportViewModel`, `InvoiceDetailViewModel`; totales reales, facturas, líneas, pagos y desglose | antiforgery, generación/reenvío existentes, enlaces de detalle; no se mezcla con ClientPortal |

## Superficies y dependencias

- Vistas de entrada: 24 archivos (23 vistas y el parcial `Expenses/_OperatingForm`). Todas parten de `_Layout` por `_ViewStart`; las migradas en Stage 2.4 declaran `_WorkspaceLayout` explícitamente.
- CSS previo: Bootstrap y namespaces legacy `s3`/`s4`, Font Awesome y estilos embebidos en varias vistas. Destino: tokens y patrones `djj-*` existentes en `components.css`, `workspace.css` y `utilities.css`.
- JavaScript funcional: validación unobtrusive; cálculo de total del gasto mediante `data-expense-money`/`data-expense-total`; confirmaciones legacy `data-s3-confirm` en clientes y crédito; scripts propios de facturación/liquidación donde aparecen. Los IDs, `name`, `asp-for`, `data-*` funcionales y secciones `Scripts` se mantienen.
- Montos: CRC visible en todos los dominios; se normaliza a prefijo `₡`, `N2`, alineación derecha y cifras tabulares sin alterar cálculos.
- Fechas: se conservan emisión, vencimiento, pago, creación, jornada/ruta y UTC tal como los entrega cada modelo. No se infieren períodos ni vencimientos ausentes.

## Gate UI UX Pro Max — preimplementación

| Dominio | Jerarquía y densidad | Riesgo UX y acciones | Responsive y accesibilidad |
| --- | --- | --- | --- |
| Finanzas / liquidaciones | Resumen de pendientes y diferencias; tabla compacta; detalle estándar | Liquidar es la única acción primaria; la diferencia debe incluir texto y cifra, no solo color | Tabla con scroll local; montos tabulares; campos y comprobantes con labels; confirmación contextual al liquidar |
| Crédito / cobro | Cliente → saldo/pendiente → vencimiento/estado → acción; compacta en listados | Evitar confundir límite, disponible y deuda; registrar movimiento/configuración requiere consecuencia explícita | Fechas y estado con texto; formularios agrupados; resumen de error enfocable; controles de 44 px |
| Clientes | Identidad/estado primero; relación comercial y pedidos después | Inactivar/reactivar es sensible y conserva motivo/contexto | Acciones apilables; tabla local; email/teléfono legibles; no mezclar portal del cliente |
| Presupuestos | Período, departamento, monto, distribuido/diferencia y estado | Presentar, aprobar, rechazar y cerrar tienen pesos semánticos distintos y confirmación solo cuando corresponde | Cifras explícitas junto al progreso; líneas editables conservan nombres; tablas con scroll local |
| Gastos | Monto, categoría, fecha, responsable, estado y evidencia | Aprobar en success; rechazar/anular en danger; pagar como acción primaria; contexto antes de decidir | Formulario por grupos, errores junto al campo, archivo accesible y acciones verticales en móvil |
| Comparativa | Pregunta central: presupuesto frente a real; línea/serie mensual con tabla equivalente | No usar gauge ni gráfico decorativo; el color nunca sustituye cifras/nivel textual | Barras con `aria-*`, valores textuales, tablas navegables y salida Print legible |
| Facturación admin | Totales reales → facturas → detalle/líneas/pagos | Reenvío/generación conservan permisos y feedback existente | Tablas compactas, importes a la derecha, acciones con texto y targets táctiles |

## Límites confirmados

- No existe un KPI contractual de EBITDA, margen, flujo de caja o aging por tramos; no se añade.
- No se añaden filtros, ordenamientos, bulk actions, acciones de factura ni estados que el backend no soporte.
- La búsqueda UI UX Pro Max para `budget expense approval` y la búsqueda específica de stack `table form responsive` no devolvieron coincidencias verificables; se aplican sus guías generales de tablas/formularios accesibles y el Design System aprobado.
- El smoke autenticado queda condicionado al acceso de Azure SQL. El error conocido es 40615 para la IP `152.231.188.125`; Stage 2.4 no autoriza cambios de firewall.

## Gate UI UX Pro Max — postimplementación

| Dominio | Jerarquía | Claridad financiera | Tabla / formulario / filtros | Estados y prevención | Accesibilidad / responsive | Resultado |
| --- | --- | --- | --- | --- | --- | --- |
| Finanzas / liquidaciones | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |
| Crédito y cobro | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |
| Clientes | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |
| Presupuestos | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |
| Gastos | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |
| Facturación administrativa | PASS | PASS | PASS | PASS | PASS por revisión estática; WARN smoke autenticado | WARN |

No quedaron `FAIL` dentro del alcance. Los `WARN` comparten una sola causa de entorno: no hubo sesión QA autenticada conectada a Azure SQL desde la IP permitida. Se comprobó localmente `GET /health` = 200, `GET /Account/Login` = 200 y redirección 302 a Login para `/Finance` y `/Clients` sin sesión. No se modificó firewall ni se intentó un bypass.

## Validación Stage 2.4

- Restore: aprobado.
- Build Release: aprobado, 0 errores y 0 advertencias.
- Tests: 304/304 aprobados.
- Cobertura Cobertura XML: 8.33% de líneas (1,406/16,863) y 5.53% de ramas. La cobertura global baja preexistente no se oculta; Stage 2.4 añadió cuatro contratos de UI focalizados.
- Secret scan: 878 archivos rastreados, 844 de texto, 12 placeholders aprobados, 0 hallazgos.
- ScriptDom: 130 archivos, 1,032 lotes, 0 errores.
- SVG: 10 archivos válidos, 0 errores. Referencias de assets Stage 2.4: 0 faltantes.
- CSS Stage 2: 7 archivos, 1,069 líneas, 74,773 bytes; 0 `!important`, 0 hex fuera de tokens y 0 tokens indefinidos (se excluyen las custom properties dinámicas declaradas en markup).
- Stage 2 acumulado: 33 vistas con layout Stage 2 de 154 vistas Razor; 121 vistas todavía no migradas.
- Alcance financiero migrado: 22 vistas de página, el parcial de gasto y la salida Print. Auditoría focalizada: 0 `s3`/`s4`, 0 Font Awesome y 0 logos legacy.
- `git diff --check`: aprobado.
