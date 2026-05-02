#!/usr/bin/env bash
set -euo pipefail

# D408: No L3 Domain Symlink Residue Lock
# Purpose: extracted L3/project/product bindings must not remain in the spine
# as compatibility symlinks or public docs that teach spine/project parity.
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FAILURES=0
CHECKS=0

pass() { CHECKS=$((CHECKS + 1)); echo "  PASS: $*"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); echo "  FAIL: $*" >&2; }

mapfile -t DOMAIN_SYMLINKS < <(find "$ROOT/ops/bindings/domains" -type l -print | sort)
if [[ "${#DOMAIN_SYMLINKS[@]}" -eq 0 ]]; then
  pass "ops/bindings/domains contains zero symlinks"
else
  fail "ops/bindings/domains contains symlink residue:"
  printf '    %s\n' "${DOMAIN_SYMLINKS[@]}" >&2
fi

STALE_PATTERNS=(
  "workbench media home"
  "workbench-spine content parity"
  "sync spine projections"
  "Compatibility projections / thin pointers"
  "Mint-owned product contract compatibility paths"
  "compatibility path to the Mint product contract home"
  "thin product authority pointers under"
)

LIVE_SURFACES=(
  "$ROOT/AGENTS.md"
  "$ROOT/NORTH_STAR.md"
  "$ROOT/README.md"
  "$ROOT/docs/governance"
  "$ROOT/docs/runbooks"
  "$ROOT/ops/bindings"
  "$ROOT/ops/capabilities.yaml"
  "$ROOT/ops/plugins/MANIFEST.yaml"
)

for pattern in "${STALE_PATTERNS[@]}"; do
  if rg -n --fixed-strings "$pattern" "${LIVE_SURFACES[@]}" >/tmp/d408-rg.out 2>/dev/null; then
    fail "stale public/operator wording remains for pattern: $pattern"
    sed 's/^/    /' /tmp/d408-rg.out >&2
  else
    pass "stale wording absent: $pattern"
  fi
done

if [[ "$FAILURES" -gt 0 ]]; then
  echo "D408 FAIL: L3 symlink residue or stale parity wording remains (checks=$CHECKS failures=$FAILURES)" >&2
  exit 1
fi

echo "D408 PASS: extracted L3/project/product bindings are not represented as spine symlinks or parity teaching"
exit 0
