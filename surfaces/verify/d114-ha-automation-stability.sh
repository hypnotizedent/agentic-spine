#!/usr/bin/env bash
# TRIAGE: HA automation inventory parity. Expected count is derived from canonical ledger.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
AUTOMATION_LEDGER="${SPINE_ROOT}/ops/bindings/ha.automations.ledger.yaml"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_API="http://${HA_HOST}:${HA_PORT}/api"
HA_GATE_MODE="${HA_GATE_MODE:-enforce}"  # enforce | report

precondition_fail() {
  local message="$1"
  if [[ "$HA_GATE_MODE" == "report" ]]; then
    echo "D114 REPORT: $message"
    exit 0
  fi
  echo "D114 FAIL: $message" >&2
  exit 1
}

if [[ ! -x "$INFISICAL_AGENT" ]]; then
  precondition_fail "infisical-agent.sh not found (secrets precondition unavailable)"
fi

if [[ ! -f "$AUTOMATION_LEDGER" ]]; then
  precondition_fail "missing canonical automation ledger: $AUTOMATION_LEDGER"
fi

command -v yq >/dev/null 2>&1 || precondition_fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || precondition_fail "missing dependency: jq"

EXPECTED_COUNT="$(yq '[.items[] | select((.status // "") != "retired" and (.status // "") != "ignored")] | length' "$AUTOMATION_LEDGER" 2>/dev/null || echo "")"
if [[ -z "$EXPECTED_COUNT" || "$EXPECTED_COUNT" == "null" ]]; then
  precondition_fail "could not derive expected automation count from ledger"
fi

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true
if [[ -z "${HA_TOKEN:-}" ]]; then
  precondition_fail "could not retrieve HA_API_TOKEN from Infisical"
fi

ALL_STATES=$(curl -s --connect-timeout 5 \
  -H "Authorization: Bearer $HA_TOKEN" \
  "${HA_API}/states" 2>/dev/null) || ALL_STATES=""

if [[ -z "$ALL_STATES" ]]; then
  precondition_fail "HA unreachable (connection timeout)"
fi

ACTUAL_COUNT=$(echo "$ALL_STATES" | jq '[.[] | select(.entity_id | startswith("automation.")) | select(.state != "unavailable")] | length' 2>/dev/null) || ACTUAL_COUNT=""
if [[ -z "$ACTUAL_COUNT" ]]; then
  precondition_fail "could not parse automation entities from HA API response"
fi

if [[ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]]; then
  echo "D114 PASS: $ACTUAL_COUNT automations (expected $EXPECTED_COUNT from ha.automations.ledger.yaml)"
  exit 0
fi

ENTITY_LIST=$(echo "$ALL_STATES" | jq -r '[.[] | select(.entity_id | startswith("automation.")) | select(.state != "unavailable") | .entity_id] | sort | .[]' 2>/dev/null) || ENTITY_LIST="(parse error)"
if [[ "$HA_GATE_MODE" == "report" ]]; then
  echo "D114 REPORT: automation count drift (actual=$ACTUAL_COUNT expected=$EXPECTED_COUNT)"
  echo "Active automations:"
  echo "$ENTITY_LIST"
  exit 0
fi

echo "D114 FAIL: automation count drift (actual=$ACTUAL_COUNT expected=$EXPECTED_COUNT)"
echo "Active automations:"
echo "$ENTITY_LIST"
exit 1
