---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-25
scope: vaultwarden-canonical-hygiene
---

# Vaultwarden Canonical Hygiene Runbook

Purpose: eliminate Vaultwarden drift using a repeatable agent-driven cycle that
classifies stale URLs, tests reachability, and produces a safe apply plan.

## Safety Contract

- Default mode is read-only (`vaultwarden.uri.audit`, `vaultwarden.uri.healthcheck`, `vaultwarden.reconcile.report`).
- Mutations are only allowed through `vaultwarden.reconcile.apply --execute --confirm GO-LIVE-VAULTWARDEN-CLI`.
- Hard-delete is prohibited. Retirement uses soft-delete to trash only.
- Apply scope is restricted to:
  - URI update
  - folder move
  - soft-delete to trash

## Canonical Policy Files

- `ops/data/vaultwarden/canonical_hosts.yaml`
- `ops/data/vaultwarden/folder_taxonomy.yaml`
- `ops/data/vaultwarden/reconcile_rules.yaml`

Update these files first whenever topology or naming changes.

## Weekly Hygiene Loop

Run from `~/code/agentic-spine`:

```bash
./bin/ops cap run vaultwarden.hygiene.weekly
```

Artifacts are written to:
- `receipts/audits/infra/vaultwarden-hygiene-<timestamp>/`
  - `uri-audit.json`
  - `uri-healthcheck.json`
  - `reconcile-report.json`
  - `reconcile-apply-dry-run.json`
  - `summary.md`

## One-Off Investigation Commands

```bash
./bin/ops cap run vaultwarden.uri.audit -- --format table
./bin/ops cap run vaultwarden.uri.healthcheck -- --format table --timeout 4
./bin/ops cap run vaultwarden.reconcile.report -- --format table
```

Export machine-readable plan:

```bash
./bin/ops cap run vaultwarden.reconcile.report -- --format json --output /tmp/vw-reconcile-report.json
```

## Guarded Apply Workflow

Dry-run (default):

```bash
./bin/ops cap run vaultwarden.reconcile.apply -- --input /tmp/vw-reconcile-report.json --max-actions 100
```

Targeted one-by-one/batched dry-run:

```bash
./bin/ops cap run vaultwarden.reconcile.apply -- \
  --input /tmp/vw-reconcile-report.json \
  --actions update_uri \
  --take 1
```

Execute (mutating):

```bash
./bin/ops cap run vaultwarden.reconcile.apply -- \
  --input /tmp/vw-reconcile-report.json \
  --execute \
  --confirm GO-LIVE-VAULTWARDEN-CLI \
  --allow-retire \
  --max-actions 50
```

Execute specific item IDs only:

```bash
./bin/ops cap run vaultwarden.reconcile.apply -- \
  --input /tmp/vw-reconcile-report.json \
  --execute \
  --confirm GO-LIVE-VAULTWARDEN-CLI \
  --item-ids <item-id-1>,<item-id-2>
```

## Safety Stops

Pause and investigate if any condition is true:

1. Planned actions exceed expected change window (`--max-actions`).
2. Execute run reports non-zero `errors`.
3. Active count drops more than expected plus 2% buffer.
4. Backup freshness check fails:

```bash
./bin/ops cap run vaultwarden.backup.verify
```

## Rollback

- Immediate rollback for Vault data uses `docs/governance/VAULTWARDEN_BACKUP_RESTORE.md`.
- Restore from latest pre-change backup tarball before retrying apply.
- Keep reconcile apply receipts for before/after comparison.

## Promotion Rules

- Promote only when URI host matches canonical map and endpoint is reachable.
- Quarantine when stale signal exists but endpoint still responds.
- Retire-candidate when stale signal exists and endpoint is unreachable.
- Unfiled items must move to `00-inbox` at minimum.

## Closure Criteria

Close the canonical hygiene loop only when all are true:

1. `vaultwarden.reconcile.report` returns zero `retire_candidate` from known legacy hosts.
2. All `old_tailscale_domain` and `old_shop_lan_ip` signals are zero (or explicitly quarantined with owner review).
3. Folder coverage includes all required folders from taxonomy.
4. Weekly hygiene receipt exists for the current week.
5. `verify.core.run` passes.
