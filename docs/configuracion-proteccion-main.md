# Configuración de protección de `main`

## Estado

La protección se configuró el 22 de julio de 2026 después de que el PR #112 confirmara los nombres reales y aprobara los checks `security-scan`, `sql-validation`, `build`, `tests` y `final-gate`.

La consulta de verificación devolvió los cinco contextos requeridos, `strict: true`, administradores sujetos a la regla, una aprobación, conversaciones resueltas y force-push/eliminación deshabilitados.

## Política requerida

- Pull Request obligatorio.
- Una aprobación como mínimo.
- Conversaciones resueltas.
- Administradores sujetos a la regla.
- Checks requeridos y actualizados con `main`.
- Force-push y eliminación de rama deshabilitados.

## Comando de reproducción con GitHub CLI

Autenticarse con una cuenta administradora y ejecutar desde una terminal Bash:

```bash
gh auth status
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  repos/d0j0fre/Desarrollo_Trilogia/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "security-scan",
      "sql-validation",
      "build",
      "tests",
      "final-gate"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "block_creations": false,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
```

Verificación:

```bash
gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  repos/d0j0fre/Desarrollo_Trilogia/branches/main/protection
```

Si GitHub rechaza un contexto, confirmar el nombre exacto en el último run y corregir solo ese contexto; no desactivar la protección completa.
