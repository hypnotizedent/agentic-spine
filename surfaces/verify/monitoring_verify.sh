#!/usr/bin/env bash
# Spine-native monitoring verification.
# Validates canonical services health binding and can optionally run live probes.

set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="${INVENTORY_PATH:-$SPINE_ROOT/ops/bindings/services.health.yaml}"
CHECK_HEALTH="${CHECK_HEALTH:-false}"
HEALTH_TOOL="$SPINE_ROOT/ops/plugins/services/bin/services-health-status"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

echo "=== Monitoring Verification (Spine) ==="
echo "Binding: $BINDING"
echo "Health checks: $CHECK_HEALTH"
echo ""

command -v yq >/dev/null 2>&1 || {
  echo -e "${RED}FAIL:${NC} missing dependency: yq"
  exit 2
}

if [[ ! -f "$BINDING" ]]; then
  echo -e "${RED}FAIL:${NC} Binding file not found: $BINDING"
  exit 2
fi

echo "--- Schema Validation ---"
if ! yq e '.' "$BINDING" >/dev/null 2>&1; then
  echo -e "${RED}FAIL:${NC} Invalid YAML syntax"
  exit 2
fi
echo -e "${GREEN}PASS:${NC} Valid YAML"
PASS=$((PASS + 1))

REQUIRED_KEYS=("version" "defaults" "endpoints")
for key in "${REQUIRED_KEYS[@]}"; do
  if [[ "$(yq e ".$key // \"missing\"" "$BINDING")" != "missing" ]]; then
    echo -e "${GREEN}PASS:${NC} Required key exists: $key"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL:${NC} Missing required key: $key"
    FAIL=$((FAIL + 1))
  fi
done

endpoint_count="$(yq e '.endpoints | length' "$BINDING" 2>/dev/null || echo "0")"
if [[ "$endpoint_count" =~ ^[0-9]+$ ]] && (( endpoint_count > 0 )); then
  echo -e "${GREEN}PASS:${NC} Endpoints catalogued: $endpoint_count"
  PASS=$((PASS + 1))
else
  echo -e "${RED}FAIL:${NC} endpoints[] is empty or invalid"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Endpoint Validation ---"
while IFS= read -r id; do
  [[ -n "$id" && "$id" != "null" ]] || continue
  host="$(yq e ".endpoints[] | select(.id == \"$id\") | .host // \"missing\"" "$BINDING")"
  url="$(yq e ".endpoints[] | select(.id == \"$id\") | .url // \"missing\"" "$BINDING")"
  expect="$(yq e ".endpoints[] | select(.id == \"$id\") | .expect // \"missing\"" "$BINDING")"
  if [[ "$host" == "missing" || "$url" == "missing" || "$expect" == "missing" ]]; then
    echo -e "${YELLOW}WARN:${NC} $id - incomplete endpoint entry"
  else
    echo -e "${GREEN}PASS:${NC} $id - schema valid"
  fi
done < <(yq e '.endpoints[].id' "$BINDING" 2>/dev/null || true)

if [[ "$CHECK_HEALTH" == "true" ]]; then
  echo ""
  echo "--- Live Health Checks ---"
  if [[ ! -x "$HEALTH_TOOL" ]]; then
    echo -e "${RED}FAIL:${NC} missing health tool: $HEALTH_TOOL"
    FAIL=$((FAIL + 1))
  elif "$HEALTH_TOOL"; then
    echo -e "${GREEN}PASS:${NC} live health checks passed"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL:${NC} live health checks failed"
    FAIL=$((FAIL + 1))
  fi
else
  echo ""
  echo -e "${YELLOW}SKIP:${NC} Live health checks disabled (set CHECK_HEALTH=true to enable)"
  SKIP=$((SKIP + 1))
fi

echo ""
echo "=== Summary ==="
echo -e "PASS: ${GREEN}$PASS${NC}"
echo -e "FAIL: ${RED}$FAIL${NC}"
echo -e "SKIP: ${YELLOW}$SKIP${NC}"
echo ""

if (( FAIL > 0 )); then
  echo -e "${RED}VERIFICATION FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}VERIFICATION PASSED${NC}"
exit 0
