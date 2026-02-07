#!/usr/bin/env bash
# Secrets Inventory Verification Script
# Governance: docs/governance/SECRETS_POLICY.md
# Purpose: Validate canonical secrets inventory binding and scan tracked files
# for obvious secret leakage patterns (read-only).

set -euo pipefail

INVENTORY_PATH="${INVENTORY_PATH:-ops/bindings/secrets.inventory.yaml}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVENTORY_FILE="$REPO_ROOT/$INVENTORY_PATH"

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

command -v yq >/dev/null 2>&1 || {
    echo -e "${RED}FAIL:${NC} missing dependency: yq"
    exit 2
}

echo "--- Schema Validation ---"

if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo -e "${RED}FAIL:${NC} Inventory file not found: $INVENTORY_PATH"
    exit 2
fi

if ! yq e '.' "$INVENTORY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL:${NC} Invalid YAML syntax"
    exit 2
fi
echo -e "${GREEN}PASS:${NC} Valid YAML"
PASS=$((PASS + 1))

REQUIRED_KEYS=("version" "source" "infisical" "projects")
for key in "${REQUIRED_KEYS[@]}"; do
    if [[ "$(yq e ".$key // \"missing\"" "$INVENTORY_FILE")" != "missing" ]]; then
        echo -e "${GREEN}PASS:${NC} Required key exists: $key"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL:${NC} Missing required key: $key"
        FAIL=$((FAIL + 1))
    fi
done

PROJECT_COUNT="$(yq e '.projects | length' "$INVENTORY_FILE" 2>/dev/null || echo "0")"
if [[ "$PROJECT_COUNT" =~ ^[0-9]+$ ]] && (( PROJECT_COUNT > 0 )); then
    echo -e "${GREEN}PASS:${NC} Projects catalogued: $PROJECT_COUNT"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL:${NC} projects[] is empty or invalid"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Project Validation ---"
while IFS= read -r project; do
    [[ -n "$project" && "$project" != "null" ]] || {
        echo -e "${YELLOW}SKIP:${NC} project with missing name"
        SKIP=$((SKIP + 1))
        continue
    }

    project_id="$(yq e ".projects[] | select(.name == \"$project\") | .id // \"missing\"" "$INVENTORY_FILE")"
    if [[ "$project_id" == "missing" || "$project_id" == "null" || -z "$project_id" ]]; then
        echo -e "${YELLOW}WARN:${NC} $project - missing project ID"
    else
        echo -e "${GREEN}PASS:${NC} $project - has ID"
    fi
done < <(yq e '.projects[].name' "$INVENTORY_FILE" 2>/dev/null || true)

echo ""
echo "--- Committed Secrets Scan ---"

SECRET_PATTERNS=(
    "INFISICAL_CLIENT_SECRET"
    "INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET"
    "STRIPE_SECRET"
    "JWT_SECRET"
    "DATABASE_URL.*password"
    "API_KEY.*="
    "Bearer [A-Za-z0-9_-]{20,}"
)

SECRETS_FOUND=0
cd "$REPO_ROOT"

for pattern in "${SECRET_PATTERNS[@]}"; do
    matches="$(git grep -l -E "$pattern" -- '*.env' '*.json' '*.yaml' '*.yml' '*.sh' 2>/dev/null \
        | grep -v "secrets.inventory.yaml" \
        | grep -v ".example" \
        | head -5 || true)"
    if [[ -n "$matches" ]]; then
        echo -e "${YELLOW}WARN:${NC} Pattern '$pattern' found in files (review manually):"
        while IFS= read -r file; do
            [[ -n "$file" ]] && echo "       - $file"
        done <<< "$matches"
        SECRETS_FOUND=$((SECRETS_FOUND + 1))
    fi
done

if [[ $SECRETS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}PASS:${NC} No obvious secrets in tracked files"
    PASS=$((PASS + 1))
else
    echo -e "${YELLOW}WARN:${NC} $SECRETS_FOUND pattern(s) need manual review"
fi

echo ""
echo "=== Summary ==="
echo -e "PASS: ${GREEN}$PASS${NC}"
echo -e "FAIL: ${RED}$FAIL${NC}"
echo -e "SKIP: ${YELLOW}$SKIP${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}VERIFICATION FAILED${NC}"
    exit 1
fi

echo -e "${GREEN}VERIFICATION PASSED${NC}"
exit 0
