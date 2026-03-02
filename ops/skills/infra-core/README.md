# Infra-Core Skill

Agent skill for infra-core execution consistency across Cloudflare, Vaultwarden, Infisical, and Authentik.

## Quick Reference

### Status Check
```bash
./bin/ops cap run infra.core.smoke
```

### Per-System Smoke
```bash
./bin/ops cap run infra.core.smoke -- cloudflare
./bin/ops cap run infra.core.smoke -- vaultwarden
./bin/ops cap run infra.core.smoke -- infisical
```

### Cloudflare Operations
```bash
# Read-path health
./bin/ops cap run cloudflare.zone.list -- --json
./bin/ops cap run domains.portfolio.status -- --json
./bin/ops cap run cloudflare.registrar.status -- --json

# Publish a new service
./bin/ops cap run cloudflare.service.publish -- --hostname HOST --service-name NAME --service-url URL

# Dry-run publish
./bin/ops cap run cloudflare.service.publish -- --hostname HOST --service-url URL --dry-run
```

### Vaultwarden Operations
```bash
./bin/ops cap run vaultwarden.vault.audit
./bin/ops cap run vaultwarden.backup.verify
./bin/ops cap run vaultwarden.cli.auth.status
./bin/ops cap run vaultwarden.item.list
```

### Secrets Operations
```bash
./bin/ops cap run secrets.status
./bin/ops cap run secrets.auth.status
./bin/ops cap run secrets.namespace.status
```

## Contracts

| Contract | Path |
|----------|------|
| Baseline | `ops/bindings/infra.core.baseline.contract.yaml` |
| SLO | `ops/bindings/infra.core.slo.yaml` |
| Runbook | `docs/governance/INFRA_CORE_CANONICAL_RUNBOOK.md` |

## Gate Coverage

| Gate | System | Check |
|------|--------|-------|
| D315 | Cloudflare | Read-path + smoke health |
| D316 | Cloudflare | Domain routing parity |
| D317 | Cloudflare | Service publish mapping |
| D318 | Cloudflare | Mail-archive + Homarr routes |
| D319 | Vaultwarden | Hygiene compliance |
| D55 | Infisical | Runtime readiness |
| D112 | Infisical | Access pattern lock |
