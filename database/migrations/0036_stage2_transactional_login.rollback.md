# Guard transaccional del login original

Evolución aditiva: no sustituye procedimientos 0031–0035, no cambia sesiones,
datos comerciales, permisos ni asignaciones. Requiere el hash exacto de 0035.
Instalar con `sqlcmd -I -b -f 65001`, SHA256 de bytes finales y respaldo restaurado
y probado antes de la instalación principal. La repetición exige igual hash y estado.

Los consumidores MVC conservan el contexto validado por middleware. Abren una
transacción exterior, comprueban perfil/capacidad/actor/login originales con locks,
ejecutan el procedimiento existente y comprueban nuevamente el vencimiento antes
de confirmar. Los readers se disponen antes del segundo guard. Una excepción
dispone y revierte la transacción; el SQL histórico no se reescribe. Los cambios
concurrentes de autorizaciones se serializan; las revocaciones ya confirmadas se
rechazan. No hay bypass Administrador ni ampliación de las ocho horas.

Para compensar, detener estos consumidores y preparar otra evolución revisada;
no quitar el guard manteniendo sus consumidores activos ni aceptar contextos sin
login original. No borrar ledger ni restaurar la principal sin autorización y
evaluación de escrituras posteriores. La serialización por perfil es conservadora
y puede limitar rendimiento; este incremento no certifica separación de identidades
SQL, todas las lecturas del producto ni los contratos de Chat V2.
