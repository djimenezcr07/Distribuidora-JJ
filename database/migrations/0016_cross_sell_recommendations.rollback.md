# Rollback de 0016 — venta cruzada

La migración solo agrega un procedimiento. Desplegar primero una versión que no invoque `dbo.sp_Ventas_CrossSellSuggestions`; luego crear una migración compensatoria que elimine el procedimiento y registre la compensación en `SchemaMigrationHistory`.

No se modifican precios, carritos ni pedidos, y 0016 no agrega datos de negocio persistentes.
