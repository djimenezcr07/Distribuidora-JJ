# Rollback 0024

El rollback es compensatorio y requiere aprobación. Antes de revertir la firma de `dbo.sp_Kilometraje_Cerrar`, debe desplegarse una versión de la aplicación que no envíe `@ActorUsuarioId` ni `@PuedeAdministrar`. Reponer la definición anterior elimina la defensa de ownership y solo es aceptable durante una recuperación controlada con el servicio fuera de línea.

El permiso `FLOTA_KILOMETRAJE_ADMIN` puede desactivarse después de retirar sus asignaciones. No se deben eliminar filas de auditoría ni modificar el ledger; registrar la compensación como una migración nueva.
