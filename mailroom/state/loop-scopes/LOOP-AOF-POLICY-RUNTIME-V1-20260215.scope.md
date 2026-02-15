---
loop_id: LOOP-AOF-POLICY-RUNTIME-V1-20260215
created: 2026-02-15
status: closed
severity: medium
owner: "@ronny"
scope: agentic-spine
objective: Wire Phase A policy knobs (drift_gate_mode, warn_policy, approval_default, session_closeout_sla_hours) from policy.presets.yaml into drift-gate.sh and cap.sh
---

# Loop Scope: AOF Policy Runtime Integration (Phase A)

## Problem Statement

AOF v0.1 foundation defines 3 policy presets with 10 knobs each in
`ops/bindings/policy.presets.yaml`, but these knobs are defined-not-consumed.
drift-gate.sh, cap.sh, and D61 all use hardcoded defaults. Selecting a preset
has no runtime effect.

## Deliverables

1. **Shared policy resolver** - `ops/lib/resolve-policy.sh` (new)
2. **drift-gate.sh wiring** - source resolver, wire drift_gate_mode + warn_policy + session_closeout_sla_hours
3. **cap.sh wiring** - source resolver, wire approval_default, display preset in banner

## Child Gaps

- GAP-OP-343: Shared policy resolution helper missing
- GAP-OP-344: Drift gates not wired to policy presets
- GAP-OP-345: Capability runner not wired to approval_default

## Constraints

- No behavioral change without explicit preset selection (backward compatible)
- resolve-policy.sh must not fail fatally — always falls back to balanced defaults
- D61 script itself is NOT modified (already parameterized via env var)
