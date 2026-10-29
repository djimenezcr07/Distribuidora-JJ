# Baseline oficial para una instalación nueva

## Artefacto congelado

El baseline oficial es `database/DistribuidoraJJ_DB.sql`, con SHA-256:

`11625D764BFECD4BB86C932A5A6FA3ECCFC00CD4E62AEBF9B603D899828922B7`

El nombre histórico del archivo no define la marca visible del producto. No se debe editar el baseline: cualquier evolución pertenece a `database/migrations/`.

## Secuencia reproducible

1. Crear una base SQL Server vacía y desechable. Nunca apuntar este procedimiento a DEV compartido o producción.
2. Verificar el SHA con `scripts/database/Test-OfficialBaseline.ps1`.
3. Ejecutar el baseline una sola vez en la base vacía, revisando previamente cualquier `CREATE DATABASE`/`USE` según el entorno local.
4. Aplicar `0001` y luego cada migración de la tabla de `database/migrations/README.md`, hasta 0029 y en orden, inyectando el SHA-256 real donde corresponda.
5. Ejecutar el archivo `verify.sql` de cada migración que lo tenga y confirmar el ledger.
6. Ejecutar la validación sintáctica, la suite .NET y `DBCC CHECKDB` en la base desechable.

No ejecutar `Fase*.sql`, `database_Esteban/`, parches `cu*.sql` ni seeds para completar una instalación nueva. Si una migración declara una dependencia que el baseline no satisface, la instalación se considera bloqueada y debe corregirse con una nueva migración o una nueva versión formal del baseline; no con cambios manuales.
