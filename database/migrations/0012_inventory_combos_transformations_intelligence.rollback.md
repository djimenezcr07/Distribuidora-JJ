# Rollback de 0012: combos, transformación e inteligencia

## Principio

0012 es una migración aditiva con datos operativos y snapshots contables. No se revierte eliminando tablas, procedimientos ni filas: hacerlo rompería trazabilidad de pedidos, facturas e inventario. El ledger de migraciones se conserva como evidencia histórica.

## Contención sin pérdida de datos

1. Detener el despliegue o volver a la versión anterior de la aplicación aprobada.
2. Retirar temporalmente de navegación las rutas de combos, transformación e inteligencia; no borrar los datos creados.
3. Si el incidente afecta checkout, suspender nuevos checkouts y conservar `CheckoutOperaciones` para evitar reintentos que descuenten existencias dos veces.
4. Ejecutar `0012_inventory_combos_transformations_intelligence.verify.sql` y recopilar el identificador de pedido, token de operación y referencia de transformación afectados.
5. Preparar una migración compensatoria nueva, revisada y con su propio BACPAC, que corrija únicamente el defecto confirmado. No editar ni volver a ejecutar 0012.

## Recuperación de inventario

Para un pedido cancelado, usar sólo el flujo autorizado que llama a `dbo.sp_Inventory_RestoreOrderStock`; éste restaura productos, regalos y componentes de combo de forma auditada. No hacer ajustes manuales de stock. Para una transformación, el ajuste correctivo debe usar una nueva transformación atómica con una referencia de auditoría distinta.

## Último recurso

La restauración de un BACPAC verificado sólo procede con aprobación expresa, ventana de mantenimiento y plan de recuperación de los cambios posteriores. Antes de restaurar, exportar evidencia de las operaciones posteriores al BACPAC y registrar quién autorizó la decisión. Esta alternativa puede perder cambios legítimos posteriores, por lo que no es un rollback rutinario.

## Cierre

Después de una corrección o recuperación, ejecutar la verificación de sólo lectura, pruebas funcionales de checkout/concurrencia y registrar en el PR: BACPAC usado, ejecutor, UTC, incidencia, script compensatorio y resultado.
