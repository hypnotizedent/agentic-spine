#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
COMPANION="$ROOT/ops/bindings/governed.change.lifecycle.contract.yaml"
SELF_GOV="$ROOT/ops/bindings/spine.self-governance.lifecycle.contract.yaml"

python3 - "$COMPANION" "$SELF_GOV" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

companion_path = Path(sys.argv[1])
self_gov_path = Path(sys.argv[2])

companion = yaml.safe_load(companion_path.read_text(encoding="utf-8"))
self_gov = yaml.safe_load(self_gov_path.read_text(encoding="utf-8"))

expected_stage_order = [
    "gap_identified",
    "discovery",
    "decision",
    "election",
    "implementation_authorized",
    "implementation_active",
    "implementation_landed",
    "verification",
    "closed",
]
expected_change_classes = {"new_truth", "ordinary_fix", "emergency_repair"}
expected_retirement_routes = {
    "active_to_transitional",
    "transitional_to_superseded",
    "superseded_to_tombstoned",
    "tombstoned_to_purge_eligible",
}

assert companion["contract"] == "GOVERNED_CHANGE_LIFECYCLE_CONTRACT_V1"
assert self_gov["change_classification"]["field"] == "change_class"
assert set(self_gov["change_classification"]["allowed_values"].keys()) == expected_change_classes
assert self_gov["change_classification"]["change_process_authority"]["contract"] == "ops/bindings/governed.change.lifecycle.contract.yaml"

related = self_gov.get("related_contracts") or []
assert any(row.get("contract") == "ops/bindings/governed.change.lifecycle.contract.yaml" for row in related)

assert companion["authority_chain"]["surface_maturity_authority"] == "ops/bindings/spine.self-governance.lifecycle.contract.yaml"
assert companion["route_rules"]["route_selector"]["contract"] == "ops/bindings/spine.self-governance.lifecycle.contract.yaml"
assert companion["route_rules"]["route_selector"]["field"] == "change_class"

assert companion["stage_model"]["stage_order"] == expected_stage_order
stages = companion["stage_model"]["stages"]
assert set(stages.keys()) == set(expected_stage_order)
for stage_name in expected_stage_order:
    stage = stages[stage_name]
    assert stage["entry_evidence"], stage_name
    assert stage["exit_evidence"], stage_name

route_classes = companion["route_rules"]["classes"]
assert set(route_classes.keys()) == expected_change_classes
assert route_classes["ordinary_fix"]["collapsed_path"] == [
    "gap_identified",
    "implementation_active",
    "implementation_landed",
    "verification",
    "closed",
]
assert route_classes["emergency_repair"]["allowed_early_entry"] == "implementation_active"
assert route_classes["emergency_repair"]["post_hoc_reconciliation"]["required_checks"]

metabolism = companion["metabolism_route_semantics"]
assert set(metabolism["retirement_oriented_maturity_transitions"]) == expected_retirement_routes
assert metabolism["required_change_process_evidence"]
assert "This contract does not redefine or duplicate surface maturity states." in metabolism["explicit_non_goal"]

print("PASS: companion contract exists")
print("PASS: stage model is codified in companion contract")
print("PASS: change_class remains the route selector")
print("PASS: surface maturity remains separate")
print("PASS: metabolism route semantics are present without an audit payload")
PY
