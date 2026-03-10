# Mailroom Runtime Extraction Boundary Map

**Recommended runtime root:** `/Users/ronnyworks/code/.runtime/spine-mailroom`

## Keep In Spine

- `mailroom/README.md`
- `mailroom/.keep`
- `mailroom/state/LOOP_SSOT_README.md`
- Active governance state under `mailroom/state/loop-scopes/`, `mailroom/state/plans/`, and active packets in `mailroom/state/orchestration/`
- Declarative governance state such as `mailroom/state/gaps/`, `mailroom/state/planning-horizon/`, `mailroom/state/maintenance-windows/`, `mailroom/state/mailroom-boundary/`, `mailroom/state/policy-autotune/`, `mailroom/state/friction-baseline.yaml`, and `mailroom/state/path.claims.yaml`

## Move To Runtime Root

- `mailroom/inbox/**`
- `mailroom/logs/**`
- Non-proposal `mailroom/outbox/**`
- `mailroom/state/sessions/**`
- `mailroom/state/locks/**`
- `mailroom/state/loop-heartbeats/**`
- `mailroom/state/terminal-heartbeats/**`
- `mailroom/state/ledger.csv`
- `mailroom/state/*.pid`
- `mailroom/state/*.lock`
- `mailroom/state/*.queue`
- `mailroom/state/*.cursor`
- `mailroom/state/*token*`
- `mailroom/state/shared_authority.db`
- `mailroom/state/traffic.index.yaml`
- `mailroom/state/communications-escalation-cooldown.yaml`

## Move To Evidence Root

- `mailroom/outbox/proposals/**`
- Archived and superseded proposal material under `mailroom/outbox/proposals/.archived/**`
- Audit, proof, hardening, incident, and synthesis material currently sitting in `mailroom/state/`:
  `tailscale-audit/`, `vaultwarden-audit/`, `infra-core-audit/`, `paperless-backup-incident/`, `mailroom-overnight/`, `media-audit/`, `verify/`, `runtime-normalization/`, `rag-sync/`, `backup-canonicalization/`, `extension-transactions/`
- Root-level state evidence docs such as `SYNOLOGY_918_FORENSIC_AUDIT_RECEIPT_20260308.md`, `mint-postgres-restore-proof-20260308.md`, and closeout summaries

## Keep As Source But Extract Out Of Spine

- `mailroom/templates/**`

These are source templates, not runtime state. They fit the extracted foundation/runtime package, not the boring spine repo.

## Sequence

1. Freeze new tracked writes to `mailroom/inbox/`, `mailroom/logs/`, `mailroom/outbox/`, and runtime state files.
2. Bind runtime writers to `/Users/ronnyworks/code/.runtime/spine-mailroom`.
3. Move proposal and audit evidence to the evidence root.
4. Leave active loop scopes/plans/orchestration in spine until the governance contract is stable under the new runtime root.

