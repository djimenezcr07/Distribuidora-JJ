# Rollback de 0021

El procedimiento es de solo lectura. El rollback ordinario consiste en retirar temporalmente la ruta `MyGoal` de la aplicación y conservar `sp_Metas_MiProgreso` hasta publicar una migración compensatoria. No se modifican ni eliminan metas, facturas, pedidos o usuarios.
