# Rollback de 0019 - motor de planilla

Los cálculos, detalles, fuentes, huellas y transiciones forman evidencia financiera y no deben borrarse ni editarse manualmente.

1. Desplegar una versión que impida crear periodos, reglas, cálculos y transiciones.
2. Crear una migración compensatoria que inactive los permisos de escritura y retire los procedimientos mutadores.
3. Mantener tablas, procedimientos de lectura, auditoría y ledger disponibles para consulta.
4. Corregir datos mediante una transición auditada o un cálculo compensatorio; nunca sobrescribir una planilla aprobada o pagada.
