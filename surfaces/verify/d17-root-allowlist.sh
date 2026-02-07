#!/usr/bin/env bash
# d17-root-allowlist.sh - Enforce strict root directory allowlist
#
# Prevents drift by forbidding unexpected directories at repo root.
# Part of D17: Root Allowlist gate.
#
# Allowlist (only these dirs allowed at root):
#   .archive/ .git/ .spine/ bin/ docs/ fixtures/ mailroom/ ops/ receipts/ surfaces/
#
# Forbidden (must not exist):
#   agents/ _imports/ runs/ scripts/ lib/ src/
#
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$SP"

# Allowed root directories (plus hidden dirs and standard files)
ALLOWED_PATTERN='^(\.archive|\.git|\.spine|bin|docs|fixtures|mailroom|ops|receipts|surfaces)/$'

# Explicitly forbidden (legacy/drift magnets)
FORBIDDEN="agents _imports runs scripts lib src"

FAIL=0

# Check for forbidden directories
for dir in $FORBIDDEN; do
  if [[ -d "$SP/$dir" ]]; then
    echo "FORBIDDEN: $dir/ exists at root (must be quarantined or removed)"
    FAIL=1
  fi
done

# Check for unexpected directories (not in allowlist)
UNEXPECTED="$(ls -1d */ 2>/dev/null | grep -Ev "$ALLOWED_PATTERN" || true)"
if [[ -n "$UNEXPECTED" ]]; then
  echo "UNEXPECTED root dirs: $UNEXPECTED"
  FAIL=1
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "D17 root allowlist: PASS"
  exit 0
else
  echo "D17 root allowlist: FAIL"
  exit 1
fi
