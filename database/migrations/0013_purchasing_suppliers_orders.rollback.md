# Rollback de 0013 — compras

La migración 0013 agrega estructuras y contratos; no tiene rollback destructivo automático.

1. Detener escrituras de compras y conservar la aplicación anterior disponible.
2. Verificar `SchemaMigrationHistory`, `ComprasAuditoria`, recepciones, órdenes e inventario.
3. Si solo falla la aplicación, revertir el commit de aplicación sin borrar tablas ni movimientos.
4. Si un procedimiento tiene un defecto, desplegar una migración compensatoria con un número nuevo; no editar 0013 aplicada.
5. Si una recepción válida debe compensarse, registrar una operación de inventario aprobada y auditada. Nunca decrementar stock ni borrar auditoría manualmente.
6. Restaurar un BACPAC verificado únicamente con aprobación del responsable, porque revierte también operaciones ajenas posteriores.

Las tablas `Proveedores`, `OrdenesCompra` y `DetalleOrdenCompra` pueden contener datos heredados del PR #116. Por esa razón no deben eliminarse durante un rollback.
