# Integración Sprint 4 — Danny y David

## Alcance y trazabilidad

La rama `codex/integracion-sprint4-danny-david-final` parte de
`codex/p0-saneamiento-integracion-total-20260722`, porque el PR #112 continúa
abierto. La integración conserva los trece commits de Danny y los dos commits
de David mediante merges explícitos. Antes de integrar se crearon las
referencias locales `backup/pre-integracion-danny`,
`backup/pre-integracion-david` y `backup/pre-integracion-final`.

Los tres commits posteriores de David se auditaron individualmente antes de
decidir no incorporarlos por estar supersedidos por esta implementación.

Los únicos conflictos estuvieron en `Proyecto_Final/appsettings.json` y
`Proyecto_Final/appsettings.Development.json`. Se conservaron las plantillas
sanitizadas que incluyen almacenamiento privado y alertas documentales; la
versión entrante solo aportaba una plantilla comentada y perdía esas secciones.
No se incorporaron credenciales ni valores operativos.

## Auditoría inicial — 25 de julio de 2026

### Evidencia automatizada de partida

- `dotnet restore Proyecto_Final.slnx`: aprobado.
- `dotnet build Proyecto_Final.slnx --configuration Release --no-restore`:
  aprobado, 0 errores y 0 advertencias.
- `dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj
  --configuration Release --no-build`: 92 aprobadas, 0 fallidas.
- Escaneo de secretos: aprobado; 639 archivos rastreados, 608 archivos de
  texto y 12 placeholders o valores vacíos permitidos.
- ScriptDom: 75 archivos y 876 lotes analizados, 0 errores de sintaxis.

Esta evidencia solo confirma el baseline integrado. No demuestra ejecución
SQL, concurrencia, login ni funcionamiento de las historias nuevas.

### Hallazgos de Danny — CU-201, CU-202, CU-221, CU-222 y CU-223

- La arquitectura funcional ya separa documentos, alertas, presupuestos,
  gastos y comparativa en controladores y servicios específicos.
- Las rutas sensibles tienen permisos granulares y los POST tienen
  antiforgery. Los archivos y comprobantes usan almacenamiento privado.
- Las migraciones 0007–0011 están documentadas como aplicadas y verificadas en
  Azure DEV; no se volverán a ejecutar.
- El QA autenticado sigue pendiente por falta de una credencial de prueba
  válida autorizada. No se modificará ninguna contraseña para resolverlo.
- Las vistas son funcionales pero demasiado compactas, con jerarquía visual,
  accesibilidad, responsive y confirmaciones insuficientes. Presupuestos y
  gastos no tienen todavía todas las rutas GET dedicadas solicitadas para
  crear/editar. La comparativa contiene estilos inline y la impresión no usa
  un estilo reutilizable.
- La validación del dominio existente cubre distribución anual, separación de
  aprobación, umbrales, archivos, presupuesto cero y CSV, pero requiere más
  pruebas de rutas, anulaciones e idempotencia.

### Hallazgos de David — CU-181, CU-182, CU-241, CU-242 y CU-243

- El código agregado compila, pero ocho procedimientos llamados desde C# no
  tienen definición en ningún script del repositorio:
  `sp_Admin_GetCombos`, `sp_Admin_GetComboDetail`,
  `sp_Admin_CreateCombo`, `sp_Admin_AddComboDetail`,
  `sp_Admin_ToggleComboStatus`, `sp_Admin_GetPurchaseSuggestions`,
  `sp_Admin_GetSlowMovingProducts` y
  `sp_Admin_GetSeasonalSalesTrend`.
- Tampoco existe el procedimiento atómico requerido para transformación. La
  implementación actual lee stock en C#, calcula y actualiza después dentro de
  una transacción, sin bloqueo determinista, protección de overflow ni una
  referencia común entre los dos movimientos.
- Combos solo existe como administración. No se publica en tienda, no entra al
  carrito, no se procesa en checkout, no conserva snapshots de pedido/factura
  y no descuenta componentes.
- La creación confía en una lista de productos enviada por el navegador, usa
  `AddWithValue` y puede aceptar IDs repetidos o manipulados. El controlador
  muestra mensajes de dominio internos y no registra errores con `ILogger`.
- Combos y transformación solo usan el permiso genérico `Inventario`; no
  existen permisos `COMBOS_VER`, `COMBOS_GESTIONAR`,
  `INVENTARIO_TRANSFORMAR` ni `INVENTARIO_INTELIGENCIA_VER`.
- Las sugerencias no exponen ventana, cobertura, stock mínimo ni datos
  insuficientes. Los estancados no exponen última venta, antigüedad ni nivel de
  riesgo. La tendencia mezcla todos los años, no garantiza doce meses y usa
  `Substring(0, 3)` sin validar longitud.
- Las vistas de David incluyen CSS y estilos inline, no tienen filtros de
  período y carecen de estados accesibles y confirmaciones consistentes.
- No hay pruebas automatizadas para combos, checkout de combos,
  transformación, concurrencia, fórmulas de inteligencia ni permisos nuevos.

### Estado SQL y Azure DEV

Después de integrar, 0012 es el siguiente número libre en el repositorio. La
nueva migración deberá crear los objetos de combos, snapshots de pedido,
transformaciones e inteligencia, además de permisos, índices, checks, claves
foráneas y contratos compatibles con C#.

La variable de entorno disponible fue validada sin imprimir su valor: apunta
al servidor DEV autorizado y a `DistribuidoraJJ_DB_DEV`. El primer intento de
lectura de metadatos devolvió temporalmente que la base no estaba disponible.
No se consultaron filas, no se ejecutó SQL y no se alteró Azure. Antes de una
aplicación serán obligatorios: ledger, confirmación de 0007–0011, ausencia de
0012, objetos reales, BACPAC o respaldo verificable y ejecutor único.

## Corrección final del PR #115 — 27 de julio de 2026

### Trazabilidad de David

Se preservaron mediante merge explícito los dos commits iniciales disponibles al
momento de iniciar la integración. Los tres commits posteriores de David fueron
revisados individualmente. Su funcionalidad fue sustituida, integrada o
reforzada por la implementación consolidada del PR #115, manteniendo la
atribución funcional de CU-181, CU-182, CU-241, CU-242 y CU-243 a David.

- `acb464f`: no se incorpora; sus migraciones 0002–0004 no son incrementales
  en esta línea y fueron sustituidas por la migración oficial 0012.
- `1801d0b`: no se incorpora; incluye una transformación menos completa,
  pruebas aisladas y assets de prueba bajo `wwwroot`. 0012 conserva bloqueo
  determinista, control de overflow, auditoría y pruebas integradas.
- `de108ff`: no se incorpora; catálogo, carrito, checkout, snapshots y correo
  están cubiertos y reforzados por 0012, `ComboDbService`, `CartController` y
  las pruebas de integración. No se agregan sus imágenes de prueba.

### Correcciones verificables

- Un combo es vendible solo si está activo, tiene componentes y todos existen,
  están activos, tienen cantidad positiva y stock suficiente. Las consultas de
  tienda excluyen el combo inválido; administración lo muestra con stock cero y
  un estado textual, y el carrito lo elimina al refrescarse.
- El checkout vuelve a validar esos componentes bajo bloqueo y rechaza una
  solicitud manipulada sin alterar el inventario.
- El comprobante usa el total confirmado por SQL, refleja descuentos, combos y
  regalos, escapa los textos HTML y no revierte un pedido ya confirmado si SMTP
  falla.
- La migración recibe `$(MigrationSha256)` desde `sqlcmd`; el ejecutor
  `scripts/database/Invoke-Migration0012.ps1` calcula el SHA-256 real del
  archivo, lo valida y no imprime secretos. El hash no se hardcodea dentro de
  la migración ni se obtiene de una cadena de versión.
- `database/00_todo_en_uno.sql` fue comparado contra la rama base: no tiene
  diferencia en este PR, no se ejecutó y el cambio mencionado en un resumen
  local fue descartado antes de commitear.

### Métricas SQL separadas

- Validación local focalizada de `database/`: 56 archivos y 517 lotes.
- Validación CI recursiva de `database` y `database_Esteban`: 83 archivos y
  916 lotes al cierre local de esta corrección.

## Arquitectura objetivo

- Servicios separados para combos, transformación e inteligencia; C# usa
  parámetros tipados, nombres de columna, cancellation tokens y mensajes
  públicos genéricos.
- SQL es la autoridad para precios, componentes, disponibilidad, stock,
  totales y transiciones. Las filas de productos se bloquean por `ProductoId`.
- El carrito distingue producto y combo por una clave tipada. El checkout
  envía solo identidad, tipo y cantidad; SQL recalcula todo y usa un token
  idempotente por intento.
- Pedido y factura conservan el nombre, precio y componentes del combo tal como
  se vendió, aunque el catálogo cambie después.
- Inteligencia usa pedidos válidos, ventanas explícitas y doce meses completos,
  con nulos tratados como cero.
- La UI reutiliza un único archivo `sprint4-admin.css`, variables de marca,
  componentes accesibles, responsive, estados vacíos y confirmaciones.

## Despliegue y rollback preliminar

La migración 0012 será aditiva, transaccional y registrada en
`SchemaMigrationHistory`. Su rollback documentado no borrará datos como paso
ordinario: primero se retirarán rutas dependientes y, si fuese necesario, se
aplicará una migración compensatoria. La restauración de BACPAC será el último
recurso y requiere aprobación expresa.

## Limitaciones reales abiertas

- Azure DEV no estuvo disponible durante el primer intento de auditoría.
- No existe todavía credencial autorizada para QA autenticado de navegador.
- La implementación, pruebas de concurrencia, migración 0012 y QA completo se
  desarrollan después de esta auditoría; no se consideran terminados en este
  punto.

## Evidencia final de integracion - 27 de julio de 2026

- `dotnet build Proyecto_Final.slnx -c Release --no-restore`: aprobado, sin errores ni advertencias.
- `dotnet test Proyecto_Final.slnx -c Release --no-restore`: 117 aprobadas, 0 fallidas.
- ScriptDom: los 56 archivos SQL y 517 lotes del directorio `database/` son válidos.
- La instancia LocalDB aislada `TrilogiaSprint4Clean` se reconstruyo desde una base nueva, aplico 0001-0011 y la version final de 0012. La unica adaptacion fue la fixture local conocida de 0004; no se modifico ningun script historico ni Azure DEV.
- La verificacion de solo lectura de 0012 aprobo. La prueba funcional con rollback aprobo checkout mixto, reintento idempotente, snapshots de factura, cancelacion/restauracion de componentes, transformacion atomica y tendencia de doce meses. El caso de token con carga distinta devolvio 54609. Dos sesiones concurrentes contra una sola unidad dieron exactamente un checkout exitoso, un 54615 y stock final cero.
- El smoke publico aislado aprobo `Home/Shop`, detalle de combo y agregado al carrito. No hubo alertas de error ni entradas `error` o `warning` en la consola del navegador.

### Cierre técnico acotado — autenticación y detalle público

- `Invoke-Migration0012.ps1` acepta `-AuthenticationMode Entra` (predeterminado,
  `sqlcmd -G`) y `-AuthenticationMode Windows` (`sqlcmd -E`). No admite
  contraseñas ni `-P`; la única variable transmitida es
  `MigrationSha256=<SHA-256>` como un argumento SQLCMD indivisible.
- `Test-InvokeMigration0012.ps1` aprobó sin conexión los dos modos, la ausencia
  de autenticaciones simultáneas, la variable única, las entradas inválidas y
  `DryRun` sin invocar `sqlcmd`. La compatibilidad del formato SQLCMD se confirmó
  en LocalDB.
- La prueba LocalDB de componente inactivo ahora ejecuta directamente
  `sp_Store_GetComboById` antes de inactivar, tras inactivar, tras reactivar y
  con stock cero; mantiene la comprobación de catálogo, administración,
  checkout manipulado e inventario intacto. Todas las escrituras revierten.
- Al cierre: build Release sin errores ni advertencias, 117/117 pruebas .NET,
  ScriptDom focalizado 56/517, ScriptDom CI 83/916 y escaneo de secretos
  aprobado (661 archivos rastreados, 630 de texto y 12 placeholders admitidos).
- 0012 permanece sin aplicar en Azure DEV; el BACPAC previo ya fue exportado,
  importado y verificado localmente. El ejecutor único de Azure y el QA
  autenticado continúan pendientes. El PR #115 se mantiene en Draft.

## Reconciliación del esquema legado real — 28 de julio de 2026

- El BACPAC previo de Azure DEV se verificó e importó en una nueva base LocalDB
  desechable. La base restaurada original se conservó sin cambios y
  `DBCC CHECKDB` aprobó.
- El esquema contenía las tablas legadas `Combos`, `ComboDetalle` y
  `PedidoCombos`, además de `PedidoDetalle.PedidoComboId`; todavía no contenía
  `FacturaCombos`, `PedidoComboDetalle`, `CheckoutOperaciones` ni las tablas de
  transformación y auditoría de 0012.
- La migración renombra `FechaCreacion` y `ComboNombre` hacia sus nombres
  canónicos, conserva las claves existentes, completa auditoría y fechas,
  valida cantidades/referencias y crea restricciones confiables dentro de la
  misma transacción.
- Se conservaron exactamente 1 combo, 3 componentes de catálogo, 4
  `PedidoCombos` y 153 `PedidoDetalle`. Los pedidos, facturas, totales e
  inventario mantuvieron sus agregados previos.
- Los componentes históricos se reconstruyeron en 12 filas de
  `PedidoComboDetalle`, sin duplicados ni cantidades fraccionarias.
  `FacturaCombos` quedó vacío para facturas anteriores a 0012, evitando doble
  contabilización.
- Pedidos, comprobantes, inteligencia, facturación y restauración filtran
  `PedidoDetalle.PedidoComboId IS NULL` para productos sueltos y usan
  `PedidoComboDetalle` como fuente canónica de componentes.
- La ruta limpia y la actualización legada aprobaron el verify oficial,
  pruebas funcionales, componente inactivo, idempotencia, concurrencia y
  `DBCC CHECKDB`. Azure DEV no recibió consultas ni cambios durante esta
  reconciliación.

## Pendientes antes de aplicar Azure DEV

- No se aplicó 0012 en Azure DEV. El BACPAC previo ya está verificado; falta
  designar ejecutor único, reconfirmar metadatos/dependencias y ejecutar la
  aplicación y verificación posterior durante una ventana controlada.
- El QA de navegador autenticado sigue pendiente de una credencial de prueba autorizada; no se cambio ni se infirio ninguna contrasena.
- El BACPAC previo se exportó y verificó fuera del repositorio; su importación
  LocalDB y `DBCC CHECKDB` aprobaron. No se ejecutó SQL contra Azure DEV y 0012
  permanece pendiente de aplicación controlada.
