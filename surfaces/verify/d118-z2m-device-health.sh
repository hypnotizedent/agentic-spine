#!/usr/bin/env bash
# TRIAGE: Z2M device battery or staleness out of bounds. Run ha.z2m.health for details.
# D118: z2m-device-health
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
DEVICES_BINDING="$SPINE_ROOT/ops/bindings/z2m.devices.yaml"
NAMING_BINDING="$SPINE_ROOT/ops/bindings/z2m.naming.yaml"
HA_GATE_MODE="${HA_GATE_MODE:-enforce}"  # enforce | report
FAIL=0

err() { echo "D118 FAIL: $*" >&2; FAIL=1; }

precondition_fail() {
  local message="$1"
  if [[ "$HA_GATE_MODE" == "report" ]]; then
    echo "D118 REPORT: $message"
    exit 0
  fi
  echo "D118 FAIL: $message" >&2
  exit 1
}

if [[ ! -f "$DEVICES_BINDING" ]]; then
  precondition_fail "z2m.devices.yaml missing"
fi
if [[ ! -f "$NAMING_BINDING" ]]; then
  precondition_fail "z2m.naming.yaml missing"
fi
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  precondition_fail "infisical-agent.sh not available"
fi

command -v curl >/dev/null 2>&1 || precondition_fail "curl not available"
command -v jq >/dev/null 2>&1  || precondition_fail "jq not available"
command -v yq >/dev/null 2>&1  || precondition_fail "yq not available"
command -v python3 >/dev/null 2>&1 || precondition_fail "python3 not available"

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true
if [[ -z "${HA_TOKEN:-}" ]]; then
  precondition_fail "HA token unavailable"
fi

HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_BASE="http://${HA_HOST}:${HA_PORT}"

BRIDGE_RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $HA_TOKEN" \
  "${HA_BASE}/api/states/binary_sensor.zigbee2mqtt_bridge_connection_state" 2>/dev/null) || true
if [[ -z "${BRIDGE_RESP:-}" ]]; then
  precondition_fail "HA API unreachable"
fi

BRIDGE_STATE=$(echo "$BRIDGE_RESP" | jq -r '.state // "unknown"' 2>/dev/null)
if [[ "$BRIDGE_STATE" != "on" ]]; then
  err "Z2M bridge not connected (state: $BRIDGE_STATE)"
fi

NOW_EPOCH=$(date +%s)

parse_epoch_date() {
  local ds="${1:-}"
  [[ -n "$ds" && "$ds" != "null" ]] || { echo 0; return; }
  python3 - "$ds" <<'PY'
import sys
from datetime import datetime, timezone

raw = (sys.argv[1] or "").strip()
if not raw:
    print(0)
    raise SystemExit(0)

try:
    dt = datetime.fromisoformat(raw)
except Exception:
    try:
        dt = datetime.strptime(raw, "%Y-%m-%d")
    except Exception:
        print(0)
        raise SystemExit(0)

if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)

print(int(dt.timestamp()))
PY
}

NAMING_COUNT=$(yq '.devices | length' "$NAMING_BINDING")
CHECKED=0
i=0

while [ "$i" -lt "$NAMING_COUNT" ]; do
  CANONICAL=$(yq ".devices[$i].canonical_name" "$NAMING_BINDING")
  IEEE=$(yq ".devices[$i].ieee" "$NAMING_BINDING")
  PREFIX=$(yq ".devices[$i].entity_id_prefix" "$NAMING_BINDING")
  STALE_EXEMPT=$(yq ".devices[$i].stale_exempt" "$NAMING_BINDING")
  MAINTENANCE_UNTIL=$(yq ".devices[$i].maintenance_until // \"\"" "$NAMING_BINDING")
  MAINTENANCE_NOTE=$(yq ".devices[$i].maintenance_note // \"\"" "$NAMING_BINDING")

  if [[ "$STALE_EXEMPT" != "true" ]]; then
    BATTERY_ENTITY="sensor.${PREFIX}_battery"
    BATTERY_JSON=$(curl -s --max-time 5 \
      -H "Authorization: Bearer $HA_TOKEN" \
      "${HA_BASE}/api/states/${BATTERY_ENTITY}" 2>/dev/null) || true
    if [[ -n "${BATTERY_JSON:-}" ]]; then
      BATTERY_VAL=$(echo "$BATTERY_JSON" | jq -r '.state // "unknown"' 2>/dev/null)
      if [[ "$BATTERY_VAL" != "unknown" && "$BATTERY_VAL" != "unavailable" ]]; then
        BATTERY_INT=${BATTERY_VAL%%.*}
        if [[ "$BATTERY_INT" -lt 20 ]]; then
          err "$CANONICAL battery critical: ${BATTERY_VAL}% (<20%)"
        fi
      fi
    fi
  fi

  if [[ "$STALE_EXEMPT" != "true" ]]; then
    LAST_SEEN=$(yq ".z2m_devices.devices[] | select(.ieee_address == \"$IEEE\") | .last_seen" "$DEVICES_BINDING")
    if [[ -n "$LAST_SEEN" && "$LAST_SEEN" != "null" && "$LAST_SEEN" != "" ]]; then
      if [[ "$(uname)" == "Darwin" ]]; then
        SEEN_EPOCH=$(TZ=UTC date -jf '%Y-%m-%dT%H:%M:%SZ' "$LAST_SEEN" +%s 2>/dev/null) || SEEN_EPOCH=0
      else
        SEEN_EPOCH=$(date -d "$LAST_SEEN" +%s 2>/dev/null) || SEEN_EPOCH=0
      fi
      if [[ "$SEEN_EPOCH" -gt 0 ]]; then
        STALE_HOURS=$(( (NOW_EPOCH - SEEN_EPOCH) / 3600 ))
        if [[ "$STALE_HOURS" -ge 48 ]]; then
          MAINTENANCE_EPOCH=$(parse_epoch_date "$MAINTENANCE_UNTIL")
          if [[ "$MAINTENANCE_EPOCH" -gt 0 && "$NOW_EPOCH" -le "$MAINTENANCE_EPOCH" ]]; then
            echo "D118 MAINT: $CANONICAL stale ${STALE_HOURS}h (>48h), maintenance window active until $MAINTENANCE_UNTIL${MAINTENANCE_NOTE:+ ($MAINTENANCE_NOTE)}" >&2
          elif [[ "$MAINTENANCE_EPOCH" -gt 0 && "$NOW_EPOCH" -gt "$MAINTENANCE_EPOCH" ]]; then
            err "$CANONICAL stale: last seen ${STALE_HOURS}h ago (>48h), maintenance window expired at $MAINTENANCE_UNTIL${MAINTENANCE_NOTE:+ ($MAINTENANCE_NOTE)}"
          else
            err "$CANONICAL stale: last seen ${STALE_HOURS}h ago (>48h)"
          fi
        fi
      fi
    fi
  fi

  CHECKED=$((CHECKED + 1))
  i=$((i + 1))
done

if [[ "$FAIL" -eq 0 ]]; then
  echo "D118 PASS ($CHECKED devices, bridge $BRIDGE_STATE)"
else
  exit 1
fi
