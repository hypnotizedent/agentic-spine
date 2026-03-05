#!/usr/bin/env bash
# TRIAGE: Ensure infra identity is consistent across all SSOTs and bindings.
set -euo pipefail

# D57: Infra Identity Cohesion Lock (composite)
# Groups infra placement/identity checks behind one STOP.
#
# Subchecks:
#   - D37 infra placement policy lock
#   - D39 infra hypervisor identity lock

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D57 FAIL: $*" >&2; exit 1; }

subcheck() {
  local id="$1"
  local script="$2"
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    rm -f "$tmp"
    return 0
  fi

  echo "subcheck ${id}: FAIL (rc=${rc})" >&2
  sed -n '1,80p' "$tmp" >&2 || true
  rm -f "$tmp"
  return 1
}

FAILS=0

subcheck "D37" "$ROOT/surfaces/verify/d37-infra-placement-policy-lock.sh" || FAILS=$((FAILS+1))
subcheck "D39" "$ROOT/surfaces/verify/d39-infra-hypervisor-identity-lock.sh" || FAILS=$((FAILS+1))

(( FAILS == 0 )) || fail "infra identity cohesion violated (${FAILS} failing subcheck(s))"
exit 0

