#!/usr/bin/env bash
# TRIAGE: Add proof_channel to the offending label in launchd.scheduler.registry.yaml.
#         Required fields: type (cycle_state|heartbeat|runtime_telemetry|systemd_journal),
#         stale_threshold_seconds (positive integer).
set -euo pipefail

# D431: Standing Program Proof Channel
# Enforces that every active standing_program has a declared proof_channel
# with valid type and stale threshold.
#
# Authority: ops/bindings/launchd.scheduler.registry.yaml

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="${SPINE_REPO}/ops/bindings/launchd.scheduler.registry.yaml"

fail() { echo "D431 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need yq
need jq

[[ -f "$REGISTRY" ]] || fail "scheduler registry not found: $REGISTRY"

VALID_PROOF_TYPES="cycle_state heartbeat runtime_telemetry systemd_journal"
VIOLATIONS=()
STANDING_COUNT=0

labels_json=$(yq e -o=json '.labels' "$REGISTRY" 2>/dev/null)
count=$(echo "$labels_json" | jq 'length')

for i in $(seq 0 $((count - 1))); do
  label=$(echo "$labels_json" | jq -r ".[$i].label")
  state=$(echo "$labels_json" | jq -r ".[$i].state")
  birth_mode=$(echo "$labels_json" | jq -r ".[$i].birth_mode // \"\"")

  # Only check active standing_program labels
  [[ "$state" == "active" && "$birth_mode" == "standing_program" ]] || continue

  STANDING_COUNT=$((STANDING_COUNT + 1))

  # Check 1: proof_channel must exist
  has_proof_channel=$(echo "$labels_json" | jq -r ".[$i].proof_channel // \"\"")
  if [[ -z "$has_proof_channel" || "$has_proof_channel" == "" ]]; then
    VIOLATIONS+=("$label: missing proof_channel")
    continue
  fi

  # Check 2: proof_channel.type must exist and be valid
  proof_type=$(echo "$labels_json" | jq -r ".[$i].proof_channel.type // \"\"")
  if [[ -z "$proof_type" ]]; then
    VIOLATIONS+=("$label: proof_channel missing type")
    continue
  fi

  valid=false
  for t in $VALID_PROOF_TYPES; do
    [[ "$proof_type" == "$t" ]] && valid=true
  done
  if ! $valid; then
    VIOLATIONS+=("$label: proof_channel.type '$proof_type' not in ($VALID_PROOF_TYPES)")
    continue
  fi

  # Check 3: proof_channel.stale_threshold_seconds must be a positive number
  stale_threshold=$(echo "$labels_json" | jq -r ".[$i].proof_channel.stale_threshold_seconds // \"\"")
  if [[ -z "$stale_threshold" ]]; then
    VIOLATIONS+=("$label: proof_channel missing stale_threshold_seconds")
    continue
  fi

  if ! [[ "$stale_threshold" =~ ^[0-9]+$ ]] || [[ "$stale_threshold" -le 0 ]]; then
    VIOLATIONS+=("$label: proof_channel.stale_threshold_seconds must be a positive number, got '$stale_threshold'")
  fi
done

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo "D431 FAIL: ${#VIOLATIONS[@]} proof-channel violation(s):" >&2
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v" >&2
  done
  exit 1
fi

echo "D431 PASS: $STANDING_COUNT standing programs, all proof channels declared"
