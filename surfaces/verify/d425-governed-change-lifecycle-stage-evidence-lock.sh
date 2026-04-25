#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      echo "Validates governed change lifecycle contract contains stage evidence durability requirements." >&2
      exit 0
      ;;
    *)
      echo "D425 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

CONTRACT="$ROOT/ops/bindings/governed.change.lifecycle.contract.yaml"
[[ -f "$CONTRACT" ]] || {
  echo "D425 FAIL: lifecycle contract not found at $CONTRACT" >&2
  exit 1
}

python3 - "$CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

contract = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))
stage_model = contract.get("stage_model")
if not stage_model:
    raise SystemExit("D425 FAIL: stage_model missing from contract")

durability = stage_model.get("stage_evidence_durability")
if durability is None:
    raise SystemExit("D425 FAIL: stage_evidence_durability section missing from stage_model")

durable = durability.get("durable_locations")
if not durable or not isinstance(durable, list):
    raise SystemExit("D425 FAIL: stage_evidence_durability.durable_locations missing or empty")

non_durable = durability.get("non_durable_locations")
if not non_durable or not isinstance(non_durable, list):
    raise SystemExit("D425 FAIL: stage_evidence_durability.non_durable_locations missing or empty")

if not any(".runtime" in loc for loc in non_durable):
    raise SystemExit("D425 FAIL: .runtime not listed in non_durable_locations")

stages = stage_model.get("stages", {})
for stage_name in ("discovery", "decision", "election"):
    exit_ev = stages.get(stage_name, {}).get("exit_evidence", [])
    if not any("durable" in ev for ev in exit_ev):
        raise SystemExit(f"D425 FAIL: {stage_name} exit_evidence does not require durable persistence")

new_truth = contract.get("route_rules", {}).get("classes", {}).get("new_truth", {})
note = new_truth.get("stage_evidence_note", "")
if "not implementation mutations" not in note:
    raise SystemExit("D425 FAIL: new_truth stage_evidence_note missing or incomplete")

print("D425 PASS: stage evidence durability requirements enforced in lifecycle contract")
PY
