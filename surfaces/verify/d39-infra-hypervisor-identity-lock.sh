#!/usr/bin/env bash
set -euo pipefail

# D39: Infra Hypervisor Identity Lock
# Purpose: during active relocation states, enforce hypervisor identity invariants.
#
# Active relocation states:
#   - preflight
#   - cutover
#   - cleanup
#
# In these states, this gate fails if infra-hypervisor-identity-status fails.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${D39_MANIFEST:-$ROOT/ops/bindings/infra.relocation.plan.yaml}"
CHECKER="${D39_CHECKER:-$ROOT/ops/plugins/infra/bin/infra-hypervisor-identity-status}"

fail() { echo "D39 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -x "$CHECKER" ]] || fail "identity checker missing or not executable: $CHECKER"

if [[ ! -f "$MANIFEST" ]]; then
    echo "D39 PASS: no relocation manifest configured"
    exit 0
fi

yq e '.' "$MANIFEST" >/dev/null 2>&1 || fail "manifest YAML invalid: $MANIFEST"
state="$(yq e '.active_relocation.state // "none"' "$MANIFEST")"

case "$state" in
    preflight|cutover|cleanup)
        "$CHECKER" >/dev/null
        echo "D39 PASS: hypervisor identity enforced for active relocation state '$state'"
        ;;
    *)
        echo "D39 PASS: relocation state '$state' does not require hypervisor identity lock"
        ;;
esac
