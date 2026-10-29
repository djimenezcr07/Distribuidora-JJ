# Cierre de Stage 2 Foundations

2026-10-07. Se completó la QA autenticada de las pantallas representativas con la sesión administradora iniciada manualmente por el usuario. DriverDeliveries se validó con acceso permitido de Administrador y estado vacío; no se certifica el recorrido de una ruta con entregas ni una sesión de Chofer. No se inicia la migración legacy.

## 1. Causa exacta de Azure SQL

La clave DefaultConnection de los User Secrets de MVC y API seguía apuntando a Azure SQL con Active Directory Interactive. En Development ganaba sobre appsettings. No había variables ConnectionStrings__* de proceso/usuario/máquina que estuvieran sobrescribiendo secretos locales correctos. El incidente anterior no provenía de LocalDB.

## 2. Configuración local efectiva final

Se cambió solo DefaultConnection en los secretos privados de ambos proyectos: LocalDB TrilogiaDev, catálogo DistribuidoraJJ_DB, seguridad integrada, TrustServerCertificate=True y MultipleActiveResultSets=True. Se conservaron las demás claves. No se versionó la cadena ni se editaron appsettings o launchSettings.

Se verificó ASPNETCORE_ENVIRONMENT=Development; DOTNET_ENVIRONMENT ausente. La sonda basada en WebApplication.CreateBuilder confirmó que el proveedor ganador final es JsonConfigurationProvider de secrets.json en ambos proyectos. Detalles y comandos reproducibles en `CONFIGURACION-Y-GATE.md`. La configuración privada deberá establecerse por equipo; el commit no provisiona bases ni usuarios.

## 3. Ejecución normal contra TrilogiaDev

MVC y API se arrancaron con sus launch profiles normales y --no-build, sin asignar cadenas en el comando. Una consulta SELECT verificó el catálogo local. API y MVC health devolvieron 200, y Home/Shop devolvieron 200 con HTML Storefront y catálogo. La sesión autenticada fue aportada por el usuario; no se fabricó ni se saltaron permisos. Se conserva abierta en Admin.

## 4. Checkpoints locales

Primer checkpoint: `ea4a854b58924d3f486a066b2d3bf7e0daa17b7d`, `fix(stage2): stabilize shared UI foundations`, 52 archivos, 1159 inserciones y 210 eliminaciones. Se añade un segundo commit local para los dos ajustes CSS descubiertos en la QA y este cierre documental. Su SHA aparece en la entrega y puede obtenerse con `git log -1` en la rama.

No se enmienda el primer commit: queda como checkpoint revisable de fundaciones antes de la QA autenticada.

## 5. Archivos incluidos

La lista exacta del primer checkpoint está en `ARCHIVOS-CHECKPOINT.txt`. Contiene layouts/CSS/JS de fundaciones, imágenes, presentación de Chat, librerías locales y licencias, tests y evidencia pública del 5 de octubre. El segundo incluye exclusivamente `base.css`, `workspace.css`, `CONFIGURACION-Y-GATE.md`, `CIERRE.md` y el manifiesto del checkpoint.

Correcciones posteriores: el reset de img/svg ahora tiene baja especificidad, para no forzar visibles las dos variantes del logo; los dos indicadores monetarios finales del dashboard ocupan dos columnas a partir de 80rem. Se comprobó logo horizontal visible y mark oculto en sidebar expandido; ambos importes quedan en una sola línea a 1440 y 390.

El estilo de los dos indicadores monetarios sigue la estructura actual del dashboard, donde son las dos últimas tarjetas. Si se reordena ese conjunto en una futura migración, debe ajustarse ese contrato.

## 6. Archivos excluidos

Fleet/Mileage.cshtml y Vehicles/Create.cshtml, Edit.cshtml, Index.cshtml permanecen modificados por el usuario y fuera de los commits de fundaciones. Se verificaron hashes antes/después. No se incluyeron .agents, caché, manuales, documentos personales, presentaciones, reportes Azure, salidas auxiliares ni untracked ajenos.

Las capturas autenticadas y el JSON técnico se guardan exclusivamente en `.git/codex-checkpoints/20261007-foundations-commit/authenticated-qa`, fuera del árbol versionado, porque las pantallas muestran datos personales. No se versionan nombres, correos ni teléfonos de esos listados en la evidencia nueva.

## 7. Admin, 1440/390

Dashboard abre con diez indicadores y dos tablas: productos críticos y pedidos recientes. CTA visible, logo consistente, estado activo correcto. Sin scroll horizontal de la página. Las tablas móviles conservan scroll local en djj-table-shell. Importes completos después del ajuste.

Sidebar desktop contrae y expande; móvil abre con foco en Cerrar navegación, bloquea fondo mediante inert, Shift+Tab lleva al último enlace y Tab vuelve al cierre. Escape cierra y devuelve foco a Abrir navegación. Los destinos del sidebar son únicos. No se ejecutó logout.

## 8. Inventory, 1440/390

Listado abre con 27 filas, ocho columnas y alerta de stock. Botones con texto/nombre accesible y miniaturas/fallback sin imágenes rotas observadas. Importes alineados a la derecha. Menú de más acciones abre dentro de la tabla sin recorte; solo se abrió/cerró el menú, sin activar operaciones.

Desktop cabe en el contenedor; móvil tiene scroll local en djj-table-wrap. No scroll horizontal de página. No se editó, activó, inactivó ni creó un producto.

## 9. Client / Clients, 1440/390

Se validó **Clients administrativo**, el contexto pedido en el smoke de Administrador: listado de 23 clientes, filtros visibles, tabla de relación comercial, importes/estados y acciones legibles. En móvil, filtros se apilan y la tabla usa scroll local; sin desbordamiento de página.

No se pulsaron acciones de modificación. El portal ClientPortal de una cuenta Cliente es otro contexto; no se acredita su QA con la sesión de Administrador utilizada.

## 10. DriverDeliveries, 1440/390

El controller permite Chofer y Administrador. La sesión Administrador abrió Mis entregas y mostró Sin rutas asignadas. Header/logo legibles, estado vacío coherente y bottom navigation con exactamente dos destinos únicos: Entregas y Perfil. No hay drawer en ese layout; se revisó su navegación presente.

No se dispuso de sesión Chofer válida con rutas asignadas. No se creó una ruta ni se reasignaron datos para probar. No se abrió Route con entregas de otra persona ni se enviaron cambios de estado o evidencias. El soporte offline real con backend y las rutas pobladas quedan expresamente sin certificar; las once pruebas JS cubren los contratos cliente con simulaciones.

## 11. Console

0 errores y 0 warnings registrados en el tab autenticado durante la revisión final de Admin, Inventory, Clients y DriverDeliveries. Los errores de herramientas de captura/selectores no fueron errores JavaScript de la aplicación: se resolvieron con controles observados y captura de rectángulo explícito, sin alterar permisos o sesión.

## 12. Network

Captura final individual por página y viewport: 0 respuestas >=400 y 0 loadingFailed. Cada captura final no estuvo truncada ni dejó páginas pendientes de eventos. Una captura global inicial sí se había truncado, por lo que fue sustituida por las capturas individuales completas.

| Pantalla | Respuestas observadas a 390 | Respuestas observadas a 1440 | Fallos |
| --- | ---: | ---: | ---: |
| Admin | 14 | 13 | 0 |
| Inventory | 18 | 21 | 0 |
| Clients | 13 | 13 | 0 |
| DriverDeliveries | 12 | 12 | 0 |

Los cuatro contextos en ambos tamaños tuvieron 0 imágenes completas rotas y 0 botones visibles sin texto/nombre accesible en la comprobación DOM. Los enlaces de cada sidebar no tuvieron destinos duplicados. Se restauró el viewport habitual al finalizar.

## 13–15. Regresión final

La compilación estándar encontró MSB3027/MSB3021 porque los ejecutables y DLL de MVC/API estaban en uso. La alternativa UseAppHost=false tampoco elimina el bloqueo de DLL. No son errores de código; no se reiniciaron las aplicaciones para preservar la sesión del usuario.

Se compiló el proyecto completo en Debug con `--artifacts-path` hacia el checkpoint local: **0 errores y 0 advertencias**. La primera ejecución de tests en esa carpeta externa tuvo 51 fallos de búsqueda de archivos: tests históricos resuelven la raíz de la solución desde AppContext.BaseDirectory y algunos asumen la profundidad normal de bin. No se cambiaron tests ni se ocultaron fallos.

Los binarios recién compilados de tests se copiaron a su ubicación normal `Proyecto_Final.Tests/bin/Debug/net9.0`, sin reemplazar los binarios de los servidores en uso. Allí se ejecutó `dotnet test Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug --no-build`, validando la compilación nueva con las rutas de fuentes esperadas: **323 passed, 0 failed, 0 skipped**. No hubo modificaciones C# adicionales en este cierre autenticado.

Las **11 pruebas JavaScript pasaron**, sin failed/skipped. git diff --check correcto. El escáner de secretos pasó antes del primer checkpoint y se vuelve a ejecutar sobre la documentación final antes del segundo. Esta variante de build/test es exclusivamente una solución al bloqueo de archivos del entorno local.

## 16. Git final

Tras los commits deben quedar exclusivamente las cuatro vistas ajenas modificadas y los untracked previos. Sin staged pendientes. No se declara working tree limpio. Los snapshots locales de manifiesto, hashes, SHA y status están en `.git/codex-checkpoints/20261007-foundations-commit`.

## 17. Confirmación

**NO PUSH. NO PR. NO ESCRITURA REMOTA.** No migraciones, cambios de registros/esquema, integración de main ni migración de las ~55 vistas legacy. Las únicas escrituras de configuración fueron las dos claves privadas locales autorizadas para sustituir Azure por TrilogiaDev.

Resultado: configuración reproducible y checkpoint local completados; smoke autenticado administrativo y Field vacío superados. El gate de esas pantallas representativas queda verificado con los límites de cuenta/ruta y portal indicados, sin certificar escenarios que no se probaron.
