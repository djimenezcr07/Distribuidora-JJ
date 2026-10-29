# 0040 — Documents por propietario

Nuevos procedimientos versionados; no modifica 0007/0008 ni otorga grants. La fuente instalada de propiedad es `DocumentosDigitales.ResponsableUsuarioId`, no el creador histórico ni el rol. No existe una fuente canónica de autorización departamental por operación: esa rama permanece denegada. No se crean departamentos ni asignaciones, ni se infieren de perfiles.

El servicio usa el login original validado y lo vuelve a comprobar antes del commit; los procedimientos bloquean la fila de propiedad durante cada operación. Listas, métricas, historial, alertas y descargas se limitan al propietario. La bandera antigua de administración no autoriza nada. Creación solo personal; cambio de departamento y transferencia de propietario no se habilitan. La eliminación lógica conserva historial; no hay purgas ni retención automática.

Prerrequisitos: backup CHECKSUM, VERIFYONLY y restauración probada antes de la promoción. Conservar archivos y versiones existentes. Si falla el despliegue, no volver al acceso global anterior: bloquear temporalmente el módulo mientras se restaura una versión segura aprobada. No ejecutar DROP ni restaurar la base principal automáticamente. No eliminar ledger, documentos ni respaldos.
