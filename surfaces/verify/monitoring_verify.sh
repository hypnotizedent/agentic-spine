#!/bin/bash
# Monitoring Inventory Verification Script
# Governance: docs/governance/WORKBENCH_TOOLING_INDEX.md (external tooling only)
# Issue: #628
# Purpose: Validate monitoring inventory and optionally check endpoint health (read-only)

set -euo pipefail

INVENTORY_PATH="${INVENTORY_PATH:-infrastructure/data/monitoring_inventory.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Options
CHECK_HEALTH="${CHECK_HEALTH:-false}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

echo "=== Monitoring Inventory Verification ==="
echo "Inventory: $INVENTORY_PATH"
echo "Health checks: $CHECK_HEALTH"
echo ""

# Check inventory exists
if [[ ! -f "$REPO_ROOT/$INVENTORY_PATH" ]]; then
    echo -e "${RED}FAIL:${NC} Inventory file not found: $INVENTORY_PATH"
    exit 2
fi

# Validate JSON structure
echo "--- Schema Validation ---"

if ! jq empty "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null; then
    echo -e "${RED}FAIL:${NC} Invalid JSON syntax"
    exit 2
fi
echo -e "${GREEN}PASS:${NC} Valid JSON"
PASS=$((PASS + 1))

# Check required top-level keys
REQUIRED_KEYS=("meta" "health_endpoints" "service_tiers")
for key in "${REQUIRED_KEYS[@]}"; do
    if jq -e ".$key" "$REPO_ROOT/$INVENTORY_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS:${NC} Required key exists: $key"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL:${NC} Missing required key: $key"
        FAIL=$((FAIL + 1))
    fi
done

# Check meta.schema_version
SCHEMA_VERSION=$(jq -r '.meta.schema_version // "missing"' "$REPO_ROOT/$INVENTORY_PATH")
if [[ "$SCHEMA_VERSION" == "missing" ]]; then
    echo -e "${RED}FAIL:${NC} Missing meta.schema_version"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}PASS:${NC} Schema version: $SCHEMA_VERSION"
    PASS=$((PASS + 1))
fi

# Count endpoints
ENDPOINT_COUNT=$(jq '.health_endpoints | length' "$REPO_ROOT/$INVENTORY_PATH")
echo -e "${GREEN}INFO:${NC} Health endpoints catalogued: $ENDPOINT_COUNT"

# Validate each endpoint has required fields
echo ""
echo "--- Endpoint Validation ---"

ENDPOINT_REQUIRED=("service" "url" "expected_status" "tier")

jq -c '.health_endpoints[]' "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null | while read -r endpoint; do
    SERVICE=$(echo "$endpoint" | jq -r '.service // "unknown"')
    URL=$(echo "$endpoint" | jq -r '.url // "missing"')
    TIER=$(echo "$endpoint" | jq -r '.tier // "missing"')

    ENDPOINT_OK=true

    for field in "${ENDPOINT_REQUIRED[@]}"; do
        VALUE=$(echo "$endpoint" | jq -r ".$field // \"missing\"")
        if [[ "$VALUE" == "missing" || "$VALUE" == "null" ]]; then
            echo -e "${YELLOW}WARN:${NC} $SERVICE - missing required field: $field"
            ENDPOINT_OK=false
        fi
    done

    if [[ "$ENDPOINT_OK" == "true" ]]; then
        echo -e "${GREEN}PASS:${NC} $SERVICE (Tier $TIER) - schema valid"
    fi
done

# Optional health checks
if [[ "$CHECK_HEALTH" == "true" ]]; then
    echo ""
    echo "--- Live Health Checks ---"

    jq -c '.health_endpoints[]' "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null | while read -r endpoint; do
        SERVICE=$(echo "$endpoint" | jq -r '.service')
        URL=$(echo "$endpoint" | jq -r '.url')
        EXPECTED=$(echo "$endpoint" | jq -r '.expected_status // 200')
        INTERNAL_URL=$(echo "$endpoint" | jq -r '.internal_url // empty')

        # Use internal URL if available (for Tailscale access)
        CHECK_URL="${INTERNAL_URL:-$URL}"

        if [[ "$CHECK_URL" == "null" || -z "$CHECK_URL" ]]; then
            echo -e "${YELLOW}SKIP:${NC} $SERVICE - no URL configured"
            continue
        fi

        # Check if URL contains placeholder
        if [[ "$CHECK_URL" == *"PLACEHOLDER"* || "$CHECK_URL" == *"example.com"* ]]; then
            echo -e "${YELLOW}SKIP:${NC} $SERVICE - placeholder URL"
            continue
        fi

        # Attempt health check
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT_SECONDS" "$CHECK_URL" 2>/dev/null || echo "000")

        if [[ "$HTTP_CODE" == "$EXPECTED" ]]; then
            echo -e "${GREEN}PASS:${NC} $SERVICE - HTTP $HTTP_CODE (expected $EXPECTED)"
        elif [[ "$HTTP_CODE" == "000" ]]; then
            echo -e "${RED}FAIL:${NC} $SERVICE - connection failed (timeout or unreachable)"
        else
            echo -e "${RED}FAIL:${NC} $SERVICE - HTTP $HTTP_CODE (expected $EXPECTED)"
        fi
    done
else
    echo ""
    echo -e "${YELLOW}SKIP:${NC} Live health checks disabled (set CHECK_HEALTH=true to enable)"
    SKIP=$((SKIP + 1))
fi

# Check service tiers defined
echo ""
echo "--- Service Tiers ---"
TIER_COUNT=$(jq '.service_tiers | length' "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null || echo "0")
if [[ "$TIER_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}PASS:${NC} Service tiers defined: $TIER_COUNT"
    jq -r '.service_tiers[] | "       Tier \(.tier): \(.name) - \(.description)"' "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null || true
    PASS=$((PASS + 1))
else
    echo -e "${YELLOW}WARN:${NC} No service tiers defined"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "PASS: ${GREEN}$PASS${NC}"
echo -e "FAIL: ${RED}$FAIL${NC}"
echo -e "SKIP: ${YELLOW}$SKIP${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}VERIFICATION FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}VERIFICATION PASSED${NC}"
    exit 0
fi
