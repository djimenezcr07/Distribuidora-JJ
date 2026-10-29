# Plan de rollback y recuperación

## Estado actual AUDIT_ONLY

Los únicos cambios persistentes son archivos nuevos bajo `docs/auditoria/`. No existen commits, push, cambios de Issues, PR, protección o base de datos. Por tanto no hay rollback remoto que ejecutar.

Estos informes permanecen sin seguimiento hasta aprobación. No se borrarán automáticamente.

## Fase posterior a Puerta A

- Crear rama apilada y `backup/pre-cierre-<timestamp>` local.
- Un commit por bloque vertical.
- Si un bloque falla dos veces, aislar causa y reducir alcance.
- En el tercer fallo, revertir únicamente el bloque/commit actual y conservar bloques verdes.
- Antes de publicar, preferir `git revert <commit>` para commits ya compartidos; nunca force-push o reset destructivo remoto.

## SQL

- Usar únicamente bases LocalDB desechables identificadas por el harness.
- No editar `SchemaMigrationHistory` manualmente.
- No modificar hashes registrados.
- Para migraciones aditivas aplicadas, revertir primero la aplicación y después crear una migración compensatoria con número nuevo.
- No borrar compras, auditoría, planillas, boletas ni asignaciones para simular rollback.
- BACPAC/restauración en Azure: último recurso y solo con autorización separada.

## Archivos e imágenes

- Inventariar antes de mover o eliminar.
- Durante reemplazo, conservar la imagen anterior hasta confirmar persistencia DB.
- Si falla la limpieza posterior, registrar el huérfano para reintento; no revertir una transacción de negocio ya confirmada mediante borrado manual.
- Boletas y documentos privados nunca se recuperarán desde `wwwroot`; se usarán snapshots y almacenamiento privado.

## GitHub

- No cerrar Issues/PR en masa.
- Toda corrección de backlog conservará el comentario histórico y añadirá evidencia nueva.
- Si una mutación autorizada fuera incorrecta, aplicar la corrección inversa documentada; no borrar comentarios.
- No modificar branch protection o rulesets sin autorización administrativa separada.
