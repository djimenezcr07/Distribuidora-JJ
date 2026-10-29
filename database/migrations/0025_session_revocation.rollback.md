# Rollback 0025

El rollback exige retirar primero el middleware y el contrato `SecurityStamp` de MVC/API. Luego puede eliminarse `dbo.tr_Usuarios_RevokeSessions` y `dbo.sp_Auth_GetSessionState`. No eliminar `Usuarios.SecurityStamp` mientras cualquier versión desplegada lo consuma.

La reversión restaura sesiones no revocables y por ello requiere ventana de mantenimiento, cierre de sesiones existentes y aprobación de seguridad. Registrar cualquier compensación como una migración nueva; no editar ni borrar el ledger.
