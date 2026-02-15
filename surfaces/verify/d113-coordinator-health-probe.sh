#!/usr/bin/env bash
# TRIAGE: Coordinator health — Z2M add-on must be started, SLZB-06MU ethernet must be on. If HA unreachable, gate SKIPs gracefully.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
HA_API="http://100.67.120.1:8123/api"

# Retrieve token from Infisical
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  echo "SKIP: infisical-agent.sh not found (secrets not available)"
  exit 0
fi

TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true

if [[ -z "$TOKEN" ]]; then
  echo "SKIP: could not retrieve HA_API_TOKEN from Infisical"
  exit 0
fi

# Helper: query HA entity state
ha_state() {
  local entity="$1"
  curl -s --connect-timeout 5 \
    -H "Authorization: Bearer $TOKEN" \
    "${HA_API}/states/${entity}" 2>/dev/null
}

FAIL=0
RESULTS=()

# ── Check 1: Z2M bridge connection state ──
# Z2M exposes binary_sensor.zigbee2mqtt_bridge_connection_state (on/off)
z2m_resp=$(ha_state "binary_sensor.zigbee2mqtt_bridge_connection_state") || z2m_resp=""

if [[ -z "$z2m_resp" ]]; then
  RESULTS+=("SKIP: HA unreachable (connection timeout)")
  echo "${RESULTS[0]}"
  exit 0
fi

z2m_state=$(echo "$z2m_resp" | jq -r '.state // "unavailable"' 2>/dev/null) || z2m_state="unavailable"

if [[ "$z2m_state" == "on" ]]; then
  RESULTS+=("Z2M: connected")
elif [[ "$z2m_state" == "off" ]]; then
  RESULTS+=("Z2M: FAIL (bridge disconnected — add-on may be stopped)")
  FAIL=1
elif [[ "$z2m_state" == "unavailable" ]]; then
  RESULTS+=("Z2M: FAIL (entity unavailable — add-on not running)")
  FAIL=1
else
  RESULTS+=("Z2M: WARN (state=$z2m_state)")
fi

# ── Check 2: SLZB-06MU ethernet status ──
slzb_resp=$(ha_state "binary_sensor.slzb_06mu_ethernet") || slzb_resp=""

if [[ -n "$slzb_resp" ]]; then
  slzb_state=$(echo "$slzb_resp" | jq -r '.state // "unavailable"' 2>/dev/null) || slzb_state="unavailable"

  if [[ "$slzb_state" == "on" ]]; then
    RESULTS+=("SLZB-06MU ethernet: on")
  elif [[ "$slzb_state" == "off" || "$slzb_state" == "unavailable" ]]; then
    RESULTS+=("SLZB-06MU ethernet: WARN (state=$slzb_state)")
  else
    RESULTS+=("SLZB-06MU ethernet: $slzb_state")
  fi
else
  RESULTS+=("SLZB-06MU ethernet: SKIP (entity not found)")
fi

# ── Check 3: Firmware versions (informational) ──
for entity in "update.slzb_06mu_core_firmware" "update.slzb_06mu_zigbee_firmware"; do
  fw_resp=$(ha_state "$entity") || fw_resp=""
  if [[ -n "$fw_resp" ]]; then
    installed=$(echo "$fw_resp" | jq -r '.attributes.installed_version // "unknown"' 2>/dev/null) || installed="unknown"
    short_name=$(echo "$entity" | sed 's/update\.slzb_06mu_//' | sed 's/_firmware//')
    RESULTS+=("SLZB-06MU ${short_name}: v${installed}")
  fi
done

# ── Output ──
if [[ "$FAIL" -eq 1 ]]; then
  echo "FAIL: $(IFS='; '; echo "${RESULTS[*]}")"
  exit 1
fi

echo "PASS ($(IFS='; '; echo "${RESULTS[*]}"))"
