# Carga demo DEMO-2026-08

Estos scripts solo aceptan `DistribuidoraJJ_DB_DEV`. Son aditivos e idempotentes y usan la marca `DEMO-2026-08`. No crean usuarios ni contraseñas; cualquier identidad usada por las relaciones debe existir previamente y ser una cuenta QA autorizada.

No se ejecutan desde CI ni automáticamente. Antes de ejecutarlos, el responsable designado debe abrir/revisar el PR, verificar el ledger de migraciones y crear un BACPAC/restauración conforme a `database/migrations/README.md`.

Ejecutar con una identidad autorizada y seleccionando explícitamente la base DEV:

1. Iniciar sesión con una identidad Microsoft Entra provisionada como usuario individual de Azure SQL y confirmar `SELECT DB_NAME()`; no usar credenciales compartidas ni `-P`.
2. Crear y validar el BACPAC de `DistribuidoraJJ_DB_DEV`; conservarlo fuera de Git.
3. Consultar `dbo.SchemaMigrationHistory`, los conteos previos y la ausencia del lote `DEMO-2026-08`.
4. Ejecutar `seed_demo_full.sql` seleccionando explícitamente `DistribuidoraJJ_DB_DEV`.
5. Ejecutar `seed_demo_full.verify.sql`, luego smoke tests autenticados por rol.
6. Usar `seed_demo_full.rollback.sql` solo para retirar el lote DEMO-2026-08; nunca como sustituto de un backup.

El script rechaza cualquier base distinta y usa una transacción con `XACT_ABORT`. No se reutilizan los seeds históricos porque contienen un destino distinto y un flujo de contraseñas temporal que no cumple estas restricciones.

El lote requiere un actor `QA`/`DEMO` activo y un segundo usuario `QA`/`DEMO` ya existente con perfil `Cliente`; el seed no crea clientes porque en este esquema un cliente es un usuario y la creación exige una contraseña. La dirección demo queda en el checkout/pedido y no se inserta una entidad independiente porque el esquema disponible solo guarda la dirección en el usuario. Documentos, evidencias, alertas documentales y sus notificaciones se excluyen deliberadamente: el contrato exige una versión con clave de almacenamiento y archivo físico válido. No se crean referencias `Pending`, rutas ni archivos ficticios. `PlanillaDetalle` también se excluye: el contrato DEV conserva una clave única legada por período/empleado, incompatible con insertar las líneas del contrato nuevo sin una relación verificable a `PeriodosPlanilla`; los cálculos y sus tres estados se cargan en `PlanillaCalculos`.
