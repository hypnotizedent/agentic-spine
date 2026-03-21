#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
BIN="$ROOT/ops/plugins/providers/bin/unifi-home-agent.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

echo "unifi-home-agent wrapper tests"
echo "════════════════════════════════════════"

assert_file_contains "$BIN" 'INFISICAL_AGENT="${SPINE_ROOT}/ops/plugins/providers/bin/infisical-agent.sh"' "wrapper resolves governed infisical agent"
assert_file_contains "$BIN" 'get-cached infrastructure prod UNIFI_HOME_USER' "wrapper reads canonical home user secret"
assert_file_contains "$BIN" 'get-cached infrastructure prod UNIFI_HOME_PASSWORD' "wrapper reads canonical home password secret"
assert_file_contains "$BIN" 'get-cached infrastructure prod UNIFI_HOME_API_KEY' "wrapper reads canonical home api key"
assert_file_contains "$BIN" 'export UNIFI_HOME_USER UNIFI_HOME_PASSWORD UNIFI_HOME_API_KEY' "wrapper exports resolved home UniFi secrets before handoff"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
