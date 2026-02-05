#!/bin/bash
# DOC-DRIFT-CHECK.SH - Weekly documentation structure audit
# Run this weekly (or add to cron) to catch drift before it accumulates
#
# Usage: ./scripts/agents/doc-drift-check.sh
# Output: Report of files in wrong locations

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(git rev-parse --show-toplevel)"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DOCUMENTATION DRIFT CHECK            ║${NC}"
echo -e "${BLUE}║     $(date +%Y-%m-%d)                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

ISSUES=0
WARNINGS=0

# ============================================================
# CHECK 1: Root-level .md files (should be minimal)
# ============================================================
echo -e "${YELLOW}[1/8] Checking root-level files...${NC}"
ROOT_MD=$(find . -maxdepth 1 -name "*.md" -not -name "00_*" -not -name "README.md" | sort)
if [ -n "$ROOT_MD" ]; then
    echo -e "${RED}ISSUE: Files at root that shouldn't be:${NC}"
    echo "$ROOT_MD" | while read f; do echo "  - $f"; done
    ISSUES=$((ISSUES + $(echo "$ROOT_MD" | wc -l)))
else
    echo -e "${GREEN}  ✓ Root level files clean${NC}"
fi
echo ""

# ============================================================
# CHECK 1.5: NON-PILLAR FOLDERS AT ROOT
# ============================================================
echo -e "${YELLOW}[1.5/8] Checking for non-pillar root folders...${NC}"
ALLOWED_DIRS="mint-os infrastructure finance media-stack home-assistant immich scripts .github .archive .githooks .agent .git"
BAD_DIRS=""
for dir in $(find . -maxdepth 1 -type d -not -name "." | sed 's|^\./||' | sort); do
    is_allowed=false
    for allowed in $ALLOWED_DIRS; do
        if [ "$dir" = "$allowed" ]; then
            is_allowed=true
            break
        fi
    done
    if [ "$is_allowed" = false ]; then
        BAD_DIRS="$BAD_DIRS $dir"
    fi
done

if [ -n "$BAD_DIRS" ]; then
    echo -e "${RED}ISSUE: Non-pillar folders at root:${NC}"
    for d in $BAD_DIRS; do
        echo "  - $d/"
    done
    ISSUES=$((ISSUES + $(echo $BAD_DIRS | wc -w)))
else
    echo -e "${GREEN}  ✓ Root folders clean${NC}"
fi
echo ""

# ============================================================
# CHECK 2: SESSION/HANDOFF files outside sessions/
# ============================================================
echo -e "${YELLOW}[2/7] Checking session file locations...${NC}"
BAD_SESSIONS=$(find . -name "*SESSION*.md" -o -name "*HANDOFF*.md" 2>/dev/null | grep -v "/sessions/" | grep -v "node_modules" | grep -v ".archive" || true)
# Exclude false positives:
# - SESSION_HANDOFF_PROTOCOL.md is a reference document, not a session
BAD_SESSIONS=$(echo "$BAD_SESSIONS" | grep -v "SESSION_HANDOFF_PROTOCOL.md" || true)
if [ -n "$BAD_SESSIONS" ]; then
    echo -e "${RED}ISSUE: Session files outside sessions/ folders:${NC}"
    echo "$BAD_SESSIONS" | while read f; do echo "  - $f"; done
    ISSUES=$((ISSUES + $(echo "$BAD_SESSIONS" | wc -l)))
else
    echo -e "${GREEN}  ✓ All session files in correct locations${NC}"
fi
echo ""

# ============================================================
# CHECK 3: REF_* files outside reference/
# ============================================================
echo -e "${YELLOW}[3/7] Checking reference file locations...${NC}"
BAD_REFS=$(find . -name "REF_*.md" 2>/dev/null | grep -v "/reference/" | grep -v "node_modules" | grep -v ".archive" || true)
if [ -n "$BAD_REFS" ]; then
    echo -e "${RED}ISSUE: REF_* files outside reference/ folders:${NC}"
    echo "$BAD_REFS" | while read f; do echo "  - $f"; done
    ISSUES=$((ISSUES + $(echo "$BAD_REFS" | wc -l)))
else
    echo -e "${GREEN}  ✓ All reference files in correct locations${NC}"
fi
echo ""

# ============================================================
# CHECK 4: PLAN_* files outside plans/
# ============================================================
echo -e "${YELLOW}[4/7] Checking plan file locations...${NC}"
BAD_PLANS=$(find . -name "PLAN_*.md" 2>/dev/null | grep -v "/plans/" | grep -v "node_modules" | grep -v ".archive" || true)
if [ -n "$BAD_PLANS" ]; then
    echo -e "${RED}ISSUE: PLAN_* files outside plans/ folders:${NC}"
    echo "$BAD_PLANS" | while read f; do echo "  - $f"; done
    ISSUES=$((ISSUES + $(echo "$BAD_PLANS" | wc -l)))
else
    echo -e "${GREEN}  ✓ All plan files in correct locations${NC}"
fi
echo ""

# ============================================================
# CHECK 5: Pillar-named files outside their pillar
# ============================================================
echo -e "${YELLOW}[5/7] Checking pillar file ownership...${NC}"
for pillar in mint-os infrastructure finance media-stack home-assistant immich; do
    pattern=$(echo "$pillar" | tr '-' '_')
    WRONG_PILLAR=$(find . -name "*${pattern}*.md" -o -name "*$(echo $pattern | tr '[:lower:]' '[:upper:]')*.md" 2>/dev/null | grep -v "^./$pillar/" | grep -v "node_modules" | grep -v ".archive" | grep -v "docs/prompts" || true)
    # Exclude false positives:
    # - INFRASTRUCTURE_MAP.md is intentional in mint-os/ (single source of truth)
    # - HA_INFRASTRUCTURE* docs are intentional in home-assistant/ (pillar-specific infrastructure docs)
    WRONG_PILLAR=$(echo "$WRONG_PILLAR" | grep -v "mint-os/INFRASTRUCTURE_MAP.md" | grep -v "home-assistant/.*HA_INFRASTRUCTURE" || true)
    if [ -n "$WRONG_PILLAR" ]; then
        echo -e "${YELLOW}WARNING: Files mentioning $pillar but not in $pillar/:${NC}"
        echo "$WRONG_PILLAR" | while read f; do echo "  - $f"; done
        WARNINGS=$((WARNINGS + $(echo "$WRONG_PILLAR" | wc -l)))
    fi
done
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✓ All pillar files in correct pillars${NC}"
fi
echo ""

# ============================================================
# CHECK 6: Archive folder consistency
# ============================================================
echo -e "${YELLOW}[6/7] Checking archive structure...${NC}"
# Archives should be in pillar/docs/.archive/, not pillar/.archive/
BAD_ARCHIVES=$(find . -type d -name ".archive" -not -path "*/docs/.archive" -not -path "./.archive" | grep -v "node_modules" || true)
# Exclude acceptable pillar-level archives:
# - immich/.archive/ (legacy content)
# - home-assistant/.archive/ (legacy content)
# - media-stack/docs/.archive/ (acceptable location)
# - mint-os/apps/admin/docs/.archive/ (app-specific)
BAD_ARCHIVES=$(echo "$BAD_ARCHIVES" | grep -v "immich/.archive" | grep -v "home-assistant/.archive" | grep -v "media-stack/docs/.archive" | grep -v "mint-os/apps/admin/docs/.archive" || true)
if [ -n "$BAD_ARCHIVES" ]; then
    echo -e "${YELLOW}WARNING: Archives outside docs/.archive/:${NC}"
    echo "$BAD_ARCHIVES" | while read f; do echo "  - $f"; done
    WARNINGS=$((WARNINGS + $(echo "$BAD_ARCHIVES" | wc -l)))
else
    echo -e "${GREEN}  ✓ Archive structure consistent${NC}"
fi
echo ""

# ============================================================
# CHECK 7: Recent files (last 7 days) - quick review
# ============================================================
echo -e "${YELLOW}[7/7] Recent .md files (last 7 days)...${NC}"
RECENT=$(find . -name "*.md" -mtime -7 -not -path "*/node_modules/*" -not -path "*/.archive/*" -not -path "*/archive/*" 2>/dev/null | sort)
if [ -n "$RECENT" ]; then
    echo "  Files modified in last 7 days (review for correctness):"
    echo "$RECENT" | while read f; do echo "    $f"; done
else
    echo -e "${GREEN}  ✓ No recent changes${NC}"
fi
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "════════════════════════════════════════════"
echo -e "${BLUE}SUMMARY${NC}"
echo "════════════════════════════════════════════"
echo ""
if [ $ISSUES -gt 0 ]; then
    echo -e "${RED}$ISSUES file(s) need to be moved${NC}"
fi
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s) to review${NC}"
fi
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Documentation structure is clean!${NC}"
fi
echo ""

# Exit with error if issues found (useful for CI)
if [ $ISSUES -gt 0 ]; then
    exit 1
fi
exit 0
