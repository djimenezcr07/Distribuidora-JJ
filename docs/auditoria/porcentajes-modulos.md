# Porcentajes por módulo y escenario

## Método

Cada historia vale 100 puntos: criterios/trazabilidad 10, funcionalidad vertical 35, pruebas 25, DB/migración/seguridad/permisos 15, QA 10 y documentación 5. Se normalizaron 92 historias únicas y se usó peso igual porque las estimaciones son no especificadas.

`Rama local` refleja evidencia ejecutada después de Puerta A. `QA/Azure` continúa siendo una proyección y no demuestra despliegue ni validación humana.

| Módulo | HU | Main | #117 | Rama local | QA/Azure |
|---|---:|---:|---:|---:|---:|
| Activos | 4 | 60,00% | 60,00% | 60,00% | 75,00% |
| Asistente | 3 | 40,00% | 68,33% | 70,00% | 81,67% |
| Autenticación | 4 | 45,75% | 45,75% | 45,75% | 57,25% |
| Chat | 3 | 80,00% | 80,00% | 80,00% | 95,00% |
| Clientes y crédito | 3 | 37,00% | 37,00% | 37,00% | 47,00% |
| Compras | 6 | 20,00% | 76,67% | 80,00% | 88,33% |
| Consultas | 3 | 37,00% | 37,00% | 37,00% | 47,00% |
| Devoluciones y garantías | 4 | 65,00% | 65,00% | 65,00% | 80,00% |
| Documentos | 2 | 0,00% | 80,00% | 80,00% | 95,00% |
| Facturación y finanzas | 4 | 37,00% | 37,00% | 37,00% | 47,00% |
| Flotilla | 4 | 60,00% | 60,00% | 60,00% | 75,00% |
| Inteligencia de inventario | 3 | 0,00% | 85,00% | 85,00% | 95,00% |
| Inventario | 6 | 37,00% | 37,00% | 39,50% | 47,00% |
| Inventario avanzado | 2 | 0,00% | 85,00% | 85,00% | 95,00% |
| KPIs | 3 | 60,00% | 60,00% | 60,00% | 75,00% |
| Logística | 4 | 50,00% | 71,25% | 71,25% | 85,00% |
| Perfil | 3 | 37,00% | 37,00% | 37,00% | 47,00% |
| Portal cliente | 4 | 37,00% | 37,00% | 37,00% | 47,00% |
| Presupuestos y gastos | 3 | 0,00% | 80,00% | 80,00% | 95,00% |
| Promociones | 4 | 75,00% | 75,00% | 75,00% | 90,00% |
| Reclamos | 2 | 60,00% | 60,00% | 60,00% | 75,00% |
| Reportes | 4 | 24,25% | 66,75% | 69,25% | 78,00% |
| RRHH y planilla | 4 | 17,50% | 17,50% | 88,00% | 95,00% |
| Rutas inteligentes | 3 | 60,00% | 60,00% | 60,00% | 75,00% |
| Seguridad | 3 | 37,00% | 37,00% | 37,00% | 47,00% |
| Ventas móviles | 4 | 37,00% | 37,00% | 37,00% | 47,00% |

## Componentes de la rama local

| Dimensión | Puntos | Máximo | Cumplimiento |
|---|---:|---:|---:|
| Criterios y trazabilidad | 480 | 920 | 52,17% |
| Implementación funcional | 2.710 | 3.220 | 84,16% |
| Pruebas | 980 | 2.300 | 42,61% |
| DB, seguridad, permisos y migración | 900 | 1.380 | 65,22% |
| QA manual/ambiente | 72 | 920 | 7,83% |
| Documentación y enlaces | 355 | 460 | 77,17% |

## Cortes comparables

| Corte | Porcentaje global | Limitación |
|---|---:|---|
| `main@434a6ee` | 39,78% | No contiene #117 |
| `#112@b6e7d7a` | 48,75% | No contiene los ocho flujos exclusivos finales de #117 |
| `#117@107bce2` | 56,14% | PR abierta; no integrada en main |
| `codex/cierre-rrhh-backlog-20260804` | 59,75% | Evidencia local; sin push, migraciones 0017–0020 no aplicadas y QA humano/Azure pendiente |
| Proyección después de QA humano/Azure | 70,86% | No es evidencia ejecutada |

La mejora local suma 332 puntos verificables: CU-111–114, ciclo de imágenes y harness de 0013–0016. No se adjudicaron puntos de QA humano, despliegue ni trazabilidad remota.
