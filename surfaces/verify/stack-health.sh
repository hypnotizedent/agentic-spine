#!/usr/bin/env bash
# Spine-native stack health check.
# Uses governed bindings and service registry (no hardcoded pre-relocation hosts).

set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SERVICE_REGISTRY="$SPINE_ROOT/docs/governance/SERVICE_REGISTRY.yaml"
SERVICES_HEALTH="$SPINE_ROOT/ops/plugins/services/bin/services-health-status"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

fail_count=0

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need yq
need curl

[[ -f "$SERVICE_REGISTRY" ]] || {
  echo "FAIL: missing service registry: $SERVICE_REGISTRY" >&2
  exit 2
}
[[ -x "$SERVICES_HEALTH" ]] || {
  echo "FAIL: missing services health tool: $SERVICES_HEALTH" >&2
  exit 2
}

echo -e "${CYAN}=== Stack Health Check (Spine) ===${NC}"
echo "Date: $(date)"
echo

echo -e "${YELLOW}[1/3] Baseline service health binding${NC}"
if "$SERVICES_HEALTH"; then
  echo -e "${GREEN}  ✓ services.health binding checks passed${NC}"
else
  echo -e "${RED}  ✗ services.health binding checks failed${NC}"
  fail_count=$((fail_count + 1))
fi
echo

check_registry_service() {
  local service="$1"
  local host port health ip url code

  host="$(yq e ".services.\"$service\".host // \"\"" "$SERVICE_REGISTRY")"
  port="$(yq e ".services.\"$service\".port // \"\"" "$SERVICE_REGISTRY")"
  health="$(yq e ".services.\"$service\".health // \"\"" "$SERVICE_REGISTRY")"

  if [[ -z "$host" || "$host" == "null" || -z "$port" || "$port" == "null" || -z "$health" || "$health" == "null" ]]; then
    echo -e "${RED}  ✗ $service: incomplete registry entry (host/port/health required)${NC}"
    fail_count=$((fail_count + 1))
    return
  fi

  ip="$(yq e ".hosts.\"$host\".tailscale_ip // \"\"" "$SERVICE_REGISTRY")"
  if [[ -z "$ip" || "$ip" == "null" ]]; then
    echo -e "${RED}  ✗ $service: host '$host' has no tailscale_ip in registry${NC}"
    fail_count=$((fail_count + 1))
    return
  fi

  url="http://${ip}:${port}${health}"
  code="$(curl -fsS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")"
  if [[ "$code" == "200" ]]; then
    echo -e "${GREEN}  ✓ $service: HTTP 200 (${url})${NC}"
  else
    echo -e "${RED}  ✗ $service: HTTP ${code} (${url})${NC}"
    fail_count=$((fail_count + 1))
  fi
}

echo -e "${YELLOW}[2/3] Relocated core services (infra-core)${NC}"
check_registry_service "infisical"
check_registry_service "vaultwarden"
echo

echo -e "${YELLOW}[3/3] Registry sanity${NC}"
for s in mint-os-api infisical vaultwarden; do
  if [[ "$(yq e ".services.\"$s\".host // \"missing\"" "$SERVICE_REGISTRY")" == "missing" ]]; then
    echo -e "${RED}  ✗ missing service in registry: $s${NC}"
    fail_count=$((fail_count + 1))
  else
    echo -e "${GREEN}  ✓ registry contains: $s${NC}"
  fi
done
echo

echo -e "${CYAN}=== Summary ===${NC}"
if (( fail_count == 0 )); then
  echo -e "${GREEN}All stack checks passed.${NC}"
  exit 0
fi

echo -e "${RED}Found ${fail_count} stack health issue(s).${NC}"
exit 1
