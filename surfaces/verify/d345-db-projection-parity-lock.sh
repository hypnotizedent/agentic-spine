#!/usr/bin/env bash
# TRIAGE: enforce SQLite plans authority parity with YAML projections.
# D345: db-projection-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RECONCILE_BIN="$ROOT/ops/plugins/lifecycle/bin/planning-plans-reconcile"

fail() {
  echo "D345 FAIL: $*" >&2
  exit 1
}

[[ -x "$RECONCILE_BIN" ]] || fail "missing reconcile runner: $RECONCILE_BIN"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

set +e
payload="$($RECONCILE_BIN --check --json 2>/dev/null)"
rc=$?
set -e

[[ -n "$payload" ]] || fail "planning.plans.reconcile returned empty payload"

sqlite_ok="$(jq -r '.summary.sqlite_integrity_ok // 0' <<<"$payload")"
parity_mismatch="$(jq -r '.summary.projection_parity_mismatch // 1' <<<"$payload")"
watermark_mismatch="$(jq -r '.summary.watermark_mismatch // 1' <<<"$payload")"
missing_docs="$(jq -r '.summary.missing_projection_docs // 0' <<<"$payload")"
orphan_docs="$(jq -r '.summary.orphan_projection_docs // 0' <<<"$payload")"

if [[ "$rc" -ne 0 || "$sqlite_ok" != "1" || "$parity_mismatch" != "0" || "$watermark_mismatch" != "0" || "$missing_docs" != "0" || "$orphan_docs" != "0" ]]; then
  errors_joined="$(jq -r '(.errors // [])[:8] | join("; ")' <<<"$payload")"
  fail "parity drift rc=$rc sqlite_ok=$sqlite_ok parity_mismatch=$parity_mismatch watermark_mismatch=$watermark_mismatch missing_docs=$missing_docs orphan_docs=$orphan_docs ${errors_joined:+errors=$errors_joined}"
fi

echo "D345 PASS: SQLite authority and YAML projections are in parity"
