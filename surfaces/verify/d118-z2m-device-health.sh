#!/usr/bin/env bash
# TRIAGE: Z2M device battery or staleness out of bounds. Run ha.z2m.health for details. Replace batteries for <20%. Check Z2M bridge if disconnected.
# D118: z2m-device-health
# Checks: battery >20%, staleness <48h (unless exempt or within active
# time-bound maintenance window), bridge connected.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
DEVICES_BINDING="$SPINE_ROOT/ops/bindings/z2m.devices.yaml"
NAMING_BINDING="$SPINE_ROOT/ops/bindings/z2m.naming.yaml"
FAIL=0

err() { echo "D118 FAIL: $*" >&2; FAIL=1; }

# ── Preconditions (SKIP if unavailable) ──

if [[ ! -f "$DEVICES_BINDING" ]]; then
  echo "D118 SKIP: z2m.devices.yaml missing"
  exit 0
fi

if [[ ! -f "$NAMING_BINDING" ]]; then
  echo "D118 SKIP: z2m.naming.yaml missing"
  exit 0
fi

if [[ ! -x "$INFISICAL_AGENT" ]]; then
  echo "D118 SKIP: infisical-agent.sh not available"
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "D118 SKIP: curl not available"; exit 0; }
command -v jq >/dev/null 2>&1  || { echo "D118 SKIP: jq not available"; exit 0; }
command -v yq >/dev/null 2>&1  || { echo "D118 SKIP: yq not available"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "D118 SKIP: python3 not available"; exit 0; }

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true
if [[ -z "${HA_TOKEN:-}" ]]; then
  echo "D118 SKIP: HA token unavailable"
  exit 0
fi

HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_BASE="http://${HA_HOST}:${HA_PORT}"

# Quick connectivity check
BRIDGE_RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $HA_TOKEN" \
  "${HA_BASE}/api/states/binary_sensor.zigbee2mqtt_bridge_connection_state" 2>/dev/null) || true

if [[ -z "${BRIDGE_RESP:-}" ]]; then
  echo "D118 SKIP: HA API unreachable"
  exit 0
fi

# ── Check 1: Bridge connected ──

BRIDGE_STATE=$(echo "$BRIDGE_RESP" | jq -r '.state // "unknown"' 2>/dev/null)
if [[ "$BRIDGE_STATE" != "on" ]]; then
  err "Z2M bridge not connected (state: $BRIDGE_STATE)"
fi

# ── Check 2: Battery levels ──

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

  # Skip battery check for stale_exempt devices (event-only, battery reading unreliable)
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

  # ── Check 3: Staleness ──

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
  echo "PASS ($CHECKED devices, bridge $BRIDGE_STATE)"
else
  exit 1
fi
