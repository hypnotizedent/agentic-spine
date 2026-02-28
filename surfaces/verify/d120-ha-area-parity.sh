#!/usr/bin/env bash
# TRIAGE: HA area parity drift. Check ha.areas.yaml against HA live area registry.
# D120: ha-area-parity
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AREAS_SSOT="$ROOT/ops/bindings/ha.areas.yaml"
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_GATE_MODE="${HA_GATE_MODE:-enforce}"  # enforce | report
FAIL=0

err() { echo "D120 FAIL: $*" >&2; FAIL=1; }

precondition_fail() {
  local message="$1"
  if [[ "$HA_GATE_MODE" == "report" ]]; then
    echo "D120 REPORT: $message"
    exit 0
  fi
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

LIVE_AREAS=$(python3 -c "
import json, asyncio, websockets, os
async def get():
    token = os.environ['HA_TOKEN']
    async with websockets.connect('ws://${HA_HOST}:${HA_PORT}/api/websocket') as ws:
        await ws.recv()
        await ws.send(json.dumps({'type': 'auth', 'access_token': token}))
        auth = json.loads(await ws.recv())
        if auth['type'] != 'auth_ok':
            print('AUTH_FAILED')
            return
        await ws.send(json.dumps({'id': 1, 'type': 'config/area_registry/list'}))
        r = json.loads(await ws.recv())
        for a in r.get('result', []):
            print(json.dumps({'area_id': a['area_id'], 'name': a.get('name',''), 'icon': a.get('icon','')}))
asyncio.run(get())
" 2>/dev/null) || true

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
