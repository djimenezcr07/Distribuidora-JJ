# Rollback de 0018 - jornadas

Las jornadas aprobadas son entrada para planilla y no deben borrarse. Para retirar el flujo:

1. Desplegar una aplicación que no permita nuevas jornadas.
2. Crear migración compensatoria que inactive permisos y procedimientos de escritura.
3. Conservar tabla, auditoría, decisiones y ledger para trazabilidad.
4. Si una jornada aprobada es incorrecta, usar un futuro flujo auditado de corrección; no modificarla manualmente.
