#!/usr/bin/env bash
# verify-identity.sh - Device identity verification script
# Part of #615: Device Identity SSOT
#
# Usage: ./scripts/infra/verify-identity.sh [--quick|--full|--json]
#
# --quick  Only check Tier 1 (critical infrastructure)
# --full   Check all tiers (default)
# --json   Output in JSON format

set -euo pipefail
OPS_SKIP_IMMICH="${OPS_SKIP_IMMICH:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from DEVICE_IDENTITY_SSOT.md
declare -A TIER1_HOSTS=(
  ["macbook"]="100.85.186.7"
  ["pve"]="100.96.211.33"
  ["docker-host"]="100.92.156.118"
  ["proxmox-home"]="100.103.99.62"
)

declare -A TIER2_HOSTS=(
  ["automation-stack"]="100.98.70.70"
  ["download-stack"]="100.107.36.76"
  ["streaming-stack"]="100.123.207.64"
)
# Conditionally add immich
if [[ "${OPS_SKIP_IMMICH:-0}" != "1" ]]; then
  TIER2_HOSTS["immich-1"]="100.114.101.50"
else
  echo "[skip] immich-1 (OPS_SKIP_IMMICH=1)" >&2
fi

declare -A TIER3_HOSTS=(
  ["ha"]="100.67.120.1"
  ["vault"]="100.93.142.63"
  ["nas"]="100.102.199.111"
  ["download-home"]="100.125.138.110"
  ["pihole-home"]="100.105.148.96"
)

# Service health endpoints
declare -A SERVICE_ENDPOINTS=(
  ["mint-os-api"]="https://mintprints-api.ronny.works/health"
  ["infisical"]="https://secrets.ronny.works/api/status"
  ["n8n"]="http://automation-stack:5678/healthz"
)

# Parse arguments
MODE="full"
OUTPUT="text"
for arg in "$@"; do
  case $arg in
    --quick) MODE="quick" ;;
    --full) MODE="full" ;;
    --json) OUTPUT="json" ;;
  esac
done

# Counters
PASS=0
FAIL=0
WARN=0

# Results array for JSON output
declare -a RESULTS=()

check_host() {
  local name=$1
  local expected_ip=$2
  local tier=$3

  # Try to resolve via Tailscale
  local actual_ip
  actual_ip=$(tailscale ip -4 "$name" 2>/dev/null || echo "UNRESOLVED")

  local reachable="false"
  local status="FAIL"
  local message=""

  if [[ "$actual_ip" == "UNRESOLVED" ]]; then
    message="Cannot resolve hostname"
    ((FAIL++))
  elif [[ "$actual_ip" != "$expected_ip" ]]; then
    message="IP mismatch: expected $expected_ip, got $actual_ip"
    ((++WARN))
    status="WARN"
  else
    # Try to ping
    if ping -c 1 -W 2 "$name" >/dev/null 2>&1; then
      reachable="true"
      status="PASS"
      message="Reachable at $actual_ip"
      ((++PASS))
    else
      message="Resolved but unreachable"
      ((++FAIL))
    fi
  fi

  if [[ "$OUTPUT" == "json" ]]; then
    RESULTS+=("{\"host\":\"$name\",\"expected_ip\":\"$expected_ip\",\"actual_ip\":\"$actual_ip\",\"tier\":$tier,\"status\":\"$status\",\"message\":\"$message\"}")
  else
    case $status in
      PASS) echo -e "  ${GREEN}✓${NC} $name ($actual_ip)" ;;
      WARN) echo -e "  ${YELLOW}⚠${NC} $name: $message" ;;
      FAIL) echo -e "  ${RED}✗${NC} $name: $message" ;;
    esac
  fi
}

check_service() {
  local name=$1
  local url=$2

  local status="FAIL"
  local message=""

  # Try to curl with timeout
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" =~ ^2 ]]; then
    status="PASS"
    message="HTTP $http_code"
    ((PASS++))
  elif [[ "$http_code" == "000" ]]; then
    message="Connection failed"
    ((FAIL++))
  else
    message="HTTP $http_code"
    ((++WARN))
    status="WARN"
  fi

  if [[ "$OUTPUT" == "json" ]]; then
    RESULTS+=("{\"service\":\"$name\",\"url\":\"$url\",\"status\":\"$status\",\"http_code\":\"$http_code\"}")
  else
    case $status in
      PASS) echo -e "  ${GREEN}✓${NC} $name (HTTP $http_code)" ;;
      WARN) echo -e "  ${YELLOW}⚠${NC} $name: $message" ;;
      FAIL) echo -e "  ${RED}✗${NC} $name: $message" ;;
    esac
  fi
}

# Main execution
if [[ "$OUTPUT" != "json" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  DEVICE IDENTITY VERIFICATION"
  echo "  Mode: $MODE | $(date '+%Y-%m-%d %H:%M:%S')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# Tier 1: Critical Infrastructure
if [[ "$OUTPUT" != "json" ]]; then
  echo "Tier 1: Critical Infrastructure"
fi
for host in "${!TIER1_HOSTS[@]}"; do
  check_host "$host" "${TIER1_HOSTS[$host]}" 1
done

# Tier 2 & 3: Only in full mode
if [[ "$MODE" == "full" ]]; then
  if [[ "$OUTPUT" != "json" ]]; then
    echo ""
    echo "Tier 2: Production Services"
  fi
  for host in "${!TIER2_HOSTS[@]}"; do
    check_host "$host" "${TIER2_HOSTS[$host]}" 2
  done

  if [[ "$OUTPUT" != "json" ]]; then
    echo ""
    echo "Tier 3: Home Services"
  fi
  for host in "${!TIER3_HOSTS[@]}"; do
    check_host "$host" "${TIER3_HOSTS[$host]}" 3
  done

  # Service health checks
  if [[ "$OUTPUT" != "json" ]]; then
    echo ""
    echo "Service Health Checks"
  fi
  for service in "${!SERVICE_ENDPOINTS[@]}"; do
    check_service "$service" "${SERVICE_ENDPOINTS[$service]}"
  done
fi

# Summary
if [[ "$OUTPUT" == "json" ]]; then
  echo "{"
  echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
  echo "  \"mode\": \"$MODE\","
  echo "  \"summary\": {\"pass\": $PASS, \"fail\": $FAIL, \"warn\": $WARN},"
  echo "  \"results\": ["
  first=true
  for result in "${RESULTS[@]}"; do
    if [[ "$first" == "true" ]]; then
      echo "    $result"
      first=false
    else
      echo "    ,$result"
    fi
  done
  echo "  ]"
  echo "}"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "  Summary: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC} | ${YELLOW}$WARN warnings${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "⚠️  Some devices are unreachable. Check:"
    echo "   1. Tailscale status: tailscale status"
    echo "   2. VPN connection on target devices"
    echo "   3. Device power state"
    exit 1
  fi
fi
