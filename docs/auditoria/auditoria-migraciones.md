# Auditoría de migraciones 0013-0020

## Inventario

| Migración | Historias | Ledger/SHA | Transacción | Verify | Segunda ejecución | Rollback | Evidencia actual |
|---|---|---|---|---|---|---|---|
| 0013 | CU-101-104 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada por contrato | Compensatorio documentado | Limpia, legado y flujo funcional documentados |
| 0014 | CU-084 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | Secuencia local documentada |
| 0015 | CU-132/134 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | Procedimientos invocados localmente |
| 0016 | CU-262 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | Venta cruzada invocada localmente |
| 0017 | CU-111 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | ScriptDom; aplicación pendiente |
| 0018 | CU-112 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | ScriptDom; aplicación pendiente |
| 0019 | CU-113 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | ScriptDom; aplicación pendiente |
| 0020 | CU-114 | Sí | `XACT_ABORT` y transacción | Sí | Rechazada | Compensatorio documentado | ScriptDom; aplicación pendiente |

0013 valida dependencias y contratos legados, preserva datos y registra auditoría. 0014-0016 son aditivas. Todas exigen un SHA hexadecimal de 64 caracteres y registran `SchemaMigrationHistory`.

## Hallazgos

- La suite ScriptDom final se registra en `docs/qa-final.md`.
- La documentación existente registra 0013 sobre esquema mínimo y legado, y la secuencia 0013-0016 en LocalDB desechable.
- Compatibilidad limpia/legada individual de 0014-0016: no especificado.
- `DBCC CHECKDB ... WITH PHYSICAL_ONLY` para la secuencia 0013-0016: aprobado en LocalDB desechable.
- Los rollback son planes compensatorios, no scripts destructivos. Esto es correcto para objetos que pueden contener datos o dependencias.
- #116 reutiliza 0007-0012; esas migraciones no se deben incorporar ni renumerar mecánicamente.

## Harness ejecutado tras Puerta A

1. Crear base LocalDB desechable mínima.
2. Preparar esquema mínimo compatible y datos sintéticos.
3. Calcular SHA-256 real sin alterar registros existentes.
4. Ejecutar 0013-0016 en orden con `sqlcmd -b`.
5. Ejecutar cada `verify.sql`.
6. Confirmar rechazo de segunda ejecución.
7. Probar recepciones, discrepancias, reportes y venta cruzada con datos suficientes/insuficientes.
8. Ejecutar `DBCC CHECKDB ... WITH PHYSICAL_ONLY`.
9. Destruir únicamente las bases desechables creadas por el harness.

El harness `scripts/database/Test-Migrations0013To0016.ps1` aprobó todos esos controles el 2026-08-04. No se ejecutó SQL contra Azure ni una base compartida. Los ledger y hashes solo existieron dentro de la base desechable, eliminada al finalizar. 0017–0020 no se aplicaron por falta de un esquema completo autorizado y QA coordinado.
