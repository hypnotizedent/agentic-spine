#!/usr/bin/env bash
# TRIAGE: Ensure top-level runtime scripts source job-wrapper and use spine_job_run.
# D296: runtime job-wrapper enforcement lock
# Enforce that every top-level scheduled runtime script sources job-wrapper
# and executes through spine_job_run for uniform telemetry + alerting.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_DIR="$ROOT/ops/runtime"

fail() {
  echo "D296 FAIL: $*" >&2
  exit 1
}

[[ -d "$RUNTIME_DIR" ]] || fail "runtime dir missing: $RUNTIME_DIR"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

violations=0
scripts_checked=0

for script in "$RUNTIME_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  scripts_checked=$((scripts_checked + 1))
  rel="ops/runtime/$(basename "$script")"

  if ! rg -n 'ops/runtime/lib/job-wrapper\.sh' "$script" >/dev/null 2>&1; then
    echo "D296 HIT: missing job-wrapper source in $rel" >&2
    violations=$((violations + 1))
  fi

  if ! rg -n '\bspine_job_run\b' "$script" >/dev/null 2>&1; then
    echo "D296 HIT: missing spine_job_run invocation in $rel" >&2
    violations=$((violations + 1))
  fi
done

if [[ "$scripts_checked" -eq 0 ]]; then
  fail "no runtime scripts found under $RUNTIME_DIR"
fi

if [[ "$violations" -gt 0 ]]; then
  fail "runtime job-wrapper enforcement violations=${violations} scripts_checked=${scripts_checked}"
fi

echo "D296 PASS: runtime job-wrapper enforcement clean (scripts_checked=${scripts_checked})"
