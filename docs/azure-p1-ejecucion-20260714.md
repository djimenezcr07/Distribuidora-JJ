# Ejecucion Azure P1 - 2026-07-14

## Resultado

- El BACPAC previo fue verificado con 76,402 bytes antes de la ejecucion colaborativa.
- La comprobacion actual del blob quedo limitada por la ausencia de un rol de datos de Storage; no se usaron claves ni Shared Key para eludirla.
- Se auditaron 28 cuentas: 27 activas y 1 inactiva antes de la contencion.
- Se rotaron 12 cuentas operativas privilegiadas con credenciales DPAPI y se desactivo 1 cuenta demo inequivoca.
- Quedaron 26 cuentas activas, 2 inactivas y 1 administrador activo.
- Danny permanece como administrador Microsoft Entra individual de Azure SQL.
- Esteban, Gerald y David tienen exactamente una asignacion Owner directa en el Resource Group.
- Ninguno de los tres tiene Owner directo en la suscripcion.
- Los Reader directos de Esteban y David fueron retirados como redundantes.
- Los tres usuarios Entra individuales tienen `db_owner`; su membresia `db_datareader` fue retirada como redundante.
- Gerald tiene una invitacion B2B pendiente de aceptacion.

## Limitacion del tenant

El tenant institucional denego la creacion y administracion de `Trilogia-Admins-DEV`. Por esta razon se aplicaron asignaciones individuales y no se cambio el administrador Entra del servidor SQL. Esta limitacion aumenta el costo de altas, bajas y auditoria.

## Firewall

Se conservaron reglas individuales, sin documentar direcciones:

- `owner-danny-20260714`
- `collab-esteban-20260714`
- `collab-gerald-20260714`
- `collab-david-20260714`
- `app-api-out-01` a `app-api-out-33`

No existen rangos amplios ni bypass global de servicios Azure.

## Pruebas

- API raiz, health, Swagger y productos: HTTP 200.
- La consulta de productos devolvio datos reales desde Azure SQL.
- MVC Home, login y tienda: HTTP 200.
- Login con una credencial local protegida: aprobado.
- API y MVC permanecieron `Running`.
- Esteban, Gerald y David: `db_owner` y `CONTROL DATABASE` aprobados.
- SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, EXECUTE y administracion de roles: aprobados mediante introspeccion de permisos, sin dejar objetos ni datos de prueba.
- Las pruebas reales desde las cuentas de los colaboradores quedan para sus equipos; Gerald debe aceptar primero su invitacion.

## Ledger e inventario SQL

- Confirmado: `0001_create_schema_migration_history.sql` aplicado.
- Confirmado: CU101 y CU102 registrados como `BaselineVerified` tras comprobar objetos y parametros.
- Faltante: ningun script adicional fue declarado faltante durante P1.2.
- Desconocido: CU090-CU100 permanecen sin evidencia suficiente de ejecucion previa.
- No aplicable: los historicos de `database_Esteban/` no son fuente de verdad de Azure DEV.
- Prohibido: ejecutar baselines, seeds o scripts historicos sin un bloque aprobado.

## Modelo operativo

Cada migracion tiene un unico ejecutor designado y registrado en el PR. Todo cambio compartido requiere script incremental, revision, CI, BACPAC reciente, estrategia de rollback y registro en `dbo.SchemaMigrationHistory`.

## Rollback

- El inventario previo y los resultados sanitizados permanecen fuera del repositorio.
- RBAC puede revertirse retirando Owner y restaurando Reader cuando corresponda.
- SQL puede revertirse retirando `db_owner` y restaurando `db_datareader` para cada usuario.
- El administrador Entra individual de Danny no fue modificado.
- No fue necesario revertir firewall ni aplicaciones.

## Riesgos pendientes

- Las asignaciones directas deben revocarse individualmente y son mas propensas a divergencia que un grupo centralizado.
- Gerald no puede iniciar sesion hasta aceptar su invitacion B2B.
- La verificacion actual del BACPAC requiere un rol de datos de Storage o una comprobacion autorizada equivalente.
- El sistema sigue comparando contrasenas de aplicacion en texto plano.
- SMTP historico continua pendiente de rotacion o revocacion.
- SCM y FTP basic auth siguen habilitados.
- Logging, health check administrado, Key Vault e identidad administrada siguen pendientes.
- El historial Git historico requiere una decision coordinada independiente.
- CU090-CU100 no tienen evidencia suficiente en el ledger y no se ejecutaron.
