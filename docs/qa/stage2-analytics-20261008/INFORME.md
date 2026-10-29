# Stage 2 — Bloque 4: dashboards, KPI y reportería

Estado: gate local cerrado. Implementación, validación automatizada y QA autenticado administrativo/personal completados dentro de los datos existentes. Las limitaciones de metas asignadas se describen abajo.

## 1. Punto de partida y protección

SHA inicial: `be96d908825954cfb6995de2e1b703c1b8be2365`, rama `codex/stage2-design-system`. HEAD coincide con el gate solicitado. Índice inicialmente vacío. Checkpoint privado previo en `.git/codex-checkpoints/20261008-analytics`, con diff previo y SHA-256 de las cuatro vistas del usuario. No se tocaron Mileage ni Vehicles/Create, Edit, Index. Los documentos y archivos personales no rastreados permanecen fuera del bloque.

## 2. Auditoría de vistas e historia

| Familia | Vista | Historia relevante | Resultado |
|---|---|---|---|
| ManagementDashboard | Index | fa23463 | Conservaba los cuatro indicadores y serie diaria legacy; sin migración Stage 2 previa |
| Kpis | Index, Report | 14e2a5e, 1b1301e | Solo cambios históricos de texto; permanecían metas, ventas, progreso, clasificación, gráfica y tabla |
| SalesReports | Index, Print reutiliza Index | 372230f | Vista actual conservaba la información y contratos originales |
| SellerPerformance | Index, Print reutiliza Index | 372230f | Vista actual conservaba tabla, filtros y exportaciones originales |
| MyGoal | Index | a03cdee | Vista original de progreso personal, sin información eliminada por Stage 2 |

Se revisaron los cinco controllers, ManagementDashboardViewModels, KpiViewModels, SalesReportViewModels, ReportsDbService, KpiDbService, scripts y hojas actuales, SalesReportTests, Stage2DesignSystemTests y pruebas de autorización. No había Chart.js u otra dependencia de gráficos en estas familias: usaban barras HTML/CSS. InventoryIntelligence ya utilizaba ese mecanismo dentro de Stage 2.

Fuentes SQL inspeccionadas, sin ejecución de migraciones: `database_Esteban/cu131_reportes_dashboard_gerencial.sql`, `cu211_213_metas_kpis.sql`, `database/migrations/0015_sales_and_seller_reports.sql` y `0021_seller_goal_progress.sql`. El catálogo local confirmó la existencia de los ocho procedimientos de lectura requeridos. Health MVC/API: 200. Sonda de configuración readonly: ambas aplicaciones Development resuelven DefaultConnection desde User Secrets hacia TrilogiaDev y DistribuidoraJJ_DB; no se mostraron ni modificaron valores privados.

## 3. Información recuperada y ampliada

No hubo pérdida histórica de métricas que requiriera restaurar contratos antiguos. Se preservó la información existente y se mostró información que el modelo vigente ya traía: PedidosPeriodo; Facturas en la serie diaria; Observaciones en metas. Se agregaron tablas equivalentes a las gráficas y montos restantes derivados exactamente de meta menos ventas, acotados a cero y con «sin meta» distinguido de un objetivo cero.

## 4. Información deliberadamente no recuperada

No se recuperaron Bootstrap, Font Awesome, gradientes morados, estilos inline legacy ni referencias CU dentro del texto de producto. No había comparaciones contra el período anterior, proyecciones, series individuales ni drill-down en estas fuentes: no se inventaron. Se preservaron las diferencias de negocio entre facturas «Generada» del tablero y facturas no anuladas de reportería; ticket por factura en ventas y por pedido en vendedores. No se interpolaron días sin facturas.

## 5–9. Cambios por familia

- **ManagementDashboard:** Workspace, filtros rápidos y personalizados, métricas compactas de período, atención operativa actual separada, gráfica diaria y tabla con ventas/facturas. Stock bajo/agotado utiliza estados semánticos.
- **Kpis:** Index conserva formulario Save y antiforgery, vendedor, período, monto y observaciones. Tabla operativa con meta, ventas, porcentaje, restante y progreso. Report conserva resumen global, vendedores con meta, metas cumplidas, clasificación original y comparación meta/venta; tabla con facturas y restante. Enlaces cruzados según permisos reales.
- **SalesReports:** filtros GET originales, agrupación diaria/mensual/categoría, categoría, cuatro totales, gráfica sobre las filas existentes, tabla completa de siete columnas, CSV e impresión. Explicación de los subtotales por categoría para evitar reconciliaciones incorrectas.
- **SellerPerformance:** visión supervisora, filtros y orden original, totales existentes, comparación ventas/meta con escala común y tabla completa, ahora con restante y estado textual. Aclara que metas cubren meses completos; no suma clientes como si fueran únicos del equipo.
- **MyGoal:** vista personal, propiedad determinada por UserId de sesión sin selector de vendedores; meta, venta, pendiente, porcentaje, estado y progreso nativo. Sin meta muestra aviso, conserva ventas propias y evita interpretar ausencia de meta como fracaso.

## 10–12. Componentes, gráficas, tablas y contratos

`_AnalyticsChart` y AnalyticsChartViewModel son presentación reusable con escala común, valores visibles, títulos y período, barras HTML/CSS sin dependencia nueva, equivalentes tabulares, vacío y cero diferenciados. Width usa formato CSS invariante, admite cero y acota la barra sin modificar el dato de origen. El máximo se calcula una vez por render.

Se preservan gráfica diaria, comparación KPI y progreso personal; se crean visualizaciones de ventas agrupadas y desempeño por vendedor. Las tablas existentes de metas, KPI, ventas y vendedores se conservan. Se agregan detalle diario y atención operativa. No se retiraron columnas comerciales originales.

CSS integrado en components.css y workspace.css; no hojas de fixes ni !important. Navegación Workspace agrupa reportes y metas bajo los permisos vigentes. REPORTE_KPI es la política de acción que reemplaza METAS_GESTIONAR; no exige ambos. Controllers, servicios, modelos de dominio, rutas, SQL, permisos y User Secrets no cambian.

## 13–18. Validación

| Pantalla | 1440 | 1280 | 768 | 390 |
|---|---|---|---|---|
| ManagementDashboard | Correcto | Correcto | Correcto | Correcto |
| Kpis/Index | Correcto | Correcto | Correcto | Correcto |
| Kpis/Report | Correcto | Correcto | Correcto | Correcto |
| SalesReports | Correcto | Correcto | Correcto | Correcto |
| SellerPerformance | Correcto | Correcto | Correcto | Correcto |
| MyGoal | Correcto | Correcto | Correcto | Correcto |

24 revisiones autenticadas con capturas privadas: 20 administrativas y 4 personales. ScrollWidth de página 1425/1265/753/375 frente a viewports 1440/1280/768/390: sin overflow horizontal. Cero desbordamientos de valores KPI y series; tablas amplias desplazan localmente (por ejemplo vendedores: 994 px dentro de 350 px en móvil). Cero imágenes rotas y campos sin labels en las medidas realizadas. Solo un h1 en cada vista; tablas con captions y encabezados de fila/columna.

QA funcional: filtros rápidos/personalizado del tablero revisados; ventas diaria (17 filas), mensual (3), categoría Cerveza (1); vendedor individual y orden cumplimiento_desc (1 fila); año/mes KPI y enlaces entre ambas vistas mantienen período. Rango invertido de ventas muestra validación y no consulta datos; el controlador conserva su comportamiento previo. No se envió Save.

CSV de ventas y vendedores descargados y revisados: cabeceras originales de 7 y 8 columnas respectivamente, 1 fila según filtros. Print conserva filtros y detalle. Emulación de medios de impresión en vendedores: sidebar, topbar y botón de impresión ocultos; scroll de tabla visible. No se ejecutó impresión física ni se promete ajuste de toda combinación posible a papel.

Teclado: scroll horizontal local con flecha derecha sin mover la página; menú móvil permite ir a KPI y se cierra tras navegar; Escape restaura foco en Abrir navegación. Emulación de prefers-reduced-motion confirma barras sin animación. Revisión focalizada de accesibilidad, no certificación WCAG completa.
- Console: 0 errores y 0 advertencias en las sesiones revisadas. Network: 0 respuestas >=400 y 0 loadingFailed en las 24 capturas por pantalla/ancho; buffers sin truncamiento ni páginas pendientes. Las acciones adicionales de filtros y validación tampoco mostraron errores de red.
- Build estándar final (`dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug`): correcto, 0 advertencias, 0 errores. También pasó Rebuild completo para asegurar el render Razor definitivo antes del QA administrativo.
- .NET: 340 correctas, 0 fallidas, 0 omitidas (323 baseline + 17 regresiones del bloque).
- JavaScript: 11 correctas, 0 fallidas, 0 omitidas; no código JS nuevo para gráficos.
- diff --check: correcto.

## Límites funcionales previos y alcance de QA

MyGoal exige vendedor activo en SQL; la excepción para Administrador del filtro de autorización no satisface esa regla. No se corrige la autorización de negocio ni se elimina esta función para ocultar el problema. Se verificó MyGoal con una sesión auténtica de Vendedor: respuesta correcta, estado Sin meta asignada, datos personales sin selector de otros vendedores, 0 errores de consola/red, sin desbordamientos ni imágenes rotas en 1440/1280/768/390. No se ejecutó la ruta MyGoal con Administrador para provocar la excepción conocida. La sesión de vendedor queda activa y el viewport se restauró. El catálogo local no contiene metas asignadas: no se crearon datos para simular cumplimiento. Las pruebas verifican los contratos de estados y el escalado con objetivos y sobrecumplimiento, pero no sustituyen un render autenticado de una meta asignada. Ese QA real depende de datos existentes autorizados.

No se envía Save durante QA: validación visual, contrato y antiforgery se revisan sin modificar metas ni otros datos. CSV e impresión son lecturas. Las capturas autenticadas permanecen en el checkpoint privado, fuera de archivos versionados.

## 19–22. Cierre Git

19. **Diff del bloque:** 13 files changed, 953 insertions(+), 520 deletions(-).
20. **Commit local:** `feat(stage2): modernize analytics dashboards`. El SHA exacto se entrega en el mensaje final y se conserva en el checkpoint privado; no se incrusta en el propio commit para evitar una referencia circular.
21. **Status final:** los únicos cambios rastreados pendientes son las cuatro vistas previas del usuario (Fleet/Mileage y Vehicles/Create, Edit, Index), con los mismos SHA-256 iniciales. Los archivos personales previamente no rastreados siguen fuera del commit. Los 13 archivos del bloque se incluyen por rutas explícitas; no se usó git add . ni git add -A. Diff staged revisado, sin archivos de configuración, datos ni capturas autenticadas. Secret scan y diff --check: correctos.
22. **Restricciones:** NO PUSH. NO PR. NO ESCRITURA REMOTA. Sin migraciones, cambios de datos, User Secrets ni merge de main.

NO PUSH. NO PR. NO ESCRITURA REMOTA. Sin migraciones, cambios de datos, User Secrets ni merge de main.
