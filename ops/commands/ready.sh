#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: ops ready

Run all pre-flight readiness checks for this terminal session.

Checks performed:
  1. ops preflight      - Split-brain detection (remote parity + worktree hygiene)
  2. agent.session.closeout - Loop/receipt truth coherence (D61 freshness)
  3. spine.verify       - Constitutional drift gate (50+ gates)
  4. spine.replay       - Receipt replay verification
  5. spine.status       - Unified work status
  6. secrets.binding    - Secrets binding check
  7. secrets.auth.load  - Load Infisical auth
  8. secrets.auth.status - Verify auth is hydrated
  9. secrets.projects.status - Project-level secrets check

On success: terminal is cleared for API-touching capabilities.
On failure: follow printed remediation steps.

Options:
  --help, -h    Show this help message
USAGE
  exit 0
fi

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
