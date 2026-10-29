# Compensación de 0031

Instalar mediante `sqlcmd -I -b -f 65001`, con SHA256 de los bytes finales,
después de verificar respaldo, restauración, ledger y contrato en copia aislada.
`-I` es obligatorio: SQL Server captura QUOTED_IDENTIFIER al crear el módulo y
Pedidos tiene un índice filtrado. El verificador exige ambas opciones ANSI/QUOTE.

La firma de actualización conserva los seis parámetros históricos y añade
`@ExpectedSecurityStamp`. El llamador MVC envía el stamp validado de su sesión;
las llamadas antiguas sin ese contexto se rechazan. Reintentar con otro UUID,
actor, recurso o contenido no equivale a recuperar la solicitud original.

La instalación no rellena evidencia física ni cambia entregas/facturas históricas.
Solo una nueva confirmación logística autorizada puede escribir la evidencia.
El registro es inmutable; no debe borrarse o reconstruirse desde Estado=Entregado.

Si se revierte el ejecutable MVC, bloquear temporalmente la mutación logística
hasta instalar un consumidor compatible; no devolver el procedimiento inseguro
ni relajar la comprobación de contexto. Una compensación SQL posterior requiere
revisión específica y debe conservar evidencia, ledger y revocaciones. No se
autoriza restauración sobre el original ni retirada automática de objetos/datos.
