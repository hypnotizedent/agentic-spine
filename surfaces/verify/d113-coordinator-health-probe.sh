#!/usr/bin/env bash
# TRIAGE: Coordinator health — Z2M bridge must be connected, SLZB-06MU ethernet on, TubesZB ESPHome reachable.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_API="http://${HA_HOST}:${HA_PORT}/api"
HA_GATE_MODE="${HA_GATE_MODE:-enforce}"  # enforce | report

precondition_fail() {
  local message="$1"
  if [[ "$HA_GATE_MODE" == "report" ]]; then
    echo "D113 REPORT: $message"
    exit 0
  fi
  echo "D113 FAIL: $message" >&2
  exit 1
}

if [[ ! -x "$INFISICAL_AGENT" ]]; then
  precondition_fail "infisical-agent.sh not found (secrets precondition unavailable)"
fi

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true
if [[ -z "${HA_TOKEN:-}" ]]; then
  precondition_fail "could not retrieve HA_API_TOKEN from Infisical"
fi

ha_state() {
  local entity="$1"
  curl -s --connect-timeout 5 \
    -H "Authorization: Bearer $HA_TOKEN" \
    "${HA_API}/states/${entity}" 2>/dev/null
}

FAIL=0
RESULTS=()

z2m_resp=$(ha_state "binary_sensor.zigbee2mqtt_bridge_connection_state") || z2m_resp=""
if [[ -z "$z2m_resp" ]]; then
  precondition_fail "HA unreachable (connection timeout)"
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
  RESULTS+=("SLZB-06MU ethernet: WARN (entity not found)")
fi

tubeszb_resp=$(ha_state "sensor.tubeszb_2026_zw_esp_ip_address") || tubeszb_resp=""
if [[ -n "$tubeszb_resp" ]]; then
  tubeszb_ip=$(echo "$tubeszb_resp" | jq -r '.state // "unavailable"' 2>/dev/null) || tubeszb_ip="unavailable"
  if [[ "$tubeszb_ip" == "10.0.0.90" ]]; then
    RESULTS+=("TubesZB: online ($tubeszb_ip)")
  elif [[ "$tubeszb_ip" == "unavailable" ]]; then
    RESULTS+=("TubesZB: WARN (ESPHome unavailable)")
  else
    RESULTS+=("TubesZB: online ($tubeszb_ip)")
  fi

  zw_serial_resp=$(ha_state "binary_sensor.tubeszb_2026_zw_tubeszb_zw_serial_connected") || zw_serial_resp=""
  if [[ -n "$zw_serial_resp" ]]; then
    zw_serial=$(echo "$zw_serial_resp" | jq -r '.state // "unknown"' 2>/dev/null) || zw_serial="unknown"
    if [[ "$zw_serial" == "on" ]]; then
      RESULTS+=("Z-Wave serial: connected")
    else
      RESULTS+=("Z-Wave serial: $zw_serial")
    fi
  fi
else
  RESULTS+=("TubesZB: WARN (entity not found)")
fi

for entity in "update.slzb_06mu_core_firmware" "update.slzb_06mu_zigbee_firmware"; do
  fw_resp=$(ha_state "$entity") || fw_resp=""
  if [[ -n "$fw_resp" ]]; then
    installed=$(echo "$fw_resp" | jq -r '.attributes.installed_version // "unknown"' 2>/dev/null) || installed="unknown"
    short_name=$(echo "$entity" | sed 's/update\.slzb_06mu_//' | sed 's/_firmware//')
    RESULTS+=("SLZB-06MU ${short_name}: v${installed}")
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  echo "D113 FAIL: $(IFS='; '; echo "${RESULTS[*]}")"
  exit 1
fi

echo "D113 PASS: $(IFS='; '; echo "${RESULTS[*]}")"
