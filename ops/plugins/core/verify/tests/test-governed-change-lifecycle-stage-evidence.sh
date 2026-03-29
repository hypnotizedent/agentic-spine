#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/governed.change.lifecycle.contract.yaml"

python3 - "$CONTRACT" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

contract_path = Path(sys.argv[1])
contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))

stage_model = contract["stage_model"]

# 1. stage_evidence_durability section exists
durability = stage_model.get("stage_evidence_durability")
if durability is None:
    raise SystemExit("stage_evidence_durability section missing from stage_model")

# 2. durable_locations list exists and is non-empty
durable = durability.get("durable_locations")
if not durable or not isinstance(durable, list):
    raise SystemExit("stage_evidence_durability.durable_locations missing or empty")

# 3. non_durable_locations list exists and is non-empty
non_durable = durability.get("non_durable_locations")
if not non_durable or not isinstance(non_durable, list):
    raise SystemExit("stage_evidence_durability.non_durable_locations missing or empty")

# 4. .runtime is classified as non-durable
runtime_mentioned = any(".runtime" in loc for loc in non_durable)
if not runtime_mentioned:
    raise SystemExit(".runtime not listed in non_durable_locations")

# 5. discovery/decision/election exit evidence requires durable paths
stages = stage_model["stages"]
for stage_name in ("discovery", "decision", "election"):
    exit_ev = stages[stage_name]["exit_evidence"]
    joined = " ".join(exit_ev)
    if "durable" not in joined:
        raise SystemExit(f"{stage_name} exit_evidence does not require durable persistence")

# 6. new_truth stage_evidence_note exists
new_truth = contract["route_rules"]["classes"]["new_truth"]
note = new_truth.get("stage_evidence_note", "")
if "not implementation mutations" not in note:
    raise SystemExit("new_truth stage_evidence_note missing or incomplete")

print("PASS: stage_evidence_durability section exists")
print("PASS: durable and non-durable locations are explicitly listed")
print("PASS: .runtime classified as non-durable")
print("PASS: discovery/decision/election exit evidence requires durable paths")
print("PASS: new_truth stage_evidence_note clarifies mutation boundary")
PY
