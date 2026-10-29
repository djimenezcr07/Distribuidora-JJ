# Rollback de 0014 — tablero de entregas

El permiso es aditivo. Si la vista debe retirarse, revertir primero el código de aplicación. No borrar asignaciones ni el permiso en una base compartida: crear una migración compensatoria que lo marque inactivo después de confirmar que ningún perfil o integración lo utiliza.
