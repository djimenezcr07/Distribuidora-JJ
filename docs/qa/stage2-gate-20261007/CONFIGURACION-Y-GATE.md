# Stage 2 Foundations — checkpoint y configuración local

2026-10-07. Preparación de configuración y checkpoint; QA autenticada completada posteriormente en la misma fecha. Los resultados definitivos están en `CIERRE.md`. No iniciar las vistas legacy.

## 1. Causa de Azure SQL

La clave `ConnectionStrings:DefaultConnection` de los User Secrets de **MVC y API** apuntaba a Azure SQL con autenticación Active Directory Interactive y TrustServerCertificate=False. No era una variable de entorno sobrescribiendo una conexión local correcta: los propios secretos todavía tenían el destino Azure.

Los appsettings base/Development no aportaban DefaultConnection. Se comprobaron variables de proceso, usuario y máquina: sin `ConnectionStrings__*`, DOTNET_ENVIRONMENT ausente; ASPNETCORE_ENVIRONMENT=Development en proceso/usuario y en ambos launch profiles. No se imprimieron contraseñas ni el contenido completo de secretos.

Ambos Program usan `WebApplication.CreateBuilder(args)` sin proveedores de configuración añadidos. Precedencia estándar de aplicación, de menor a mayor: appsettings.json, appsettings del entorno, User Secrets en Development, variables de entorno y argumentos de línea de comandos. La selección del entorno también considera DOTNET_ENVIRONMENT, que aquí está ausente.

## 2. Configuración final efectiva

Se sustituyó **únicamente** `ConnectionStrings:DefaultConnection` en los secretos de cada proyecto por la conexión integrada LocalDB solicitada: instancia `TrilogiaDev`, catálogo `DistribuidoraJJ_DB`, Integrated Security=True, TrustServerCertificate=True y MultipleActiveResultSets=True. No se eliminaron los secretos ni se editaron appsettings, launchSettings o variables persistentes. Esta corrección de configuración es posterior al informe histórico del 5 de octubre.

Una sonda temporal fuera del árbol versionado utilizó WebApplication.CreateBuilder, los assemblies MVC/API, sus ContentRoot y Development. En ambos casos el proveedor ganador fue **JsonConfigurationProvider de secrets.json**, y verificó TrilogiaDev y el catálogo esperado sin imprimir la cadena. La sonda no arrancó servidores HTTP ni escribió SQL; está en `.git/codex-checkpoints/20261007-config-probe`.

LocalDB TrilogiaDev estaba detenido y se inició. Una consulta SELECT de DB_NAME/SERVERPROPERTY comprobó la conexión real al catálogo local. No se modificaron registros ni esquema.

## 3. Ejecución normal comprobada

Se detuvieron únicamente los ejecutables MVC/API de este checkout que venían de la sesión anterior y se arrancaron sin asignaciones de ConnectionStrings en el comando:

```powershell
dotnet run --project Proyecto_Final/Proyecto_Final.csproj --no-build --launch-profile https
dotnet run --project Proyecto_FinalAPI/Proyecto_FinalAPI.csproj --no-build --launch-profile Proyecto_FinalAPI
```

Ambos anuncian Development. API health en 57541 y MVC health en 5074: 200. Home: 200 con HTML Storefront; Shop: 200 con HTML Storefront y catálogo. MVC HTTPS: 7013; API HTTPS: 57540. Edge carga Login en HTTPS sin interstitial. Health aislado no prueba SQL; Home/Shop se comprobaron además del health.

La configuración privada no pertenece al commit. En otro equipo debe configurarse su propia instancia/base y su clave de User Secrets; el commit no transporta credenciales ni pretende provisionar SQL.

## 4–6. Checkpoint Git y exclusiones

Se preparan únicamente archivos identificados de fundaciones: CSS/tokens/layouts, navegación JS, storage/cola/mapa/firma, pipeline de imágenes, presentación Chat, validación y licencias, tests y documentación/capturas de QA públicas. El SHA y lista definitiva se obtienen del commit local `fix(stage2): stabilize shared UI foundations`; la salida de preparación/commit se conserva en el checkpoint local.

Excluidos expresamente: Fleet/Mileage y Vehicles/Create, Edit, Index; `.agents`, caché, documentos personales, presentaciones, reportes Azure, manuales y demás untracked ajenos. No git add global, reset, clean ni borrado de archivos. Los User Secrets permanecen fuera del repositorio.

## 7–10. Estado al preparar el primer checkpoint

| Contexto | 1440 | 390 | Motivo |
| --- | --- | --- | --- |
| Admin | Pendiente | Pendiente | Sin sesión autenticada |
| Inventory | Pendiente | Pendiente | Sin sesión autenticada |
| Client / Clients | Pendiente | Pendiente | Sin sesión autenticada; distinguir listado administrativo y portal según permisos |
| DriverDeliveries | Pendiente | Pendiente | Requiere cuenta/sesión válida; no fabricar autenticación |

Edge quedó en `https://localhost:7013/Account/Login`; se detiene automatización del navegador hasta que el usuario inicie sesión. No se enviaron credenciales, pedidos, entregas ni evidencias. Se continuará usando la misma sesión, verificando consola/red, layout, métricas/tablas, navegación, foco y overflow. Las capturas públicas del 5 de octubre siguen como evidencia histórica, no como QA autenticada de esta fecha.

## 11–12. Console y Network

Pendientes en contextos autenticados. No se declara que estén libres de errores antes de examinarlos. Los smoke HTTP públicos contra la configuración corregida devolvieron 200; esa prueba no equivale a inspección completa de recursos de navegador.

## 13–15. Regresión de este cierre

- Build Debug del proyecto de tests: 0 errores, 0 advertencias.
- Tests .NET: 323 passed, 0 failed, 0 skipped.
- Tests JavaScript: 11 passed, 0 failed, 0 skipped.
- git diff --check: correcto.

No hubo cambios de aplicación adicionales en este cierre: configuración privada, arranque local, documentación y preparación del checkpoint. Se ajustó el token ficticio del test JavaScript a un placeholder explícito para que el escáner de secretos no lo confunda con una credencial; los 11 casos volvieron a pasar.

## 16–17. Estado y límites

Tras el checkpoint deben permanecer los cuatro archivos modificados del usuario y untracked ajenos. No afirmar working tree limpio. La documentación posterior de resultados autenticados podrá añadirse cuando exista sesión real.

**NO PUSH. NO PR. NO ESCRITURA REMOTA.** No conexión Azure, migraciones, cambios de datos, integración de main ni migración de las ~55 vistas legacy. El primer checkpoint dejó el gate abierto; `CIERRE.md` documenta la QA realizada tras el login manual del usuario.
