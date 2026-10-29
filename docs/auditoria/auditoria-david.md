# Auditoría específica del trabajo de David

## Conclusión

El trabajo de David aporta dos bloques distintos. El primero, PR #114, fue integrado semánticamente y endurecido durante PR #115; el tip original no es ancestro de #117. El segundo, PR #116, tampoco es ancestro: #117 reimplementa CU-101-104 con contratos de seguridad, pruebas y migración consolidada 0013. No debe fusionarse #116 directamente.

## PR #114 y #115

PR #114 modifica 38 rutas y tiene cinco commits exclusivos. En #117:

- 28 rutas existen, pero con contenido posterior modificado por la integración y correcciones de #115/#112.
- Dos pruebas originales (`ComboValidatorTests`, `StockTransformationValidatorTests`) y `Validators.cs` no existen con esos nombres; fueron sustituidos por servicios y pruebas de dominio/integración actuales.
- Dos imágenes bajo `wwwroot/uploads/productos` no se portaron; no se deben versionar cargas de usuario como requisito funcional.
- Las migraciones originales `0002`-`0006` no se portaron porque colisionaban; su intención se consolidó en `0012_inventory_combos_transformations_intelligence.sql` con verify y rollback.

| Cambio de David | En #117 | Sustitución/mejora | Conflicto | Decisión |
|---|---|---|---|---|
| Combos, carrito y checkout | Sí, modificado | Snapshot, atomicidad, componente inactivo y pruebas adicionales | No | Conservar versión #117 |
| Transformación de inventario | Sí, modificado | Servicio dedicado, locks y pruebas de concurrencia | No | Conservar versión #117 |
| Inteligencia CU-241-243 | Sí, modificado | Servicio y contratos endurecidos | No | Conservar versión #117 |
| Pruebas `*ValidatorTests` | No con esos nombres | Sustituidas por pruebas actuales de dominio/contrato | No | No portar duplicados |
| Imágenes cargadas en `wwwroot` | No | Se evita versionar uploads | Riesgo de persistencia | No portar archivos |
| Migraciones 0002-0006 | No | Consolidación canónica 0012 | Sí, numeración | No portar ni renumerar |
| Configuración de correo | Sí, corregida | Secretos retirados y configuración segura | Riesgo histórico de secreto | Conservar saneamiento |

## PR #116

Las 14 rutas de código/vistas de compras existen en #117, todas modificadas. Las seis migraciones de #116 no existen en #117.

| Cambio de David | En #117 | Sustituido por implementación mejor | Ausente | Conflicto | Decisión |
|---|---|---|---|---|---|
| Controllers de proveedores, órdenes e histórico | Sí | Sí: validación, idempotencia y manejo de discrepancias | No | No | Conservar #117 |
| ViewModels, servicio y vistas | Sí | Sí: contratos y flujos ampliados | No | No | Conservar #117 y acreditar intención original |
| `Program.cs` y `_Layout.cshtml` | Sí | Integración adaptada a arquitectura vigente | No | No | Conservar #117 |
| `appsettings*.json` | Existen, contenido distinto | Saneamiento excluye valores de #116 | No | Riesgo de configuración | No portar valores |
| `0007_compras_proveedores.sql` | No | 0013 consolidada | Sí | Colisiona con 0007 canónica | No portar |
| `0008`-`0012` de compras | No | 0013 consolidada | Sí | Colisionan con 0008-0012 canónicas | No portar |

No se añade `Co-authored-by`: correo público confirmado no especificado. La trazabilidad deberá citar PR #114/#116 y los commits públicos sin inventar correo.
