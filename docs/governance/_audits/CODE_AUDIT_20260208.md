---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: spine-workbench-code-audit
---

# CODE AUDIT — Spine + Workbench (2026-02-08)

## Summary

Purpose: reduce agent confusion and docs-vs-deploy drift across `agentic-spine` (governance/runtime) and `workbench` (tools/supporting inventories).

Focus areas:
- Secrets (Infisical), edge/routing (Cloudflare), auth (Authentik), monitoring, dev tools (Gitea), and binding alignment.

Outputs:
- Redacted export in spine outbox
- This audit report (evidence-backed)
- Findings logged in `ops/bindings/operational.gaps.yaml` (GAP-OP-029+)

## Baselines

- Date: 2026-02-08
- Spine baseline SHA (pre-audit): `7d88ab0427f3efd13b0915d4d2531b33e7426b8c`
- Workbench baseline SHA (pre-audit): `86acf02886380da7c27755b7e3ac0cd0be1b978e`

## Evidence Index (Receipts + Outbox)

Receipts live under `agentic-spine/receipts/sessions/`.

- `docs.lint` PASS: `RCAP-20260208-111648__docs.lint__Rju1q68733`
- `spine.verify` PASS: `RCAP-20260208-111634__spine.verify__Rxdb065639`
- `host.drift.audit` PASS: `RCAP-20260208-093022__host.drift.audit__Rbcrh70777`
- `audit.export.governance_iac` PASS: `RCAP-20260208-110810__audit.export.governance_iac__R4yjw42207`
  - OUTBOX_EXPORT_DIR: `mailroom/outbox/audit-export/FS_EXPORT_20260208-160810`
- `cloudflare.tunnel.ingress.status` PASS: `RCAP-20260208-095452__cloudflare.tunnel.ingress.status__Rg25c97257`
- `cloudflare.domain_routing.diff` PASS: `RCAP-20260208-110109__cloudflare.domain_routing.diff__Rwa0y18221`
- `cloudflare.inventory.sync` PASS: `RCAP-20260208-110816__cloudflare.inventory.sync__Rq36142755`
- `secrets.namespace.status` PASS: `RCAP-20260208-105831__secrets.namespace.status__Rwaub7817`
- `docker.compose.status` DONE (status reported): `RCAP-20260208-111131__docker.compose.status__Rtksx49674`
- `services.health.status` DONE (status reported): `RCAP-20260208-111259__services.health.status__Rmnwb55011`

## Static Drift Scans (Repo-Only)

Scans were executed from `/Users/ronnyworks/code` (excluding `.git/`, `.worktrees/`, and `node_modules/`).

- Legacy `infrastructure/` path references: 664 hits
  - Most hits are in legacy docs, audits, or archived materials.
  - Remediation focus: remove contradictions in spine governance docs and ensure any referenced staged sources exist.
- Legacy `ronny-ops` references: 410 hits
  - Expected in legacy/reference materials; active runtime is guarded by spine drift gates and workbench strict-core checks.
- Workbench SSOT language checks:
  - `SINGLE SOURCE OF TRUTH` in workbench core docs/inventories: 0 hits
  - `docs/infrastructure/` pointer docs are marked as `status: pointer` where appropriate.
- Forbidden home-root output sinks:
  - No executable runtime surfaces were found writing to `/Users/ronnyworks/*.log|*.out|*.err`.
  - Mentions exist in audit/reference docs only.
- Repo-local secret spill risk:
  - Untracked local backup artifacts were found under workbench and moved to a governed quarantine outbox:
    `mailroom/outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550`

## Findings + Remediation (By Domain)

### Authority Separation (Spine vs Workbench)

Findings:
- Workbench “core” infrastructure docs risked being treated as SSOT by agents, even when they were meant as convenience surfaces.

Remediation shipped:
- Workbench pointer/index alignment (no SSOT claims; explicit “canonical sources are in spine”):
  - workbench: `docs/infrastructure/AUTHORITY_INDEX.md`
  - workbench: `docs/infrastructure/SSOT.md`
  - workbench: `docs/infrastructure/SERVICE_REGISTRY.md`
- Workbench snapshot marked non-authoritative:
  - workbench: `infra/data/SERVICE_REGISTRY.yaml`
- Spine SSOT registry expanded so the authority chain is explicit:
  - spine: `docs/governance/SSOT_REGISTRY.yaml`

### Secrets (Infisical) + Namespace Hygiene

Findings:
- `secrets.namespace.status` was failing due to missing Gitea keys under `/spine/vm-infra/gitea`.

Remediation shipped:
- Required keys present and namespaced; gate now passes.
- Note: secrets were written using file-based Infisical CLI values to avoid leaking secret values into receipts/command lines.

### Cloudflare / Ingress / Domain Routing

Findings:
- No spine-native export of Cloudflare tunnel ingress rules existed; drift between dashboard and docs was not mechanically detectable.
- DOMAIN_ROUTING_REGISTRY drifted from live tunnel config.

Remediation shipped:
- Added tunnel ingress export capability and a registry diff helper:
  - spine: `cloudflare.tunnel.ingress.status`
  - spine: `cloudflare.domain_routing.diff`
- Updated spine domain routing registry and ingress authority docs to match infra-core reality:
  - spine: `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
  - spine: `docs/governance/INGRESS_AUTHORITY.md`

### Auth (Authentik)

Findings:
- Auth surfaces depend on non-interactive API health and correct placement of keys/tokens in secrets namespaces.

Remediation shipped:
- Health probes expanded for Authentik (safe URL checks).
- Manual verification remains required for full browser SSO flow (out of scope to automate).

### Monitoring

Findings:
- Health probes needed to cover infra-core stacks (Infisical, Vaultwarden, Pi-hole, Authentik) using safe unauthenticated endpoints where possible.

Remediation shipped:
- Expanded spine health binding:
  - spine: `ops/bindings/services.health.yaml`

### Dev Tools (Gitea)

Findings:
- Gitea deployment existed but the required operational secrets were not fully present in Infisical namespace bindings.
- App-level backup/restore procedure is not documented (see gaps).

Remediation shipped:
- Secrets namespace for Gitea fixed (see Secrets section).

### Bindings Alignment (SSH / Compose / Inventory)

Findings:
- docker.compose.targets.yaml contained at least one invalid compose target path.
- Device identity and SSH targets needed to include the dev-tools host and clarify vault rollback vs infra-core.

Remediation shipped:
- spine: `ops/bindings/docker.compose.targets.yaml`
- spine: `ops/bindings/ssh.targets.yaml`
- spine: `docs/governance/DEVICE_IDENTITY_SSOT.md`
- spine: `ops/bindings/secrets.inventory.yaml`
- spine: `ops/bindings/backup.inventory.yaml`

### VM-Infra Staged Compose SSOT (ops/staged)

Findings:
- Some infra-core stacks referenced by governance docs did not have a sanitized, repo-tracked staged source.

Remediation shipped:
- Added staged sources with `.env.example` (no values) and minimal READMEs:
  - spine: `ops/staged/cloudflared/`
  - spine: `ops/staged/pihole/`
  - spine: `ops/staged/secrets/` (Infisical)
  - spine: `ops/staged/vaultwarden/`

### Legacy Surface Quarantine

Findings:
- Legacy watcher script wrote to deprecated paths and relied on SSH alias behavior.

Remediation shipped:
- Quarantined the legacy watcher and removed it from closeout flow:
  - spine: `ops/legacy/agents/clerk-watcher.sh`

## Operational Gaps Logged

See spine: `ops/bindings/operational.gaps.yaml`

- Fixed during this audit: `GAP-OP-029` .. `GAP-OP-033`
- Remaining open: `GAP-OP-034` (app-level backup/restore procedures for Authentik + Gitea)

## Follow-Up Loops Suggested

1. Backup procedures: create and test app-level backup/restore runbooks for Authentik + Gitea (close `GAP-OP-034`).
2. Optional gate: promote `cloudflare.domain_routing.diff` into a regular drift gate once stability is confirmed across networks.
