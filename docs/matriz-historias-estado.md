# Matriz de historias, implementación y verificación

Estado al 3 de agosto de 2026. Para CU-201/202/221/222/223, “pendiente entorno” significa que el esquema 0007–0011 ya fue verificado en Azure, pero falta login autorizado y flujo real en navegador. No se cerraron issues automáticamente.

| CU | Issue | Estado | Evidencia principal | Verificación / pendiente |
|---|---:|---|---|---|
| 081 | #28 | Implementada; pendiente entorno | `RoutesAdminController`, `cu081_rutas_entregas_esquema.sql` | Build/SQL; QA de rutas |
| 101 | #36 | En QA; issue cerrada con comentario de duplicado incorrecto | `SuppliersController`, `PurchasingDbService`, vistas de proveedores | Migración 0013 y pruebas locales; corregir trazabilidad de GitHub |
| 082 | #29 | Implementada; pendiente entorno | `DriverDeliveriesController`, `cu082_entregas_estado_offline_sps.sql` | Build/SQL; QA chofer/offline |
| 102 | #37 | En QA; issue cerrada con comentario de duplicado incorrecto | `PurchaseOrdersController`, recepción parcial/total y discrepancias | 0013 validada en esquema limpio/legado; falta QA Azure/UI |
| 083 | #30 | Reforzada; pendiente entorno | `EvidenceStorageService`, `DeliveryEvidenceController`, migración 0004 | Tests de archivos; QA SQL/almacenamiento |
| 103 | #38 | En QA; issue cerrada con comentario de duplicado incorrecto | Sugerencias en `PurchaseOrdersController`/`PurchasingDbService` | Pruebas y SQL locales; falta QA con datos productivos anonimizados |
| 105 | #40 | Implementada; pendiente entorno | `ReturnsController`, `cu141_142_105_devoluciones_cuarentena_liquidacion.sql` | Build/SQL; QA liquidación |
| 106 | #41 | Implementada; pendiente entorno | `FinanceController`, `cu106_liquidacion_financiera.sql` | Build/SQL; QA financiera |
| 131 | #50 | Implementada; pendiente entorno | `ManagementDashboardController`, `cu131_reportes_dashboard_gerencial.sql` | Build/SQL; QA dashboard |
| 141 | #54 | Implementada; pendiente entorno | `ReturnsController`, `cu141_142_105_devoluciones_cuarentena_liquidacion.sql` | Build/SQL; QA devolución |
| 142 | #55 | Implementada; pendiente entorno | `ReturnsController`, mismo script CU-141 | Build/SQL; QA cuarentena |
| 143 | #56 | Implementada; pendiente entorno | `ReturnsController`, mismo script CU-141 | Build/SQL; QA seguimiento |
| 144 | #57 | Reforzada; pendiente entorno | `ClientPortalController`, `WarrantyRequestsAdminController`, migración 0006 | Tests de filtros; QA SQL completo |
| 151 | #58 | Implementada; pendiente entorno | `VehiclesController`, `cu151_vehiculos_marca.sql` | Build/SQL; QA flotilla |
| 152 | #59 | Implementada; pendiente entorno | `FleetController`, `cu152_153_154_161_flota_activos.sql` | Build/SQL; QA kilometraje |
| 153 | #60 | Implementada; pendiente entorno | `FleetController`, mismo script CU-152 | Build/SQL; QA mantenimiento |
| 154 | #61 | Implementada; pendiente entorno | `FleetController`, mismo script CU-152 | Build/SQL; QA alertas |
| 161 | #62 | Implementada; pendiente entorno | `AssetsController`, mismo script CU-152 | Build/SQL; QA activos |
| 162 | #63 | Implementada; pendiente entorno | `ComodatosController`, `cu162_163_164_comodatos.sql` | Build/SQL; QA asignación |
| 163 | #64 | Implementada; pendiente entorno | `ComodatosController`, mismo script CU-162 | Build/SQL; QA devolución |
| 164 | #65 | Implementada; pendiente entorno | `ComodatosController`, mismo script CU-162 | Build/SQL; QA rentabilidad |
| 171 | #66 | Reforzada; pendiente entorno | `PromotionsController`, `PromotionEngine`, migración 0005 | Tests de prioridad; QA SQL |
| 172 | #67 | Reforzada; pendiente entorno | Segmento en `PromotionEngine`/0005 | Test de segmento; QA SQL |
| 173 | #68 | Reforzada; pendiente entorno | `CartController`, `StoreDbService`, migración 0005 | Tests de promociones; QA concurrencia |
| 174 | #69 | Implementada; pendiente entorno | `PromotionsController`, `cu171_174_promociones.sql` | Build/SQL; QA inactivación |
| 181 | PR #114/#115 | Integrada; pendiente Azure/QA | `ComboDbService`, `CartController`, migración 0012 | Combos vendibles, snapshots, componente inactivo y QA público local |
| 182 | PR #114/#115 | Integrada; pendiente Azure/QA | `InventoryTransformationDbService`, migración 0012 | Transformación atómica, locks y concurrencia LocalDB |
| 241 | PR #114/#115 | Integrada; pendiente Azure/QA | `InventoryIntelligenceDbService`, migración 0012 | Sugerencias con cobertura y datos insuficientes |
| 242 | PR #114/#115 | Integrada; pendiente Azure/QA | `InventoryIntelligenceDbService`, migración 0012 | Productos de baja rotación y riesgo |
| 243 | PR #114/#115 | Integrada; pendiente Azure/QA | `InventoryIntelligenceDbService`, migración 0012 | Tendencia de doce meses y datos cero |
| 191 | #72 | Implementada; pendiente entorno | `ReclamosController`, `cu191_192_reclamos.sql` | Build/SQL; QA registro |
| 192 | #73 | Implementada; pendiente entorno | `ReclamosController`, mismo script CU-191 | Build/SQL; QA cierre/resolución |
| 201 | #74 | Implementada; DB verificada, QA autenticado pendiente | `DocumentsController`, almacenamiento privado, migración 0007 | Objetos/permisos Azure verificados; falta flujo UI |
| 202 | #75 | Implementada; DB verificada, QA autenticado pendiente | `DocumentAlertService`, migración 0008 | Objetos/permisos Azure verificados; falta idempotencia UI/SMTP opcional |
| 211 | #76 | Implementada; pendiente entorno | `KpisController`, `cu211_213_metas_kpis.sql` | Build/SQL; QA metas |
| 212 | #77 | Implementada; pendiente entorno | `KpisController`, mismo script CU-211 | Build/SQL; QA progreso |
| 213 | #78 | Implementada; pendiente entorno | `KpisController`, mismo script CU-211 | Build/SQL; QA reporte |
| 221 | #79 | Implementada; DB verificada, QA autenticado pendiente | `BudgetsController`, `BudgetDbService`, migración 0009 | Objetos/permisos Azure verificados; falta aprobación/concurrencia UI |
| 222 | #80 | Implementada; DB verificada, QA autenticado pendiente | `ExpensesController`, `ExpensesDbService`, migración 0010 | Objetos/permisos Azure verificados; falta comprobante/transiciones UI |
| 223 | #81 | Implementada; DB verificada, QA autenticado pendiente | `BudgetComparisonController`, migración 0011 | Procedimiento Azure verificado; falta UI/CSV/impresión autenticados |
| 231 | #82 | Corregida y probada; pendiente entorno | `ChatController`, `ChatHub`, migración 0002 | Tests autorización; QA SignalR/SQL |
| 232 | #83 | Corregida y probada; pendiente entorno | `ChatDbService`, vista admin, migración 0003 | Tests filtros; QA CRUD/SignalR |
| 233 | #84 | Corregida y probada; pendiente entorno | `chat.js`, `sp_Chat_SearchMessages` | Paginación implementada; QA SQL/UI |
| 251 | #88 | Implementada; pendiente entorno | `RoutesAdminController`, `cu251_252_253_rutas_inteligentes.sql` | Build/SQL; QA secuenciación |
| 252 | #89 | Implementada; pendiente entorno | Vistas/servicio de rutas, mismo script CU-251 | Build/SQL; QA mapa móvil |
| 253 | #90 | Implementada; pendiente entorno | `RoutesAdminController`, mismo script CU-251 | Build/SQL; QA recálculo |
| 261 | #91 | Implementada; pendiente entorno | `AssistantController`, `cu261_263_asistente.sql` | Asistente por reglas; QA intenciones |
| 262 | #92 | En QA | `CrossSellDbService`, `CrossSellPolicy`, recomendaciones en carrito, migración 0016 | Pruebas de soporte/fallback/exclusiones y SQL local; falta QA Azure/UI |
| 263 | #93 | Implementada; pendiente entorno | `AssistantController`, `cu261_263_asistente.sql` | Build/SQL; QA ayuda por módulo |

## Cobertura automatizada de esta rama

- Chat: pertenencia/administración, política de mensajes y filtros de controladores.
- Evidencias: firmas, extensión/MIME, claves seguras, traversal y ciclo stage/commit/read.
- Promociones: prioridad, redondeo, segmento, vigencia y límite por stock de regalía.
- Seguridad MVC: filtros de sesión/admin y antiforgery en POST críticos.
- Sprint 4 Danny: distribución decimal, segregación, umbrales, proyección, neutralización CSV, archivos privados y atributos de seguridad.

- Sprint 4 David integrado: contratos de combo activo, carrito, checkout atómico,
  hash de migración, correo autoritativo, descuentos y regalos.

Total local actualizado en PR #115: 117 pruebas aprobadas. El detalle de QA de entorno está en `docs/qa-final.md`.

## Cierre integral — matriz de decisión persistente

| CU | Issue | Estado GitHub | Evidencia en código | Evidencia SQL | Pruebas | QA | Brecha | Acción |
|---|---:|---|---|---|---|---|---|---|
| 012 | #2 / #3 | #2 abierta; #3 cerrada | Funcionalidad histórica presente | Esquema histórico | Regresión general | Pendiente entorno | Duplicidad de issue | Conservar una canónica y enlazar la otra con evidencia |
| 084 | #31 | Abierta | `DeliveryBoardController`, vista con sondeo autorizado | 0014 | Contrato de permiso/endpoint | Local automatizado | Navegador y datos reales | Mantener En QA hasta smoke autenticado |
| 101 | #36 | Cerrada | Proveedores extremo a extremo | 0013 | Políticas/permisos | LocalDB limpio y legado | Comentario de duplicado erróneo | Reabrir o corregir cierre y enlazar este PR |
| 102 | #37 | Cerrada | Órdenes, recepción, cancelación y discrepancia | 0013 | Idempotencia y contratos | LocalDB funcional | Falta Azure/UI | Corregir cierre y ejecutar plan manual |
| 103 | #38 | Cerrada | Reabastecimiento con datos insuficientes | 0013 | Contratos | LocalDB funcional | Falta Azure/UI | Corregir cierre y enlazar evidencia |
| 104 | #39 | Cerrada | Histórico y variación absoluta de precio | 0013 | Umbral del 15 % | LocalDB funcional | Falta Azure/UI | Confirmar etiqueta Completada tras QA |
| 111 | #42 | Abierta | Expediente, concurrencia, salario, historial y auditoría mediante `IEmployeesService` | 0017 | Seguridad y reglas focales | Automatización local | Falta aplicar migración y QA autenticado | Mantener En QA; no cerrar todavía |
| 112 | #43 | Abierta | Jornadas propias, envío y decisión segregada | 0018 | Reglas, permisos y antiforgery | Automatización local | Falta base completa y QA de roles | Mantener En QA |
| 113 | #44 | Abierta | Motor configurable, snapshot, huella, idempotencia y estados segregados | 0019 | Cálculo puro, configuración y permisos | Automatización local | Responsable debe validar factores, fuentes y reglas; falta QA SQL/UI | Mantener En QA |
| 114 | #45 | Abierta | Boleta privada por propietario, descarga derivada y correo con enlace HTTPS | 0020 | Fake SMTP, idempotencia, encoding y permisos | Automatización local | Falta URL pública/SMTP seguro y QA autenticado | Mantener En QA |
| 132 | #51 | Abierta | `SalesReportsController`, impresión y CSV | 0015 | Filtros, permisos, métricas y contrato | SQL local | Falta navegador/Azure | Mantener En QA |
| 134 | #53 | Abierta | `SellerPerformanceController`, metas opcionales | 0015 | Filtros, permisos y CSV | SQL local | Falta navegador/Azure | Mantener En QA |
| 262 | #92 | Abierta | Co-compra explicable y fallback en carrito | 0016 | Datos suficientes/insuficientes, stock, repetidos y sin historial | SQL local | Falta navegador/Azure | Mantener En QA |

### Cambios recomendados en GitHub Issues

- #2/#3: declarar explícitamente cuál issue de CU-012 queda canónica y enlazar la otra como duplicada, sin conservar dos estados contradictorios.
- #36, #37 y #38: retirar la afirmación de que CU-101/102/103 duplican CU-081/082/083; son proveedores, compras y abastecimiento. Enlazar migración 0013, pruebas y este PR.
- #39: enlazar CU-104 con el histórico de precios de 0013 y exigir QA antes de confirmar “Completada”.
- #31, #51, #53 y #92: cambiar a “En QA” cuando este PR sea aceptado; cerrar solo tras evidencia autenticada.
- #42: “Implementada sin QA”; #43–#45: “No iniciada”. No cerrarlas por compilación ni por código histórico parcial.
