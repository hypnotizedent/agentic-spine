#!/usr/bin/env bash
# TRIAGE: Run planning.plans.reconcile --check and enforce lock discipline on plan mutators.
# D343: plans lifecycle integrity lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RECONCILE_BIN="$ROOT/ops/plugins/lifecycle/bin/planning-plans-reconcile"
CONTRACT="$ROOT/ops/bindings/plans.lifecycle.yaml"

fail() {
  echo "D343 FAIL: $*" >&2
  exit 1
}

[[ -x "$RECONCILE_BIN" ]] || fail "missing reconcile runner: $RECONCILE_BIN"
[[ -f "$CONTRACT" ]] || fail "missing plans lifecycle contract: $CONTRACT"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

# Verify plan mutators are lock-guarded.
MUTATORS=(
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-create"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-promote"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-retire"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-cancel"
)

for script in "${MUTATORS[@]}"; do
  [[ -f "$script" ]] || fail "missing mutator script: ${script#$ROOT/}"
  grep -q 'git-lock\.sh' "$script" || fail "mutator missing git-lock source: ${script#$ROOT/}"
  grep -q 'acquire_git_lock plans' "$script" || fail "mutator missing acquire_git_lock plans: ${script#$ROOT/}"
done

set +e
payload="$($RECONCILE_BIN --check --json 2>/dev/null)"
rc=$?
set -e

[[ -n "$payload" ]] || fail "planning.plans.reconcile returned empty payload"

if ! jq -e '.summary' >/dev/null 2>&1 <<<"$payload"; then
  fail "planning.plans.reconcile did not return parseable JSON summary"
fi

noncanonical="$(jq -r '.summary.noncanonical_status // 0' <<<"$payload")"
missing_terminal="$(jq -r '.summary.missing_terminal_audit // 0' <<<"$payload")"
missing_docs="$(jq -r '.summary.missing_projection_docs // 0' <<<"$payload")"
orphan_docs="$(jq -r '.summary.orphan_projection_docs // 0' <<<"$payload")"
dup_ids="$(jq -r '.summary.duplicate_plan_ids // 0' <<<"$payload")"
unfixable="$(jq -r '.summary.unfixable_rows // 0' <<<"$payload")"

if [[ "$rc" -ne 0 ]]; then
  errors_joined="$(jq -r '(.errors // [])[:8] | join("; ")' <<<"$payload")"
  fail "plans lifecycle drift detected (noncanonical=$noncanonical missing_terminal=$missing_terminal missing_docs=$missing_docs orphan_docs=$orphan_docs duplicate_ids=$dup_ids unfixable=$unfixable) ${errors_joined:+errors=$errors_joined}"
fi

echo "D343 PASS: plans lifecycle integrity clean (noncanonical=$noncanonical missing_terminal=$missing_terminal missing_docs=$missing_docs orphan_docs=$orphan_docs duplicate_ids=$dup_ids unfixable=$unfixable)"
