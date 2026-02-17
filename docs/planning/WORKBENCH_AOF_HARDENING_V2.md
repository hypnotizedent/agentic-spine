---
status: draft
owner: "@ronny"
last_verified: 2026-02-17
scope: workbench-aof-hardening-v2
parent_loop: LOOP-WORKBENCH-AOF-HARDENING-V2-20260217
---

# Workbench AOF Hardening (v2)

## Objective

Keep v1 normalization stable over time by hardening contracts, checker behavior, and operating procedures without adding new drift gates.

## Current Baseline (Locked)

1. Contract exists: `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml`
2. Checker exists and is clean: `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh` (`P0=0 P1=0 P2=0`)
3. Proposal preflight hook exists: `/Users/ronnyworks/code/agentic-spine/ops/plugins/proposals/bin/proposals-apply`
4. V1 cert exists: `/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_CERT_20260217.md`

## Non-Goals

1. No new drift gates.
2. No secret value rotation.
3. No legacy-doc full rewrite.

## Hardening Workstreams

### WS1 — Checker Determinism and Safety

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T1 | `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh` | Add deterministic file ordering and explicit scan-prune policy docs in script header. | `./scripts/root/aof/workbench-aof-check.sh --mode all --format json | jq '.summary'` stable across 2 consecutive runs. | Same findings/order for repeated runs. |
| V2-T2 | `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh` | Add strict `--changed-files` validation (error if non-existent path passed) to avoid false-pass preflight. | `./scripts/root/aof/workbench-aof-check.sh --mode all --changed-files does/not/exist` exits non-zero with clear error. | Invalid changed-file input cannot silently pass. |
| V2-T3 | `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh` | Add `--explain` output mode that prints each active rule and severity mapping from contract for operator clarity. | `./scripts/root/aof/workbench-aof-check.sh --mode all --format text --explain` includes docs/compose/secrets rule list. | Operators can inspect checker policy without reading source. |

### WS2 — Proposal Preflight Hardening

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T4 | `/Users/ronnyworks/code/agentic-spine/ops/plugins/proposals/bin/proposals-apply` | Fail fast if proposal references workbench but workbench root is unreachable; include remediation text. | Dry-run proposal with workbench path and missing root returns actionable error. | No ambiguous preflight failures. |
| V2-T5 | `/Users/ronnyworks/code/agentic-spine/ops/plugins/proposals/bin/proposals-apply` | Record checker preflight summary in apply output for audit readability. | Apply output includes `P0/P1/P2` summary line when workbench paths touched. | Proposal receipts show policy decision context. |
| V2-T6 | `/Users/ronnyworks/code/agentic-spine/docs/governance/PROPOSAL_FLOW_QUICKSTART.md` | Add one section: “Workbench preflight behavior” with fail/repair examples. | Manual read confirms section exists and commands match actual behavior. | Operators know exactly why an apply blocked. |

### WS3 — Contract Evolution and Ratchets

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T7 | `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml` | Add explicit `contract_version`, `effective_date`, `deprecated_alias_block_on` fields to make cutoff behavior machine-readable. | `yq e '.contract_version,.effective_date,.migration_window.deprecated_alias_block_on' infra/contracts/workbench.aof.contract.yaml` returns non-empty values. | Alias cutoff no longer implied by prose only. |
| V2-T8 | `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml` | Add `transitional_allowlist` section keyed by absolute path with expiration date to make exceptions explicit and temporary. | Checker warns when allowlist entry is expired. | Exceptions become time-bound and auditable. |
| V2-T9 | `/Users/ronnyworks/code/workbench/docs/infrastructure/WORKBENCH_AOF_BASELINE.md` | Add “Contract change protocol” and “How to request temporary exception.” | Doc includes protocol with required fields and expiry rule. | Contract mutations are standardized and predictable. |

### WS4 — Compose and Runtime Guardrail Expansion

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T10 | `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml` | Add canonical healthcheck policy profile (minimum retries/start_period defaults) by service class. | Checker `--explain` shows compose health policy. | Health patterns are consistently enforced as code policy. |
| V2-T11 | `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh` | Enforce compose service `restart` policy presence in active stacks. | Remove restart from one changed compose file => checker P1 fail. | New services cannot omit restart policy. |
| V2-T12 | `/Users/ronnyworks/code/workbench/docs/infrastructure/WORKBENCH_AOF_BASELINE.md` | Add compose “new service checklist” block (logging/limits/healthcheck/restart/ports). | Checklist present and referenced by proposal quickstart. | Agents use one predictable service-add process. |

### WS5 — Secrets Runway and Naming Completion

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T13 | `/Users/ronnyworks/code/workbench/scripts/agents/infisical-agent.sh` | Keep deprecated project reads blocked by default and add explicit telemetry marker when `--allow-deprecated-read` is used. | Run deprecated read with flag emits warning marker; without flag blocks. | Transitional usage is visible and controlled. |
| V2-T14 | `/Users/ronnyworks/code/workbench/infra/data/secrets_inventory.json` | Normalize any remaining deprecated key aliases in placeholder mappings and examples. | `rg -n 'FIREFLY_ACCESS_TOKEN|FIREFLY_TOKEN|HA_TOKEN|PAPERLESS_SECRET_KEY' infra/data/secrets_inventory.json` returns zero. | Inventory examples align with canonical keys only. |
| V2-T15 | `/Users/ronnyworks/code/workbench/docs/infrastructure/WORKBENCH_AOF_BASELINE.md` | Add single canonical secret naming table and project/path resolution examples. | Table includes `FIREFLY_PAT`, `PAPERLESS_API_TOKEN`, `HA_API_TOKEN` with canonical paths. | Agents stop inventing alternate key names. |

### WS6 — Operational Cadence and Certification

| Task | Files | Action | Verify | Done |
|---|---|---|---|---|
| V2-T16 | `/Users/ronnyworks/code/agentic-spine/docs/governance/TERMINAL_C_DAILY_RUNBOOK.md` | Add weekly “workbench AOF sweep” step using checker full mode + proposal status check. | Runbook contains exact commands and escalation path. | Hardening becomes routine, not ad hoc. |
| V2-T17 | `/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/WORKBENCH_AOF_HARDENING_V2_CERT_<YYYYMMDD>.md` | Define and publish v2 certification template. | Template includes run keys, checker summary, residual exceptions table. | Every hardening cycle produces comparable evidence. |
| V2-T18 | `/Users/ronnyworks/code/agentic-spine/mailroom/state/loop-scopes/LOOP-WORKBENCH-AOF-HARDENING-V2-20260217.scope.md` | Move loop status from `draft` to `active` only after T1-T3 pass on baseline branch. | Scope status updated with start date and owner confirmation. | Execution starts with checker foundation already validated. |

## Execution Order

1. WS1 (checker determinism)
2. WS2 (proposal preflight hardening)
3. WS3 (contract ratchets)
4. WS4 (compose guardrail expansion)
5. WS5 (secrets runway completion)
6. WS6 (cadence + cert)

## Certification Sequence (v2)

1. `./bin/ops cap run stability.control.snapshot`
2. `./bin/ops cap run verify.core.run`
3. `./bin/ops cap run verify.domain.run aof --force`
4. `cd /Users/ronnyworks/code/workbench && ./scripts/root/aof/workbench-aof-check.sh --mode all --format text`
5. `cd /Users/ronnyworks/code/agentic-spine && ./bin/ops cap run proposals.status`

## Acceptance Criteria

1. Proposal preflight reports clear checker results for workbench-targeted proposals.
2. Checker behavior is deterministic and explainable.
3. Contract has explicit version/cutoff/exception semantics.
4. Workbench canonical key naming remains clean (no deprecated aliases in active surfaces).
5. Weekly operating runbook includes workbench AOF sweep and escalation path.
6. V2 certification artifact published with run keys and residual risk table.
