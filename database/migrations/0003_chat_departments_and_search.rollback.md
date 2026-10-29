# Rollback de 0003

No se eliminan ni recrean `ChatDepartamentos`, membresías o mensajes. Para deshabilitar el módulo se retiran sus rutas y la unión departamental de SignalR mediante despliegue de aplicación, conservando toda la información heredada.

Los cambios de procedimientos o permisos se realizan mediante una migración compensatoria. Una restauración completa solo procede como último recurso autorizado, porque descartaría departamentos y mensajes creados después del respaldo.
