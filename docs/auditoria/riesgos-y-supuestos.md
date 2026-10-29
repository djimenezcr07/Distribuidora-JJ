# Riesgos, bloqueos y supuestos

| Riesgo/supuesto | Evidencia | Impacto | Mitigación/decisión |
|---|---|---|---|
| Project no auditado | Falta scope `project/read:project` | Campos/estimaciones pueden existir fuera de Issues | `NO EJECUTABLE`; continuar con Issues; auth refresh solo manualmente autorizado |
| #117 grande | 45 commits, 251 archivos acumulados | Revisión difícil y mayor superficie de regresión | PR futuro apilado y commits atómicos |
| #117 no está en main | Ancestro main -> #117, no inverso | Código abierto no cuenta como integrado | Separar porcentajes main/#117 |
| #114 no es ancestro de #117 | `merge-base --is-ancestor` devuelve falso | Riesgo de afirmar integración Git literal | Documentar integración semántica vía #115 |
| #116 no es ancestro | Dos commits exclusivos y 22 archivos | Merge directo reintroduce configuraciones y SQL conflictivo | No merge; conservar sustitución de #117 |
| Numeración SQL conflictiva | #116 usa 0007-0012 | Puede sobreescribir contratos canónicos | No portar ni renumerar mecánicamente |
| CU-111 local, sin despliegue | 0017 e interfaz implementadas | No demuestra funcionamiento en el esquema real | Aplicar y verificar solo tras backup/Puerta B |
| Reglas legales de CU-113 | Fuentes/tasas no especificadas | Riesgo legal y resultados falsos | Motor configurable; no inventar valores ni otorgar 100% |
| Datos de RRHH/boletas | Información sensible | Exposición bajo URL/log/wwwroot | Datos sintéticos y almacenamiento privado |
| Imágenes configurables | Nuevas imágenes fuera de `wwwroot`; legado puede seguir en ruta anterior | Persistencia depende de volumen configurado y legado puede quedar huérfano | Configurar `ProductImages:StoragePath`, respaldar y migrar legado de forma controlada |
| Evidencia versionada en wwwroot | Archivo rastreado histórico | Posible dato no apto para repo | No abrir/borrar en AUDIT_ONLY; revisar con autorización |
| Cobertura global baja | 5,80% líneas y 3,92% ramas | Regresiones históricas aún posibles | Mantener métrica y priorizar controladores/servicios heredados |
| QA manual | 72/920 puntos locales | Build verde no demuestra Done | Checklist autenticado/Azure después de publicación autorizada |
| SMTP/Azure/usuarios de prueba | no especificados | CU-114 y QA de entorno bloqueados | Fake SMTP y checklist; no simular resultados |
| Protección administrativa | Cinco checks + revisión | PR seguirá bloqueada sin humano | Conservar; no bypass |
| Credenciales/secrets | Sesión gh activa; secretos no solicitados | Exposición si se imprimen | Solo verificar scopes; nunca mostrar valores |

## Confianza

- Código/compilación/pruebas/SQL: alta.
- Estado de Git y PR: alta.
- Backlog en Issues: media; la mayoría no contiene criterios explícitos.
- Project: no especificado.
- QA humano/Azure: baja.
- Porcentaje global #117: 56,14%, sensibilidad 48%-64%, no estadística.

No se usaron datos personales reales ni se ejecutó Azure.
