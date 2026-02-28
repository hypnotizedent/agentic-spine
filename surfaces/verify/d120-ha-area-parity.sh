#!/usr/bin/env bash
# TRIAGE: HA area parity drift. Check ha.areas.yaml against HA live area registry.
# D120: ha-area-parity
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AREAS_SSOT="$ROOT/ops/bindings/ha.areas.yaml"
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
FAIL=0

err() { echo "D120 FAIL: $*" >&2; FAIL=1; }

precondition_fail() {
  local message="$1"
  echo "D120 FAIL: $message" >&2
  exit 1
}

if [[ ! -f "$AREAS_SSOT" ]]; then
  precondition_fail "missing $AREAS_SSOT"
fi
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  precondition_fail "infisical-agent.sh not available"
fi

HA_TOKEN=$($INFISICAL_AGENT get home-assistant prod HA_API_TOKEN 2>/dev/null) || true
if [[ -z "${HA_TOKEN:-}" ]]; then
  precondition_fail "HA_API_TOKEN not available"
fi
export HA_TOKEN

if ! curl -sf -o /dev/null -m 5 "http://${HA_HOST}:${HA_PORT}/api/" -H "Authorization: Bearer $HA_TOKEN" 2>/dev/null; then
  precondition_fail "HA not reachable at ${HA_HOST}:${HA_PORT}"
fi

fetch_areas_ws() {
  python3 - "$HA_HOST" "$HA_PORT" <<'PY'
import asyncio
import json
import os
import sys

host = sys.argv[1]
port = sys.argv[2]
token = os.environ.get("HA_TOKEN", "")
if not token:
    sys.exit(1)

try:
    import websockets
except Exception:
    sys.exit(1)

async def get():
    try:
        uri = f"ws://{host}:{port}/api/websocket"
        async with websockets.connect(uri) as ws:
            await ws.recv()
            await ws.send(json.dumps({"type": "auth", "access_token": token}))
            auth = json.loads(await ws.recv())
            if auth.get("type") != "auth_ok":
                print("AUTH_FAILED")
                return 2

            await ws.send(json.dumps({"id": 1, "type": "config/area_registry/list"}))
            response = json.loads(await ws.recv())
            result = response.get("result")
            if not isinstance(result, list):
                return 1

            for area in result:
                area_id = area.get("area_id")
                if not area_id:
                    continue
                print(json.dumps({
                    "area_id": area_id,
                    "name": area.get("name", ""),
                    "icon": area.get("icon", ""),
                }))
            return 0
    except Exception:
        return 1

rc = asyncio.run(get())
sys.exit(rc)
PY
}

fetch_areas_rest() {
  local endpoint payload parsed
  for endpoint in "/api/config/area_registry/list" "/api/config/area_registry"; do
    payload="$(curl -sf -m 8 "http://${HA_HOST}:${HA_PORT}${endpoint}" \
      -H "Authorization: Bearer $HA_TOKEN" \
      -H "Content-Type: application/json" 2>/dev/null || true)"
    [[ -z "$payload" ]] && continue

    parsed="$(printf '%s' "$payload" | python3 - <<'PY' 2>/dev/null || true
import json
import sys

raw = sys.stdin.read().strip()
if not raw:
    sys.exit(1)

try:
    data = json.loads(raw)
except Exception:
    sys.exit(1)

if isinstance(data, dict) and isinstance(data.get("result"), list):
    data = data["result"]

if not isinstance(data, list):
    sys.exit(1)

lines = []
for area in data:
    if not isinstance(area, dict):
        continue
    area_id = area.get("area_id")
    if not area_id:
        continue
    lines.append(json.dumps({
        "area_id": area_id,
        "name": area.get("name", ""),
        "icon": area.get("icon", ""),
    }))

if not lines:
    sys.exit(1)

print("\\n".join(lines))
PY
)"
    if [[ -n "$parsed" ]]; then
      printf '%s\n' "$parsed"
      return 0
    fi
  done
  return 1
}

LIVE_AREAS="$(fetch_areas_ws 2>/dev/null || true)"
if [[ -z "$LIVE_AREAS" || "$LIVE_AREAS" == "AUTH_FAILED" ]]; then
  LIVE_AREAS="$(fetch_areas_rest 2>/dev/null || true)"
fi

if [[ -z "$LIVE_AREAS" || "$LIVE_AREAS" == "AUTH_FAILED" ]]; then
  precondition_fail "could not fetch HA areas"
fi

CHECKED=0
while IFS= read -r area_id; do
  [[ -z "$area_id" ]] && continue
  expected_name=$(yq e ".areas[] | select(.area_id == \"$area_id\") | .name" "$AREAS_SSOT")

  live_line=$(echo "$LIVE_AREAS" | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line.strip())
    if d['area_id'] == '$area_id':
        print(d['name'])
        break
" 2>/dev/null || true)

  if [[ -z "$live_line" ]]; then
    err "area '$area_id' defined in SSOT but missing in HA"
  elif [[ "$live_line" != "$expected_name" ]]; then
    err "area '$area_id' name mismatch: SSOT='$expected_name' HA='$live_line'"
  else
    CHECKED=$((CHECKED + 1))
  fi
done < <(yq -r '.areas[].area_id' "$AREAS_SSOT")

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  live_id=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['area_id'])" 2>/dev/null || true)
  [[ -z "$live_id" ]] && continue
  ssot_match=$(yq -r ".areas[] | select(.area_id == \"$live_id\") | .area_id" "$AREAS_SSOT" 2>/dev/null)
  if [[ -z "$ssot_match" ]]; then
    err "area '$live_id' exists in HA but missing from SSOT"
  fi
done <<< "$LIVE_AREAS"

if [[ "$FAIL" -eq 0 ]]; then
  echo "D120 PASS ($CHECKED areas verified)"
else
  exit 1
fi
