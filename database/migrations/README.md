# Migraciones de base de datos

## Responsabilidad

Danny, Esteban, Gerald y David forman el equipo administrativo DEV mediante usuarios individuales con `db_owner`. Danny permanece como administrador Microsoft Entra individual del servidor por una limitacion del tenant.

Cada migracion tiene un unico ejecutor designado y registrado en el PR. Los demas administradores no ejecutan simultaneamente el mismo script.

## Flujo obligatorio

1. Crear un script incremental, idempotente y revisable dentro de `database/migrations/`.
2. Abrir un pull request y obtener revision antes de ejecutar.
3. Validar el script con Microsoft ScriptDom.
4. Crear y verificar un BACPAC antes de cualquier cambio compartido.
5. Aplicar el script durante una ventana controlada por el ejecutor designado.
6. Registrar SHA-256, estado, fecha UTC, ejecutor, ambiente y notas en `dbo.SchemaMigrationHistory`.
7. Ejecutar consultas de verificacion y documentar el rollback.

## Rollback

Cada migracion debe indicar su estrategia de rollback antes de ejecutarse. Los cambios transaccionales deben usar `XACT_ABORT` y revertirse ante una validacion fallida. Restaurar un BACPAC es el ultimo recurso y requiere aprobacion expresa.

## Prohibiciones en DEV compartido

- No ejecutar `00_todo_en_uno.sql` ni `DistribuidoraJJ_DB.sql` sobre una base existente.
- No ejecutar scripts de `database_Esteban/`.
- No ejecutar seeds ni datos demo.
- No ejecutar CU090-CU100 sin evidencia, revision y bloque separado.
- No aplicar cambios manuales sin script, PR, backup y registro en el ledger.
- No compartir la cuenta administradora SQL.
- No ejecutar una migracion si otro administrador ya figura como ejecutor activo.

## Orden vigente

| Orden | Archivo | Propósito | Dependencia |
|---:|---|---|---|
| 0001 | `0001_create_schema_migration_history.sql` | Ledger de migraciones | Esquema base |
| 0002 | `0002_chat_private_security.sql` | Conversaciones privadas y pertenencia | Usuarios y perfiles |
| 0003 | `0003_chat_departments_and_search.sql` | Departamentos, miembros, búsqueda y auditoría | 0002 |
| 0004 | `0004_private_delivery_evidence.sql` | Evidencia privada y descarga autorizada | Rutas/entregas CU-081 a CU-083 |
| 0005 | `0005_atomic_checkout_promotions.sql` | Pedido, inventario y promociones atómicos | Checkout CU-097 y promociones CU-171 a CU-174 |
| 0006 | `0006_warranty_workflow.sql` | Garantías sin duplicados y resolución auditada | Pedidos, garantías y auditoría |
| 0007 | `0007_secure_document_management.sql` | Documentos privados, versiones y catálogos operativos | Usuarios y permisos |
| 0008 | `0008_document_expiration_alerts.sql` | Alertas documentales idempotentes | 0007 |
| 0009 | `0009_annual_department_budgets.sql` | Presupuestos anuales normalizados | 0007 (departamentos) |
| 0010 | `0010_operating_expenses_alignment.sql` | Gastos operativos, comprobantes privados y estados | 0009; esquema CU-222 legado opcional |
| 0011 | `0011_budget_actual_comparison.sql` | Comparación presupuesto versus real | 0009 y 0010 |
| 0012 | `0012_inventory_combos_transformations_intelligence.sql` | Combos vendibles, snapshots de pedido/factura, checkout idempotente, transformación atómica, inteligencia y permisos específicos | Esquema de productos/pedidos/usuarios/facturas/permisos; 0005 para checkout/promociones; dependencias Sprint 4 verificadas cuando correspondan |
| 0013 | `0013_purchasing_suppliers_orders.sql` | Proveedores, órdenes, recepción parcial/total, discrepancias, sugerencias e histórico de precios | 0012 y esquema base de productos/inventario/permisos |
| 0014 | `0014_delivery_board_permission.sql` | Permiso exacto del tablero agregado de entregas | Perfiles y permisos |
| 0015 | `0015_sales_and_seller_reports.sql` | Reportes de ventas y desempeño de vendedores | Facturas, pedidos, productos, usuarios, perfiles y permisos |
| 0016 | `0016_cross_sell_recommendations.sql` | Recomendaciones explicables por co-compra con fallback | Pedidos, detalle de pedido y productos |
| 0017 | `0017_rrhh_employee_records.sql` | Expediente laboral, concurrencia, historial y auditoría | Empleados, usuarios, perfiles y permisos |
| 0018 | `0018_rrhh_attendance.sql` | Jornadas propias, aprobación segregada e idempotencia | 0017 |
| 0019 | `0019_payroll_engine.sql` | Planilla configurable, reproducible y auditada | 0018 |
| 0020 | `0020_private_pay_slips.sql` | Boletas privadas y notificación idempotente | 0019 |
| 0021 | `0021_seller_goal_progress.sql` | Progreso mensual de la meta propia del vendedor | Metas, facturas, pedidos y usuarios |
| 0022 | `0022_password_hash_transition.sql` | Transición compatible de credenciales directas a PBKDF2 con actualización gradual | Usuarios, perfiles y API de autenticación |
| 0023 | `0023_supervisor_rrhh_permisos.sql` | Capacidades explícitas de expedientes y boletas para Supervisor | 0017 y 0020 |
| 0024 | `0024_stage1_ownership_security.sql` | Ownership de cierre de kilometraje y capacidad administrativa explícita | Flota, usuarios y permisos |
| 0025 | `0025_session_revocation.sql` | Security stamp y estado vigente de sesión | Usuarios, perfiles y autenticación |
| 0026 | `0026_hash_only_credentials.sql` | Retiro de autenticación activa con contraseña plana | 0022; todos los usuarios activos deben tener hash |
| 0027 | `0027_dynamic_authorization_capabilities.sql` | Capacidades dinámicas para venta móvil, chat y meta propia | Perfiles y permisos |
| 0028 | `0028_granular_mutation_permissions.sql` | Separación de lectura y mutaciones sensibles | Perfiles, permisos, clientes, consultas e inventario |
| 0029 | `0029_complete_capability_catalog.sql` | Versionado de capacidades activas antes presentes solo en scripts históricos | Perfiles y permisos |

Los scripts no incluyen `USE`: el ejecutor debe seleccionar explícitamente la base antes de iniciar. Los hashes escritos por 0002–0011 son hashes de manifiesto para identificar versión; la evidencia de despliegue debe registrar además el SHA-256 real del archivo y actualizar el ledger si corresponde.

Desde 0012, cada migración nueva debe contar con verificador y estrategia de rollback documentada. La verificación y rollback faltantes de 0023 se incorporaron sin alterar el script de migración. La instalación desde cero se define en `database/baseline/README.md`; los archivos `Fase*.sql` y `database_Esteban/` no forman parte de esa secuencia.

## Estado de Azure SQL DEV y fuente de verdad

`dbo.SchemaMigrationHistory` es la única fuente de verdad del estado aplicado en
Azure DEV. Las notas de QA, PR y este repositorio son evidencia histórica: no
autorizan una ejecución ni sustituyen una consulta actual al ledger. Antes de
cualquier migración, el ejecutor designado debe leer únicamente los campos no
sensibles necesarios (`MigrationId`, `FileName`, `FileSha256`, `Status` y
`AppliedAtUtc`) y contrastarlos con el SHA-256 del archivo que pretende aplicar.

La última evidencia documental archivada (2026-08-12) describe respaldo previo y
verificación de 0022, además de ejecuciones anteriores de 0013–0020. No se
reproduce aquí como una afirmación de estado actual porque la consulta directa
del ledger puede cambiar. 0021 también exige confirmación explícita en el ledger.
`database_Esteban/cu222_gastos_presupuesto.sql` es sólo referencia histórica.

## Ejecución controlada de 0012 cuando el ledger la reporte pendiente

No ejecutar 0012 si el ledger ya registra una fila `Applied`. Si está pendiente,
exige BACPAC verificado, ejecutor único y verificación posterior. Tampoco deben
ejecutarse las migraciones `0002`–`0006` por inferencia documental.

Use el ejecutor seguro para calcular el SHA-256 real del archivo final e
inyectarlo por `sqlcmd`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/database/Invoke-Migration0012.ps1 -ServerInstance "<instancia>" -Database "<base>"
```

El modo predeterminado es `-AuthenticationMode Entra` y agrega `sqlcmd -G` para
usuarios individuales de Microsoft Entra. Para LocalDB se usa
`-AuthenticationMode Windows`, que agrega `sqlcmd -E`. El ejecutor no acepta
contraseñas, no usa `-P` y transmite el hash únicamente como una variable
SQLCMD: `-v "MigrationSha256=<SHA-256>"`.

`-DryRun` solo calcula y valida el hash, informa la ruta y el modo seleccionado
sin abrir conexión. El script usa `sqlcmd -b`, no recibe ni imprime connection
strings o contraseñas y falla si la expansión de hash no es válida. La prueba
sin conexión `scripts/database/Test-InvokeMigration0012.ps1` cubre los modos
Entra/Windows, la variable SQLCMD y las protecciones del ejecutor. Después debe ejecutarse
`0012_inventory_combos_transformations_intelligence.verify.sql` en modo de solo
lectura. El rollback continúa documentado en el archivo correspondiente.

### Compatibilidad legada validada localmente

La versión final de 0012 acepta tanto una instalación sin tablas de combos como
el esquema legado confirmado en el BACPAC previo de Azure DEV. La reconciliación
renombra columnas legadas, conserva claves y datos, rellena las columnas
canónicas, valida antes de crear restricciones y reconstruye
`PedidoComboDetalle` únicamente desde `PedidoDetalle.PedidoComboId`. Cualquier
cantidad no divisible, referencia huérfana, duplicado o snapshot contradictorio
produce `THROW` y rollback.

Los componentes legados dejan de contarse como productos sueltos en pedidos,
checkout, inteligencia, restauración y facturación. `FacturaCombos` no recibe
backfill de facturas antiguas para evitar doble contabilización; se usa para
facturas generadas después de 0012.

`database/verify/0012_legacy_reconciliation_local.sql` es una prueba en dos
fases exclusiva de LocalDB desechable: antes de 0012 captura evidencia agregada
sin datos personales y después compara conteos, claves, totales, inventario y
la reconstrucción, además de ejecutar `DBCC CHECKDB`.

## Migraciones 0013–0016

Estas migraciones no reutilizan los números 0007–0012 del prototipo de compras del PR #116. Cada archivo recibe el SHA-256 real mediante `sqlcmd -v "MigrationSha256=<SHA-256>"`, cuenta con `verify.sql` y rollback documentado, y rechaza una segunda aplicación registrada.

La ruta 0013 se validó en LocalDB desde esquema mínimo y desde la variante legada de compras; su prueba funcional cubre reintentos, recepción parcial, sobre-recepción, cierre con discrepancia, inventario y auditoría transaccional. La secuencia 0013–0016 también se ejecutó en una base LocalDB desechable, incluyendo la invocación vacía de los procedimientos de reportes y venta cruzada. El estado de Azure DEV debe obtenerse del ledger antes de cualquier operación; el QA autenticado sigue siendo una actividad separada.

El harness reproducible crea y elimina una base cuyo nombre empieza por `TrilogiaMigrations_`, se niega a operar fuera de LocalDB y cubre hash inválido, ausencia de residuos, migraciones y verificadores en orden, flujo funcional de compras, invocaciones vacías, segunda aplicación rechazada, documentos de rollback, ledger y `DBCC CHECKDB ... WITH PHYSICAL_ONLY`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/database/Test-Migrations0013To0016.ps1 -ServerInstance "(localdb)\MSSQLLocalDB"
```

Si la instancia estándar no está disponible, se debe pasar explícitamente otra instancia LocalDB propia. Nunca usar este harness contra Azure o SQL compartido.

## Migraciones 0017–0020

Estas migraciones se validaron sintácticamente con ScriptDom y tienen `verify.sql` y rollback compensatorio documentado. El estado de Azure DEV no se infiere de esta sección: debe obtenerse del ledger. Antes de cualquier aplicación se exige BACPAC, ejecutor único, SHA-256 real, configuración responsable de factores/reglas y QA autenticado. No se precargan porcentajes, tasas ni fórmulas legales.

## 0030 — Invalidación de autorización Stage 2

`0030_stage2_authorization_invalidation.sql` depende de los IDs completos
`0025_session_revocation` y `0027_dynamic_authorization_capabilities` y sus hashes
acreditados. Amplía el `SecurityStamp` existente mediante triggers transaccionales
en `PerfilPermisos`, `Permisos` y `Perfiles`; no asigna usuarios ni privilegios.
No elige entre las colisiones históricas 0023–0028 ni reescribe filas previas del ledger.
Requiere respaldo restaurado y prueba en copia aislada antes de instalar. Recibe
`MigrationSha256` calculado sobre los bytes finales; repetir con el mismo hash es
idempotente y un hash distinto se rechaza. Verificación y compensación: archivos
`0030_stage2_authorization_invalidation.verify.sql` y `.rollback.md`.

Esta evolución no certifica identidad de login original, emisión separada de precios
ni autorización comercial en la transacción de pedidos: son contratos adicionales.

## 0031 — Confirmación física de entrega

Depende de 0030 y del contrato existente Rutas/RutaPedidos/EntregaSyncLog/Facturas.
Agrega evidencia física inmutable sin backfill. La actualización de entrega
comprueba stamp vigente, asignación, UUID/contenido y factura antes de confirmar;
no descuenta inventario. Todos los consumidores locales deben enviar
`@ExpectedSecurityStamp`. Ejecutar con `sqlcmd -I -b -f 65001` y hash de archivo;
el verificador exige QUOTED_IDENTIFIER/ANSI_NULLS capturados en ON. Ver las
limitaciones y compensación en `0031_stage2_physical_delivery.rollback.md`.

Esta evidencia no sustituye los contratos pendientes de login original y precios,
ni certifica el circuito comercial completo.

## 0032 — Garantías con propiedad, entrega y autorización

Depende del hash exacto de 0031 y del contrato local acreditado de Garantias.
Evoluciona la creación y agrega gestión con GARANTIAS_GESTIONAR efectivo,
SecurityStamp vigente y auditoría atómica. No reescribe históricos ni crea
privilegios. Instalar con `sqlcmd -I -b -f 65001` y hash real después de respaldar,
restaurar y probar. Ver archivos `.verify.sql` y `.rollback.md` de 0032.

## 0033 — Reclamos CU-191/192

Depende de 0032 por hash y del permiso RECLAMOS_GESTIONAR ya existente. Solo
instala donde no haya objetos previos del módulo. Agrega el esquema vacío y los
seis procedimientos consumidos por MVC, con autorización transaccional real,
propiedad de factura/pedido y auditoría atómica. No copia los stubs de autorización
del laboratorio, no crea grants ni datos demo. Usar `sqlcmd -I -b -f 65001` y hash
real después de respaldo/restauración/pruebas aisladas. Ver `.verify.sql` y `.rollback.md`.

## 0034 — Login original MVC con ocho horas absolutas

Depende de 0033 por hash. Registro inmutable de actor/perfil/stamp, binding de sesión
y timestamps UTC datetime2(7). SQL fija ocho horas sin renovación deslizante y confirma
emisión/revocación con auditoría atómica. No adopta sesiones antiguas ni crea relaciones
comerciales, perfiles o grants. Los consumidores MVC requieren autenticación nueva.
Usar respaldo/restauración/prueba aislada, `sqlcmd -I -b -f 65001` y hash real;
ver `.verify.sql` y `.rollback.md`, incluidos los límites de esta integración.

## 0035 — Capacidad explícita de garantías para Administrador

Autorización humana expresa: GARANTIAS_GESTIONAR únicamente para el perfil
Administrador existente, PerfilId 1. Depende de 0034 por hash. Agrega la definición
ausente y una asignación explícita, audita con la identidad SQL real e invalida
sesiones anteriores mediante 0030. No crea asignaciones comerciales ni bypass.
Requiere pruebas SQL/HTTP aisladas y respaldo restaurado del conjunto 0034/0035.
Ver `.verify.sql` y `.rollback.md`; instalar con `sqlcmd -I -b -f 65001` y hash real.

## Evidencia privada legada

Los registros anteriores a 0004 conservan `StorageStatus = Legacy` y no se sirven desde la aplicación. Antes de retirar cualquier carpeta pública histórica, un operador debe copiar cada archivo a `EvidenceStorage:RootPath`, asignar una clave generada, verificar la firma binaria y marcar el registro como `Ready`. No se debe marcar como listo un archivo inexistente o no validado.

## 0036–0038 — Transacciones, facturación y propiedad original del checkout

- **0036_stage2_transactional_login** agrega el guard del login original/capacidad
  dentro de la transacción MVC, con locks hasta el commit y comprobación final de
  vencimiento. No prolonga sesiones ni cambia procedimientos históricos.
- **0037_stage2_invoice_states** agrega contratos versionados para facturación y
  estado manual. Factura pedidos con inventario ya acreditado; conserva la factura
  existente en reintentos, audita Liberado → Facturado y no infiere entrega física.
  Retenidos, importes superiores al umbral sin relación supervisora e inventario
  no acreditado permanecen bloqueados. No reescribe históricos durante instalación.
- **0038_stage2_checkout_intent_owner** conserva de manera inmutable el UUID,
  login/actor originales y huella del contenido. La reserva sobrevive a un fallo
  comercial, pero el logout, otra sesión o un cambio de cuerpo no permite apropiarla.
  MVC conserva el cuerpo solamente en su sesión del servidor y recupera el recibo
  sin depender del carrito ya vaciado. No adopta tokens históricos sin propietario.

Requieren sus hashes de prerequisitos exactos, respaldo actual restaurado y probado,
`sqlcmd -I -b -f 65001`, SHA256 de bytes finales, archivos `.verify.sql` y lectura de
las limitaciones/compensación de cada `.rollback.md`. No elegir ni reinterpretar
las colisiones históricas 0023–0028.

El guard C# del checkout reutiliza PromotionEngine y las fuentes SQL bloqueadas
por 0012: si aplicaciones/importes difieren, revierte el pedido. También bloquea
importes finales mayores que 2.000.000 sin la relación supervisora acreditada.
La precisión por unidad de 0012 no se corrige reescribiendo esa migración. Estas
mejoras no certifican el checkout 6B completo, autoridad separada de cotizaciones,
retención/aprobación operativa ni facturación automática de pedidos nuevos.
## 0039–0042 — Maestro 2: importes y operación local

Aplicar en orden 0039, 0040, 0041 y 0042 solo después de acreditar destino, respaldo CHECKSUM/VERIFYONLY, restauración real y aceptación en la copia. Cada script requiere su SHA256 real mediante `MigrationSha256`; ejecutar su `.verify.sql` con el mismo valor. Conservar 0030–0038 y las colisiones históricas sin reinterpretar sus hashes.

- **0039**: snapshots inmutables V2 de bruto, descuento agregado, neto, impuesto13% y total final; nuevos procedimientos de checkout académico, detalle y factura. No reparte descuentos por unidad ni reescribe históricos. Los lectores nuevos usan fallback para registros sin snapshot. No activa facturación automática integral, autoridad de cotizaciones ni supervisión comercial.
- **0040**: procedimientos Documents por `ResponsableUsuarioId` con transacción de login original desde MVC. Listas, métricas, historial, cambios y alertas propios; no hay bypass de Administrador. Sin fuente de grants departamentales: creación personal y bloqueo de delegación/cambio de departamento. No crea grants ni departamentos y no ejecuta purgas.
- **0041**: elegibilidad positiva Facturado+factura vigente para rutas; confirmación y auditoría atómicas; nuevas evidencias privadas con SHA256/longitud y lectura verificada. Añade campos nullable al esquema legado sin backfill ni conversión de ArchivoUrl. Históricos conservados como referencias, no habilitados como archivos privados por inferencia. Liquidaciones/reentregas pendientes permanecen bloqueadas.
- **0042**: nueva revisión V2.1 acreditada por hash del módulo0039, que omite descuentos redondeados a cero antes de seleccionar prioridad/id; auditoría de autorización de descarga propia. No modifica módulos previos. La descarga autorizada no significa transferencia completa del archivo.

Los snapshots nuevos se consumen también desde los lectores de facturación, portal y reportes que antes multiplicaban el unitario. Los importes y filtros históricos permanecen. CheckoutPricingGuard y PromotionEngine original siguen comprobándose: no aceptar diferencias para habilitar un flujo bloqueado. Ver los documentos `.rollback.md`; no ejecutar un down destructivo, borrar ledger o restaurar la principal automáticamente.

- **0043**: reporte de ventas por categoría versionado, conserva filtros/resultsets y usa neto V2 con fallback histórico. Aplicar después de0039, con las mismas comprobaciones de respaldo/restauración/hash. El procedimiento0015 original permanece intacto.
