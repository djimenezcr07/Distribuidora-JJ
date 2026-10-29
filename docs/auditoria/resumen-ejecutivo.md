# Resumen ejecutivo de auditoría

Fecha de corte: 2026-08-03, zona `America/Costa_Rica`.

## Base y alcance

- Repositorio verificado: `d0j0fre/Desarrollo_Trilogia`, público, rama predeterminada `main`.
- PR de integración: [#117](https://github.com/d0j0fre/Desarrollo_Trilogia/pull/117), abierta y mergeable.
- Cabeza remota y local: `107bce2b9fe5e509ca221ae67da4bf008f33e274`.
- Rama: `codex/cierre-integral-historias`; árbol limpio antes de crear estos informes.
- Cuenta `gh`: `d0j0fre`, con scopes `repo` y `workflow`; Projects no es consultable porque falta `project/read:project`.
- `NO EJECUTABLE: falta scope project/read:project`.
- Acción manual autorizable, no ejecutada: `gh auth refresh -h github.com -s project`.
- Ubicación formal del backlog: no especificada; se utilizaron Issues y la matriz interna como fuentes canónicas provisionales.

## Resultados verificables

- 94 issues: 44 abiertas y 50 cerradas.
- 92 historias únicas después de normalizar `CU-012` (#2/#3) y `CU- 241`.
- CU-107 a CU-110: no especificado.
- Estimaciones canónicas: no especificadas. Se usa peso igual por historia.
- #36, #37 y #38 fueron cerradas con una relación de duplicado falsa respecto de CU-081/082/083.
- En la base de #117, CU-111 era parcial y CU-112–114 no tenían flujo vertical verificable. La rama local posterior a Puerta A implementa los cuatro; permanecen pendientes de migración y QA de entorno.
- #117 contiene cuatro commits exclusivos sobre #112 y es la base técnica más completa.
- Los tips de PR #114 y #116 no son ancestros Git de #117. La intención de #114 fue integrada y endurecida mediante #115; la de #116 fue sustituida por los cuatro commits exclusivos de #117.
- Las migraciones 0007-0012 de #116 colisionan con la numeración canónica y no deben portarse.
- Los cinco checks requeridos existen y pasan en #117: `security-scan`, `sql-validation`, `build`, `tests`, `final-gate`.
- `main` exige checks estrictos, una aprobación, resolución de conversaciones y protección para administradores.

## Línea base técnica

| Control | Resultado |
|---|---|
| Restore | Correcto |
| Build Release | 0 errores, 0 advertencias |
| Pruebas | 158 aprobadas, 0 fallidas, 0 omitidas |
| SQL ScriptDom | 94 archivos, 951 lotes, 0 errores |
| Secretos | 706 archivos revisados; 675 de texto; aprobado |
| `git diff --check` | Correcto |
| Cobertura de líneas en la rama local | 5,80% (895/15.407) |
| Cobertura de ramas en la rama local | 3,92% (417/10.631) |

`coverlet.collector` quedó incorporado. El porcentaje global es bajo y se reporta sin maquillarlo; las políticas críticas nuevas tienen cobertura focalizada entre 87,8% y 100% de líneas.

## Porcentajes

Fórmula por historia: `10 criterios + 35 funcional + 25 pruebas + 15 DB/seguridad + 10 QA + 5 documentación`. Denominador: `92 × 100 = 9.200` puntos.

| Escenario | Puntos | Porcentaje |
|---|---:|---:|
| Integrado en `main` | 3.660 / 9.200 | 39,78% |
| Cabeza actual de #117 | 5.165 / 9.200 | 56,14% |
| Proyección después de automatización aprobada | 5.860 / 9.200 | 63,70% |
| Proyección después de QA humano/Azure | 6.519 / 9.200 | 70,86% |
| Rama local después de Puerta A | 5.497 / 9.200 | 59,75% |

Las proyecciones no son evidencia ejecutada ni autorizan 100%. Intervalo de sensibilidad actual de #117: 48%-64%, no estadístico. Confianza global: media-baja.

## Decisión recomendada

La ejecución local autorizada por `APROBADO PUERTA A` se realizó en `codex/cierre-rrhh-backlog-20260804`, apilada sobre el SHA verificado de #117. Antes de publicar se requiere `APROBADO PUERTA B`.

No se modificó GitHub, Azure ni SQL compartido. Se implementaron CU-111–114, migraciones incrementales 0017–0020, ciclo privado de imágenes, harness LocalDB y cobertura. La suite local aprobó 189 pruebas; ScriptDom y validaciones finales se registran en `docs/qa-final.md`.
