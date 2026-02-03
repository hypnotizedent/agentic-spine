#!/bin/bash
# =============================================================================
# Stack Health Check - Audit all stacks for health and credential alignment
# Created: January 6, 2026 (Issue #188)
# =============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${CYAN}=== Stack Health Check ===${NC}"
echo -e "Date: $(date)"
echo ""

# Track issues
ISSUES_FOUND=0

# =============================================================================
# MINT OS STACK
# =============================================================================
echo -e "${YELLOW}[1/6] Mint OS Stack${NC}"

# Check containers
MINT_CONTAINERS=$(ssh docker-host "docker ps --filter 'name=mint-os' --format '{{.Names}}: {{.Status}}'" 2>/dev/null || echo "ERROR")
if [[ "$MINT_CONTAINERS" == "ERROR" ]]; then
    echo -e "${RED}  ✗ Cannot connect to docker-host${NC}"
    ((ISSUES_FOUND++))
else
    # Check critical containers
    if echo "$MINT_CONTAINERS" | grep -q "mint-os-postgres.*healthy"; then
        echo -e "${GREEN}  ✓ Postgres: healthy${NC}"
    else
        echo -e "${RED}  ✗ Postgres: not healthy${NC}"
        ((ISSUES_FOUND++))
    fi
    
    if echo "$MINT_CONTAINERS" | grep -q "mint-os-dashboard-api"; then
        # Check API health endpoint
        API_HEALTH=$(ssh docker-host "curl -s http://localhost:3335/api/health" 2>/dev/null || echo "{}")
        if echo "$API_HEALTH" | grep -q '"status":"healthy"'; then
            ORDERS=$(echo "$API_HEALTH" | grep -o '"orders":[0-9]*' | cut -d':' -f2 || echo "?")
            echo -e "${GREEN}  ✓ API: healthy ($ORDERS orders)${NC}"
        else
            echo -e "${RED}  ✗ API: not responding correctly${NC}"
            ((ISSUES_FOUND++))
        fi
    else
        echo -e "${RED}  ✗ API container not found${NC}"
        ((ISSUES_FOUND++))
    fi
    
    if echo "$MINT_CONTAINERS" | grep -q "mint-os-redis.*healthy"; then
        echo -e "${GREEN}  ✓ Redis: healthy${NC}"
    else
        echo -e "${YELLOW}  ⚠ Redis: status unknown${NC}"
    fi
fi

# Check credential alignment
echo -e "  ${CYAN}Credential check:${NC}"
VAULT_DB_HOST=$(ssh docker-host "grep '^VAULT_DB_HOST=' ~/stacks/mint-os/.env 2>/dev/null | cut -d'=' -f2" || echo "")
VAULT_DB_USER=$(ssh docker-host "grep '^VAULT_DB_USER=' ~/stacks/mint-os/.env 2>/dev/null | cut -d'=' -f2" || echo "")

if [[ "$VAULT_DB_HOST" == "mint-os-postgres" ]]; then
    echo -e "${GREEN}    ✓ VAULT_DB_HOST correct${NC}"
else
    echo -e "${RED}    ✗ VAULT_DB_HOST: $VAULT_DB_HOST (expected: mint-os-postgres)${NC}"
    ((ISSUES_FOUND++))
fi

if [[ "$VAULT_DB_USER" == "mint_os_admin" ]]; then
    echo -e "${GREEN}    ✓ VAULT_DB_USER correct${NC}"
else
    echo -e "${RED}    ✗ VAULT_DB_USER: $VAULT_DB_USER (expected: mint_os_admin)${NC}"
    ((ISSUES_FOUND++))
fi

echo ""

# =============================================================================
# MCPJUNGLE
# =============================================================================
echo -e "${YELLOW}[2/6] MCPJungle${NC}"
MCP_STATUS=$(ssh docker-host "docker ps --filter 'name=mcpjungle' --format '{{.Status}}'" 2>/dev/null || echo "ERROR")
if [[ "$MCP_STATUS" == *"healthy"* ]] || [[ "$MCP_STATUS" == *"Up"* ]]; then
    echo -e "${GREEN}  ✓ MCPJungle: running${NC}"
else
    echo -e "${YELLOW}  ⚠ MCPJungle: $MCP_STATUS${NC}"
fi
echo ""

# =============================================================================
# FINANCE STACK
# =============================================================================
echo -e "${YELLOW}[3/6] Finance Stack${NC}"
FIREFLY_STATUS=$(ssh docker-host "docker ps --filter 'name=firefly' --format '{{.Names}}: {{.Status}}'" 2>/dev/null || echo "")
if [[ -n "$FIREFLY_STATUS" ]]; then
    echo -e "${GREEN}  ✓ Firefly III: running${NC}"
else
    echo -e "${YELLOW}  ⚠ Firefly III: not found${NC}"
fi

GHOSTFOLIO_STATUS=$(ssh docker-host "docker ps --filter 'name=ghostfolio' --format '{{.Status}}'" 2>/dev/null || echo "")
if [[ -n "$GHOSTFOLIO_STATUS" ]]; then
    echo -e "${GREEN}  ✓ Ghostfolio: running${NC}"
else
    echo -e "${YELLOW}  ⚠ Ghostfolio: not found${NC}"
fi
echo ""

# =============================================================================
# INFISICAL
# =============================================================================
echo -e "${YELLOW}[4/6] Infisical${NC}"
INFISICAL_STATUS=$(ssh docker-host "docker ps --filter 'name=infisical' --format '{{.Names}}'" 2>/dev/null | wc -l || echo "0")
if [[ "$INFISICAL_STATUS" -ge 1 ]]; then
    echo -e "${GREEN}  ✓ Infisical: $INFISICAL_STATUS containers running${NC}"
else
    echo -e "${RED}  ✗ Infisical: not running${NC}"
    ((ISSUES_FOUND++))
fi
echo ""

# =============================================================================
# PAPERLESS
# =============================================================================
echo -e "${YELLOW}[5/6] Paperless${NC}"
PAPERLESS_STATUS=$(ssh docker-host "docker ps --filter 'name=paperless' --format '{{.Status}}'" 2>/dev/null || echo "")
if [[ -n "$PAPERLESS_STATUS" ]]; then
    echo -e "${GREEN}  ✓ Paperless: running${NC}"
else
    echo -e "${YELLOW}  ⚠ Paperless: not found${NC}"
fi
echo ""

# =============================================================================
# IMMICH (on immich-1 VM)
# =============================================================================
echo -e "${YELLOW}[6/6] Immich (R730XD)${NC}"
IMMICH_STATUS=$(ssh immich-1 "docker ps --filter 'name=immich' --format '{{.Names}}: {{.Status}}'" 2>/dev/null || echo "ERROR")
if [[ "$IMMICH_STATUS" == "ERROR" ]]; then
    echo -e "${YELLOW}  ⚠ Cannot connect to immich-1${NC}"
else
    IMMICH_COUNT=$(echo "$IMMICH_STATUS" | wc -l)
    if [[ "$IMMICH_COUNT" -ge 3 ]]; then
        echo -e "${GREEN}  ✓ Immich: $IMMICH_COUNT containers running${NC}"
    else
        echo -e "${YELLOW}  ⚠ Immich: only $IMMICH_COUNT containers${NC}"
    fi
fi
echo ""

# =============================================================================
# SUMMARY
# =============================================================================
echo -e "${CYAN}=== Summary ===${NC}"
if [[ "$ISSUES_FOUND" -eq 0 ]]; then
    echo -e "${GREEN}All checks passed! No issues found.${NC}"
else
    echo -e "${RED}Found $ISSUES_FOUND issue(s) requiring attention.${NC}"
    exit 1
fi
