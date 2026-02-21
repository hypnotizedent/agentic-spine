---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: aof-policy-runtime-enforcement
---

# AOF Policy Runtime Enforcement

> Declares how policy preset knobs are enforced at runtime.

## Policy Knobs

AOF defines 10 policy knobs in `ops/bindings/policy.presets.yaml`. Each knob must have a runtime enforcement point.

| Knob | Enforcement Point | Wired | Step |
|------|------------------|-------|-------|
| `drift_gate_mode` | drift-gate.sh | Yes | A |
| `approval_default` | cap.sh | Yes | A |
| `session_closeout_sla_hours` | drift-gate.sh (D61) | Yes | A |
| `warn_policy` | drift-gate.sh | Yes | A |
| `stale_ssot_max_days` | drift-gate.sh (D58) | Yes | B |
| `gap_auto_claim` | gaps-file | Yes | B |
| `proposal_required` | cap.sh | Yes | B |
| `receipt_retention_days` | evidence.export.plan | Yes | B |
| `commit_sign_required` | pre-commit hook | Yes | B |
| `multi_agent_writes` | cap.sh + pre-commit hook | Yes | B |

## Step A (Complete)

4 knobs wired through `ops/lib/resolve-policy.sh`:
- Discovery chain: `SPINE_POLICY_PRESET` > `SPINE_TENANT_PROFILE` > `tenant.profile.yaml` > `balanced`
- Runtime reads preset, exports knob values as environment variables
- `drift-gate.sh` and `cap.sh` consume these variables

## Step B (Complete)

6 remaining knobs wired through the same `resolve-policy.sh` resolver:
- `stale_ssot_max_days` → D58 `SSOT_FRESHNESS_DAYS` threshold override
- `gap_auto_claim` → `gaps-file` auto-claims after filing when `true`
- `proposal_required` → `cap.sh` blocks mutating caps when `true`
- `receipt_retention_days` → `evidence-export-plan` overrides session receipt retention
- `commit_sign_required` → `.githooks/pre-commit` blocks unsigned commits when `true`
- `multi_agent_writes` → `cap.sh` + `.githooks/pre-commit` blocks direct writes when `proposal-only`

## Enforcement

- **Binding**: `ops/bindings/policy.runtime.contract.yaml`
- **Gate**: D94 (policy-runtime-enforcement-lock)
- **Capability**: `policy.runtime.audit` (read-only enforcement status + policy source fingerprint + recent git-backed policy change history)
