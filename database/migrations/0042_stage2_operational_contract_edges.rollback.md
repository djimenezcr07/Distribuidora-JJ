# 0042 — bordes operativos acreditados

Nueva versión monetaria que conserva el cuerpo 0039 acreditado por SHA256 y solo añade la elegibilidad del descuento redondeado positivo antes de la selección por prioridad/id. No altera 0012, 0039 ni sus módulos. Esta transformación exige una única coincidencia del punto de evolución; no admite un módulo distinto por nombre. El PromotionEngine original y CheckoutPricingGuard siguen verificando el resultado real. No habilita cotizaciones ni aprobación comercial.

La autorización de descarga propia se audita en la transacción. El evento dice «Autorizar descarga»; no afirma que el archivo se haya transmitido completo. No se almacenan cookies, cuerpos ni rutas físicas en la auditoría.

Exigir respaldo/restauración y prueba real en copia. No ejecutar down ni borrar snapshots, documentos, auditoría o ledger. En caso de fallo, bloquear la operación afectada y preparar recuperación segura aprobada; no volver al acceso global ni a aceptar discrepancias monetarias.
