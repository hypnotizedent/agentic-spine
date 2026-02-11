#!/usr/bin/env bash
set -euo pipefail

# D25: Secrets CLI Canonical Lock
# Purpose: Ensure spine-owned helper CLIs exist, and (optionally) warn if the
#          workbench vendored copies drift (advisory only).
#
# Output contract:
#   - Exit 0 on PASS (may emit WARN lines).
#   - Exit 1 on FAIL (emits D25 FAIL reason).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WB="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail() { echo "D25 FAIL: $*" >&2; exit 1; }
warn() { echo "WARN $*"; }

CANONICAL_INFISICAL="$ROOT/ops/tools/infisical-agent.sh"
VENDORED_INFISICAL="$WB/scripts/agents/infisical-agent.sh"

CANONICAL_CF="$ROOT/ops/tools/cloudflare-agent.sh"
VENDORED_CF="$WB/scripts/agents/cloudflare-agent.sh"

# Canonical scripts must exist and be executable.
[[ -x "$CANONICAL_INFISICAL" ]] || fail "canonical infisical-agent.sh missing or not executable ($CANONICAL_INFISICAL)"
[[ -x "$CANONICAL_CF" ]] || fail "canonical cloudflare-agent.sh missing or not executable ($CANONICAL_CF)"

# Workbench infisical-agent hash parity is now enforced (not advisory).
if [[ ! -f "$VENDORED_INFISICAL" ]]; then
  fail "workbench infisical-agent missing ($VENDORED_INFISICAL)"
else
  ic_hash="$(shasum -a 256 "$CANONICAL_INFISICAL" | awk '{print $1}')"
  iv_hash="$(shasum -a 256 "$VENDORED_INFISICAL" | awk '{print $1}')"
  [[ "$ic_hash" == "$iv_hash" ]] || fail "infisical-agent hash mismatch: canonical=$ic_hash vendored=$iv_hash"
fi

if [[ ! -f "$VENDORED_CF" ]]; then
  warn "(workbench cloudflare-agent missing — spine canonical remains source of truth)"
else
  cf_hash="$(shasum -a 256 "$CANONICAL_CF" | awk '{print $1}')"
  cv_hash="$(shasum -a 256 "$VENDORED_CF" | awk '{print $1}')"
  [[ "$cf_hash" == "$cv_hash" ]] || warn "(cloudflare-agent hash drift in workbench; sync advisory)"
fi

exit 0

