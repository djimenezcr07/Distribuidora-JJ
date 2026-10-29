# Colaboracion segura en Azure DEV

## Arquitectura

- Azure SQL DEV y los recursos de `rg-trilogia-cursos-dev` son el entorno compartido de integracion.
- Danny, Esteban, Gerald y David forman el equipo administrativo DEV mediante asignaciones individuales.
- Esteban, Gerald y David tienen Owner directo solo en el Resource Group y `db_owner` individual en la base DEV.
- Danny conserva el acceso heredado y permanece como administrador Microsoft Entra individual del servidor SQL por una limitacion del tenant institucional.
- Ningun colaborador recibe Owner de la suscripcion ni credenciales SQL compartidas.

El grupo administrativo previsto no pudo crearse porque el tenant institucional denego la administracion de grupos. Las asignaciones directas son una medida operativa y requieren una revocacion individual cuidadosa.

## Accesos del equipo

| Colaborador | GitHub | Portal Azure | Azure SQL |
| ----------- | ------ | ------------ | --------- |
| Danny | `d0j0fre` | Propietario heredado | Administrador Entra y acceso administrativo |
| Esteban | `EstebanAVF` | Owner directo del Resource Group | `db_owner` individual con Microsoft Entra |
| Gerald | `GeraldRB` | Owner directo del Resource Group | `db_owner` individual con Microsoft Entra |
| David | `MontDavidH` | Owner directo del Resource Group | `db_owner` individual con Microsoft Entra |

Gerald debe aceptar su invitacion B2B antes de iniciar sesion. La asignacion puede existir mientras la invitacion permanece pendiente.

## Conexion con Microsoft Entra MFA

1. Abrir SSMS o una herramienta compatible con Azure SQL.
2. Usar el servidor y la base comunicados mediante el canal privado del equipo.
3. Elegir autenticacion Microsoft Entra con MFA.
4. Iniciar sesion con la cuenta individual autorizada.
5. Confirmar el acceso y respetar el ejecutor designado para cualquier cambio.

## Cambio de IP publica

1. Confirmar la IP nueva desde el equipo que se conectara.
2. Comunicarla por un canal privado a un administrador del proyecto.
3. Reemplazar la regla individual por otra regla de una sola IP.
4. Probar la conexion y retirar la regla anterior.
5. Verificar que no se creo un rango ni el bypass de servicios Azure.

Las IPs no se publican en Git.

## Flujo de migraciones

1. Crear un archivo incremental, idempotente y revisable en `database/`.
2. Designar en el PR a un unico ejecutor para esa migracion.
3. Validar el script con ScriptDom y CI.
4. Revisar impacto y rollback.
5. Crear y verificar un BACPAC reciente.
6. El ejecutor designado aplica el cambio en una ventana coordinada.
7. Registrar el resultado en `dbo.SchemaMigrationHistory`.
8. Ejecutar verificaciones y adjuntar evidencia sanitizada al PR.

Nunca dos administradores ejecutan simultaneamente el mismo script. Todo cambio requiere script, PR, CI, backup y ledger.

## Retiro de un integrante

1. Retirar su Owner directo del Resource Group.
2. Retirar `db_owner` y los permisos SQL individuales que ya no correspondan.
3. Retirar su regla de firewall individual.
4. Actualizar CODEOWNERS y los permisos GitHub mediante un proceso separado.
5. Verificar que no conserve asignaciones en el Resource Group ni en la suscripcion.
6. Registrar el retiro y conservar evidencia sanitizada para rollback.

## Secretos

- No modificar `appsettings` versionados con valores reales.
- No compartir connection strings, contrasenas, tokens, claves ni perfiles de publicacion.
- No usar ni distribuir la cuenta administradora SQL.
- Guardar credenciales operativas solo en el mecanismo privado aprobado.
- Rotar una credencial inmediatamente si se expone.
