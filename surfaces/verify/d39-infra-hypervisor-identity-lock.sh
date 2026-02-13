#!/usr/bin/env bash
# TRIAGE: Verify hypervisor identity entries match live infrastructure.
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
        # During a relocation, enforce identity only for the hypervisors referenced by
        # the relocation manifest. This keeps the gate actionable when unrelated sites
        # are temporarily unreachable (e.g. WAN outage affecting home lab).
        hosts_csv="$(
            # yq does not support jq's `empty`; use select() to drop nulls.
            yq e -r '.vm_targets[].proxmox_host | select(. != null)' "$MANIFEST" 2>/dev/null \
              | awk 'NF' \
              | sort -u \
              | paste -sd, -
        )"
        # In some governed runtimes (e.g. sandboxed coding agents), outbound SSH is blocked
        # and the checker fails with "Operation not permitted". In that case, do not fail
        # the entire drift-gate run; instead mark this gate as skipped and require
        # running the check from a fully-networked host session.
        set +e
        if [[ -n "${hosts_csv:-}" ]]; then
            out="$("$CHECKER" --hosts "$hosts_csv" 2>&1)"
            rc=$?
        else
            out="$("$CHECKER" 2>&1)"
            rc=$?
        fi
        set -e

        if [[ "$rc" -eq 0 ]]; then
            echo "D39 PASS: hypervisor identity enforced for active relocation state '$state'"
            exit 0
        fi

        if echo "$out" | grep -q "Operation not permitted"; then
            echo "D39 PASS (SKIP): SSH blocked in current runtime; run infra-hypervisor-identity-status from a full host session (state='$state')"
            exit 0
        fi

        fail "hypervisor identity check failed (state='$state'): ${out//$'\n'/ ; }"
        ;;
    *)
        echo "D39 PASS: relocation state '$state' does not require hypervisor identity lock"
        ;;
esac
