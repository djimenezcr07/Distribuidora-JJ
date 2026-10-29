# Compensación de 0030

0030 amplía la invalidación del `Usuarios.SecurityStamp` existente para cambios en
grants, permisos y perfil. La instalación no cambia estados, asignaciones, precios,
pedidos ni stamps de usuarios existentes; agrega tres triggers y una fila de ledger.

Un stamp que ya fue revocado por una operación posterior **no debe restaurarse**:
reutilizarlo reactivaría sesiones antiguas. Si aparece una incompatibilidad, detener
las mutaciones de autorización afectadas y preparar una migración compensatoria
revisada que preserve esa revocación y el historial del ledger. No borrar la fila
de 0030 ni restaurar toda la base sobre datos nuevos automáticamente.

La retirada de triggers o una restauración sobre el destino original requiere
aprobación específica, respaldo reciente y valoración de escrituras posteriores.
El respaldo COPY_ONLY y su restauración de prueba se registran en la evidencia
privada del incremento; no se versionan datos ni archivos BAK/MDF/LDF.
