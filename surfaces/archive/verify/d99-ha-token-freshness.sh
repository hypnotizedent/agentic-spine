#!/usr/bin/env bash
# TRIAGE: HA API token must return HTTP 200. If stale, rotate in Infisical home-assistant/prod/HA_API_TOKEN and restart dependents.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
HA_HOST="${HA_HOST:-10.0.0.100}"
HA_PORT="${HA_PORT:-8123}"
HA_API="http://${HA_HOST}:${HA_PORT}/api/"

# Retrieve token from Infisical
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  echo "D99 SKIP: infisical-agent.sh not found (secrets not available)"
  exit 0
fi

HA_TOKEN=$("$INFISICAL_AGENT" get home-assistant prod HA_API_TOKEN 2>/dev/null) || true

if [[ -z "$HA_TOKEN" ]]; then
  echo "D99 FAIL: could not retrieve HA_API_TOKEN from Infisical"
  exit 1
fi

# Probe HA API with token
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 \
  -H "Authorization: Bearer $HA_TOKEN" "$HA_API" 2>/dev/null) || HTTP_CODE="000"

case "$HTTP_CODE" in
  200)
    echo "D99 PASS: HA API token valid (HTTP $HTTP_CODE)"
    ;;
  401|403)
    echo "D99 FAIL: HA API token is stale (HTTP $HTTP_CODE). Rotate in Infisical home-assistant/prod/HA_API_TOKEN."
    exit 1
    ;;
  000)
    echo "D99 SKIP: HA unreachable (connection timeout)"
    exit 0
    ;;
  *)
    echo "D99 WARN: HA API returned unexpected HTTP $HTTP_CODE"
    exit 0
    ;;
esac
