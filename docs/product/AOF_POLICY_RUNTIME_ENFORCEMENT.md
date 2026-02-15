---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: aof-policy-runtime-enforcement
---

# AOF Policy Runtime Enforcement

> Declares how policy preset knobs are enforced at runtime.

## Policy Knobs

AOF defines 10 policy knobs in `ops/bindings/policy.presets.yaml`. Each knob must have a runtime enforcement point.

| Knob | Enforcement Point | Wired | Phase |
|------|------------------|-------|-------|
| `drift_gate_mode` | drift-gate.sh | Yes | A |
| `approval_default` | cap.sh | Yes | A |
| `session_closeout_sla_hours` | drift-gate.sh (D61) | Yes | A |
| `warn_policy` | drift-gate.sh | Yes | A |
| `stale_ssot_max_days` | drift-gate.sh | No | B |
| `gap_auto_claim` | gaps.sh | No | B |
| `proposal_required` | cap.sh | No | B |
| `receipt_retention_days` | evidence.export | No | B |
| `commit_sign_required` | pre-commit hook | No | B |
| `multi_agent_writes` | cap.sh | No | B |

## Phase A (Current)

4 knobs are wired through `ops/lib/resolve-policy.sh`:
- Discovery chain: `SPINE_POLICY_PRESET` > `SPINE_TENANT_PROFILE` > `tenant.profile.yaml` > `balanced`
- Runtime reads preset, exports knob values as environment variables
- `drift-gate.sh` and `cap.sh` consume these variables

## Phase B (Planned)

Remaining 6 knobs need enforcement wiring at their respective enforcement points.

## Enforcement

- **Binding**: `ops/bindings/policy.runtime.contract.yaml`
- **Gate**: D94 (policy-runtime-enforcement-lock)
- **Capability**: `policy.runtime.audit` (read-only enforcement status report)
