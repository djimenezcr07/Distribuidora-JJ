# Permisos administrativos directos del equipo DEV

## Estado

El tenant institucional impide crear y administrar el grupo de seguridad previsto. Para mantener la operacion del proyecto, Esteban, Gerald y David tienen asignaciones individuales equivalentes dentro del alcance autorizado.

| Area | Danny | Esteban | Gerald | David |
| ---- | ----- | ------- | ------ | ----- |
| Resource Group DEV | Owner heredado | Owner directo | Owner directo | Owner directo |
| Suscripcion | Acceso existente | Sin Owner directo | Sin Owner directo | Sin Owner directo |
| Servidor Azure SQL | Administrador Entra individual | Sin administrador de servidor | Sin administrador de servidor | Sin administrador de servidor |
| Base DEV | Acceso administrativo | `db_owner` | `db_owner` | `db_owner` |

Los accesos usan identidades Microsoft Entra individuales. No existen cuentas SQL compartidas ni contrasenas distribuidas al equipo. Gerald debe aceptar su invitacion B2B antes de iniciar sesion.

## Alcance RBAC

- Cada colaborador tiene exactamente una asignacion Owner directa en `rg-trilogia-cursos-dev`.
- No se concedio Owner directo en la suscripcion, tenant, management group ni raiz.
- Los Reader directos anteriores fueron retirados una vez verificado Owner.
- Los permisos GitHub no fueron modificados por las operaciones de Azure.

## Azure SQL

- Danny permanece como administrador Microsoft Entra individual del servidor.
- Los tres colaboradores conservan usuarios Microsoft Entra individuales en la base DEV.
- Cada usuario pertenece a `db_owner` y ya no necesita `db_datareader`.
- Se verificaron `CONTROL DATABASE`, DML, DDL, ejecucion y administracion de usuarios y roles mediante introspeccion de permisos.
- No se ejecutaron baselines, seeds ni migraciones funcionales durante la elevacion.

## Migraciones

1. Crear un script incremental e idempotente.
2. Abrir un PR y designar un unico ejecutor.
3. Ejecutar ScriptDom, CI y revision de seguridad.
4. Crear y verificar un BACPAC reciente.
5. Revisar el rollback antes de ejecutar.
6. Aplicar una sola vez durante una ventana coordinada.
7. Registrar resultado, ejecutor y evidencia en `dbo.SchemaMigrationHistory`.

Ningun segundo administrador ejecuta el mismo script mientras exista un ejecutor designado.

## Retiro de un integrante

1. Capturar un inventario sanitizado de sus asignaciones actuales.
2. Retirar Owner directo del Resource Group.
3. Retirar `db_owner` y decidir si el usuario SQL debe conservarse sin roles o eliminarse.
4. Retirar la regla individual de firewall.
5. Actualizar CODEOWNERS y gestionar GitHub por separado.
6. Verificar ausencia de permisos directos en Resource Group y suscripcion.
7. Registrar el cambio y conservar la estrategia de rollback fuera del repositorio.

## Cambio de IP

1. Recibir la nueva IP por un canal privado.
2. Crear o actualizar solo la regla individual del integrante.
3. Mantener inicio y fin en la misma direccion.
4. Probar la conexion antes de retirar la regla anterior.
5. Confirmar que no existe bypass global de servicios Azure ni rangos amplios.

## Verificacion

- Owner directo en el Resource Group: aprobado para los tres colaboradores.
- Owner directo de suscripcion: ausente para los tres.
- `db_owner` y `CONTROL DATABASE`: aprobados para los tres.
- API, health, Swagger, productos, MVC, login y tienda: aprobados.
- Firewall individual y reglas de salida de App Services: preservados.
- Administrador Entra individual de Danny: preservado.

Las pruebas reales desde las cuentas de Esteban, Gerald y David se realizan en sus equipos. La prueba de Gerald depende de aceptar la invitacion.

## Rollback

- Retirar Owner directo de cada colaborador agregado.
- Restaurar Reader solo cuando el modelo anterior de lectura deba recuperarse.
- Retirar `db_owner` y restaurar `db_datareader` si se revierte al acceso de lectura.
- No modificar el administrador Entra de Danny durante este rollback.
- Verificar aplicaciones, firewall y acceso de Danny despues de cada reversa.

## Riesgos

- Las asignaciones directas no ofrecen una baja centralizada.
- Una revocacion incompleta puede dejar permisos divergentes entre RBAC, SQL, firewall y GitHub.
- La invitacion pendiente de Gerald impide validar su inicio de sesion desde su equipo.
- La lectura actual del BACPAC esta limitada por RBAC de datos de Storage; no deben usarse claves compartidas para evitar esa restriccion.
