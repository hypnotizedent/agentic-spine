#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_cap() {
  local cap="$1"
  shift || true
  echo
  echo "────────────────────────────────────────"
  echo "READY CHECK: $cap"
  echo "────────────────────────────────────────"
  ./bin/ops cap run "$cap" "$@"
}

echo "========================================"
echo "SPINE READY CHECK (operator convenience)"
echo "========================================"

# Preflight is the fastest split-brain detector (remote parity + worktree hygiene).
echo
echo "────────────────────────────────────────"
echo "READY CHECK: ops preflight"
echo "────────────────────────────────────────"
./bin/ops preflight

# Session closeout keeps loop/receipt truth coherent (D61 freshness).
run_cap agent.session.closeout

run_cap spine.verify
run_cap spine.replay
run_cap spine.status

run_cap secrets.binding
run_cap secrets.auth.load

set +e
run_cap secrets.auth.status
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  :
elif [[ $rc -eq 2 ]]; then
  echo
  echo "STOP (exit 2): Infisical auth is NOT hydrated in this terminal."
  echo
  echo "Run this once in *this same terminal*:"
  echo "  source \"$HOME/.config/infisical/credentials\""
  echo
  echo "Then rerun:"
  echo "  ./bin/ops ready"
  exit 2
else
  echo
  echo "FAIL: secrets.auth.status exited $rc"
  exit $rc
fi

run_cap secrets.projects.status

echo
echo "READY: This terminal is cleared for API-touching capabilities."
