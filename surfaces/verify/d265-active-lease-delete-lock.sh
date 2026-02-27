#!/usr/bin/env bash
# TRIAGE: Ensure active lease ownership blocks destructive cleanup.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/worktree.lifecycle.contract.yaml"
CLEANUP_CMD="$ROOT/ops/plugins/ops/bin/worktree-lifecycle-cleanup"

fail() { echo "D265 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -x "$CLEANUP_CMD" ]] || fail "missing cleanup command: $CLEANUP_CMD"

block_flag="$(yq e -r '.cleanup.block_if_active_lease // false' "$CONTRACT")"
[[ "$block_flag" == "true" ]] || fail "cleanup.block_if_active_lease must be true"

rg -n "active_lease" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing active_lease guard"
rg -n "block_if_active_lease" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing block_if_active_lease contract read"

echo "D265 PASS: active lease delete lock enforced"
