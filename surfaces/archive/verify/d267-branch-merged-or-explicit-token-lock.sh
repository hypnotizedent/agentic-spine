#!/usr/bin/env bash
# TRIAGE: Block cleanup delete unless branch is merged or explicit cleanup token is present.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/worktree.lifecycle.contract.yaml"
CLEANUP_CMD="$ROOT/ops/plugins/ops/bin/worktree-lifecycle-cleanup"

fail() { echo "D267 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -x "$CLEANUP_CMD" ]] || fail "missing cleanup command: $CLEANUP_CMD"

merged_or_token="$(yq e -r '.cleanup.require_branch_merged_or_explicit_token // false' "$CONTRACT")"
[[ "$merged_or_token" == "true" ]] || fail "cleanup.require_branch_merged_or_explicit_token must be true"

token_env="$(yq e -r '.cleanup.delete_token_env_var // ""' "$CONTRACT")"
token_value="$(yq e -r '.cleanup.delete_token_value // ""' "$CONTRACT")"
[[ -n "$token_env" && -n "$token_value" ]] || fail "delete token env/value must be configured"

rg -n "not_merged_no_token" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing branch merged/token guard"
rg -n "delete mode requires explicit token" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing token gate"

echo "D267 PASS: branch merged-or-explicit-token lock enforced"
