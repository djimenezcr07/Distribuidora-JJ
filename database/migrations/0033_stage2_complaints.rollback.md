# 0033 — Reclamos CU-191/192

Evolución para un destino acreditado sin objetos previos de Reclamos. Rechaza
esquemas desconocidos y exige 0032 por hash, AuditoriaSistema y la capacidad
RECLAMOS_GESTIONAR ya existente. No otorga permisos ni crea usuarios o ejemplos.
Recibe MigrationSha256 real; instalar con `sqlcmd -I -b -f 65001`.

Lista, búsqueda, facturas, detalle, creación y cambio de estado exigen actor y
SecurityStamp vigentes, perfil activo y capacidad efectiva dentro de la transacción.
No existe excepción por Administrador. Cliente, pedido y factura se verifican en
SQL; factura y pedido deben corresponder al mismo recurso cuando se indican ambos.
Cerrar requiere resolución y un caso cerrado no se reabre mediante este contrato.
Creación/cambio y auditoría canónica son atómicos. No ejecuta devoluciones, créditos,
reembolsos, cambios de stock o facturación. La identidad original del login continúa
siendo un contrato pendiente independiente.

Antes de aplicar: respaldo COPY_ONLY/CHECKSUM, VERIFYONLY, restauración comprobada
con CHECKDB y prueba aislada de los seis consumidores reales. Conservar pruebas de
autorización, propiedad, revocación/regrant y rollback cuando falla auditoría.

Compensación: bloquear escrituras y diseñar una migración revisada preservando
reclamos, resoluciones, auditorías y ledger. No eliminar la tabla para desinstalar.
Una restauración sobre la base de trabajo requiere autorización explícita y análisis
de las operaciones posteriores al respaldo. No hay rollback destructivo automático.
