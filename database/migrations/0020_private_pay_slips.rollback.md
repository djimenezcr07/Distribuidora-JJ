# Rollback de 0020 - boletas privadas

Las boletas se derivan del snapshot inmutable de planilla y la bitácora de envíos es evidencia; ninguna debe borrarse.

1. Desplegar una versión que retire las acciones de notificación y descarga.
2. Crear una migración compensatoria que inactive `PLANILLA_BOLETAS_GESTIONAR` y retire los procedimientos mutadores.
3. Conservar `PlanillaBoletaEnvios`, `PlanillaCalculos`, `PlanillaDetalle`, auditoría y ledger.
4. Revocar o corregir una boleta mediante la reversión auditada del cálculo; no publicar archivos bajo `wwwroot`.
