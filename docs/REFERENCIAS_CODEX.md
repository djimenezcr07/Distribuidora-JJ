# Referencias actuales para Codex

Este es el índice operativo vigente. El código del checkout y sus cambios locales prevalecen sobre notas históricas; `origin/main` es la referencia de integración.

## Estado operativo vigente

- Para una tarea en curso, inspeccionar el checkout y preservar sus cambios locales. `origin/main` orienta la integración; no autoriza descartar trabajo ni sincronizar automáticamente. Las ramas y PR históricos no definen el estado actual.
- Los `appsettings` compartidos están sanitizados; la configuración funcional vive fuera de Git.
- CI separa secretos, SQL, build, pruebas y su `final-gate`.
- La protección de `main` se documenta en `docs/configuracion-proteccion-main.md`.
- La fuente de verdad de migraciones en Azure DEV es `dbo.SchemaMigrationHistory`. `database/migrations/README.md` contiene el procedimiento vigente; las notas de aplicación anteriores son históricas y no sustituyen la consulta del ledger.
- Las métricas SQL focalizadas (`database/`) y las de CI recursivo (`database` + `database_Esteban`) se reportan por separado.
- El QA autenticado requiere cuentas temporales autorizadas y nunca se acredita por documentación o sesiones antiguas.

## Índice por tema

- Seguridad y configuración: `docs/credenciales-configuracion-segura.md`, `SECURITY.md`, `docs/incidente-seguridad-credencial-smtp-20260722.md`.
- CI y rama principal: `.github/workflows/ci-security-build.yml`, `docs/configuracion-proteccion-main.md`.
- SQL: `database/migrations/README.md`, `docs/inventario-sql-y-migraciones.md`.
- Trazabilidad funcional: `docs/matriz-historias-estado.md`, `docs/resumen-final-proyecto.md`.
- QA: `docs/qa-final.md`, `docs/api-pruebas-manuales.md`.
- Sprint 4 Danny: `docs/sprint4-danny-cu201-cu202-cu221-cu222-cu223.md`.
- Cliente/pedidos: `docs/portal-cliente-pedidos.md`.
- API: `docs/api-endpoints.md`, `docs/api-auth-futura.md`.
- Azure histórico: `docs/azure-despliegue-final-qa.md` y guías relacionadas.

## Regla de lectura

1. Leer este índice.
2. Inspeccionar los archivos actuales del módulo.
3. Leer solo la documentación relacionada.
4. No tratar prompts, ramas personales ni QA histórico como fuente de verdad.
