# Login original MVC — ocho horas absolutas

Requiere 0033 con hash exacto, Usuarios/Perfiles/SecurityStamp y AuditoriaSistema.
Respaldo COPY_ONLY/CHECKSUM con restauración real, comprobación de ledger y pruebas
aisladas antes de instalar. Usar `sqlcmd -I -b -f 65001` y MigrationSha256 de bytes finales.

Solo el flujo MVC tras validar credenciales mediante API solicita un login nuevo.
SQL comprueba otra vez perfil/stamp activos, emite ID y timestamps datetime2(7),
confirma registro/auditoría juntos y fija ExpiresUtc=IssuedUtc+8h. El binding hash
combina el ID de sesión MVC con un nonce aleatorio por login, guardado solo en la
sesión del servidor. No se guardan cuerpos privados ni se inventa un proof del cliente.
No hay backfill: sesiones anteriores deben autenticarse nuevamente. Los 45 minutos
de inactividad MVC permanecen vigentes y no prolongan el límite absoluto.

La validación canónica compara actor/perfil/stamp/binding/emisión/vencimiento;
consulta el reloj SQL y no actualiza expiraciones. Logout revoca persistentemente
y audita una sola vez. Un cambio de cuenta retira el login anterior. Otra sesión de
la misma cuenta recibe otro ID y no adopta el original. Registros originales no se
reescriben ni borran automáticamente; una revocación no se revierte.

Esto integra la admisión por request MVC. No certifica todavía los consumidores
de ContextHandle/IntentBinding, la comprobación de login dentro de cada transacción
de negocio, cotizaciones/6B ni Chat V2. La API de validación de credenciales permanece
sin emitir tokens de acceso. No se certifica separación de identidades técnicas SQL.

Para compensar, detener los consumidores afectados y diseñar otra migración revisada
que preserve registros y auditoría. No volver a aceptar sesiones sin identidad original
ni eliminar tabla/ledger. Una restauración sobre el entorno de trabajo requiere
aprobación explícita y análisis de las escrituras posteriores al respaldo.
