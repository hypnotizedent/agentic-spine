#!/usr/bin/env bash
# TRIAGE: Enforce report-only -> archive-only -> delete with archive proof before destructive actions.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/worktree.lifecycle.contract.yaml"
CLEANUP_CMD="$ROOT/ops/plugins/ops/bin/worktree-lifecycle-cleanup"

fail() { echo "D266 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -x "$CLEANUP_CMD" ]] || fail "missing cleanup command: $CLEANUP_CMD"

require_archive="$(yq e -r '.cleanup.require_archive_before_delete // false' "$CONTRACT")"
[[ "$require_archive" == "true" ]] || fail "cleanup.require_archive_before_delete must be true"

rg -n "report-only\|archive-only\|delete" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing 3-phase mode support"
rg -n "archive manifest" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing archive-before-delete enforcement"
rg -n "archive-only" "$CLEANUP_CMD" >/dev/null 2>&1 || fail "cleanup command missing archive-only mode"

echo "D266 PASS: archive-before-delete lock enforced"
