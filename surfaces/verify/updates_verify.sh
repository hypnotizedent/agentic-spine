#!/usr/bin/env bash
set -euo pipefail

RULE_PREFIX="UPDATES"
SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

MACBOOK_SSOT="$SPINE_ROOT/docs/governance/MACBOOK_SSOT.md"
MINILAB_SSOT="$SPINE_ROOT/docs/governance/MINILAB_SSOT.md"
SHOP_SSOT="$SPINE_ROOT/docs/governance/SHOP_SERVER_SSOT.md"

fail() { echo "${RULE_PREFIX}-${1} FAIL: ${2}"; exit 1; }
pass() { echo "${RULE_PREFIX}-${1} PASS: ${2}"; }
warn() { echo "${RULE_PREFIX}-${1} WARN: ${2}"; }

# UPDATES-001: canonical update-governance docs present
[[ -f "$MACBOOK_SSOT" ]] || fail "001" "missing update governance doc: $MACBOOK_SSOT"
[[ -f "$MINILAB_SSOT" ]] || fail "001" "missing update governance doc: $MINILAB_SSOT"
[[ -f "$SHOP_SSOT" ]] || fail "001" "missing update governance doc: $SHOP_SSOT"
pass "001" "update governance SSOT docs present"

# UPDATES-002: at least one local package manager exists on operator host
pm=()
for cmd in brew apt apt-get yum dnf pacman zypper; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pm+=("$cmd")
  fi
done
(( ${#pm[@]} > 0 )) || fail "002" "no known package manager command found"
pass "002" "package manager(s) detected: ${pm[*]}"

# UPDATES-003: update surfaces are referenced in verify index
VERIFY_INDEX="$SPINE_ROOT/docs/governance/VERIFY_SURFACE_INDEX.md"
[[ -f "$VERIFY_INDEX" ]] || fail "003" "missing verify index: $VERIFY_INDEX"
if rg -n "updates_verify\\.sh" "$VERIFY_INDEX" >/dev/null 2>&1; then
  pass "003" "verify index includes updates_verify.sh"
else
  warn "003" "updates_verify.sh not listed in verify index"
fi

echo "UPDATES-999 PASS: updates verification complete"
