# 0032 — Garantías con entrega y autorización acreditadas

Requiere 0031 con hash acreditado y el esquema local Garantias/AuditoriaSistema.
Instalar mediante `sqlcmd -I -b -f 65001`, con `MigrationSha256` calculado sobre
los bytes finales. SQL valida las opciones de sesión y el contrato previo por hash.
No cambia garantías existentes, estados de pedidos, inventario ni datos financieros.

Los consumidores deben enviar el SecurityStamp de la sesión validada. Crear una
garantía exige cliente propietario y Stage2PhysicalDeliveries; los estados históricos
Entregado no sustituyen esa evidencia. Combos y regalías quedan pendientes de sus
validaciones específicas. Gestionar exige GARANTIAS_GESTIONAR vigente; el rol
Administrador no concede excepción. La auditoría canónica se confirma en la misma
transacción. La resolución no representa por sí sola devolución, reembolso ni crédito.

Antes de aplicar, conservar respaldo COPY_ONLY/CHECKSUM con restauración comprobada,
ledger anterior y huella de Garantias. Probar creación, negativos, revocación/regrant
y fallo de auditoría en la copia. No restaurar sobre la base de trabajo sin aprobación.

Si es necesario retirar esta evolución, bloquear las operaciones afectadas y preparar
una migración compensatoria revisada. No reinstalar el procedimiento histórico que
acepta garantías sin entrega acreditada; no eliminar auditorías, garantías ni filas del
ledger. Una restauración requiere aprobación explícita y análisis de escrituras posteriores.

Límites: no certifica la identidad original de login, sesiones con vigencia absoluta,
reconciliación global de migraciones ni contratos comerciales todavía pendientes.
