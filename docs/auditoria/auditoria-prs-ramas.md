# Auditoría de ramas y pull requests

Base común relevante: `main@434a6ee22e5a296cbc4c0c53aa120bddd547a748`. Cabeza canónica provisional: `#117@107bce2b9fe5e509ca221ae67da4bf008f33e274`.

| Rama remota | SHA | Fecha / autor | Main atrás/adelante | Archivos | PR | Contención y riesgo | Decisión propuesta |
|---|---|---|---:|---:|---|---|---|
| `codex/cierre-integral-historias` | `107bce2` | 2026-08-03 / d0j0fre | 0/45 | 251 | #117 abierta | Base más completa; bloqueada por revisión | Conservar y apilar trabajo |
| `sprint4-David-segundatarea` | `9d37e18` | 2026-07-30 / MontDavidH | 0/2 | 22 | #116 abierta | Tip no contenido; intención sustituida; SQL colisiona | No fusionar directamente |
| `codex/p0-saneamiento-integracion-total-20260722` | `b6e7d7a` | 2026-07-29 / GeraldRB | 0/41 | 201 | #112 abierta | Ancestro de #117 | Conservar hasta aprobación de sucesor |
| `codex/integracion-sprint4-danny-david-final` | `f8bdbde` | 2026-07-28 / d0j0fre | 0/40 | 201 | #115 merged | Contenida en #112/#117 | Archivable solo con autorización futura |
| `sprint4-David-primertrabajo` | `de108ff` | 2026-07-25 / MontDavidH | 0/5 | 38 | #114 abierta | Tip no ancestro; intención integrada vía #115 | No cerrar aún; documentar sustitución |
| `codex/danny-sprint4-cu201-cu202-cu221-cu222-cu223` | `4103825` | 2026-07-23 / d0j0fre | 0/20 | 156 | #113 merged | Contenida en #115/#112/#117 | Archivable con autorización |
| `main` | `434a6ee` | 2026-07-21 / GeraldRB | 0/0 | 0 | - | Base protegida | Conservar |
| `Gerald-New-UsuarioHistory-4` | `12a5c91` | 2026-07-21 / Gerald | 2/0 | 0 | #110/#111 | Contenida en main | Archivable con autorización |
| `feature/esteban-rutas-entregas-reportes` | `794041a` | 2026-07-20 / Esteban | 5/0 | 0 | #107/#109 | Contenida en main | Archivable con autorización |
| `Gerald-Sprint-4` | `d8eb978` | 2026-07-20 / Gerald | 13/0 | 0 | #108 | Contenida en main | Archivable con autorización |
| `Danny` | `f6f437e` | 2026-07-20 / GeraldRB | 11/1 | 0 | #97 | Commit divergente pero árbol equivalente a main | Revisar y archivar con autorización |
| `sprint3-David` | `8efb821` | 2026-07-15 / MontDavidH | 16/0 | 0 | #106 | Contenida en main | Archivable con autorización |
| `p1/permisos-equipo-administradores` | `1f67fde` | 2026-07-14 / d0j0fre | 28/0 | 0 | #102 | Contenida en main | Archivable con autorización |
| `p1/azure-colaborativo` | `8819d0a` | 2026-07-14 / d0j0fre | 30/0 | 0 | #101 | Contenida en main | Archivable con autorización |
| `p0/seguridad-sincronizacion` | `7fbe05f` | 2026-07-12 / d0j0fre | 35/0 | 0 | #100 | Contenida en main | Archivable con autorización |
| `codex/rebranding-visual-bloque-1-2` | `e238398` | 2026-06-24 / d0j0fre | 50/0 | 0 | #98 | Contenida en main | Archivable con autorización |
| `merge/danny-final-test` | `61a94c4` | 2026-06-14 / d0j0fre | 86/0 | 0 | - | Contenida en main | Archivable con autorización |
| `David` | `187307c` | 2026-06-03 / MontDavidH | 133/0 | 0 | #95/#96 | Contenida en main | Archivable con autorización |
| `feature/seguridad-roles` | `b3e4893` | 2026-06-02 / Esteban | 137/0 | 0 | - | Contenida en main | Archivable con autorización |

## PR prioritarias

| PR | Estado | Base <- cabeza | Commits/archivos observados | Checks/revisión | Decisión |
|---:|---|---|---:|---|---|
| #112 | Abierta | `main <- codex/p0...` | 41 / al menos 201 localmente | Cinco checks verdes; revisión requerida | Es ancestro de #117; no cerrar todavía |
| #114 | Abierta | `main <- sprint4-David-primertrabajo` | 5 / 38 | Sin evidencia equivalente a los cinco checks | Sustituida semánticamente mediante #115 |
| #115 | Fusionada en #112 | `codex/p0... <- codex/integracion...` | Integra Danny y David | Evidencia local documentada | Explica por qué #114 no necesita merge directo |
| #116 | Abierta | `main <- sprint4-David-segundatarea` | 2 / 22 | Solo `validate`; aprobada | No merge; portar intención ya sustituida |
| #117 | Abierta | `main <- codex/cierre-integral-historias` | 45 / 251 localmente | Cinco checks verdes; falta aprobación | Base recomendada |

#112 sí es ancestro de #117. #114 y #116 no son ancestros. Ninguna rama o PR se cerró, fusionó o eliminó.
