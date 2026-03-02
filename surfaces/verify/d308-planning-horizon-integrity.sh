#!/usr/bin/env bash
# TRIAGE: Ensure all open loop scopes have valid horizon/readiness fields per planning.horizon.contract.yaml. Fix by running planning.horizon.set for loops with missing or invalid values.
set -euo pipefail

ROOT="${SPINE_REPO:-$HOME/code/agentic-spine}"
SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"
CONTRACT="$ROOT/ops/bindings/planning.horizon.contract.yaml"

GATE_ID="D308"
FAIL=0
MESSAGES=""

# Validate contract exists
if [[ ! -f "$CONTRACT" ]]; then
  echo "${GATE_ID} FAIL: planning.horizon.contract.yaml not found" >&2
  exit 1
fi

if [[ ! -d "$SCOPES_DIR" ]]; then
  echo "${GATE_ID} PASS: no scopes directory" >&2
  exit 0
fi

_fm_field() {
  local file="$1" field="$2"
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file" \
    | { grep "^${field}:" || true; } \
    | sed "s/^${field}: *//" \
    | tr -d '"' \
    | head -1
}

VALID_HORIZONS="now later future"
VALID_READINESS="runnable blocked"
VALID_TRIGGERS="manual date dependency"

for scope_file in "$SCOPES_DIR"/*.scope.md; do
  [[ -f "$scope_file" ]] || continue

  status="$(_fm_field "$scope_file" "status")"
  # Only check open loops
  case "$status" in
    active|draft|open) ;;
    *) continue ;;
  esac

  loop_id="$(_fm_field "$scope_file" "loop_id")"
  [[ -z "$loop_id" ]] && continue

  horizon="$(_fm_field "$scope_file" "horizon")"
  readiness="$(_fm_field "$scope_file" "execution_readiness")"

  # Horizon: if present, must be valid; missing defaults to "now" (backward compat)
  if [[ -n "$horizon" ]]; then
    valid=false
    for v in $VALID_HORIZONS; do
      [[ "$horizon" == "$v" ]] && valid=true && break
    done
    if [[ "$valid" == "false" ]]; then
      FAIL=1
      MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: invalid horizon '${horizon}' (must be now|later|future)\n"
    fi
  fi

  # Boundary model: active loops must be horizon=now (later/future requires status=planned)
  if [[ "$status" == "active" && -n "$horizon" && "$horizon" != "now" ]]; then
    FAIL=1
    MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: status=active with horizon=${horizon} violates boundary model (use status=planned for deferred work)\n"
  fi

  # Readiness: if present, must be valid
  if [[ -n "$readiness" ]]; then
    valid=false
    for v in $VALID_READINESS; do
      [[ "$readiness" == "$v" ]] && valid=true && break
    done
    if [[ "$valid" == "false" ]]; then
      FAIL=1
      MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: invalid execution_readiness '${readiness}' (must be runnable|blocked)\n"
    fi
  fi

  # If horizon is later/future, activation_trigger should be set
  if [[ "$horizon" == "later" || "$horizon" == "future" ]]; then
    trigger="$(_fm_field "$scope_file" "activation_trigger")"
    if [[ -n "$trigger" ]]; then
      valid=false
      for v in $VALID_TRIGGERS; do
        [[ "$trigger" == "$v" ]] && valid=true && break
      done
      if [[ "$valid" == "false" ]]; then
        FAIL=1
        MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: invalid activation_trigger '${trigger}'\n"
      fi

      # Date trigger requires not_before_est
      if [[ "$trigger" == "date" ]]; then
        not_before="$(_fm_field "$scope_file" "not_before_est")"
        if [[ -z "$not_before" ]]; then
          FAIL=1
          MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: date trigger requires not_before_est\n"
        fi
      fi

      # Dependency trigger requires depends_on_loop
      if [[ "$trigger" == "dependency" ]]; then
        depends_on="$(_fm_field "$scope_file" "depends_on_loop")"
        if [[ -z "$depends_on" ]]; then
          FAIL=1
          MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: dependency trigger requires depends_on_loop\n"
        fi
      fi
    fi
  fi

  # Proposal eligibility: if readiness=blocked, must have blocked_by
  if [[ "$readiness" == "blocked" ]]; then
    blocked_by="$(_fm_field "$scope_file" "blocked_by")"
    if [[ -z "$blocked_by" || "$blocked_by" == "none" ]]; then
      FAIL=1
      MESSAGES="${MESSAGES}    ${GATE_ID} FAIL: ${loop_id}: execution_readiness=blocked but no blocked_by set\n"
    fi
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  printf '%b' "$MESSAGES" >&2
  echo "${GATE_ID} FAIL: planning horizon integrity violations detected" >&2
  exit 1
fi

echo "${GATE_ID} PASS: all open loop scopes have valid horizon/readiness fields" >&2
exit 0
