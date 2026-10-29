# 0041 — logística positiva y evidencia

Versiona asignación/despacho, confirmación y almacenamiento de evidencias sin sobrescribir procedimientos históricos ni 0031. Solo Facturado con factura vigente y stock previamente descontado es despachable. No backfill de entregas o hashes. Una carga de archivo nunca confirma la entrega. El chofer debe estar asignado; el administrador no recibe excepción para registrar evidencia. La lectura puede acreditarse por cliente propietario, chofer asignado o capacidad explícita ENTREGAS_EVIDENCIA_VER, sin excepción por nombre del perfil.

Auditoría de ruta, confirmación e integridad se confirma en la transacción del login original. La confirmación conserva UUID/actor/recurso/contenido, no vuelve a descontar inventario y no se duplica al reintentar. El hash SHA256 y longitud de nuevas evidencias se verifica antes de mover el archivo y al leerlo. Los archivos históricos sin hash no reciben certificación de integridad retrospectiva.

Liquidaciones y reentregas por fallo no se habilitan; cancelaciones posteriores al despacho permanecen bloqueadas. No se inventan asignaciones ni notas de crédito. Conservar las reglas existentes de secuenciación.

Exigir backup CHECKSUM/VERIFYONLY y restauración probada antes de promover. No ejecutar DROP de evidencia, archivos o ledger. Ante una incidencia, bloquear el carril afectado y preparar recuperación coordinada aprobada preservando las operaciones posteriores. No restaurar principal ni borrar historial automáticamente.
