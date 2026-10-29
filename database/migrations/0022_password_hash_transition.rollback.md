# Rollback de 0022

La reversión ordinaria es compensatoria: volver a desplegar la versión anterior de la API y conservar las columnas nuevas. No se eliminan hashes ni columnas porque eso destruiría credenciales creadas o actualizadas después de 0022.

Antes de volver a la API anterior se debe confirmar que ningún usuario dependa exclusivamente de `ContrasenaHash`. Si existen usuarios migrados, deben completar un restablecimiento controlado mediante el flujo autorizado; nunca se deriva ni se recupera la contraseña original desde el hash.

Una restauración del respaldo previo es el último recurso y solo procede si también se revierten todos los datos creados desde la migración durante una ventana aprobada.
