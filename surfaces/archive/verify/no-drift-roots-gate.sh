#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "OK: $*"; }

HOME_DIR="${HOME:-/Users/$(whoami)}"

# Roots that must NEVER exist outside spine.
DRIFT_ROOTS=(
  "$HOME_DIR/agent"
  "$HOME_DIR/logs"
  "$HOME_DIR/log"
)

echo "=== NO DRIFT ROOTS GATE ==="
echo "HOME=$HOME_DIR"

found=0
for d in "${DRIFT_ROOTS[@]}"; do
  if [ -e "$d" ]; then
    echo "DRIFT FOUND: $d"
    found=1
  else
    ok "absent: $d"
  fi
done

if [ "$found" -ne 0 ]; then
  fail "Drift roots present under HOME. All agent/log activity must live inside the spine mailroom/ + receipts/."
fi

ok "No drift roots detected"
