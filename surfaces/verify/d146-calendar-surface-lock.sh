#!/usr/bin/env bash
# TRIAGE: Calendar surface matrix lock (capabilities, contracts, artifacts, and AOF control-plane integration)
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AUDIT_BIN="$ROOT/ops/plugins/verify/bin/calendar-surface-audit"

fail() {
  echo "D146 FAIL: $*" >&2
  exit 1
}

[[ -x "$AUDIT_BIN" ]] || fail "missing audit runtime: $AUDIT_BIN"
command -v jq >/dev/null 2>&1 || fail "required tool missing: jq"

audit_json="$(mktemp)"
if "$AUDIT_BIN" --check-only --json >"$audit_json" 2>/tmp/d146-calendar-surface-lock.err; then
  status="$(jq -r '.status // ""' "$audit_json" 2>/dev/null || true)"
  passed="$(jq -r '.data.summary.checks_passed // 0' "$audit_json" 2>/dev/null || echo 0)"
  failed="$(jq -r '.data.summary.checks_failed // 0' "$audit_json" 2>/dev/null || echo 0)"
  if [[ "$status" != "pass" ]]; then
    detail="$(jq -r '.data.failures[0] // "unknown failure"' "$audit_json" 2>/dev/null || echo "unknown failure")"
    rm -f "$audit_json" >/dev/null 2>&1 || true
    fail "calendar surface audit status=$status (${detail})"
  fi
  echo "D146 PASS: calendar surface matrix lock valid (checks_passed=$passed checks_failed=$failed)"
  rm -f "$audit_json" >/dev/null 2>&1 || true
  exit 0
fi

detail="$(sed -n '1,4p' /tmp/d146-calendar-surface-lock.err | tr '\n' ' ' | xargs || true)"
rm -f "$audit_json" >/dev/null 2>&1 || true
fail "calendar surface audit execution failed (${detail:-unknown error})"
