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

echo "OK D443: blueprint admission matrix valid ($entry_count entries)"
