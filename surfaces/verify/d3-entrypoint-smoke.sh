#!/usr/bin/env bash
# TRIAGE: Validate bin/ops entrypoint wiring without invoking heavyweight preflight.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

if [[ ! -x "$ROOT/bin/ops" ]]; then
  echo "D3 FAIL: missing executable bin/ops at $ROOT/bin/ops" >&2
  exit 1
fi

[[ -f "$ROOT/ops/capabilities.yaml" ]] || {
  echo "D3 FAIL: missing capabilities registry at $ROOT/ops/capabilities.yaml" >&2
  exit 1
}

# Keep D3 as an entrypoint smoke check only; avoid status aggregation cost.
if "$ROOT/bin/ops" --help >/dev/null 2>&1 && "$ROOT/bin/ops" cap list >/dev/null 2>&1; then
  echo "D3 PASS: entrypoint smoke checks succeeded"
  exit 0
fi

echo "D3 FAIL: bin/ops smoke checks failed (--help/cap list)" >&2
exit 1
