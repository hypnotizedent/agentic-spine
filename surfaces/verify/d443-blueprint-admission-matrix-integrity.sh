#!/usr/bin/env bash
# D443 — blueprint-admission-matrix-integrity
# Ensures operator.blueprint.admission.yaml exists, entries carry required
# fields, and materialized entries have proof.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATRIX="$REPO_ROOT/ops/bindings/operator.blueprint.admission.yaml"
FAIL=0

if [[ ! -f "$MATRIX" ]]; then
  echo "FAIL D443: operator.blueprint.admission.yaml not found"
  exit 1
fi

REQUIRED_FIELDS=(id source_ref operator_intent_class layer decision status claim_type)

entry_count=$(yq '.entries | length' "$MATRIX")
if [[ "$entry_count" -eq 0 ]]; then
  echo "FAIL D443: admission matrix has zero entries"
  exit 1
fi

for i in $(seq 0 $((entry_count - 1))); do
  eid=$(yq ".entries[$i].id" "$MATRIX")
  for field in "${REQUIRED_FIELDS[@]}"; do
    val=$(yq ".entries[$i].$field" "$MATRIX")
    if [[ "$val" == "null" || -z "$val" ]]; then
      echo "FAIL D443: entry $eid missing required field: $field"
      FAIL=1
    fi
  done

  decision=$(yq ".entries[$i].decision" "$MATRIX")
  if [[ "$decision" == "materialize" ]]; then
    authority=$(yq ".entries[$i].materialization_target.authority" "$MATRIX")
    proof=$(yq ".entries[$i].materialization_target.proof" "$MATRIX")
    if [[ "$authority" == "null" || -z "$authority" ]]; then
      echo "FAIL D443: materialized entry $eid missing materialization_target.authority"
      FAIL=1
    fi
    if [[ "$proof" == "null" || -z "$proof" ]]; then
      echo "FAIL D443: materialized entry $eid missing materialization_target.proof"
      FAIL=1
    fi
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  exit 1
fi

python3 - "$REPO_ROOT" <<'PY' || exit 1
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
status_bin = root / "ops/plugins/core/lifecycle/bin/blueprint-admission-status"
proc = subprocess.run([sys.executable, str(status_bin), "--l3-proof-tranche", "--json"], text=True, capture_output=True)
if proc.returncode != 0:
    print(proc.stderr.strip() or proc.stdout.strip(), file=sys.stderr)
    raise SystemExit(1)
payload = json.loads(proc.stdout)
summary = payload.get("summary") or {}
if summary.get("subjects") != 3:
    print("FAIL D443: L3 proof tranche must cover travel, health, and investment", file=sys.stderr)
    raise SystemExit(1)
if summary.get("ready_for_governed_spec_readback") != 3:
    print("FAIL D443: L3 proof tranche subjects must all have v1 bases present", file=sys.stderr)
    raise SystemExit(1)
if summary.get("old_l3_cleanup_excluded") is not True:
    print("FAIL D443: L3 proof tranche must exclude old L3 cleanup", file=sys.stderr)
    raise SystemExit(1)
PY

echo "OK D443: blueprint admission matrix valid ($entry_count entries)"
