#!/usr/bin/env bash
# TRIAGE: Communications queue pipeline V1-V6 integrity: required capabilities, contracts, safety/approval invariants, alerting channel guard.
# D292: Communications queue pipeline lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAPS_FILE="$ROOT/ops/capabilities.yaml"
violations=0

fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "D292 FAIL: missing command: $1" >&2; exit 1; }
}

need_cmd yq

[[ -f "$CAPS_FILE" ]] || { echo "D292 FAIL: capabilities.yaml not found" >&2; exit 1; }

# ─── Check 1: Required capabilities exist ────────────────────────────────
required_caps=(
  "communications.alerts.dispatcher.start"
  "communications.alerts.dispatcher.status"
  "communications.alerts.dispatcher.stop"
  "communications.alerts.deadletter.replay"
  "communications.alerts.queue.status"
  "communications.alerts.queue.slo.status"
  "communications.alerts.runtime.status"
  "communications.alerts.queue.escalate"
  "communications.alerts.flush"
  "communications.alerts.incident.bundle.create"
)

for cap in "${required_caps[@]}"; do
  exists="$(yq e ".capabilities.\"${cap}\".command" "$CAPS_FILE" 2>/dev/null || echo "")"
  if [[ -z "$exists" || "$exists" == "null" ]]; then
    fail_v "required capability missing: $cap"
  fi
done

# ─── Check 2: Required contracts exist ───────────────────────────────────
required_contracts=(
  "$ROOT/ops/bindings/communications.alerts.queue.contract.yaml"
  "$ROOT/ops/bindings/communications.alerts.escalation.contract.yaml"
)

for contract in "${required_contracts[@]}"; do
  if [[ ! -f "$contract" ]]; then
    fail_v "required contract missing: $(basename "$contract")"
  fi
done

# ─── Check 3: Safety/approval invariants ────────────────────────────────
# Read-only + auto caps
readonly_auto_caps=(
  "communications.alerts.dispatcher.status"
  "communications.alerts.queue.status"
  "communications.alerts.queue.slo.status"
  "communications.alerts.runtime.status"
  "communications.alerts.incident.bundle.create"
)

for cap in "${readonly_auto_caps[@]}"; do
  safety="$(yq e ".capabilities.\"${cap}\".safety" "$CAPS_FILE" 2>/dev/null || echo "")"
  approval="$(yq e ".capabilities.\"${cap}\".approval" "$CAPS_FILE" 2>/dev/null || echo "")"
  if [[ "$safety" != "read-only" ]]; then
    fail_v "$cap safety must be read-only (got: $safety)"
  fi
  if [[ "$approval" != "auto" ]]; then
    fail_v "$cap approval must be auto (got: $approval)"
  fi
done

# Mutating + manual caps
mutating_manual_caps=(
  "communications.alerts.flush"
  "communications.alerts.dispatcher.start"
  "communications.alerts.dispatcher.stop"
  "communications.alerts.deadletter.replay"
  "communications.alerts.queue.escalate"
)

for cap in "${mutating_manual_caps[@]}"; do
  safety="$(yq e ".capabilities.\"${cap}\".safety" "$CAPS_FILE" 2>/dev/null || echo "")"
  approval="$(yq e ".capabilities.\"${cap}\".approval" "$CAPS_FILE" 2>/dev/null || echo "")"
  if [[ "$safety" != "mutating" ]]; then
    fail_v "$cap safety must be mutating (got: $safety)"
  fi
  if [[ "$approval" != "manual" ]]; then
    fail_v "$cap approval must be manual (got: $approval)"
  fi
done

# ─── Check 4: Alerting channel guard ────────────────────────────────────
# The alerting.dispatch capability (if it exists) must NOT have direct provider
# dispatch (Resend/Twilio API calls) in its command chain. It writes intents only.
# We verify this by ensuring queue dispatch surfaces do not force global
# secrets-exec wrappers (scoped provider secret resolution happens inside
# communications execution scripts).
alerting_dispatch_cmd="$(yq e '.capabilities."alerting.dispatch".command // ""' "$CAPS_FILE" 2>/dev/null || echo "")"
if [[ -n "$alerting_dispatch_cmd" && "$alerting_dispatch_cmd" != "null" ]]; then
  # alerting.dispatch must NOT contain secrets-exec (intent-only model)
  if echo "$alerting_dispatch_cmd" | grep -q "secrets-exec"; then
    fail_v "alerting.dispatch command contains secrets-exec (must be intent-only, no direct provider dispatch)"
  fi
fi

# communications.alerts.flush MUST NOT use secrets-exec (precondition scope is
# communications-critical routes/secrets, not global namespace health).
flush_cmd="$(yq e '.capabilities."communications.alerts.flush".command // ""' "$CAPS_FILE" 2>/dev/null || echo "")"
if [[ -n "$flush_cmd" && "$flush_cmd" != "null" ]]; then
  if echo "$flush_cmd" | grep -q "secrets-exec"; then
    fail_v "communications.alerts.flush command must not use secrets-exec (must avoid broad namespace coupling)"
  fi
fi

send_exec_cmd="$(yq e '.capabilities."communications.send.execute".command // ""' "$CAPS_FILE" 2>/dev/null || echo "")"
if [[ -n "$send_exec_cmd" && "$send_exec_cmd" != "null" ]]; then
  if echo "$send_exec_cmd" | grep -q "secrets-exec"; then
    fail_v "communications.send.execute command must not use secrets-exec wrapper"
  fi
fi

# ─── Check 5: Implementation scripts exist and are executable ────────────
cap_scripts=(
  "$ROOT/ops/plugins/communications/bin/communications-alerts-dispatcher-start"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-dispatcher-status"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-dispatcher-stop"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-deadletter-replay"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-queue-status"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-queue-slo-status"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-runtime-status"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-queue-escalate"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-flush"
  "$ROOT/ops/plugins/communications/bin/communications-alerts-incident-bundle-create"
)

for script in "${cap_scripts[@]}"; do
  if [[ ! -x "$script" ]]; then
    fail_v "implementation script not executable: $(basename "$script")"
  fi
done

# ─── Result ──────────────────────────────────────────────────────────────
checks_run=5
if [[ $violations -gt 0 ]]; then
  echo "D292 FAIL: communications queue pipeline lock: $violations violation(s) detected (checks=$checks_run)" >&2
  exit 1
fi

echo "D292 PASS: communications queue pipeline lock valid (checks=$checks_run, caps=${#required_caps[@]}, contracts=${#required_contracts[@]}, violations=0)"
