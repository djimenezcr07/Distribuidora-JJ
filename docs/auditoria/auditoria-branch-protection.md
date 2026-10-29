# Auditoría de branch protection y CI

## Snapshot de `main`

| Control | Valor |
|---|---|
| Checks estrictos | Sí |
| Checks requeridos | `security-scan`, `sql-validation`, `build`, `tests`, `final-gate` |
| Aprobaciones requeridas | 1 |
| Descartar aprobaciones obsoletas | Sí |
| Aplicar a administradores | Sí |
| Resolver conversaciones | Sí |
| Force push | Deshabilitado |
| Eliminación de rama | Deshabilitada |
| Rulesets adicionales visibles | `[]` |

El endpoint de protección fue accesible con la credencial actual. No se requiere ni se propone reducir protección.

## CI

El workflow de `main` todavía tiene un job histórico `validate`; la versión en #112/#117 define los cinco jobs canónicos. En #117 los cinco contextos requeridos reportan `SUCCESS` y `final-gate` depende de los otros cuatro.

De los 30 runs consultados: 20 terminaron con éxito y 10 con fallo; los fallos históricos no contradicen el estado verde actual de #117.

## Decisión

- Conservar los cinco checks.
- Conservar aprobación humana y resolución de conversaciones.
- No habilitar bypass.
- No modificar protection ni rulesets mediante API o navegador.
- Tras una futura rama apilada, comprobar que los cinco nombres se mantengan exactos.

No se realizó ninguna mutación administrativa.
