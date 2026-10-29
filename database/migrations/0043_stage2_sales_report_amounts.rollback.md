# Rollback 0043

Revertir primero el consumidor ReportsDbService a su contrato anterior solo si no consulta pedidos V2. No se sobrescribe sp_Reportes_VentasDetallado ni se reescriben datos. Conservar el nuevo procedimiento y ledger para trazabilidad; no borrar automáticamente. Ante incompatibilidad, detener nuevas operaciones y usar el respaldo acreditado en una restauración aislada antes de decidir recuperación operativa.
