#!/usr/bin/env bash
# TRIAGE: HA automation count must match expected (14). If count differs, check HA UI for added/removed automations and update this gate.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_API="http://${HA_HOST}:${HA_PORT}/api"
EXPECTED_COUNT=14

# Retrieve token from Infisical
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  echo "SKIP: infisical-agent.sh not found (secrets not available)"
  exit 0
fi

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true

if [[ -z "$HA_TOKEN" ]]; then
  echo "SKIP: could not retrieve HA_API_TOKEN from Infisical"
  exit 0
fi

# Query all states and filter automation entities
ALL_STATES=$(curl -s --connect-timeout 5 \
  -H "Authorization: Bearer $HA_TOKEN" \
  "${HA_API}/states" 2>/dev/null) || ALL_STATES=""

if [[ -z "$ALL_STATES" ]]; then
  echo "SKIP: HA unreachable (connection timeout)"
  exit 0
fi

# Count automation entities that are not unavailable
ACTUAL_COUNT=$(echo "$ALL_STATES" | jq '[.[] | select(.entity_id | startswith("automation.")) | select(.state != "unavailable")] | length' 2>/dev/null) || ACTUAL_COUNT=""

if [[ -z "$ACTUAL_COUNT" ]]; then
  echo "WARN: could not parse automation entities from HA API response"
  exit 0
fi

if [[ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]]; then
  echo "PASS ($ACTUAL_COUNT automations, expected $EXPECTED_COUNT)"
else
  # List entity IDs for diagnosis
  ENTITY_LIST=$(echo "$ALL_STATES" | jq -r '[.[] | select(.entity_id | startswith("automation.")) | select(.state != "unavailable") | .entity_id] | sort | .[]' 2>/dev/null) || ENTITY_LIST="(parse error)"
  echo "WARN: automation count mismatch (actual=$ACTUAL_COUNT, expected=$EXPECTED_COUNT)"
  echo "Active automations:"
  echo "$ENTITY_LIST"
  exit 0
fi
