#!/usr/bin/env bash
# TRIAGE: Add birth_mode to the offending label in launchd.scheduler.registry.yaml.
#         Valid modes: standing_program, exception_only, migration_project, human_session_only.
#         Parked labels must use classify_on_promotion.
set -euo pipefail

# D430: Scheduler Birth Mode Truth
# Enforces that every label in the scheduler registry has a valid birth_mode
# and that the combination of state + birth_mode + intended_node_role is honest.
#
# Authority sources:
#   - ops/bindings/launchd.scheduler.registry.yaml
#   - ops/bindings/launchd.runtime.contract.yaml (birth_mode_vocabulary)

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="${SPINE_REPO}/ops/bindings/launchd.scheduler.registry.yaml"

fail() { echo "D430 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need yq
need jq

[[ -f "$REGISTRY" ]] || fail "scheduler registry not found: $REGISTRY"

VALID_BIRTH_MODES="standing_program exception_only migration_project human_session_only classify_on_promotion"
VIOLATIONS=()

labels_json=$(yq e -o=json '.labels' "$REGISTRY" 2>/dev/null)
count=$(echo "$labels_json" | jq 'length')

for i in $(seq 0 $((count - 1))); do
  label=$(echo "$labels_json" | jq -r ".[$i].label")
  state=$(echo "$labels_json" | jq -r ".[$i].state")
  birth_mode=$(echo "$labels_json" | jq -r ".[$i].birth_mode // \"\"")
  intended_role=$(echo "$labels_json" | jq -r ".[$i].intended_node_role // \"\"")
  launchd_loaded=$(echo "$labels_json" | jq -r ".[$i].operator_console_launchd_loaded // \"null\"")

  # Check 1: birth_mode must exist
  if [[ -z "$birth_mode" ]]; then
    VIOLATIONS+=("$label: missing birth_mode")
    continue
  fi

  # Check 2: birth_mode must be valid
  valid=false
  for m in $VALID_BIRTH_MODES; do
    [[ "$birth_mode" == "$m" ]] && valid=true
  done
  if ! $valid; then
    VIOLATIONS+=("$label: invalid birth_mode '$birth_mode'")
    continue
  fi

  # Check 3: parked labels must use classify_on_promotion
  if [[ "$state" == "parked" && "$birth_mode" != "classify_on_promotion" ]]; then
    VIOLATIONS+=("$label: parked label must use birth_mode=classify_on_promotion, got '$birth_mode'")
  fi

  # Check 4: classify_on_promotion only valid for parked labels
  if [[ "$birth_mode" == "classify_on_promotion" && "$state" != "parked" ]]; then
    VIOLATIONS+=("$label: birth_mode=classify_on_promotion only valid for parked labels, state='$state'")
  fi

  # Check 5: active + human_session_only is illegal (must use suspended)
  if [[ "$state" == "active" && "$birth_mode" == "human_session_only" ]]; then
    VIOLATIONS+=("$label: state=active + birth_mode=human_session_only is illegal (use state=suspended)")
  fi

  # Check 6: human_session_only must target operator_console
  if [[ "$birth_mode" == "human_session_only" && "$intended_role" != "operator_console" ]]; then
    VIOLATIONS+=("$label: birth_mode=human_session_only requires intended_node_role=operator_console, got '$intended_role'")
  fi

  # Check 7: standing_program on operator_console with launchd unloaded is contradictory
  if [[ "$birth_mode" == "standing_program" && "$intended_role" == "operator_console" && "$launchd_loaded" == "false" ]]; then
    VIOLATIONS+=("$label: birth_mode=standing_program on operator_console with launchd_loaded=false — no scheduler behind this label")
  fi

  # Check 8: suspended + standing_program is contradictory
  if [[ "$state" == "suspended" && "$birth_mode" == "standing_program" ]]; then
    VIOLATIONS+=("$label: state=suspended + birth_mode=standing_program is contradictory — standing programs must be active")
  fi
done

# Cross-check: contract lists must not reference parked/suspended labels
CONTRACT="${SPINE_REPO}/ops/bindings/launchd.runtime.contract.yaml"
if [[ -f "$CONTRACT" ]]; then
  # Build lookup of non-active labels (parked or suspended)
  non_active_labels=""
  for i in $(seq 0 $((count - 1))); do
    state=$(echo "$labels_json" | jq -r ".[$i].state")
    if [[ "$state" == "parked" || "$state" == "suspended" ]]; then
      label=$(echo "$labels_json" | jq -r ".[$i].label")
      non_active_labels="${non_active_labels} ${label}"
    fi
  done

  # Check scheduler_execution.labels
  sched_labels=$(yq e -o=json '.scheduler_execution.labels // []' "$CONTRACT" 2>/dev/null)
  sched_count=$(echo "$sched_labels" | jq 'length')
  for i in $(seq 0 $((sched_count - 1))); do
    sl=$(echo "$sched_labels" | jq -r ".[$i]")
    for na in $non_active_labels; do
      if [[ "$sl" == "$na" ]]; then
        VIOLATIONS+=("contract drift: $sl in scheduler_execution.labels but registry state is parked/suspended")
      fi
    done
  done

  # Check required_labels.labels
  req_labels=$(yq e -o=json '.required_labels.labels // []' "$CONTRACT" 2>/dev/null)
  req_count=$(echo "$req_labels" | jq 'length')
  for i in $(seq 0 $((req_count - 1))); do
    rl=$(echo "$req_labels" | jq -r ".[$i]")
    for na in $non_active_labels; do
      if [[ "$rl" == "$na" ]]; then
        VIOLATIONS+=("contract drift: $rl in required_labels but registry state is parked/suspended")
      fi
    done
  done
fi

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo "D430 FAIL: ${#VIOLATIONS[@]} birth-mode truth violation(s):" >&2
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v" >&2
  done
  exit 1
fi

echo "D430 PASS: $count labels, all birth-mode truth checks passed"
