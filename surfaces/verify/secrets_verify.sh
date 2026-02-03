#!/bin/bash
# Secrets Inventory Verification Script
# Governance: infrastructure/docs/runbooks/INFISICAL_GOVERNANCE.md
# Issue: #628
# Purpose: Validate secrets inventory structure and check for committed secrets (read-only)

set -euo pipefail

INVENTORY_PATH="${INVENTORY_PATH:-infrastructure/data/secrets_inventory.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

echo "=== Secrets Inventory Verification ==="
echo "Inventory: $INVENTORY_PATH"
echo "Repo root: $REPO_ROOT"
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
REQUIRED_KEYS=("meta" "summary" "infisical_projects")
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

# Count projects
PROJECT_COUNT=$(jq '.infisical_projects | length' "$REPO_ROOT/$INVENTORY_PATH")
echo -e "${GREEN}INFO:${NC} Infisical projects catalogued: $PROJECT_COUNT"

# Validate each project has required fields
echo ""
echo "--- Project Validation ---"

jq -r '.infisical_projects[].name' "$REPO_ROOT/$INVENTORY_PATH" 2>/dev/null | while read -r project; do
    if [[ -z "$project" || "$project" == "null" ]]; then
        echo -e "${YELLOW}SKIP:${NC} Project with missing name"
        continue
    fi

    # Check project has id
    HAS_ID=$(jq -r --arg name "$project" '.infisical_projects[] | select(.name == $name) | .id // "missing"' "$REPO_ROOT/$INVENTORY_PATH")
    if [[ "$HAS_ID" == "missing" || "$HAS_ID" == "null" ]]; then
        echo -e "${YELLOW}WARN:${NC} $project - missing project ID"
    else
        echo -e "${GREEN}PASS:${NC} $project - has ID"
    fi
done

# Secret scanning (DO NOT print matches)
echo ""
echo "--- Committed Secrets Scan ---"

SECRET_PATTERNS=(
    "INFISICAL_CLIENT_SECRET"
    "STRIPE_SECRET"
    "JWT_SECRET"
    "DATABASE_URL.*password"
    "API_KEY.*="
    "Bearer [A-Za-z0-9_-]+"
)

SECRETS_FOUND=0
cd "$REPO_ROOT"

for pattern in "${SECRET_PATTERNS[@]}"; do
    # Search staged and committed files, excluding inventory files
    MATCHES=$(git grep -l -E "$pattern" -- '*.env' '*.json' '*.yaml' '*.yml' 2>/dev/null | grep -v "_inventory.json" | grep -v ".example" | head -5 || true)

    if [[ -n "$MATCHES" ]]; then
        echo -e "${YELLOW}WARN:${NC} Pattern '$pattern' found in files (review manually):"
        echo "$MATCHES" | while read -r file; do
            echo "       - $file"
        done
        SECRETS_FOUND=$((SECRETS_FOUND + 1))
    fi
done

if [[ $SECRETS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}PASS:${NC} No obvious secrets in tracked files"
    PASS=$((PASS + 1))
else
    echo -e "${YELLOW}WARN:${NC} $SECRETS_FOUND pattern(s) need manual review"
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
