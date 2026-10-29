# Azure SQL DEV compartido para companeros

## Objetivo

Este documento explica como usar la base compartida `DistribuidoraJJ_DB_DEV` en Azure SQL DEV sin modificar `appsettings`, sin subir secretos a Git y sin ejecutar scripts desordenados.

La meta es que el equipo trabaje contra una misma base DEV, con reglas claras para conexion, firewall, pruebas locales y cambios de base de datos.

## Estado actual

Bloque 5 - Azure SQL DEV e importacion `.bacpac`: completado.

Bloque 6 - Pruebas locales MVC/API contra Azure SQL DEV: completado.

Validaciones realizadas:

- API local levanta correctamente.
- API local conecta contra Azure SQL DEV usando `ConnectionStrings__DefaultConnection`.
- Endpoint `/api/productos` devuelve productos reales desde Azure SQL DEV.
- Login API aprobado.
- MVC local conecta correctamente.
- Login administrador aprobado.
- Login cliente aprobado.
- Login vendedor/empleado aprobado.
- Admin aprobado.
- Flujo general local contra Azure SQL DEV funcionando.

## Recursos Azure usados

| Recurso | Valor |
| ------- | ----- |
| Resource Group | `rg-trilogia-cursos-dev` |
| Region | `Central US` |
| SQL Server | `sql-trilogia-cursos-dev-cr01.database.windows.net` |
| Database | `DistribuidoraJJ_DB_DEV` |
| Storage temporal | `sttrilogiadevcr01` |
| Container | `bacpac` |
| BACPAC final usado | `DistribuidoraJJ_DB_Azure_Final_20260702.bacpac` |

Nota: el archivo anterior `DistribuidoraJJ_DB_post_bloque2_20260701.bacpac` quedo descartado como referencia principal para Azure. El archivo correcto usado para la importacion final fue `DistribuidoraJJ_DB_Azure_Final_20260702.bacpac`.

## Reglas de seguridad

- No poner connection strings reales en `appsettings.json` ni `appsettings.Development.json`.
- No compartir contrasenas en chats grupales.
- No subir secretos a Git.
- Usar variables de entorno por cada equipo.
- No documentar contrasenas reales.
- Rotar la contrasena si se expone accidentalmente.
- No enviar connection strings completas con password por medios publicos.
- No usar datos personales en nombres de recursos, usuarios o archivos.

## Connection string plantilla

Usar esta plantilla sin reemplazarla dentro de archivos versionados:

```text
Server=tcp:sql-trilogia-cursos-dev-cr01.database.windows.net,1433;Initial Catalog=DistribuidoraJJ_DB_DEV;Persist Security Info=False;User ID=<sql-user>;Password=<sql-password>;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

Solicitar una credencial temporal al responsable del entorno por un canal privado. La credencial real debe configurarse localmente y quedar fuera del repositorio.

## Configurar variable de entorno en Windows

Ejecutar en PowerShell. No pegar la contrasena en documentos ni commits.

```powershell
$SqlUser = "<sql-user>"
$SqlPassword = "<sql-password>"
setx ConnectionStrings__DefaultConnection "Server=tcp:sql-trilogia-cursos-dev-cr01.database.windows.net,1433;Initial Catalog=DistribuidoraJJ_DB_DEV;Persist Security Info=False;User ID=$SqlUser;Password=$SqlPassword;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

Despues de ejecutar `setx`:

1. Cerrar Visual Studio.
2. Cerrar terminales abiertas.
3. Abrir Visual Studio nuevamente.
4. Ejecutar la solucion.

`setx` aplica para nuevas sesiones; las ventanas abiertas antes del comando pueden no ver la variable.

## Conexion desde SSMS

Datos de conexion:

| Campo | Valor |
| ----- | ----- |
| Server | `sql-trilogia-cursos-dev-cr01.database.windows.net` |
| Authentication | `SQL Server Authentication` |
| User | `<sql-user>` |
| Database | `DistribuidoraJJ_DB_DEV` |
| Encrypt | Obligatorio |
| Trust Server Certificate | No |

Si SSMS da error temporal de certificado, se puede probar `Trust Server Certificate = Yes` solo para diagnostico local. No debe documentarse como configuracion recomendada.

## Error de firewall o IP

Si aparece error de firewall:

1. Pedir autorizacion al responsable del Azure SQL Server.
2. Obtener la IP publica actual del companero.
3. En Azure Portal, abrir el SQL Server.
4. Ir a Networking / Firewalls.
5. Agregar una regla especifica para esa IP.
6. Guardar cambios.
7. Probar de nuevo desde SSMS o la aplicacion.

Reglas:

- No deshabilitar el firewall.
- No abrir rangos amplios innecesarios.
- No permitir `0.0.0.0 - 255.255.255.255`.
- Revisar y limpiar IPs antiguas cuando ya no se usen.

## Scripts que NO deben ejecutarse sin bloque aprobado

No ejecutar sin revision especifica:

- `database/cu098_retencion_autorizacion_pedidos.sql`
- Scripts grandes de inventario sin validacion previa.
- Scripts grandes de facturacion sin validacion previa.
- Scripts de `database_Esteban` salvo revision especifica.
- Baselines destructivos o scripts con `DROP` sobre bases con datos.
- Seeds demo sobre Azure SQL DEV sin aprobacion.

## Reglas para cambios de base de datos

- Solo una persona designada ejecuta scripts en Azure SQL DEV.
- Todo cambio debe tener script versionado en `database/`.
- Crear backup o export antes de cambios grandes.
- Registrar script ejecutado, fecha, responsable y resultado.
- Validar con consultas de solo lectura despues de ejecutar scripts.
- No ejecutar scripts directamente en Azure sin aprobacion del bloque.
- No editar datos manualmente salvo que el bloque lo apruebe.
- Si un script falla, no intentar arreglar en caliente sin reportar el error completo.

## Checklist de prueba local contra Azure SQL DEV

Cada companero debe validar:

- Build correcto.
- API levanta.
- `/api/productos` responde.
- Login API funciona.
- MVC Home funciona.
- Shop funciona.
- Login admin funciona.
- Login cliente funciona.
- Login vendedor/empleado funciona.
- `/SellerOrders` funciona.
- `/SellerOrders/MyOrders` funciona.

Pruebas recomendadas:

```powershell
dotnet build Trilogia-Cursos\Proyecto_Final.slnx
```

Despues ejecutar API/MVC desde Visual Studio o terminal y probar los flujos indicados.

## Riesgos conocidos

- El proyecto todavia usa contrasenas en texto plano.
- `cu098_retencion_autorizacion_pedidos.sql` sigue pendiente.
- Flujo gerente/retencion puede seguir incompleto.
- SMTP real pendiente.
- App Service API pendiente.
- App Service MVC pendiente.
- Storage temporal `sttrilogiadevcr01` debe eliminarse cuando ya no sea necesario.
- Costos Azure deben monitorearse.
- Connection strings reales deben mantenerse fuera del repositorio.

## Estado final de bloques

| Bloque | Estado |
| ------ | ------ |
| Bloque 5 - Azure SQL DEV e importacion `.bacpac` | Completado |
| Bloque 6 - Pruebas MVC/API locales contra Azure SQL DEV | Completado |
| Bloque 7 - Guia para companeros y estrategia de base compartida | Documentado en este archivo |

## Proximo bloque recomendado

Bloque 8 - Publicar API en Azure App Service.

Objetivo sugerido:

- Publicar `Proyecto_FinalAPI` en Azure App Service.
- Configurar variables de entorno sin secretos en Git.
- Probar endpoints publicos.
- Validar login API.
- Mantener MVC sin publicar hasta que API este estable.
