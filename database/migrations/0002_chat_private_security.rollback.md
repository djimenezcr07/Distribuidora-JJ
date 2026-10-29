# Rollback de 0002

La migración contiene datos conversacionales y no debe revertirse eliminando tablas. El rollback ordinario consiste en retirar temporalmente las rutas y el Hub de chat mediante despliegue de aplicación, conservando `ChatConversaciones` y `ChatMensajes`.

Si un procedimiento requiere corrección, se publica una migración compensatoria con `CREATE OR ALTER`. Restaurar un respaldo completo es el último recurso y requiere autorización expresa porque perdería conversaciones posteriores al respaldo.
