# Rollback de 0017 - expedientes RRHH

No borrar `EmpleadoHistorialSalarios`, `RRHHAuditoria` ni la columna `VersionFila`: contienen trazabilidad y pueden ser dependencias de jornadas y planilla.

1. Desplegar primero una aplicación que no invoque `sp_RRHH_UpdateEmployee`.
2. Crear una migración compensatoria con número nuevo para restaurar el procedimiento anterior si fuera necesario.
3. Marcar permisos inactivos solo después de comprobar asignaciones y dependencias.
4. Conservar el registro de `SchemaMigrationHistory`; nunca editarlo manualmente.
5. Restaurar BACPAC únicamente como último recurso aprobado.
