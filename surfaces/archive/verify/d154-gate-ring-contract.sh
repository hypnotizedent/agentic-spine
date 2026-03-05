#!/usr/bin/env bash
# TRIAGE: Reconcile verify.ring.policy.yaml and gate.registry ring assignments.
# D154: gate ring contract
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/verify.ring.policy.yaml"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D154 FAIL: $*" >&2
  exit 1
}

[[ -f "$POLICY" ]] || fail "missing policy file: $POLICY"
[[ -f "$REGISTRY" ]] || fail "missing gate registry: $REGISTRY"
[[ -f "$TOPOLOGY" ]] || fail "missing gate topology: $TOPOLOGY"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$POLICY" "$REGISTRY" "$TOPOLOGY" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

policy_path = Path(sys.argv[1])
registry_path = Path(sys.argv[2])
topology_path = Path(sys.argv[3])


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


errors: list[str] = []

try:
    policy = load_yaml(policy_path)
except Exception as exc:
    print(f"D154 FAIL: policy parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_rings = {"instant", "standard", "deep"}
rings_raw = policy.get("rings")
if not isinstance(rings_raw, list):
    errors.append("policy.rings must be a list")
    rings = set()
else:
    rings = {str(v).strip() for v in rings_raw if str(v).strip()}
    if rings != required_rings:
        errors.append(f"policy.rings must be exactly {sorted(required_rings)} (got {sorted(rings)})")

budgets = policy.get("budgets_seconds")
if not isinstance(budgets, dict):
    errors.append("policy.budgets_seconds must be a map")
else:
    for ring, expected in {"instant": 5, "standard": 60, "deep": 300}.items():
        value = budgets.get(ring)
        if value != expected:
            errors.append(f"policy.budgets_seconds.{ring} must be {expected} (got {value})")

assignment = policy.get("assignment_policy")
if not isinstance(assignment, dict):
    errors.append("policy.assignment_policy must be a map")
else:
    required_assignment = {
        "core_gates": "instant",
        "domain_pack_gates": "standard",
        "release_only_or_non_pack_active_gates": "deep",
    }
    for key, expected in required_assignment.items():
        value = assignment.get(key)
        if value != expected:
            errors.append(f"policy.assignment_policy.{key} must be '{expected}' (got '{value}')")

registry = load_yaml(registry_path)
topology = load_yaml(topology_path)

gates = registry.get("gates")
if not isinstance(gates, list):
    errors.append("gate.registry gates must be a list")
    gates = []

core_gate_ids = topology.get("core_mode", {}).get("core_gate_ids") or []
if not isinstance(core_gate_ids, list):
    errors.append("gate.execution.topology core_mode.core_gate_ids must be a list")
    core_gate_ids = []
core_gate_set = {str(gid).strip() for gid in core_gate_ids if str(gid).strip()}

allowed_ring_values = {"instant", "standard", "deep"}
seen: set[str] = set()
active_by_id: dict[str, dict] = {}
active_count = 0

for gate in gates:
    if not isinstance(gate, dict):
        continue

    gid = str(gate.get("id", "")).strip()
    if not gid:
        errors.append("gate entry missing id")
        continue

    if gid in seen:
        errors.append(f"duplicate gate id: {gid}")
        continue
    seen.add(gid)

    retired = bool(gate.get("retired", False))
    ring = gate.get("ring")

    if retired:
        # Retired gates are intentionally excluded from required ring coverage.
        continue

    active_count += 1
    active_by_id[gid] = gate

    if ring in (None, ""):
        errors.append(f"{gid}: active gate missing ring")
        continue

    ring_value = str(ring).strip()
    if ring_value not in allowed_ring_values:
        errors.append(f"{gid}: ring must be one of {sorted(allowed_ring_values)} (got '{ring_value}')")

for gid in sorted(core_gate_set):
    gate = active_by_id.get(gid)
    if gate is None:
        errors.append(f"{gid}: core gate id missing from active gate registry")
        continue
    ring_value = str(gate.get("ring", "")).strip()
    if ring_value != "instant":
        errors.append(f"{gid}: core gate ring must be instant (got '{ring_value or 'missing'}')")

if errors:
    for err in errors:
        print(f"  FAIL: {err}", file=sys.stderr)
    print(f"D154 FAIL: gate ring contract violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D154 PASS: gate ring contract valid (active={active_count} core={len(core_gate_set)})")
PY
