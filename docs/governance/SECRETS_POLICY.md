---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-24
scope: secrets-management
github_issue: "#541"
---

# Secrets Policy

> **Purpose:** Governance-grade rules for secrets management in the agentic-spine.
> Infisical is the single source of truth for all secrets.

---

## Core Rules

1. **No secrets in the repo.** No `.env` files, no hardcoded tokens, no API keys.
2. **Infisical is SSOT.** All secrets are stored in Infisical and injected at runtime.
3. **Bindings, not values.** The spine stores binding metadata (project names, key names)
   but never secret values. See `docs/core/SECRETS_BINDING.md`.
4. **Namespace under `/spine/*`.** New infrastructure secrets must be created under
   `/spine/*` secret paths (not root `/`) to avoid legacy collision.
5. **Hard-zero root path.** Root-path (`/`) keys are not allowed in infrastructure/prod.
   All governed keys must resolve to `/spine/*` namespace routes.

---

## Secret Injection

Secrets are injected via the `secrets.exec` capability:

```bash
# Check secrets configuration (no values, no network)
./bin/ops cap run secrets.status

# Check auth presence
./bin/ops cap run secrets.auth.status

# Run a command with secrets injected (requires operator approval)
./bin/ops cap run secrets.exec -- <command>
```

## Canonical Bundle Rotation (CLI-Only)

Use bundle-based rotation so agents never guess project names/paths.

```bash
# Verify canonical bundle route + endpoint auth (no writes)
./bin/ops cap run secrets.bundle.verify finance

# Apply new bundle values from clipboard JSON and sync local finance .env
# Clipboard JSON format:
# {"FIREFLY_ACCESS_TOKEN":"...","PAPERLESS_API_TOKEN":"..."}
echo "yes" | ./bin/ops cap run secrets.bundle.apply finance --clipboard --sync-local-env

# Enforce fail if deprecated-project shadow keys still exist
./bin/ops cap run secrets.bundle.verify finance --fail-on-legacy-shadow
```

Bundle contract source:
- `ops/bindings/secrets.bundle.contract.yaml`

---

## What Must Never Be Committed

| Pattern | Example |
|---------|---------|
| `.env` files | `.env`, `.env.local`, `.env.production` |
| Token values | `GITHUB_TOKEN=ghp_...` |
| Private keys | `*.pem`, `*.key` |
| Auth credentials | `client_secret`, `api_key` values |

---

## Rotation Policy

- Secrets older than 90 days trigger a **critical** alert.
- Secrets older than 60 days trigger a **warning**.
- Monitoring: `surfaces/verify/check-secret-expiry.sh`.

---

## Verification Commands

```bash
# Check secrets binding integrity
./bin/ops cap run secrets.binding

# Compare SSOT inventory vs live Infisical projects
./bin/ops cap run secrets.projects.status

# Verify namespace hygiene for infrastructure/prod
./bin/ops cap run secrets.namespace.status

# Check secret age/expiry
surfaces/verify/check-secret-expiry.sh
```

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SECRETS_BINDING.md](../core/SECRETS_BINDING.md) | Non-secret binding metadata |
| [INFISICAL_PROJECTS.md](../core/INFISICAL_PROJECTS.md) | Project inventory |
| `ops/bindings/secrets.namespace.policy.yaml` | Namespace policy + hard-zero root lock |
| `ops/bindings/secrets.enforcement.contract.yaml` | Strict enforcement toggles + deprecated alias contract |
| `ops/staged/SECRETS_NAMESPACE_MIGRATION_MAP.md` | Phased migration plan for GAP-OP-013 |
| [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Governance entry point |
