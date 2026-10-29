# Ejecución autorizada después de Puerta A

Puerta A fue aprobada y el plan se ejecutó localmente. Permanece prohibido publicar hasta recibir exactamente `APROBADO PUERTA B`.

## Rama y checkpoint

```powershell
git fetch --all --prune --tags
git switch --detach 107bce2b9fe5e509ca221ae67da4bf008f33e274
$branch = "codex/cierre-rrhh-backlog-$(Get-Date -Format yyyyMMdd)"
if (git show-ref --verify --quiet "refs/heads/$branch") {
    $branch = "$branch-$(Get-Date -Format HHmmss)"
}
git switch -c $branch
git branch "backup/pre-cierre-$(Get-Date -Format yyyyMMdd-HHmmss)"
```

Antes de crear la rama se volverán a verificar árbol limpio y SHA remoto de #117. No se hará push.

## Bloques

1. **Cobertura y harness:** añadir `coverlet.collector`; automatizar LocalDB 0013-0016.
2. **CU-111:** migración canónica siguiente, interfaz de servicio, auditoría transaccional, concurrencia, permisos exactos y pruebas.
3. **CU-112:** jornada, ausencias, extras, envío/aprobación/rechazo, idempotencia y segregación.
4. **CU-113:** motor configurable, catálogos versionados, snapshots, estados, doble cálculo/pago y reversión. Tasas legales: no especificadas.
5. **CU-114:** boleta privada, autorización por propietario/permiso, almacenamiento privado, fake SMTP e idempotencia de envío.
6. **Imágenes:** almacenamiento configurable, retiro, huérfanos, permisos y pruebas faltantes.
7. **Paradigmas:** documentar exactamente orientado a objetos, imperativo, funcional y declarativo con símbolos productivos y pruebas.
8. **QA/documentación:** actualizar matriz, porcentajes, riesgos, changelog y cuerpo de PR.

## Migraciones previstas

El inventario se confirmó sin colisiones: 0017 corresponde a CU-111, 0018 a CU-112, 0019 a CU-113 y 0020 a CU-114.

Cada migración tendrá `.sql`, `.verify.sql`, `.rollback.md`, SHA, ledger, transacción y contrato explícito de segunda ejecución.

## Commits previstos

1. `docs: auditar backlog y trazabilidad`
2. `feat(rrhh): completar expediente y jornada`
3. `feat(payroll): agregar planilla configurable`
4. `feat(payroll): agregar boleta privada`
5. `fix(images): completar ciclo de vida seguro`
6. `test: ampliar cobertura y harness SQL`
7. `docs: actualizar paradigmas y QA`

Antes de cada commit: `git status --short`, `git diff --stat`, `git diff --name-only`, `git diff --check`, pruebas focales, build y SQL correspondiente. Se usarán rutas explícitas; no `git add .`.

## Backlog remoto propuesto para Puerta B

- Conservar #2 como CU-012 canónica y enlazar #3 como duplicada.
- Corregir/reabrir #36-#38; revisar #39 como En QA.
- Marcar #31, #51, #53 y #92 En QA.
- #42-#45: proponer `En QA`; la implementación local existe, pero las migraciones y el QA de entorno están pendientes.
- Proponer las etiquetas `estado: en-qa`, `estado: implementada-sin-qa`, `estado: no-iniciada` sin crearlas todavía.

No se usarán referencias `Closes` mientras falte QA. No se cerrarán #112, #114 o #116 antes de confirmar cobertura y aprobación de #117 o su sucesor.

## Criterio de Puerta B

Mostrar rama, base, commits, archivos, diff, pruebas, cobertura, SQL, secretos, backlog propuesto, riesgos, rollback y PR apilado. Detenerse sin push hasta `APROBADO PUERTA B`.
